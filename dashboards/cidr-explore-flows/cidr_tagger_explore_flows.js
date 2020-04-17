// CIDR Explore flows
// send Keyspace request and get all avilable keys
// For each available keys send aggregate flows request and update UI


class CIDRTaggerToppers{
  constructor(opts){
    this.name = opts.name;
    this.max_count = 100;
    this.toppers = {};
   
  }
  update_toppers(resp_toppers){
    for(let i=0;i<resp_toppers.length;i++){
      let keyt = resp_toppers[i].key;
      if(this.toppers[keyt.key]==undefined){
        this.toppers[keyt.key]={key:keyt.key,label:keyt.label,readable:keyt.readable,
                                count:resp_toppers[i].count.toNumber(),metric:resp_toppers[i].metric.toNumber()}
      }
      else{
        this.toppers[keyt.key].count = this.toppers[keyt.key].count + resp_toppers[i].count.toNumber();
        this.toppers[keyt.key].metric = this.toppers[keyt.key].metric + resp_toppers[i].metric.toNumber();
      }
    }
  }
  get_top_n_toppers(){
    return _.chain(this.toppers)
            .values()
           .sortBy(function(a){
              return -a.metric;
            })
           .slice(0,this.max_count)
           .value();
  }
}


class CIDRExploreFlows{
  constructor(opts){
    this.dom = $(opts.divid);
    this.default_selected_time = opts.new_time_selector;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.add_form(opts);
    this.counter_group =opts.jsparams.counter_group || GUID.GUID_CG_INTERNAL_HOSTS();
    this.ips = {};
  }
  // load the frame 
  async load_assets(opts)
  {
    // load app.css file
    load_css_file(opts);
    // load template.haml file 
    let html_str = await get_html_from_hamltemplate(opts);
    this.haml_dom =$(html_str)
  }
  //add the form to UI
  async add_form(opts){
    await this.load_assets(opts)
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);
    let update_ids = "#from_date,#to_date";
    new ShowNewTimeSelector({divid:"#new_time_selector",
                              update_input_ids:update_ids,
                              default_ts:this.default_selected_time
                            });
    this.form.submit($.proxy(this.submit_form,this));
  }

  submit_form(){
    //this.form.find("#cidr_subnet").val("163.53.207.225/30");
    let cidr = this.form.find("#cidr_subnet").val();
    if($.trim(cidr).length==0){
      alert("Please enter a valid subnet.")
      return false;
    }
    this.reset_ui();
    this.mk_time_interval();
    this.get_data();
    return false;
  }

  reset_ui(){
    $('#app_error_box').addClass('hidden');
    this.dom.find(".cidr_explore_flows_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
    this.all_agg_groups =  ["source_port", "dest_port", "source_ip", "dest_ip",
                            "internal_ip", "external_ip", "internal_port", "protocol",
                            "flowtag"];
    for(let i=0; i<this.all_agg_groups.length;i++){
      this[this.all_agg_groups[i]]= new CIDRTaggerToppers({name:this.all_agg_groups[i]});
    }

    this.key_spaces_mustache_tmpl = '{{readable}}';

    this.mustache_tmpl ='<td>{{readable}}</td>'+
                        '<td>{{label}}</td>'+
                        '<td>{{count}}</td>'+
                        '<td>{{volume}}</td>'+
                        '<td class="hide">{{metric}}</td>';

    $('#agg_tabs a').click(function (e) {
      e.preventDefault()
      $(this).tab('show');
    });
    window.flowApp = new TFlowApp({});
    window.flowApp.flow_count=10000;
    this.flowModel= new TFlowModel();
    this.flowUI = new TFlowUI(this.flowModel);
    this.tris_pg_bar = new TrisProgressBar({max:1,
                                            divid:'cidr_progress_bar'});
     new ExportToCSV({table_id:"agg_internal_port_tbl",download_format:"xlsx",filename_prefix:"aggregate_flows"});
  }
   mk_time_interval(){
    var selected_fromdate = this.form.find('#from_date').val();
    var selected_todate = this.form.find('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }
  async get_data(){
    //get time interval day by day
    this.tint_arr = await new TimeInterval({default_selected_time:this.default_selected_time}).get_tint_array(true);
    let cidr = this.form.find("#cidr_subnet").val();
    let cidr_range = calculateCidrRange(cidr);
    let from_key = TRP.KeyT.create({label:cidr_range[0]});
    let to_key = TRP.KeyT.create({label:cidr_range[1]});
    let key_spaces = TRP.KeySpaceRequest.KeySpace.create({from_key:from_key,to_key:to_key})
    //do search key space for ean day 
    window.flowApp = new TFlowApp({});
    for(let i=0;i<this.tint_arr.length;i++){
      let resp = await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST, 
                                  {counter_group:this.counter_group,
                                  time_interval:this.tint_arr[i],
                                  spaces:[key_spaces]

      });
      
      this.tris_pg_bar.max = this.tint_arr.length + resp.hits.length;
      this.tris_pg_bar.update_progress_bar();
      for(let j=0; j < resp.hits.length;j++){
        let keyt = resp.hits[j];
        this.ips[keyt.key]= this.ips[keyt.key] || {key:keyt.key,readable:keyt.readable,label:keyt.label};
      }
      this.redraw_ip_list();
      //for each key send aggregate flow
      for(let j=0; j < resp.hits.length;j++){
        let keyt = resp.hits[j];
        this.ips[keyt.key]= this.ips[keyt.key] || {key:keyt.key,readable:keyt.readable,label:keyt.label};
        let agg_resp = await fetch_trp(TRP.Message.Command.AGGREGATE_SESSIONS_REQUEST,
                                      {any_ip:TRP.KeyT.create({key:keyt.key}),
                                       time_interval:this.tint_arr[i]
        });
        for(let k=0; k<this.all_agg_groups.length;k++){
          this[this.all_agg_groups[k]].update_toppers(agg_resp[this.all_agg_groups[k]]);
        }
        //get raw flows
        let flows = await fetch_trp(TRP.Message.Command.QUERY_SESSIONS_REQUEST,
                                      {any_ip:TRP.KeyT.create({key:keyt.key}),
                                       time_interval:this.tint_arr[i]
        });
        let tint = this.tint_arr[i];
        let flow_arr = new MakeFlowArray({}).mk_flow_arr(flows.sessions);
        var incoming=_.collect(flow_arr,function(flow){
                    return new TFlow(flow,[tint.from.tv_sec,tint.to.tv_sec]);
                  },this);
        this.flowModel.proc_new_flows(incoming);
        this.tris_pg_bar.update_progress_bar();
      }

      for(let i=0; i<this.all_agg_groups.length;i++){
        this.redraw_table(this.all_agg_groups[i]);
      }
      this.flowUI.redraw_flow_table();
      
    }
    
  }
  redraw_table(id){
    let data = this[id].get_top_n_toppers();
    this.data_dom.find(`.${id}_count`).html(` (${data.length}) `);
    _.each(data,function(d){
      d.volume = h_fmtvol(d.metric);
    });
    let cthis = this;
    let table_id = `agg_${id}_tbl`;
    let trs = d3.select(`table#${table_id}`).selectAll("tbody").selectAll("tr")
          .data(data);

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
  redraw_ip_list(){
    this.data_dom.find("#ips_count")
    let data = Object.values(this.ips);
    this.data_dom.find(".ips_count").html(data.length);
    this.data_dom.find(".cidr_subnet_text").html(this.form.find("#cidr_subnet").val());

    let cthis = this;
    let lis = d3.select(`ul.key_spaces_ul`).selectAll("li")
          .data(data);

    lis.enter()
        .insert("li")
        .html(function(d){
          return Mustache.to_html(cthis.key_spaces_mustache_tmpl ,d);
        });

    lis
        .html(function(d){
          return Mustache.to_html(cthis.key_spaces_mustache_tmpl,d);
        });

    lis.exit().remove();

  } 
}
function run(opts){
  new CIDRExploreFlows(opts)
}

  //# sourceURL=cid_tagger_explore_flows.js
