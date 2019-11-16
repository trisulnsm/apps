/*
  // File Name   : host_total.ks
  // Author      : Unleash Networks
  // Version     : 0.1
  // Description : Show the total usage for filtered host in last 24 hours.
*/

// Build a class model
var HostTotal   =  $.klass({
  init:function(opts){
    this.available_time = opts["available_time"];
    this.default_selected_time = opts.new_time_selector;
    this.domid = opts["divid"];
    this.available_host = [];
    this.add_form();
    this.bucketsize = 60;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.ax_cancel = false;
  },
  
  //submit the form
  submit_form:function(){
    this.reset_ui();
    var val = $('#search_host').val().trim();
    if(val.length ==  0 ){
      alert("Text field can't be empty.")
      return false;
    }
    this.mk_time_interval();
    deferq = $.Deferred();
    prom = deferq.promise();
    // build a callback chain
    //
    var cthis = this;
    prom = prom.then( function( f) {
      return cthis.load_keys();
    }).then ( function(f) {
      cthis.redraw();
      return cthis.load_total();
    });
    deferq.resolve();
    return false;
  },
  // send the ajax request and get all the matched host.
  load_keys:function(){
    //trp request 
    var cthis = this;
    var req = mk_trp_request(TRP.Message.Command.SEARCH_KEYS_REQUEST,
              {
                counter_group: GUID.GUID_CG_HOSTS(),
                pattern:  $('#search_host').val().trim(),
              });
    return  get_response(req,function(resp){
      _.each(resp.keys,$.proxy(function(key){
        this.available_host.push({key:key.key,label:key.label,readable:key.readable,total:0,recv:0,transmit:0})
      },cthis));
    });
  },
  //Get total usage for each hosts
  load_total:function(){
    this.processed = 0;
    var cthis = this;
    _.each( this.available_host, $.proxy(function (k) {
        var req = mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,
          {
            counter_group: GUID.GUID_CG_HOSTS(),
            key:  TRP.KeyT.create({key:k.key}),
            time_interval:cthis.tmint,
          });
        return  get_response(req,function(resp){
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
          cthis.processed = cthis.processed+1;
          cthis.redraw();
        });
    },this));
  },
 
  // Add a text box to filter the host
  // add table to show keys
  add_form:function(){
    var form = $("<div class='col-xs-12' id='host_search_form'> <form class='form-horizontal'> <div class='row'> <div class='col-xs-8'> <div class='form-group'> <div id='new_time_selector'></div> </div> </div> </div> <div class='row'> <div class='col-xs-8'> <div class='form-group'> <label class='control-label col-xs-4'>Enter Host</label> <div class='col-xs-8'> <input class='form-control' id='search_host' placeholder='Enter host name' style='width:100%' type='text'> </div> </div> </div> </div> <div class='row'> <div class='col-xs-10 col-md-offset-4' style='padding-top:10px'> <input id='from_date' name='from_date' type='hidden'> <input id='to_date' name='to_date' type='hidden'> <input class='btn-submit' id='btn_submit' name='commit' type='submit' value='Search'> </div> </div> </form> </div>");
    $(this.domid).append(form);
    //auto_complete('search_host',{cgguid:GUID.GUID_CG_HOSTS()},{});
    $(this.domid).append("<div id='trp_data_hosts'></div>");

    //new time selector 
    new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            });

    form.submit($.proxy(this.submit_form,this));
  },

  mk_time_interval(){
    var selected_fromdate = $('#from_date').val();
    var selected_todate = $('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  },
  reset_ui:function(){
    $('#trp_data_hosts').html(" ");
    $('#search_host_staus').html('');
    this.processed = 0;
    $('#host_search_form').after("<div class='col-xs-4' id='search_host_staus'></div>");
    $('#search_host_staus').append("<span id='process_status'></span>");
    $('#search_host_staus').append("<span id='total_usage' class='text-success' style='font-size:1.3em;padding-left:10px'></span>");
    this.available_host=[];
    var table = get_table_shell();
    table.addClass('table-sysdata hide'); 
    table.attr("id","search_host_tbl");
    table.find("thead tr").append("<th>Host</th><th>IP</th><th>Total</th><th>Received</th><th>Transmit</th>");
    $('#trp_data_hosts').append(table);

  },

  //redraw the table
  redraw:function(){
    $('table#search_host_tbl').removeClass('hide');
    $('#process_status').html(this.processed+"/"+this.available_host.length);
    var total = _.reduce(this.available_host,function(acc,ai){
      return acc + ai.total;
    },0);

   $('#total_usage').html("Total - "+h_fmtvol(total)+"B");
    var params = {
      guid:GUID.GUID_CG_HOSTS,
      dash_key:'key'
    }
    var anchor  = "<a href='/newdash/index?key={{key}}&" + $.param(params) + "' target='_blank'>{{label}}</a>";
    var table_tmpl = "<td>"+anchor+"</td><td>{{readable}}</td><td>{{h_total}}B</td><td>{{h_recv}}B</td><td>{{h_trans}}B</td>";
            
    var trs = d3.select('table#search_host_tbl' + " tbody")
                .selectAll("tr")
                .data(_.sortBy(this.available_host,function(ai){return -ai.total}));

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
  }
});
// Run function should automatically called when page is loaded.
function run(opts)
{
  host_totals = new HostTotal(opts);
}

