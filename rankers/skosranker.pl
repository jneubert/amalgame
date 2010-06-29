:- module(skosranker,
	  [
	   justify_candidates/3
	  ]
	 ).

:- use_module(library(semweb/rdf_db)).
:- use_module('../edoal/edoal').
:- use_module('../namespaces.pl').

match_property(propmatch/def,  P):- rdf_equal(skos:definition, P).
match_property(propmatch/pref, P):- rdf_equal(skos:prefLabel, P).
match_property(propmatch/alt,  P):- rdf_equal(skos:altLabel, P).

justify_candidates(C1, S2, Options) :-
	findall(Cand,
		(   rdf_has(Cand, align:entity1, C1),
		    rdf_has(Cand, align:entity2, C2),
		    rdf_has(C2, skos:inScheme, S2)
		),
		Candidates
	       ),
	findall(Cand:Justifications,
		(   member(Cand, Candidates),
		    justify(Cand, Options, Justifications)
		),
	       _JustList).

justify(Cand, Options, Justifications) :-
	findall(Justification,
		justification(Cand, Options, Justification),
		Justifications).



justification(Cell, Options, Justification) :-
	option(graph(Graph), Options, align),
	match_property(_MatchType, Property),
	rdf_has(Cell, align:entity1, E1),
	rdf_has(Cell, align:entity2, E2),

	(   rdf_has(E1, Property, Value, RealProp1),
	    rdf_has(E2, Property, Value, RealProp2)
	->  Value = TestValue1, Value = TestValue2
	;   rdf_has(E1, Property, literal(lang(Lang1, Value)), RealProp1),
	    rdf_has(E2, Property, literal(lang(Lang2, Value)), RealProp2),
	    lang_equiv(Lang1, Lang2),
	    TestValue1 = literal(lang(Lang1, Value)),
	    TestValue2 = literal(lang(Lang2, Value))
	),

	rdf_has(E1, skos:inScheme, Scheme1),
	rdf_has(E2, skos:inScheme, Scheme2),
	findall(Occurence1,
		(   rdf_has(Occurence1, Property, TestValue1),
		    rdf_has(Occurence1, skos:inScheme, Scheme1)
		),
		Occurences1),
	findall(Occurence2,
		(   rdf_has(Occurence2, Property, TestValue2),
		    rdf_has(Occurence2, skos:inScheme, Scheme2)
		),
		Occurences2),
	length(Occurences1, Freq1),
	length(Occurences2, Freq2),

	format(atom(Justification), 'exact match: ~p:~w/~p:~w',
	       [RealProp1,Freq1,RealProp2, Freq2]),
	rdf_assert(Cell, amalgame:justification, literal(Justification), Graph).




lang_equiv(L1, L2) :-
	downcase_atom(L1, Lower),
	downcase_atom(L2, Lower).







