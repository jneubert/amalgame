:- module(eq_stats,
	  [
	  ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(semweb/rdf_label)).
:- use_module(library(amalgame/amalgame_modules)).
:- use_module(library(amalgame/expand_graph)).
:- use_module(cliopatria(components/label)).

:- use_module(controls).
:- use_module(eq_util).

% http handlers for this applications

:- http_handler(amalgame(private/nodeinfo), http_eq_nodeinfo, []).
:- http_handler(amalgame(private/info), http_eq_info, []).


%%	http_eq_nodeinfo(+Request)
%
%	Emit HTML snippet with statistics for an amalgame URI

http_eq_nodeinfo(Request) :-
	http_parameters(Request,
			[ url(URL,
			      [description('URL of a node (mapping,vocab,process,strategy)')]),
			  alignment(Alignment,
				    [description('URL of the alignment strategy')])
		       ]),
	html_current_option(content_type(Type)),
	format('Content-type: ~w~n~n', [Type]),
	(   rdfs_individual_of(URL, amalgame:'Mapping')
	->  with_mutex(URL, mapping_counts(URL, Alignment, _MN, _SN, _TN, SPerc, TPerc)),
	    format('s:~w\% t:~w\%', [SPerc,TPerc])
	;   with_mutex(URL, concept_count(URL, Alignment, Count)),
	    format('~w', [Count])
	).

%%	http_eq_info(+Request)
%
%	Emit HTML snippet with information about an amalgame URI

http_eq_info(Request) :-
	http_parameters(Request,
			[ url(URL,
			      [description('URL of a node (mapping,vocab,process,strategy)')]),
			  alignment(Strategy,
				    [description('URL of the alignment strategy')])
		       ]),
	amalgame_provenance(URL, Strategy, Prov),
	amalgame_info(URL, Strategy, Stats),
	append(Prov, Stats, Info),
	amalgame_parameters(URL, Strategy, Params),
	phrase(html([\html_prop_table(Info),
		     \html_form(Params, URL)
		    ]),
	       HTML),
	html_current_option(content_type(Type)),
	format('Content-type: ~w~n~n', [Type]),
	print_html(HTML).

%%	html_prop_table(+Pairs)
%
%	Emit an HTML table with key-value pairs.

html_prop_table(Pairs) -->
	html(table(tbody(\html_rows(Pairs)))).

html_rows([]) --> !.
html_rows([Key-Value|Ss]) -->
	html_row(Key, Value),
	html_rows(Ss).

html_row(Key, set(Values)) -->
	 html(tr([th(Key),
		  td([])
		 ])),
	 html_rows(Values).
html_row(Key, Value) -->
	 html(tr([th(Key),
		  td(\html_cell(Value))
		])).

html_cell([]) --> !.
html_cell(Vs) -->
	{ is_list(Vs)
	},
	!,
	html_cell_list(Vs).
html_cell(V) -->
	html(V).

html_cell_list([V]) -->
	html_cell(V).
html_cell_list([V|Vs]) -->
	html_cell(V),
	html(', '),
	html_cell_list(Vs).


%%	html_form(+Parameters, +URI)
%
%	Emit HTML with parameter form.

html_form([], _) --> !.
html_form(Params, URI) -->
	html(div(class(parameters),
		 table([input([type(hidden), name(process), value(URI)]),
			input([type(hidden), name(update), value(true)]),
			\html_parameter_form(Params)
		       ]))).



%%	amalgame_info(+Mapping, -Info)
%
%	Stats of a resourcemapping

amalgame_info(URL, Strategy, Stats) :-
	rdfs_individual_of(URL, amalgame:'Mapping'),
	!,
	Stats = ['total mappings'-MN,
		 'mapped source concepts'-SN,
		 'mapped target concepts'-TN
		],
	with_mutex(URL, mapping_counts(URL, Strategy, MN, SN0, TN0, SPerc, TPerc)),
	concat_atom([SN0, ' (',SPerc,'%)'], SN),
	concat_atom([TN0, ' (',TPerc,'%)'], TN).
amalgame_info(Scheme, Strategy,
	    ['Total concepts'-Total
	    ]) :-
	rdfs_individual_of(Scheme, skos:'ConceptScheme'),
	!,
	concept_count(Scheme, Strategy, Total).

amalgame_info(EDMGraph, _Strategy,
	    ['Total concepts'-Total
	    ]) :-
	P='http://www.europeana.eu/schemas/edm/country',
	rdf(_, P, _, EDMGraph),
	!,
	findall(I,rdf(I,P,_,EDMGraph),Is),
	sort(Is, Sorted),
	length(Sorted, Total).

amalgame_info(URL, Strategy,
	       ['type'   - \(cp_label:rdf_link(Type)),
		'about'   - Definition
	       ]) :-
	rdfs_individual_of(URL, amalgame:'Process'),
	rdf(URL, rdf:type, Type, Strategy),
	(   rdf_has(Type, skos:definition, literal(Definition))
	->  true
	;   Definition = '-'
	).

amalgame_info(_URL, _Strategy, []).


%%	amalgame_provenance(+R, +Alignment, -Provenance:[key-value])
%
%	Provenance is a list of key-value pairs with provenance about
%	node R as defined by strategy Alignment

amalgame_provenance(R, Alignment, Provenance) :-
	findall(Key-Value, ag_prov(R, Alignment, Key, Value), Provenance).

ag_prov(R, A, 'created by', \rdf_link(Agent)) :-
	(   rdf_has(R, dc:creator, Agent, RealProp),
	    rdf(R, RealProp, Agent, A)
	->  true
	;   rdf_has(R, dc:creator, Agent)
	).

ag_prov(R, _A, 'controlled by', \rdf_link(Agent)) :-
	rdf_has(R,  opmv:wasControlledBy, Agent).

ag_prov(R, _A, 'generated by', \rdf_link(Agent)) :-
	rdf(R, opmv:wasGeneratedBy, Process),
	rdf_has(Process, opmv:wasControlledBy, Agent).


ag_prov(R, A, 'created at', V) :-
	(   rdf_has(R, dc:date, V, RealProp),
	    rdf(R, RealProp, V, A)
	->  true
	;   rdf_has(R, dc:date, V)
	).
ag_prov(R, A, owl:'version', V) :-
	(   rdf_has(R, owl:versionInfo, literal(V), RealProp),
	    rdf(R, RealProp, literal(V), A)
	->  true
	;   rdf(R, owl:versionInfo, literal(V))
	).
ag_prov(Graph, Graph, contributors, Vs) :-
	rdfs_individual_of(Graph, amalgame:'AlignmentStrategy'),
	findall(V,
		(   rdf(R, _, _, Graph),
		    \+ R == Graph,
		    rdf(R, dc:creator, V),
		    \+ rdf(Graph, dc:creator, V)
		), Vs0),
	Vs0 \== [],
	!,
	sort(Vs0, Vs).

%%	amalgame_parameters(+URI, -Parmas)
%
%	Params is a list of parameters for URI.

amalgame_parameters(Process, Strategy, Params) :-
	rdfs_individual_of(Process, amalgame:'Process'),
	!,
	rdf(Process, rdf:type, Type, Strategy),
	amalgame_module_id(Type, Module),
	amalgame_module_parameters(Module, DefaultParams),
	process_options(Process, Module, CurrentValues),
	override_options(DefaultParams, CurrentValues, Params).
amalgame_parameters(_, _Strategy, []).

override_options([], _, []).
override_options([H|T], Current, [V|Results]) :-
	override_options(T, Current, Results),
	H=parameter(Id, Type, Default, Desc),
	V=parameter(Id, Type, Value,   Desc),
	Opt =.. [Id, Value],
	option(Opt, Current, Default).



