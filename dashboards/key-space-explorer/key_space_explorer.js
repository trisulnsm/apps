/*
  // File Name   : key_space_explorer.js
  // Author      : Unleash Networks
  // Version     : 0.1
  // Description : Show the total usage for subnet ips
*/

// Build a class model
var InKeysMagicMap   =  $.klass({
  init:function(opts){
    this.available_time = opts["available_time"];
    this.domid = opts["divid"];
    deferq = $.Deferred();
    prom = deferq.promise();
    var cthis = this;
    this.available_inkeys = {};
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.meters = {};
    prom = prom.then( function( f) {
      return get_counters_and_meters_json(opts);
    }).then ( function(f) {
      cthis.cg_meter_json=opts["all_cg_meters"];
      cthis.all_meters_type = opts["all_meters_type"];
      cthis.all_cg_bucketsize = opts["all_cg_bucketsize"];
      cthis.bucketsize = 60;
      cthis.add_form();
    });
    deferq.resolve();
    this.max_group_size=16;
    this.recentsecs = 86400;
    this.default_selected_time = opts.new_time_selector;
  },
  // Add a text box to filter the host
  // add table to show keys
  add_form:function(){
    var form = $(Haml.render(`
      #inkey_search_form
        %form#fkeymatch.form-horizontal
          .row
            .col-6
              .row.mb-3
                %label.col-form-label.col-4 Counter Group
                .col-8
                  %select#inkeys_counter_guid{name:"counter[guid]"}
            .col-6
              .row.mb-3
                %label.col-form-label.col-4 Meters
                .col-8
                  %select#inkeys_meter_id{multiple:"multiple", name:"meter[]",size:"5"}
          .row
            .col-6
              .row.mb-3
                %label.col-form-label.col-4 Key spaces
                .col-8
                  %textarea#in_keys{name:"keys"}
                  %span.form-help Enter one key range per line Ex.(192.168.1.10~192.168.1.20) (Port-10~Port-50) etc
            .col-6
              .row.mb-2
                #new_time_selector_ks
            
          .row
            .row
              .col-2.offset-md-4
                %input#from_date_ks{type:"hidden",name:"from_date"}
                %input#to_date_ks{type:"hidden",name:"to_date"}
                %input.btn-submit{name:"commit", type:"submit", value:"Search"}
    #in_keys_status
      `))
    $(this.domid).append(form);
    new ShowNewTimeSelector({divid:"#new_time_selector_ks",
                               update_input_ids:"#from_date_ks,#to_date_ks",
                               add_class:"pull-right",
                               default_ts:this.default_selected_time
                            });
    //auto_complete('in_keys',{cgguid:GUID.GUID_CG_HOSTS()},{});
    $(this.domid).append("<div id='inkey_treemap' class='row mt-2'></div>");
    $(this.domid).append("<div id='trp_data_inkeys'></div>");

    var js_params = {meter_details:this.cg_meter_json,
      selected_cg : "",
      selected_st : "0",
      update_dom_cg : "inkeys_counter_guid",
      update_dom_st : "inkeys_meter_id"    
    }
    new CGMeterCombo(JSON.stringify(js_params));
    form.submit($.proxy(this.submit_form,this));

  },


  //submit the form
  submit_form:function(){
    this.meters = {};
    this.units = {};
    this.mk_time_interval();
    var val = $('#in_keys').val().trim();
    if(val.length ==  0 ){
      alert("Text field can't be empty.")
      return false;
    }
    var valid_keyspace = true
    _.each(val.split("\n"),function(inkey){
      if(! inkey.match(new RegExp(/~/))){
        valid_keyspace = false
      }
    });
    if( ! valid_keyspace ) {
      alert("Invalid Keyspace");
      return false;
    }
    deferq = $.Deferred();
    prom = deferq.promise();
    // build a callback chain
    //
    var cthis = this;
    prom = prom.then( function( f) {
      return cthis.load_keys();
    }).then ( function(f) {
      return cthis.load_total();
    });
    deferq.resolve();
    return false;
  },

  mk_time_interval:function(){
    var selected_fromdate = $('#from_date_ks').val();
    var selected_todate = $('#to_date_ks').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  },
  // send the ajax request and get all the matched host.
  load_keys:function(){
    //trp request 
    var cthis = this;
    cthis.cgguid = $('#inkeys_counter_guid').val();
    var meters  = $('#inkeys_meter_id').val();
    var length = meters.length;

    for(i=0;i < length;i++){
      meters[i] = parseInt(meters[i])
    }
    meters = meters.slice(0,3);

    _.chain(this.cg_meter_json[this.cgguid])
    .last()
    .each(function(ai){
      if(meters.includes(ai[0])){
        this.meters[ai[0]] = ai[1];
        var unit = cthis.all_meters_type[cthis.cgguid][ai[0]].units;
        if(unit.match(new RegExp(/ps$/))){
          unit = unit.replace(/ps$/,"");
        }
        this.units[ai[0]] = unit;
      }
    },this)
    .value();

    this.bucketsize = this.all_cg_bucketsize[this.cgguid]["bucket_size"] || 60 ;
    var key = "/dash_extra_json/"+dashboard_id;
    var extra_json =  localStorage.getItem(key);
    var recentsecs = JSON.parse(localStorage.getItem(key)).recentsecs
    if(recentsecs != 0 ){
      this.recentsecs= recentsecs;
    }

    this.reset_ui();

    var inkeys = $('#in_keys').val().trim();
    var spaces = _.collect(inkeys.split("\n"),function(inkey){
      inkey = inkey.split("~");
      return TRP.KeySpaceRequest.KeySpace.create({
        from_key :TRP.KeyT.create({label:inkey[0]}),
        to_key : TRP.KeyT.create({label:inkey[1]})
      });
    });
    var req = mk_trp_request(TRP.Message.Command.KEYSPACE_REQUEST,
      {
        counter_group: this.cgguid,
        time_interval:this.tmint,
        spaces:spaces,
        maxitems:50
      });
    return  get_response(req,function(resp){
      var keys = [];
      var inkeys = _.chain(resp.hits)
                    .sortBy(function(key){return key.key})
                    .reject(function(k1){
                      if(keys.includes(k1.key)){
                        return true
                      }
                      else{
                        keys.push(k1.key)
                        return false;
                      }
                    })
                    .slice(0,100)
                    .value()

      var maxitems_per_group = Math.ceil(inkeys.length/cthis.max_group_size);
      var i =  -1;
      _.each(inkeys,$.proxy(function(key,idx){
        if(idx % maxitems_per_group == 0){
          i = i +1;
        }
        if(! _.has(cthis.available_inkeys,i)){
          cthis.available_inkeys[i] = [];
        }
        var key_hash = {id:key.key,key:key.key,label:key.label||key.readable,readable:key.readable,is_inkey:true}
        var data_hsh = {}
        _.each(cthis.meters,function(name,id){
          data_hsh[id] = 0
        });
        cthis.available_inkeys[i].push(_.extend({},key_hash,data_hsh))
      },cthis));
      cthis.all_inkeys = _.chain(cthis.available_inkeys)
                         .values()
                         .flatten()
                         .value();
      var pg_bar_max = cthis.all_inkeys.length == 0 ? 1 : cthis.all_inkeys.length
      cthis.tris_pg_bar = new TrisProgressBar({max:pg_bar_max,
                                            divid:'in_keys_status'
                                            });
     
    });

  },
  //Get total usage for each hosts
  load_total:function(){
    var cthis = this;
    if(this.all_inkeys.length <= 0){
      this.tris_pg_bar.update_progress_bar();
      return true;
    }
    k = this.all_inkeys.shift();

    var req = mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,
    {
        counter_group: this.cgguid,
        key:  TRP.KeyT.create({key:k.key}),
        time_interval:this.tmint
    });
    return  get_response(req,function(resp){
      if(resp == undefined ) {
        resp = {stats:[]}
      }
      _.each(_.keys(cthis.meters),function(id,idx){
        var id  = parseInt(id);
        var value = _.chain(resp.stats)
                  .collect( function(ai) { return  ai.values[id].toNumber()})
                  .reduce(function(acc, i){return acc+i;}, 0)
                  .value();
        var bucketsize = cthis.bucketsize;
        if(cthis.all_meters_type[cthis.cgguid][id].type != 4 ){
          bucketsize = 1;
        }
        k[id] = value * bucketsize;
        cthis.redraw_treemap(id);
      },this);
      _.each
      cthis.redraw();
      cthis.load_total();
    },this);
  },
 
  


  reset_ui:function(){
    var classname = 'col-'+Math.floor(12/_.size(this.meters))
    $('#trp_data_inkeys').html(" ");
    $('#in_keys_status').html('');
    this.available_inkeys={};
    this.all_inkeys=[];
    var table = get_table_shell();
    table.addClass('table-sysdata hide'); 
    table.attr("id","in_keys_tbl");
    var th = "";
    _.each(_.values(this.meters),function(ai){
      th = th + "<th>" + ai + "</th>";
    })
    table.find("thead tr").append("<th>Item</th><th>Label</th>"+th);
    $('#trp_data_inkeys').append(table);
    $('#inkey_treemap').html("");
    _.each(_.keys(this.meters),function(meterid){
      $('#inkey_treemap').append($("<div>",{class:classname,id:'inkey_treemap_'+meterid}))
    });
   
  },

  
  redraw_treemap : function(key) { 

    var divid = '#inkey_treemap_'+key;
    var container_div = $(divid);
    container_div.children().remove();
    container_div.append( '<svg width=250 height=200></svg>');
    container_div.find("svg").attr('width', container_div.width());
    container_div.find("svg").attr('height', 200);
    container_div.find("svg").css('font-size', "0.8em");


    var svg = d3.select(divid+" svg"),
        width = +svg.attr("width"),
        height = +svg.attr("height");

    var color = d3.scaleOrdinal(d3.schemeCategory20),
        format = d3.format(",d");

    var treemap = d3.treemap()
        .tile(d3.treemapResquarify)
        .size([width, height])
        .round(true)
        .paddingInner(1);

    var cthis = this;

    var total = 0
   //add value d3.hierarchy need this
    _.each( this.available_inkeys, function (inkeys,idx) {
      _.each(inkeys,function(k){
        k.value = k[key];
        if(k.key == "C0.A8.01.50"){
          k.value = 0;
        }
        total = total + k.value;
      });
    });

    total = "<strong class='badge bg-secondary'>"+h_fmtvol(total)+this.units[key]+"</strong>";
    container_div.prepend('<h5>MagicMap click on '+ this.cg_meter_json[this.cgguid][0] +  ' by '+this.meters[key]+' for past '+h_fmtduration(this.recentsecs,true) + ' - '+ total +'</h5>');

    var root = d3.hierarchy(cthis.available_inkeys, function(ai) {
      if (_.has(ai,'is_groupindex')) {
          return cthis.available_inkeys[ ai.name ];
      } else if (_.has(ai,'is_inkey')) {
        return null;
      } else {
          return _.chain(ai)
                  .keys()
                  .collect( function(ai) {  return {id: ai, name : ai, is_groupindex: true }; })
                  .value();
      }

    });

    root.sort(function(a, b) { return b.height - a.height || b.value - a.value; });
    root.sum(function(d) { 
      return d.value ;    
    });


    treemap(root);

    var cell = svg.selectAll("g")
                .data(root.leaves())
                .enter()
                .append("g")
                    .attr("transform", function(d) { 
                      return "translate(" + d.x0 + "," + d.y0 + ")"; 
                    });

    cell.append("rect")
      .attr("id", function(d) { return d.data.id; })
      .attr("width", function(d) { return d.x1 - d.x0; })
      .attr("height", function(d) { return d.y1 - d.y0; })
      .attr("fill", function(d) { return color(d.parent.data.id); });

    cell.append("clipPath")
        .attr("id", function(d) { return "clip-" + d.data.id; })
    .append("use")
        .attr("xlink:href", function(d) { return "#" + d.data.id; });

    cell.append("text")
        .attr("clip-path", function(d) { return "url(#clip-" + d.data.id + ")"; })
    .selectAll("tspan")
        .data(function(d) { return d.data.readable.split(/(?=[A-Z][^A-Z])/g); })
    .enter().append("tspan")
        .attr("x", 4)
        .attr("y", function(d, i) { return 13 + i * 10; })
        .text(function(d) { return d; })
        
    cell.append("title")
      .text(function(d) { return   d.data.label + "\n" + h_fmtvol(d.value); });
  },

  redraw:function(){
    this.update_status();
    $('table#in_keys_tbl').removeClass('hide');
    var data = _.chain(this.available_inkeys)
                .values()
                .flatten()
                .value();
    

    var total = _.reduce(data,function(acc,ai){
      return acc + ai.total;
    },0);

    var params = {
      guid:this.cgguid,
      dash_key:'key'
    }
    var meterids = _.keys(this.meters);
    for(i=0;i < meterids.length;i++){
      meterids[i] = parseInt(meterids[i])
    }    
  

    var anchor  = "<a href='/newdash/index?key={{key}}&" + $.param(params) + "' target='_blank'>{{readable}}</a>";
    var table_tmpl = "<td>"+anchor+"</td><td>{{label}}</td>";
    _.each(meterids,function(meterid,idx){
      table_tmpl = table_tmpl + "<td>{{h_"+ meterid +"}}"+this.units[meterid]+"</td>";
    },this);
    var trs = d3.select('table#in_keys_tbl' + " tbody")
                .selectAll("tr")
                .data(_.sortBy(data,function(ai){return -ai[meterids[0]]}));


    trs.enter()
            .insert("tr","tr")
            .html(function(d){
              var data_hsh = {};
              _.each(meterids,function(meterid){
                key = 'h_'+meterid;
                value = h_fmtvol(d[meterid]);
                data_hsh[key] =value;
              })
              return Mustache.to_html(table_tmpl,$.extend({},data_hsh,d));
            });

    trs
         .html(function(d){ 
           var data_hsh = {};
            _.each(meterids,function(meterid){
              key = 'h_'+meterid;
              value = h_fmtvol(d[meterid]);
              data_hsh[key] =value;
            })
            return Mustache.to_html(table_tmpl,$.extend({},data_hsh,d));
          });
    trs.exit().remove();
  },

  update_status:function(){
    this.tris_pg_bar.update_progress_bar();


  }
});
// Run function should automatically called when page is loaded.
function run(opts)
{
  inkeys_magic_map = new InKeysMagicMap(opts);
}


//# sourceURL=key_space_explorer.js

/*


      



*/