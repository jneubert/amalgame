YUI.add('mappingtable', function(Y) {

	var Lang = Y.Lang,
		Node = Y.Node,
		Widget = Y.Widget;

	function MappingTable(config) {
		MappingTable.superclass.constructor.apply(this, arguments);
	}
	MappingTable.NAME = "mappingtable";
	MappingTable.ATTRS = {
		srcNode: {
			value: null
		},
		rows: {
			value:100,
			validator:function(val) {
				return Lang.isNumber(val);
			}
		},
		alignment: {
			value: null
		},
		mapping: {
			value: null
		},
		datasource: {
			value: null
		},
		loading: {
			value:false,
			validator:function(val) {
				return Lang.isBoolean(val);
			}
		}
	};

	Y.extend(MappingTable, Y.Base, {
		initializer: function(config) {
			var instance = this,
				content = this.get("srcNode");

			this._tableNode = content.appendChild(Node.create(
				'<div class="table"></div>'
			));
			this._loadingNode = content.appendChild(Node.create(
				'<div class="loading"></div>'
			));
				
			this.table = new Y.DataTable({
				columns:[{key:"source",
					       formatter:this.formatResource,
				 	       allowHTML: true,
					       sortable:true
					      },
					      {key:"relation",
					       formatter:this.formatRelation,
				 	       allowHTML: true,
					       sortable:true
					      },
					      {key:"target",
					       formatter:this.formatResource,
				 	       allowHTML: true,
					       sortable:true
					      }]
			})
			.render(this._tableNode);

			this.paginator = new Y.Paginator({
				rowsPerPage:this.get("rows"),
				template: '{FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink}',
				firstPageLinkLabel:'|&lt;',
				previousPageLinkLabel: '&lt;',
				nextPageLinkLabel: '&gt;',
				lastPageLinkLabel: '&gt;|'
			})
			.render(content.appendChild(Node.create(
				'<div class="paginator"></div>'
			)));
			this.paginator.on("changeRequest", function(state) {
				this.setPage(state.page, true);
				instance.loadData({offset:state.recordOffset}, true);
			});
			this.on('loadingChange', this._onLoadingChange, this);
			
			// get new data if mapping is changed
			this.after('mappingChange', function() {this.loadData()}, this);
			this.table.delegate('click', this._onRowSelect, '.yui3-datatable-data tr', this);
			this.loadData();
		},

		loadData : function(conf, recordsOnly) {
			var oSelf = this,
				mapping = this.get("mapping"),
				datasource = this.get("datasource"),
				alignment = this.get("alignment"),
				table = this.table,
				paginator = this.paginator;

			var callback =	{
				success: function(o) {
					var records = o.response.results,
						total = o.response.meta.totalNumberOfResults;
					if(!recordsOnly) {
						paginator.setPage(1, true);
						paginator.setTotalRecords(total, true);
					}
					table.set("data", records);
					oSelf.set("loading", false);
				}
			};

			if(mapping) {
				conf = conf ? conf : {};
				conf.url = mapping;
				conf.alignment=alignment;
				this.set("loading", true);
				datasource.sendRequest({
					request:'?'+Y.QueryString.stringify(conf),
					callback:callback
				})
			} else {
				paginator.setTotalRecords(0, true);
				table.set("data", []);
			}
		},

		formatResource : function(o) {
			var label = o.value ? o.value.label : "";
			return "<div class=resource>"+label+"</div>";
		},
		formatRelation : function(o) {
			var label = o.value ? o.value.label : "";
			label = label?label:"";
			return "<div class=relation>"+label+"</div>";
		},

		_onRowSelect : function(e) {
			var row = e.currentTarget;
				current = this.table.getRecord(e.target);
				source = current.get("source");
				target = current.get("target");
				
			var data = {
					row:row,
					sourceConcept: source,
					targetConcept: target,
					relation:current.get("relation")
				};
			Y.all(".yui3-datatable tr").removeClass("yui3-datatable-selected");
			row.addClass("yui3-datatable-selected");
			Y.log("selected correspondence: "+source.uri+" - "+target.uri);
			this.fire("rowSelect", data);
		},

		nextRow : function(row) {
			    var rows = row.get("parentNode").all("tr"),
			        i = rows.indexOf(row);

			    if (++i < rows.size()) {
			      return rows.item(i);
			    } else {
			      var begin = rows.item(0);
			      this.fire("wrapAround", begin.getXY());
			      return row; // fix me
			    }
			  },
		prevRow : function(row) {
			    var rows = row.get("parentNode").all("tr"),
			        i = rows.indexOf(row);
			    if (--i >= 0) {
			        return rows.item(i);
			    } else {
			      var end = rows.item(rows.size() - 1);
			      this.fire("wrapAround", null);
			      Y.log(end.getXY());
			      return row; // fix me
			    }
			  },
		nextRecord : function(row) {
			       var next = this.nextRow(row);
			       return id = this.table.getRecord(next.get("id"));
			     },
		prevRecord : function(row) {
			       var prev = this.prevRow(row);
			       return this.table.getRecord(prev.get("id"));
			     },
			
		_onLoadingChange : function (o) {
			if(o.newVal) {
				this._tableNode.addClass("hidden");
				this._loadingNode.removeClass("hidden");
			} else {
				this._loadingNode.addClass("hidden");
				this._tableNode.removeClass("hidden");
			}
		}
	});

	Y.MappingTable = MappingTable;

}, '0.0.1', { requires: ['node,event','gallery-paginator','datatable','datatable-sort']});
