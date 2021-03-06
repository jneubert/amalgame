:- module(am_vocstats,
	  [
	      is_vocabulary/1,
	      voc_property/2,
	      voc_property/3,
	      voc_clear_stats/1,
	      concept_list_depth_stats/3,
	      concept_list_branch_stats/3
          ]).

:- use_module(library(semweb/rdfs)).
:- use_module(library(semweb/rdf_db)).

:- use_module(library(stat_lists)).
:- use_module(library(amalgame/map)).
:- use_module(library(amalgame/ag_provenance)).
:- use_module(library(amalgame/vocabulary)).

/** <module> Compute and cache vocabulary-oriented properties and statistics.

Currently supported statistical properties include:
* version(Literal)
* revision (Literal)
* format(oneof([skos,skosxl,null]))
* numberOfConcepts(xsd:int)
* numberOfPrefLabels(xsd:int)
* numberOfAltLabels(xsd:int)
* numberOfMappedConcepts(xsd:int)
* numberOfHomonyms(label_property, xsd:int)
* languages(list)
* languages(label_property, list)

@author Jacco van Ossenbruggen
*/

:- dynamic
	voc_stats_cache/2.

:- rdf_meta
	children(r,r,t,t),
	has_child(r,r,-),
	voc_property(r, -),
	voc_languages(r,-),
	voc_languages(r,r,-),
	voc_languages_used(r,r,-),
	count_labels(r,r,-,-,-),
	count_homonyms(r,r,-).

voc_property(Voc, P) :-
	voc_property(Voc, P, []).

voc_property(Voc, P, Options) :-
	rdf_global_term(P, PG),
	(   voc_stats_cache(Voc, PG)
	->  true
	;   (   option(compute(no), Options)
	    ->  fail
	    ;   voc_ensure_stats(Voc, PG)
	    )
	).

assert_voc_prop(Voc, M) :-
	assert(voc_stats_cache(Voc, M)).


voc_clear_stats(all) :-
	retractall(voc_stats_cache(_,_)),
	rdf_unload_graph(vocstats),
	print_message(informational, map(cleared, 'vocabulary statistics', all_vocs, all)).

voc_clear_stats(Voc) :-
	retractall(voc_stats_cache(Voc, _)),
	print_message(informational, map(cleared, 'vocabulary statistics', Voc, all)).


is_vocabulary(Voc) :-
	rdfs_individual_of(Voc, skos:'ConceptScheme').

is_vocabulary(Voc) :-
	rdfs_individual_of(Voc, amalgame:'Alignable').

voc_ensure_stats(Voc, virtual(Result)) :-
	(   rdf_has(_, skos:inScheme, Voc)
	->  Virtual = false
	;   rdfs_individual_of(Voc, amalgame:'Alignable')
	->  Virtual = false
	;   Virtual = true
	),
	assert(voc_stats_cache(Voc, virtual(Virtual))),
	Result = Virtual.

voc_ensure_stats(Voc, format(Format)) :-
	rdfs_individual_of(Voc, skos:'ConceptScheme'),
	(   voc_stats_cache(Voc, format(Format))
	->  true
	;   voc_find_format(Voc, Format),
	    assert(voc_stats_cache(Voc, format(Format)))
	).

voc_ensure_stats(Voc, version(Version)) :-
	(   rdf_has(Voc, owl:versionInfo, literal(Version))
	->  true
	;   Version = ''
	),
	assert(voc_stats_cache(Voc, version(Version))).

voc_ensure_stats(Voc, revision(Revision)) :-
	(   rdf(Voc, amalgame:wasGeneratedBy, _)
	->  Revision = amalgame_generated
	;   assert_voc_version(Voc, Revision)
	->  true
	;   debug(info, 'Failed to ensure revision stats for ~p', [Voc]),
	    Revision = '?'
	),
	assert(voc_stats_cache(Voc, revision(Revision))).

voc_ensure_stats(Voc, numberOfConcepts(Count)) :-
	(   count_concepts(Voc, Count) -> true ; Count = 0),
	assert_voc_prop(Voc, numberOfConcepts(Count)).
voc_ensure_stats(Voc, numberOfLabels(Prop, Lang, LCount, CCount)) :-
	(   count_labels(Voc, Prop, Lang, LCount, CCount)
	->  format(atom(ILabel), '~p ~p ~w', [Voc, Prop, Lang]),
	    print_message(informational, map(found, 'labels', ILabel, LCount)),
	    print_message(informational, map(found, 'concepts with labels', ILabel, CCount))
	;   LCount = 0, CCount = 0),
	assert_voc_prop(Voc, numberOfLabels(Prop, Lang, LCount, CCount)).
voc_ensure_stats(Voc, numberOfUniqueLabels(P, Lang, Lcount, Ccount)) :-
	(   count_unique_labels(Voc, P, Lang, Lcount, Ccount) -> true ; Lcount = 0, Ccount=0),
	assert_voc_prop(Voc, numberOfUniqueLabels(P, Lang, Lcount, Ccount)).
voc_ensure_stats(Voc, numberOfMappedConcepts(Count)) :-
	(   count_mapped_concepts(Voc, Count) -> true ; Count = 0),
	assert_voc_prop(Voc, numberOfMappedConcepts(Count)).
voc_ensure_stats(Voc, languages(L)) :-
	(   voc_languages_used(Voc, L) -> true ; L = []),
	assert(voc_stats_cache(Voc, languages(L))).
voc_ensure_stats(Voc, languages(P,L)) :-
	(   voc_languages_used(Voc, P, L) -> true ; L = []),
	assert(voc_stats_cache(Voc, languages(P,L))).
voc_ensure_stats(Voc, numberOfHomonyms(P, Lang, Lcount, Ccount)) :-
	(   count_homonyms(Voc, P, Lang, Lcount, Ccount) -> true ; Lcount = 0, Ccount=0),
	assert_voc_prop(Voc, numberOfHomonyms(P, Lang, Lcount, Ccount)).
voc_ensure_stats(Voc, depth(Stats)) :-
	(  compute_depth_stats(Voc, depth(Stats)) -> true ; Stats = []),
	assert_voc_prop(Voc, depth(Stats)).
voc_ensure_stats(Voc, branch(Stats)) :-
	(  compute_branch_stats(Voc, branch(Stats)) -> true ; Stats = []),
	assert_voc_prop(Voc, branch(Stats)).
voc_ensure_stats(Voc, nrOfTopConcepts(Count)) :-
	voc_property(Voc, depth(_)), % ensure nrOfTopConcepts has been computed
	(   rdf(Voc, amalgame:nrOfTopConcepts, literal(type(xsd:int, Count))) -> true ; Count = 0 ),
	assert_voc_prop(Voc, nrOfTopConcepts(Count)).


%%	assert_voc_version(+Voc, +TargetGraph) is det.
%
%	Assert version of Voc using RDF triples in named graph TargetGraph.

assert_voc_version(Voc, Version) :-
	(   rdf(Voc, amalgame:subSchemeOf, SuperVoc)
	->  assert_subvoc_version(Voc, SuperVoc, Version)
	;   assert_supervoc_version(Voc, Version)
	).

assert_subvoc_version(Voc, SuperVoc, Version) :-
	rdf_has(SuperVoc, owl:versionInfo, Version),
	assert(voc_stats_cache(Voc, version(Version))).

assert_supervoc_version(Voc, Version) :-
	rdf(_, skos:inScheme, Voc, SourceGraph:_),!,
	prov_get_entity_version(Voc, SourceGraph, Version).
assert_supervoc_version(Voc, Version) :-
	rdf(Voc, amalgame:graph, SourceGraph), !,
	prov_get_entity_version(Voc, SourceGraph, Version).

count_concepts(Voc, Count) :-
	findall(Concept,
		vocab_member(Concept, Voc),
		Concepts),
	length(Concepts, Count),
	print_message(informational, map(found, 'Concepts', Voc, Count)).

count_labels(Voc, Property, Lang, CCount, LCount) :-
	var(Lang),
	findall(Label-Concept,
		(   vocab_member(Concept, Voc),
		    (	rdf_has(Concept, Property, literal(lang(Lang,Label))),
			var(Lang)
		    ;	rdf_has(Concept, Property, LabelObject),
			rdf_has(LabelObject,   skosxl:literalForm, literal(Label)),
			atom(Label)
		    )
		),
		Pairs),
	keysort(Pairs, Sorted),
	Lang='?',
	assert_voc_prop(Voc, cp_pairs(Property, Lang, Sorted)),
	pairs_values(Sorted, Concepts),
	sort(Concepts, ConceptsUnique),
	length(Sorted, LCount),
	length(ConceptsUnique, CCount).

count_labels(Voc, Property, Lang, LCount, CCount) :-
	findall(Label-Concept,
		(   vocab_member(Concept, Voc),
		    (	rdf_has(Concept, Property, literal(lang(Lang,Label)))
		    ;	rdf_has(Concept, Property, LabelObject),
			rdf_has(LabelObject,   skosxl:literalForm, literal(lang(Lang,Label)))
		    )
		),
		Pairs),
	keysort(Pairs, Sorted),
	assert_voc_prop(Voc, cp_pairs(Property, Lang, Sorted)),
	pairs_values(Sorted, Concepts),
	sort(Concepts, ConceptsUnique),
	length(Sorted, LCount),
	length(ConceptsUnique, CCount).

count_unique_labels(Voc, Prop, Lang, LabelCount, ConceptCount) :-
	voc_property(Voc, numberOfLabels(Prop, Lang, _, _)), % fill cache if needed
	voc_stats_cache(Voc, cp_pairs(Prop, Lang, Sorted)),
	group_pairs_by_key(Sorted, Grouped),
	include(is_unique_label, Grouped, Uniques),
	pairs_values(Uniques, ConceptsL),
	pairs_keys(Uniques, Labels),
	append(ConceptsL, Concepts),
	sort(Concepts, ConceptsUnique),
	sort(Labels, LabelsUnique),
	length(LabelsUnique, LabelCount),
	length(ConceptsUnique, ConceptCount),
	print_message(informational, map(found, 'unique labels', Voc, LabelCount)),
	print_message(informational, map(found, 'unique concepts', Voc, ConceptCount)).

count_homonyms(Voc, Prop, Lang, LabelCount, ConceptCount) :-
	voc_property(Voc, numberOfLabels(Prop, Lang, _, _)), % fill cache if needed
	voc_stats_cache(Voc, cp_pairs(Prop, Lang, Sorted)),
	group_pairs_by_key(Sorted, Grouped),
	include(is_homonym, Grouped, Homonyms),
	pairs_values(Homonyms, AmbConceptsL),
	append(AmbConceptsL, AmbConcepts),
	sort(AmbConcepts, AmbConceptsUnique),
	length(Homonyms, LabelCount),
	length(AmbConceptsUnique, ConceptCount),
	print_message(informational, map(found, 'ambiguous labels', Voc, LabelCount)),
	print_message(informational, map(found, 'ambiguous concepts', Voc, ConceptCount)).

is_unique_label(_Label-[_Concept]).

is_homonym(_Label-Concepts) :-
	length(Concepts, N), N > 1.

count_mapped_concepts(Voc, Count) :-
	findall(C,
		(   vocab_member(C, Voc),
		    (	has_correspondence_chk(align(C, _, _), _)
		    ;	has_correspondence_chk(align(_, C, _), _)
		    )
                ),
		Concepts),
	sort(Concepts, Sorted),
	length(Sorted, Count),
	print_message(informational, map(found, 'SKOS mapped concepts', Voc, Count)).

voc_languages_used(all, Langs) :-
	findall(L,
		(   rdfs_individual_of(Voc, skos:'ConceptScheme'),
		    voc_languages_used(Voc, L)
		),
		Ls),
	flatten(Ls, Flat),
	sort(Flat, Langs).

voc_languages_used(Voc, Langs) :-
	(   setof(Lang, language_used(Voc, Lang), Langs)
	->  true
	;   Langs = []
	).

voc_languages_used(Voc, Prop, Langs) :-
	(   setof(Lang, language_used(Voc, Prop, Lang), Langs)
	->  true
	;   Langs = []
	).

language_used(Voc, Lang) :-
	language_used(Voc, _Prop, Lang).

language_used(Voc, Prop, Lang) :-
	vocab_member(Concept, Voc),
	(   rdf_has(Concept, Prop, LabelObject),
	    rdf_is_resource(LabelObject),
	    rdf_has(LabelObject, skosxl:literalForm, literal(lang(Lang, _)))
	;   rdf_has(Concept, Prop, literal(lang(Lang, _)))
	),
	ground(Lang).

voc_find_format(Voc, Format) :-
	ground(Voc),
	(   vocab_member(Concept, Voc)
	->  (   rdf_has(Concept, skosxl:prefLabel, _)
	    ->  Format = skosxl
	    ;   rdf_has(Concept, skos:prefLabel, _)
	    ->  Format = skos
	    ;   rdf_has(Concept, skos:altLabel, _)
	    ->  Format = skos
	    ;   Format = null           % no concepts with known labels
	    )
	;   Format = null		% no concepts in the scheme
	).

compute_depth_stats(Voc, depth(Stats)) :-
	with_mutex(Voc,
		   (   assert_depth(Voc),
		       findall(Concept, vocab_member(Concept, Voc), Concepts),
		       maplist(concept_depth, Concepts, Depths),
		       sort(Depths, SortedDepths),
		       list_five_number_summary(SortedDepths, Stats)
		   )
		  ).

compute_branch_stats(Voc, branch([Tops|Stats])) :-
	voc_property(Voc, depth(_)), % ensure basic depth stats for voc have been computed
	rdf(Voc, amalgame:nrOfTopConcepts, literal(type(xsd:int, NrTops)), vocstats),
	Tops = nrOfTopConcepts(NrTops),
	with_mutex(Voc,
		   (
		       findall(Concept, vocab_member(Concept, Voc), Concepts),
		       maplist(concept_children_count, Concepts, Children),
		       sort(Children, ChildrenS),
		       list_five_number_summary(ChildrenS, Stats)
		   )
		  ).

concept_list_depth_stats([], _Voc, depth([])) :-!.
concept_list_depth_stats(CList, Voc, depth(Stats)) :-
	voc_property(Voc, depth(_), [compute(no)]), % only if basic depth stats for voc already computed
	maplist(concept_depth, CList, Depths),
	sort(Depths, DepthsSorted),
	list_five_number_summary(DepthsSorted, Stats).

concept_list_branch_stats([], _Voc, branch([])) :-!.
concept_list_branch_stats(CList, Voc, branch([Tops|Stats])) :-
	Tops = nrOfTopConcepts(TopConceptsCount),
	findall(TopConcept,
		(   member(TopConcept, CList),
		    \+ (parent_child_chk(Child, TopConcept),
			vocab_member(Child, Voc)
		       )
		),
		TopConcepts),
	length(TopConcepts, TopConceptsCount),
	voc_property(Voc, depth(_)), % ensure basic depth stats for voc have been computed
	maplist(concept_children_count, CList, Children),
	sort(Children, ChildrenSorted),
	list_five_number_summary(ChildrenSorted, Stats).

concept_depth(C, D) :-
	 rdf(C, amalgame:depth, literal(type(xsd:int, D))),!.
concept_depth(C, 0) :-
	debug(depth, 'Warning: no depth assigned to ~p', [C]). % probably another cycle error

concept_children_count(C,S) :-
	rdf(C, amalgame:nrOfChildren, literal(type(xsd:int, S))),!.
concept_children_count(C,0) :-
	debug(depth, 'Warning: no children count assigned to ~p', [C]). % probably another cycle error

assert_depth(Voc) :-
	findall(Concept, vocab_member(Concept, Voc), AllConcepts),

	findall(TopConcept,
		(   member(TopConcept, AllConcepts),
		    \+ (parent_child_chk(Child, TopConcept),
			vocab_member(Child, Voc)
		       )
		),
		TopConcepts),
	length(TopConcepts, TopConceptsCount),
	rdf_assert(Voc, amalgame:nrOfTopConcepts, literal(type(xsd:int, TopConceptsCount)), vocstats),
	forall(member(C, TopConcepts),
	       assert_depth(C, Voc, 1)
	      ).

assert_depth(Concept, _Voc, _Depth) :-
	rdf(Concept, amalgame:depth, _),
	!. % done already, dual hierarchy & loop detection

assert_depth(Concept, Voc, Depth) :-
	findall(Child,
		(   parent_child(Concept, Child),
		    vocab_member(Child, Voc)
		),
		Children),
	length(Children, ChildrenCount),
	rdf_assert(Concept, amalgame:depth,        literal(type(xsd:int, Depth)), vocstats),
	rdf_assert(Concept, amalgame:nrOfChildren, literal(type(xsd:int, ChildrenCount)), vocstats),
	NewDepth is Depth + 1,

	forall(member(C, Children),
	       assert_depth(C, Voc, NewDepth)
	      ).

parent_child_chk(P,C) :-
	parent_child(P,C),!.

parent_child(Parent, Child) :-
	(   rdf_has(Child, skos:broader, Parent)
	;   rdf_has(Parent, skos:narrower, Child)
	),
	Parent \= Child.

%%	mean_std(List, Stats) is det.
%
%	This recursive version is adapted from the incremental version
%	at:
%	http://stackoverflow.com/questions/895929/how-do-i-determine-the-standard-deviation-stddev-of-a-set-of-values
%
%

mean_std([], [length(0)]) :- !.
mean_std(List, Stats) :-
	Stats = [mean(Mean),
		 standard_deviation(Std),
		 max(Max),
		 min(Min),
		 length(K)
		],
	mean_std_(List, Mean, S, Min, Max, K),
	Std is sqrt(S/K).

mean_std_([Value], Value, 0, Value, Value, 1) :- !.
mean_std_([Value|Tail], Mean, S, Min, Max, K) :-
	!,
	mean_std_(Tail, Tmean, Tstd, Tmin, Tmax, Tk),
	K is Tk + 1,
	Max is max(Tmax, Value),
	Min is min(Tmin, Value),
	Mean is Tmean + (Value - Tmean) / K,
	S is Tstd  + (Value - Tmean) * (Value - Mean).






