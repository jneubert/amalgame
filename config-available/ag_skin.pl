:- module(ag_skin, []).

:- use_module(library(version)).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/html_head)).
:- use_module(library(http/http_path)).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(semweb/rdf_label)).

:- use_module(cliopatria(hooks)).
:- use_module(skin(cliopatria)).
:- use_module(components(label)).
:- use_module(components(menu)).
:- use_module(components(simple_search)).

:- set_setting_default(graphviz:format, svg).

:- html_resource(css('amalgame.css'),
		 [requires([ css('cliopatria.css')
			   ])
		 ]).
:- html_resource(cliopatria,
		 [ virtual(true),
		   requires([ css('amalgame.css')
			    ])
		 ]).
/*
cliopatria:resource_link(Alignment, Link) :-
	rdfs_individual_of(Alignment, amalgame:'Alignment'),
	http_link_to_id(http_list_alignment, [graph(Alignment)], Link).
cliopatria:resource_link(Voc, Link) :-
	rdfs_individual_of(Voc, skos:'ConceptScheme'),
	http_link_to_id(http_list_skos_voc, [voc(Voc)], Link).
*/
cliopatria:display_link(Cell, _Options) -->
	{
	 rdfs_individual_of(Cell, align:'Cell'),
	 resource_link(Cell, HREF)
	},
	html(a([class(r_def), href(HREF)], ['Map: ', \turtle_label(Cell)])).

rdf_label:display_label_hook(Cell, _Lang, Label) :-
	rdfs_individual_of(Cell, align:'Cell'),
	atom_concat('Map: ', Cell, Label).

cliopatria:predicate_order(P, "zzz") :- rdf_equal(align:map, P).
cliopatria:predicate_order(P, 400) :-
	rdf_has(P, rdfs:isDefinedBy, 'http://purl.org/net/opmv/ns').
cliopatria:predicate_order(P, 405) :-
	rdf_has(P, rdfs:isDefinedBy, 'http://purl.org/vocabularies/amalgame').

cliopatria:bnode_label(TimeInstant) -->
	{ rdf(TimeInstant, time:inXSDDateTime, Literal)
	},
	html(\turtle_label(Literal)).

user:body(amalgame(search), Body) -->
	{
	 http_link_to_id(http_list_skos_vocs, [], BackOfficeLink)
	},
	html_requires(cliopatria),
	html(body(class(['yui-skin-sam', ag_search, cliopatria]),
		  [
		    div(class(ag_search),
			[
			 \simple_search_form,
			 div(class(content), Body)
			]),
			br(clear(all)),
			div(class(footer),
			    \(cliopatria:server_address)
			),
		        div([class(backoffice)],
			    [a(href(BackOfficeLink), 'back office')
			    ])
		  ])).

% Amalgame is an extension of ClioPatria and uses the ClioPatria
% skin.

:- multifile
        user:body//2.

user:body(user(Style), Body) -->
        user:body(cliopatria(Style), Body).
