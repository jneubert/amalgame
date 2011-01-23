:- module(most_methods, []).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).

:- public partition/3.
:- multifile amalgame:component/2.

amalgame:component(partition, most_methods(alignment_graph, [selected(alignment_graph),
							     discarded(alignment_graph),
							     undecided(alignment_graph)
							    ], [])).

%%	partition(+Input, -Output, +Options)
%
%	Output a list of graphs where the first element contains
%	all ambiguous alignments and the second the unambiguous
%	ones.
%       Input is a sorted list of alignment terms.

partition(AlignmentGraph, ListOfGraphs, _Options) :-
	ListOfGraphs = [selected(S),
			discarded(D),
			undecided(U)
		      ],
	partition_(AlignmentGraph, S, D, U).

partition_([], [], [], []).
partition_([align(S,T,P)|As], Sel, Dis, Und) :-
	same_source(As, S, Same, Rest),
	(   most_methods([align(S,T,P)|Same], Selected, Discarded)
	->  Sel = [Selected|SelRest],
	    append(Discarded, DisRest, Dis),
	    Und = UndRest
	;   append([align(S,T,P)|Same], UndRest, Und),
	    Sel = SelRest,
	    Dis = DisRest
	),
	partition_(Rest, SelRest, DisRest, UndRest).

same_source([align(S,T,P)|As], S, [align(S,T,P)|Same], Rest) :-
	!,
	same_source(As, S, Same, Rest).
same_source(As, _S, [], As).


most_methods(As, Selected, [A|T]) :-
	group_method_count(As, Counts),
	sort(Counts, [N-Selected,N1-A|T0]),
	pairs_values(T0, T),
	\+ N == N1.

group_method_count([], []).
group_method_count([Align|As], [Count-Align|Ts]) :-
	Align = align(_,_,Provenance),
	findall(M, (member(P,Provenance),memberchk(M,P)), Methods),
	length(Methods, Count0),
	Count is 1/Count0,
 	group_method_count(As, Ts).
