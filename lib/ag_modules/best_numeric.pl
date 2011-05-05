:- module(best_numeric, []).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(amalgame/map)).

:- public amalgame_module/1.
:- public selecter/5.
:- public parameter/4.

parameter(type,
	  oneof(source,target), source,
	  'Select best sources or best targets').


amalgame_module(amalgame:'BestNumeric').


%%      selecter(+Source, -Selected, -Discarded, -Undecided, +Options)
%
%

selecter(AlignmentGraph, Sel, Disc, Und, Options) :-
	option(disamb(SourceOrTarget), Options, source),
	(   SourceOrTarget = target
	->  predsort(ag_map:compare_align(sourceplus), AlignmentGraph, SortedAlignmentGraph)
	;   predsort(ag_map:compare_align(targetplus), AlignmentGraph, SortedAlignmentGraph)
	),
	partition_(SourceOrTarget, SortedAlignmentGraph, Sel, Disc, Und).

partition_(_, [], [], [], []) :- !.
partition_(SourceOrTarget, [align(S,T,P)|As], Sel, Dis, Und) :-
	(   SourceOrTarget = target
	->  same_source(As, S, Same, Rest)
	;   same_target(As, T, Same, Rest)
	),
	(   best_numeric([align(S,T,P)|Same], Selected, Discarded)
	->  Sel = [Selected|SelRest],
	    append(Discarded, DisRest, Dis),
	    Und = UndRest
	;   append([align(S,T,P)|Same], UndRest, Und),
	    Sel = SelRest,
	    Dis = DisRest
	),
	partition_(SourceOrTarget, Rest, SelRest, DisRest, UndRest).

same_source([align(S,T,P)|As], S, [align(S,T,P)|Same], Rest) :-	!,  same_source(As, S, Same, Rest).
same_source(As, _S, [], As).

same_target([align(S,T,P)|As], T, [align(S,T,P)|Same], Rest) :-	!,  same_target(As, T, Same, Rest).
same_target(As, _S, [], As).

best_numeric(As, Selected, Discarded) :-
	group_match(As, Counts0),
	!,
	(   Counts0 = [_N-Selected]
	->  Discarded = []
	;   sort(Counts0, Counts),
	    reverse(Counts, [N-Selected,N1-A|T0]),
	    N > N1,
	    pairs_values(T0, T),
	    Discarded = [A|T]
	).

group_match([], []).
group_match([Align|As], [Match-Align|Ts]) :-
	Align = align(_,_,Provenance),
	member(P, Provenance),
	% memberchk(method(M), P),
	% memberchk(M, [jaccard, isub]),
	memberchk(match(Match), P),
  	group_match(As, Ts).