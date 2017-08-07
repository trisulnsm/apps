/*
  // File Name   : key_space_explore.js
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
  },
  // Add a text box to filter the host
  // add table to show keys
  add_form:function(){
    var form = $("<div id='inkey_search_form'> <form class='form-horizontal' id='fkeymatch'> <div class='row'> <div class='col-xs-5'> <div class='form-group'> <label class='control-label col-xs-4'> Counter Group </label> <div class='col-xs-8'> <select name='counter[guid]' id='inkeys_counter_guid'></select> </div> </div> </div> <div class='col-xs-5'> <div class='form-group'> <label class='control-label col-xs-4'> Key spaces </label> <div class='col-xs-8'> <textarea name='keys' id='in_keys'></textarea> <span class='help-block'>Enter one key range per line Ex.(192.168.1.10~192.168.1.20) (Port-10~Port-50) etc</span> </div> </div> </div> <div class='form-group'> <div class='col-xs-2 col-md-offset-2'> <input type='submit' name='commit' value='Search' class='btn-submit'> </div> <div class='col-xs-3' id='in_keys_status'> </div> </form> </div>");
    $(this.domid).append(form);
    //auto_complete('in_keys',{cgguid:GUID.GUID_CG_HOSTS()},{});
    $(this.domid).append("<div id='inkey_treemap' class='col-xs-12' style='padding-top:10px'><div id='inkey_treemap_0' class='col-xs-4'></div><div id='inkey_treemap_1' class='col-xs-4'></div><div id='inkey_treemap_2' class='col-xs-4'></div></div>");
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
  // send the ajax request and get all the matched host.
  load_keys:function(){
    //trp request 
    var cthis = this;
    cthis.cgguid = $('#inkeys_counter_guid').val();
    this.bucketsize = this.all_cg_bucketsize[this.cgguid]["bucket_size"] || 60 ;
    var key = "/dash_extra_json/"+dashboard_id;
    var extra_json =  localStorage.getItem(key);
    var recentsecs = JSON.parse(localStorage.getItem(key)).recentsecs
    if(recentsecs != 0 ){
      this.recentsecs= recentsecs;
    }

    var meters_arr= _.last(this.cg_meter_json[this.cgguid]).slice(0,3);
    _.each(meters_arr,function(meter){
      this.meters[meter[0]] = meter[1];
    },this);


    this.reset_ui();

    var inkeys = $('#in_keys').val().trim();
    var spaces = _.collect(inkeys.split("\n"),function(inkey){
      inkey = inkey.split("~");
      return new TRP.KeySpaceRequest.KeySpace({
        from_key :new TRP.KeyT({label:inkey[0]}),
        to_key : new TRP.KeyT({label:inkey[1]})
      });
    });

    var req = mk_trp_request(TRP.Message.Command.KEYSPACE_REQUEST,
      {
        counter_group: this.cgguid,

        time_interval:mk_time_interval($.extend({recentsecs:this.recentsecs},this.available_time)),
        spaces:spaces,
        maxitems:50
      });
    return  get_response(req,function(resp){
      var inkeys = _.sortBy(resp.hits,function(key){return key.key});
      var maxitems_per_group = Math.ceil(inkeys.length/cthis.max_group_size);
      var i =  -1;
      _.each(inkeys,$.proxy(function(key,idx){
        if(idx % maxitems_per_group == 0){
          i = i +1;
        }
        if(! _.has(cthis.available_inkeys,i)){
          cthis.available_inkeys[i] = [];
        }

        cthis.available_inkeys[i].push({id:key.key,key:key.key,label:key.label||key.readable,readable:key.readable,total:0,recv:0,transmit:0,is_inkey:true})
      },cthis));
      cthis.all_inkeys = _.chain(cthis.available_inkeys)
                         .values()
                         .flatten()
                         .value();
     
    });

  },
  //Get total usage for each hosts
  load_total:function(){
    var cthis = this;
    if(this.all_inkeys.length <= 0){
      this.update_status();
      return true;
    }
    k = this.all_inkeys.shift();

    var req = mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,
    {
        counter_group: this.cgguid,
        key:  new TRP.KeyT({key:k.key}),
        time_interval:mk_time_interval($.extend({recentsecs:this.recentsecs},this.available_time))
    });
    return  get_response(req,function(resp){
      if(resp == undefined ) {
        resp = {stats:[]}
      }
      var total = _.chain(resp.stats)
                  .collect( function(ai) { return  ai.values[0].toNumber()})
                  .reduce(function(acc, i){return acc+i;}, 0)
                  .value();
      var recv = _.chain(resp.stats)
                  .collect( function(ai) { return  ai.values[1].toNumber()})
                  .reduce(function(acc, i){return acc+i;}, 0)
                  .value();
      var transmit = _.chain(resp.stats)
                  .collect( function(ai) { return  ai.values[2].toNumber()})
                  .reduce(function(acc, i){return acc+i;}, 0)
                  .value();
        
      k.total = total*cthis.bucketsize;
      k.recv = recv*cthis.bucketsize;
      k.transmit = transmit*cthis.bucketsize;
      cthis.redraw_treemap(0,'total');
      cthis.redraw_treemap(1,'recv');
      cthis.redraw_treemap(2,'transmit');
      cthis.redraw();
      cthis.load_total();
    },this);
  },
 
  


  reset_ui:function(){
    $('#trp_data_inkeys').html(" ");
    $('#in_keys_status').html('');
    $('#in_keys_status').append($("<i>",{id:'in_keys_status_fa',class:'fa fa-spinner fa-spin fa-lw'}));
    $('#in_keys_status').append($("<span>",{id:'in_keys_status_text',class:"text-info"}));
    $('#host_search_form').after("<div class='col-xs-4' id='in_keys_status'></div>");
    this.available_inkeys={};
    var table = get_table_shell();
    table.addClass('table-sysdata hide'); 
    table.attr("id","in_keys_tbl");
    var th = "";
    _.each(_.values(this.meters),function(ai){
      th = th + "<th>" + ai + "</th>";
    })
    table.find("thead tr").append("<th>Item</th><th>Label</th>"+th);
    $('#trp_data_inkeys').append(table);
    $('#inkey_treemap_0').html("");
    $('#inkey_treemap_1').html("");
    $('#inkey_treemap_2').html("");
  },

  
  redraw_treemap : function(meterid,key) {
    var divid = '#inkey_treemap_'+meterid;
    var container_div = $(divid);
    container_div.children().remove();
    container_div.append('<h4>MagicMap click on '+ this.cg_meter_json[this.cgguid][0] +  ' by '+this.meters[meterid]+' for past '+h_fmtduration(this.recentsecs,true) +'</h4>');
    container_div.append( '<svg width=250 height=200></svg>');
    container_div.find("svg").attr('width', container_div.width());
    container_div.find("svg").attr('height', container_div.height()+20);
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
   //add value d3.hierarchy need this
    _.each( this.available_inkeys, function (inkeys,idx) {
      _.each(inkeys,function(k){
        k.value = k[key]
      });
    });
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

   $('#total_usage').html("Total - "+h_fmtvol(total)+"B");
    var params = {
      guid:this.cgguid,
      dash_key:'key'
    }
    var anchor  = "<a href='/newdash/index?key={{key}}&" + $.param(params) + "' target='_blank'>{{readable}}</a>";
    var table_tmpl = "<td>"+anchor+"</td><td>{{label}}</td><td>{{h_total}}B</td><td>{{h_recv}}B</td><td>{{h_trans}}B</td>";
            
    var trs = d3.select('table#in_keys_tbl' + " tbody")
                .selectAll("tr")
                .data(_.sortBy(data,function(ai){return -ai.total}));

    trs.enter()
            .insert("tr","tr")
            .html(function(d){ 
              return Mustache.to_html(table_tmpl,$.extend(
                {h_total:h_fmtvol(d.total),h_recv:h_fmtvol(d.recv),h_trans:h_fmtvol(d.transmit)},d));
            });

    trs
         .html(function(d){ 
            return Mustache.to_html(table_tmpl,$.extend(
                {h_total:h_fmtvol(d.total),h_recv:h_fmtvol(d.recv),h_trans:h_fmtvol(d.transmit)},d));
          });

    trs.exit().remove();
  },

  update_status:function(){
    var data = _.chain(this.available_inkeys)
                .values()
                .flatten()
                .value();

    var processed = data.length- this.all_inkeys.length;
    $('#in_keys_status_text').text(processed+"/"+data.length );

    if(data.length == 0 ){
      $('#in_keys_status_fa').removeClass();
      $('#in_keys_status_fa').addClass("fa fa-info-circle fa-fw fa-lg");
      $('#in_keys_status_text').text("No keys found" );

      setTimeout(function() { 
        $('#in_keys_status').html( '' );
      }, 5000);
    }
    else if(processed >= data.length ) {
      $('#in_keys_status_fa').removeClass();
      $('#in_keys_status_fa').addClass("fa fa-check fa-fw fa-lg");      
      $('#in_keys_status_text').text("Completed" );
      setTimeout(function() { 
        $('#in_keys_status').html( '' );
      }, 5000);
    }

  }
});
// Run function should automatically called when page is loaded.
function run(opts)
{
  inkeys_magic_map = new InKeysMagicMap(opts);
}

