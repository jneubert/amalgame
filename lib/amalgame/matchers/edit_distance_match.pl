:- module(edit_distance_match,
	  []).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(lit_distance)).

:- public match/3.
:- multifile amalgame:component/2.

amalgame:component(matcher, edit_distance_match(align(uri, uri, provenance), align(uri,uri,provenance),
					      [sourcelabel(uri, [default(rdfs:label)]),
					       targetlabel(uri, [default(rdfs:label)]),
					       threshold(integer)
					      ])).

match(align(Source, Target, Prov0), align(Source, Target, [Prov|Prov0]), Options) :-
	rdf_equal(rdfs:label, DefaultProp),
 	option(sourcelabel(MatchProp1), Options, DefaultProp),
	option(targetlabel(MatchProp2), Options, DefaultProp),
	option(matchacross_lang(MatchAcross), Options, _),
	option(language(SourceLang),Options, _),
	option(case_sensitive(CaseSensitive), Options, false),
	option(threshold(Threshold), Options, 4),

	rdf_has(Source, MatchProp1, literal(lang(SourceLang, SourceLabel)), SourceProp),
	(   var(SourceLang)
	->  LangString = 'all'
	;   LangString = SourceLang
	),
	(   CaseSensitive==true
	->  CaseString=cs;
	    CaseString=ci
	),

        % If we can't match across languages, set target language to source language
	(   MatchAcross == false
	->  TargetLang = SourceLang
	;   true
	),

	rdf_has(Target, MatchProp2, literal(lang(TargetLang, TargetLabel)), TargetProp),
	Source \== Target,
	literal_distance(SourceLabel, TargetLabel, Distance),
	Distance < Threshold,
	Prov = [method(edit_distance_match),
		match([distance(Distance)]),
		graph([rdf(Source, SourceProp, literal(lang(SourceLang, SourceLabel))),
		       rdf(Target, TargetProp, literal(lang(TargetLang, TargetLabel)))])
	       ].
