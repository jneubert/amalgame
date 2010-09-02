:- module(am_skosvocs,
          [skos_statistics/1,
	   voc_get_computed_props/2,

	   voc_ensure_stats/1
          ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(semweb/rdfs)).

:- use_module(amalgame(mappings/map)).


%%	skos_statistics(-Stats) is det.
%
%	Return a list of all skos concept schemes with statistics.
%	Stats is a list of the form URI:VocStat, where URI is the URI of
%	the scheme, and VocStat is a list with statistics on that
%	scheme.  Currently supported stats include:
%	* numberOfConcepts(N)
%	* numberOfPrefLabels(N)
%	* numberOfAltLabels(N)
%
%	Side effect: These statistics will also be asserted as RDF
%	triples to the 'amalgame' named graph, using similarly named
%	properties with the 'amalgame:' namespace prefix. These asserted
%	triples will be used in subsequent calls for efficiency reasons.
%
%	See also http_clear_cache/1.
%
skos_statistics(Stats) :-
	findall(Scheme,
		rdfs_individual_of(Scheme, skos:'ConceptScheme'),
		Schemes),
	skos_vocs_stats(Schemes, [], Stats).


voc_get_computed_props(Voc, Props) :-
	findall([PropLn, Value],
		(   rdf(Voc, Prop, Value, amalgame),
		    rdf_global_id(amalgame:PropLn, Prop)
		),
		GraphProps
	       ),
	maplist(=.., Props, GraphProps).

voc_ensure_stats(numberOfConcepts(Voc)) :-
	(   rdf(Voc,amalgame:numberOfConcepts, literal(type(_, Count)))
	->  true
	;   count_concepts(Voc, Count),
	    assert_voc_props(Voc:[numberOfConcepts(literal(type('http://www.w3.org/2001/XMLSchema#int', Count)))])
	),!.

voc_ensure_stats(numberOfPrefLabels(Voc)) :-
	(   rdf(Voc,amalgame:numberOfPrefLabels, literal(type(_, Count)))
	->  true
	;   count_prefLabels(Voc, Count),
	    assert_voc_props(Voc:[numberOfPrefLabels(literal(type('http://www.w3.org/2001/XMLSchema#int', Count)))])
	),!.

voc_ensure_stats(numberOfAltLabels(Voc)) :-
	(   rdf(Voc,amalgame:numberOfAltLabels, literal(type(_, Count)))
	->  true
	;   count_altLabels(Voc, Count),
	    assert_voc_props(Voc:[numberOfAltLabels(literal(type('http://www.w3.org/2001/XMLSchema#int', Count)))])
	),!.

voc_ensure_stats(numberOfMappedConcepts(Voc)) :-
	(   rdf(Voc,amalgame:numberOfMappedConcepts, literal(type(_, Count)))
	->  true
	;   count_mapped_concepts(Voc, Count),
	    assert_voc_props(Voc:[numberOfMappedConcepts(literal(type('http://www.w3.org/2001/XMLSchema#int', Count)))])
	),!.

assert_voc_props([]).
assert_voc_props([Head|Tail]) :-
	assert_voc_props(Head),
	assert_voc_props(Tail),!.

assert_voc_props(Voc:Props) :-
	rdf_equal(amalgame:'', NS),
	(   rdf(Voc, rdf:type, skos:'ConceptScheme')
	->  true
	;   rdf_assert(Voc, rdf:type, skos:'ConceptScheme', amalgame)
	),
	forall(member(M,Props),
	       (   M =.. [PropName, Value],
		   format(atom(URI), '~w~w', [NS,PropName]),
		   rdf_assert(Voc, URI, Value, amalgame)
	       )).

strip_sort_value(_:V:S, V:S).

skos_vocs_stats([], Unsorted, Results) :-
	sort(Unsorted, Sorted),
	maplist(strip_sort_value, Sorted, Results).

skos_vocs_stats([Voc|Tail], Accum, Stats) :-
	skos_voc_stats(Voc, SortValue, VocStats),
	skos_vocs_stats(Tail, [SortValue:Voc:VocStats|Accum], Stats).

skos_voc_stats(Voc, Count, Stats) :-
	rdf(Voc,amalgame:numberOfConcepts,   literal(type(xsd:int, Count)),  amalgame),
	rdf(Voc,amalgame:numberOfPrefLabels, literal(type(xsd:int, PCount)), amalgame),
	rdf(Voc,amalgame:numberOfAltLabels,  literal(type(xsd:int, ACount)), amalgame),
	Stats = [numberOfConcepts(Count),
		 numberOfPrefLabels(PCount),
		  numberOfAltLabels(ACount)
		].

skos_voc_stats(Voc, Count, Stats) :-
	count_concepts(Voc,   Count),
	count_prefLabels(Voc, PCount),
	count_altLabels(Voc,  ACount),
	rdf_assert(Voc,amalgame:numberOfConcepts,   literal(type(xsd:int, Count)),  amalgame),
	rdf_assert(Voc,amalgame:numberOfPrefLabels, literal(type(xsd:int, PCount)), amalgame),
	rdf_assert(Voc,amalgame:numberOfAltLabels,  literal(type(xsd:int, ACount)), amalgame),
	Stats = [numberOfConcepts(Count),
		 numberOfPrefLabels(PCount),
		 numberOfAltLabels(ACount)
		].

count_concepts(Voc, Count) :-
	findall(Concept,
		rdf(Concept, skos:inScheme, Voc),
		Concepts),
	length(Concepts, Count).

count_prefLabels(Voc, Count) :-
	findall(Label,
		(   rdf(Concept, skos:inScheme, Voc),
		    rdf_has(Concept, skos:prefLabel, literal(Label))
		),
		Labels),
	length(Labels, Count).

count_altLabels(Voc, Count) :-
	findall(Label,
		(   rdf(Concept, skos:inScheme, Voc),
		    rdf_has(Concept, skos:altLabel, literal(Label))
		),
		Labels),
	length(Labels, Count).

count_mapped_concepts(Voc, Count) :-
	findall(C,
		(   rdf(C, skos:inScheme, Voc),
		    (  	has_map([C,_], _, _); has_map([_,C], _, _) )
                ),
		Concepts),
	sort(Concepts, Sorted),
	length(Sorted, Count).
