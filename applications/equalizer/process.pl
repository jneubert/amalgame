:- module(eq_process,
	  []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(semweb/rdf_label)).

:- use_module(eq_util).

:- http_handler(amalgame(data/addprocess), http_add_process, []).

:- rdf_meta
	new_mapping_output(r,r,+).

http_add_process(Request) :-
	http_parameters(Request,
			[ input(Input,
				[uri,
				 optional(true),
				 description('URI of input mapping')]),
			  source(Source,
				 [uri,
				  optional(true),
				  description('URI of the source')]),
			  target(Target,
				 [uri,
				  optional(true),
				  description('URI of the target')]),
			  process(ProcessType,
				  [uri,
				   description('URI of the process class')]),
			  alignment(Alignment,
				    [uri,
				     description('URI of the alignment graph to which the process is added')])
			],
			[form_data(Params0)]),
	(   ((nonvar(Source), nonvar(Target)) ; nonvar(Input))
	->  rdf_bnode(ProcessURI),
	    subtract(Params0, [input=_,source=_,target=_,process=_], Params),
	    rdf_transaction((
			     assert_process(ProcessURI, ProcessType, Alignment, Params),
			     assert_input(ProcessURI, Alignment, Source, Target, Input),
			     assert_output(ProcessURI, ProcessType, Alignment)))
	),
	js_alignment_nodes(Alignment, Nodes),
	reply_json(json([nodes=json(Nodes)])).

assert_input(Process, Graph, Source, Target, _Input) :-
 	nonvar(Source),
	nonvar(Target),
	!,
	rdf_assert(Process, amalgame:source, Source, Graph),
	rdf_assert(Process, amalgame:target, Target, Graph).
assert_input(Process, Graph, _Source, _Target, Input) :-
 	rdf_assert(Process, amalgame:input, Input, Graph).

assert_process(Process, Type, Graph, Params) :-
	process_label(Type, Label),
	uri_query_components(Search, Params),
 	rdf_assert(Process, rdf:type, Type, Graph),
	rdf_assert(Process, rdfs:label, Label, Graph),
	rdf_assert(Process, amalgame:parameters, Search, Graph).

assert_output(Process, Type, Graph) :-
	rdfs_subclass_of(Type, amalgame:'Select'),
	!,
	new_mapping_output(Process, amalgame:selectedBy, Graph),
	new_mapping_output(Process, amalgame:discardedBy, Graph),
	new_mapping_output(Process, amalgame:undecidedBy, Graph).
assert_output(Process, _Type, Graph) :-
	new_mapping_output(Process, opmv:wasGeneratedBy, Graph).

new_mapping_output(Process, P, Graph) :-
	rdf_bnode(OutputURI),
	rdf_assert(OutputURI, rdf:type, amalgame:'Mapping', Graph),
        rdf_assert(OutputURI, P, Process, Graph).


process_label(P, Lit) :-
	(   rdf_label(P, L)
	->  Lit = L
	;   rdf_global_id(_:Local, P),
	    Lit = literal(Local)
	).
