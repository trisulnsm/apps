
//
 
  //EdgeVertexMonitor
  //Show the usage for keys and meters
  
//

var EdgeVertexMonitor= $.klass({
  init:function(opts){
    this.domid = opts["divid"];
    this.new_time_selector = opts.new_time_selector;
    this.dash_params = opts.dash_params || {};
    var deferq = $.Deferred();
    var prom = deferq.promise();
    var cthis = this;
    prom = prom.then( function( f) {
      return get_counters_and_meters_json(opts);
    }).then ( function(f) {
      cthis.cg_meter_json=opts["all_cg_meters"];
      cthis.all_meters_type = opts["all_meters_type"];
      cthis.all_cg_bucketsize = opts["all_cg_bucketsize"];
      cthis.add_form();
    });
    deferq.resolve();
    this.data=[];
  },
  //add the form to the dom
  add_form:function(){
    this.form=$("<form class='form-horizontal'> <div class='row'> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Counter Group</label> <div class='col-xs-8'> <select class='cg_id' id='cgguid' name='cgguid'></select> </div> </div> <div class='form-group'> <label class='control-label col-xs-4'>Keys</label> <div class='col-xs-8'> <textarea id='keys' name='keys'></textarea> <span class='help-block'>comma seperated</span> </div> </div> </div> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Meter</label> <div class='col-xs-8'> <select class='meter_id' id='meters' multiple name='meter'></select> </div> </div> <div class='form-group'> <div id='new_time_selector'></div> </div> </div> </div> <div class='row'> <div class='form-group'> <div class='col-xs-10 col-md-offset-4'> <input id='from_date' name='from_date' type='hidden'> <input id='to_date' name='to_date' type='hidden'> <input class='btn-submit' id='btn_submit' name='commit' type='submit' value='Get Usage'></input> </div> </div> </div> </form>");
    $(this.domid).append(this.form);

    //defaults from local storage
    var default_meters="0";
    var default_cgguid="";
    var default_keys = "";
    var tmint = this.new_time_selector;

    //for edge vertex automatically submit the form
    if(localStorage.getItem("/trisul/edge_vertex/monitor/valid_input")==1)
    {
      default_cgguid  = localStorage.getItem("/trisul/edge_vertex/monitor/cgguid");
      default_meters   = localStorage.getItem("/trisul/edge_vertex/monitor/meters");
      default_keys =  localStorage.getItem("/trisul/edge_vertex/monitor/keys");
      from_date = localStorage.getItem("/trisul/edge_vertex/monitor/from_date");
      to_date= localStorage.getItem("/trisul/edge_vertex/monitor/to_date")
      tmint = mk_time_interval({from_date:from_date,to_date:to_date});
      tmint = {start_date:from_date,end_date:to_date,start_time_db:tmint.from.tv_sec,end_time_db:tmint.to.tv_sec}

    }


    $('#keys').text(default_keys);
    
    new ShowNewTimeSelector({divid:"#new_time_selector",
                            update_input_ids:"#from_date,#to_date",
                            default_ts:tmint,
                            add_class:"pull-right"});
    $('#new_time_selector').find('.report_range').css("width","100%")

    var js_params = {meter_details:this.cg_meter_json,
      selected_cg : default_cgguid,
      selected_st : default_meters,
      update_dom_cg : "cgguid",
      update_dom_st : "meters"
    }
    new CGMeterCombo(JSON.stringify(js_params));

    //default select all the meters
    if(localStorage.getItem("/trisul/edge_vertex/monitor/valid_input")!=1 ){
      $('#meters').find('option').prop('selected',true);
    }

    $(this.domid).append("<div class='clearfix' id='show_key_usage' class='hide' style='padding-top:20px'></div>");
    this.form.submit($.proxy(this.submit_form,this));
  },
   //submit the form
  submit_form:function(){
    this.keys = this.form.find("#keys").val();
    this.keys = this.keys.trim();
    if(this.keys.length ==  0 ){
      alert("Keys field can't be empty.")
      return false;
    }
    this.reset_ui();
    
    return false;
  },

 //UI
  reset_ui:function(){

    this.data=[];
    this.cgguid = this.form.find('#cgguid').val();

    $('#show_key_usage').html('');
    $('#show_key_usage').removeClass('hide');
    this.selected_meters=_.map($('#meters').val(),function(ai){return parseInt(ai)});
    var table = $("<table>",{class:'table table-sysdata',id:"table_show_key_usage"});

    this.tris_pg_bar = new TrisProgressBar({max:this.keys.split(",").length,
                                            divid:'show_key_usage',
                                            slim: true });

    var anchor = '<a href="/newdash/index?dash_key=key&guid={{cgguid}}">'
    
    var meters = this.cg_meter_json[this.cgguid];
    var ths = "<th>Readable</th><th>Label</th>";
    this.mustache_tmpl = "<td><a href='/newdash/index?dash_key=key&guid={{cgguid}}&key={{key}}' target='_blank'>{{readable}}</a></td>"+
                         "<td><a href='/newdash/index?dash_key=key&guid={{cgguid}}&key={{key}}' target='_blank'>{{label}}</a></td>"
    _.each(meters[1],function(meter){
      if(! this.selected_meters.includes(meter[0])){
        return;
      }
      ths = ths+"<th sort='volume'>"+meter[1]+"</th>";
      this.mustache_tmpl = this.mustache_tmpl+"<td>{{stat_"+meter[0]+"}}</td>";
    },this);
    table.append("<thead><tr>"+ths+"</tr></thead>");
    table.append("<tbody></tbody>");

    var panel = get_panel_shell({});
    var text="Usage report for "+this.cg_meter_json[this.cgguid][0];

    var from_date = new Date(this.form.find('#from_date').val());
    var duration =  new Date(this.form.find('#to_date').val()).getTime() - from_date.getTime();
    text = text + " ( " + this.keys.split(",").length + " ) " ;
    text = text + "<span class='text-info'>"+h_fmtduration(duration/1000,true)+" Ending " + from_date.toString()+"</span>";

    panel.find('.panel-heading').html(text)
    panel.find('.panel-body').append(table);
    $('#show_key_usage').append(panel);
    this.get_usage();
    table.tablesorter();

  },

  get_usage:function(){
    var deferq = $.Deferred();
    var prom = deferq.promise();
    var cgguid = this.form.find('#cgguid').val();
    var meters = this.form.find('#meters').val();
    var cthis = this;
    var date = {from_date:this.form.find('#from_date').val(),to_date:this.form.find('#to_date').val()}
    _.each(this.keys.split(","),$.proxy(function(key){
      var keyt= TRP.KeyT.create({label:key});
      if(localStorage.getItem("/trisul/edge_vertex/monitor/valid_input")==1){
        keyt =  TRP.KeyT.create({key:key})
      }
      var req=  mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,
      {
        counter_group: this.cgguid,
        key:  keyt,
        time_interval:mk_time_interval(date)
      });
      prom = prom.then( function( f) {
        return cthis.get_resp(req)
      });

    },this));

    deferq.resolve();
  },
  //chain the resp
  get_resp:function(req){
    var cthis = this;
    var meter_type = cthis.all_meters_type[cthis.cgguid];
    return  get_response(req,function(resp){
      var o = {key:resp.key.key,readable:resp.key.readable,label:resp.key.label,cgguid:cthis.cgguid};
      var l = _.size(cthis.all_meters_type[cthis.cgguid])
      var v = new Array(l).fill(0);
      _.each(resp.stats,function(stat){
        _.each(stat.values,function(ai,i){
            v[i] = v[i] + ai.toNumber();
        });
      });
      _.each(v,function(ai,i){
        var bucket_size = 1;
        if(meter_type[i].type==4){
          bucket_size = cthis.all_cg_bucketsize[cthis.cgguid].bucket_size;
        }
        o["stat_"+i] = h_fmtvol(ai*bucket_size);
       
      });
      cthis.data.push(o);
      cthis.update_table();
    });
  },

  //update the table

  update_table:function(){
    var cthis = this;
    cthis.tris_pg_bar.update_progress_bar();
    $('#table_show_key_usage').find('tbody').html('');
    var trs = d3.select("table#table_show_key_usage").selectAll("tbody").selectAll("tr")
        .data(cthis.data);

    trs.enter()
        .insert("tr")
        .html(function(d){
          return Mustache.to_html(cthis.mustache_tmpl,d);
        });

    trs
        .html(function(d){ 
          return Mustache.to_html(cthis.mustache_tmpl,d);
        });

    trs.exit().remove();
  }





});

function run(opts){
  var evm = new EdgeVertexMonitor(opts);
  $(document).ajaxStop(function () {
    var valid_input=localStorage.getItem("/trisul/edge_vertex/monitor/valid_input");

    if(evm.form !=undefined && evm.auto_submitted!=true && valid_input==1){
      evm.form.submit();
      evm.auto_submitted = true;
      localStorage.setItem("/trisul/edge_vertex/monitor/valid_input",0);
    }
  });
}

/*
%form.form-horizontal
  .row
    .col-xs-6
      .form-group 
        %label.control-label.col-xs-4 Counter Group         
        .col-xs-8 
          %select.cg_id#cgguid{name:'cgguid'}

      .form-group
        %label.control-label.col-xs-4 Keys
        .col-xs-8
          %textarea{name:'keys',id:'keys'}
          %span.help-block comma seperated

    .col-xs-6
      .form-group 
        %label.control-label.col-xs-4 Meter 
        .col-xs-8 
          %select.meter_id#meters{multiple:true,name:'meter'}
  
      .form-group
        #new_time_selector
  .row
    .form-group 
      .col-xs-10.col-md-offset-4
        %input{type:"hidden",name:"from_date",id:"from_date"}
        %input{type:"hidden",name:"to_date",id:"to_date"}
        %input.btn-submit{id:"btn_submit",name:"commit",type:"submit",value:"Get Usage"}

     
*/

//# sourceURL=edge_vertex_monitor.js
