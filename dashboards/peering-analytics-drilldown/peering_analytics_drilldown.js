  class ISPDrilldownMapping{
    constructor(opts) {
      let js_file =opts.jsfile;
      let file_path = js_file.split("/")
      file_path.pop()
      file_path = file_path.join("/");
      let css_file = `/plugins/${file_path}/app.css`;
      $('head').append(`<link rel="stylesheet" type="text/css" href="${css_file}">`);
      this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
      this.dash_params = opts.dash_params;
      this.dom = $(opts.divid);
      this.time_selector = opts.new_time_selector;
      this.rand_id=parseInt(Math.random()*100000);
      this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
      this.meters = this.dash_params.statids.split(",");
      this.maxitems=10;
      this.probe_id = opts.probe_id;
      this.default_selected_time = opts.new_time_selector;
      this.load_meters(opts);
    }
    

    // load the frame 
  
  async load_meters(opts){
    await this.load_assets(opts);
    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    var fromTS = this.time_selector.start_time_db
    var toTS = this.time_selector.end_time_db
    this.tmint = mk_time_interval([fromTS,toTS]);
    this.reset_ui();

  }

  async load_assets(opts)
  {
    // load app.css file
    load_css_file(opts);
    // load template.haml file 
    this.html_str = await get_html_from_hamltemplate(opts);
  }
  async reset_ui(){
    this.dom.find(".drilldown_data").remove();
    this.data_dom=$(this.html_str)
    this.dom.append(this.data_dom);

    this.dom.find("#drilldown_asn").val(this.dash_params.readable.split("\\")[0])
    this.form = this.dom.find(".drilldown_asn_form")
       //new time selector 
    new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            });
    
    this.mk_time_interval();
    this.form.submit($.proxy(this.submit_form,this));
    this.filter_text = this.dash_params.key;
    this.agg_flows = [];
    this.update_description();
    
    for(let i=0;i<this.meters.length;i++){
      this.meter = this.meters[i];
      this.meter_name=["upload","download"][i]
      await this.get_toppers()
      
    }
    await this.get_aggregated_flows("in");
    await this.get_aggregated_flows("out");
    this.draw_aggregate_table('internal_ip');
    this.draw_aggregate_table('external_ip');
    this.draw_aggregate_table('tag_asnumber');
    this.draw_aggregate_table('tag_prefixes');
  }
  mk_time_interval(){
    var selected_fromdate = $('#from_date').val();
    var selected_todate = $('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);

  }
  update_description(){
    let description = "Drilldown for"
    let label = this.dash_params.label.split("\\");
    let readable = this.dash_params.readable.split("\\")

    if (readable.length > 1){
      description = `${description}  interface ${label[1]} -> ASN ${readable[0]} `
    }else{
      description = `${description}   ASN ${label[0]}`
    }
    description = `${description} <i class='fa fa-clock-o fa-fw'></i> ${h_fmtduration(this.tmint.to.tv_sec- this.tmint.from.tv_sec)}`
    $('.show_description').html(description)
  }
  submit_form(){
    this.mk_time_interval();
    var newasn = this.form.find("#drilldown_asn").val();
    var readable = this.dash_params.readable.split("\\")

    readable[0]=newasn
    readable=readable.join("\\").replace(/\\/g,"\\\\")
    window.open("/newdash/index?" + 
                    $.param({
                        key: newasn,
                        statids:this.dash_params.statids,
                        label:this.dash_params.label.replace(/\\/g,"\\\\"),
                        readable:readable,                        
                        cgguid:this.dash_params.cgguid,
                        ck_cgguid:this.dash_params.ck_cgguid,
                        filter_cgname:this.dash_params.filter_cgname,
                        window_fromts:this.tmint.from.tv_sec,
                        window_tots:this.tmint.to.tv_sec,
                        "dash_key_regex":"gitPeeringAnalyticsDrilldown"
                    }),"_self");
    return false;
  }
  draw_drill_chart(){
    let traf_chart_id = `drill_traffic_chart_${this.rand_id}`;
   
    $.ajax({
      url:"/trpjs/generate_chart",
      data:model_data,
      context:this,
      success:function(resp){
        $('#'+traf_chart_id).html(resp);

      }
    });

  }

  async get_toppers(filter_cgbase){
    this.crosskey_cgguid =  this.dash_params.ck_cgguid;
    this.top_bucket_size =  300;
    this.meter_types=this.cg_meters.all_meters_type[this.dash_params.cgguid];
    if(this.crosskey_cgguid){
      this.top_bucket_size=this.cg_meters.all_cg_bucketsize[this.crosskey_cgguid].top_bucket_size;
      this.meter_types = this.cg_meters.all_meters_type[this.crosskey_cgguid];
      if(_.size(this.meter_types) == 0 ){
        let parent_cgguid = this.selected_crosskey[this.crosskey_cgguid][1];
        this.meter_types = this.cg_meters.all_meters_type[parent_cgguid];
      }
    }
    this.cgtoppers_resp=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.crosskey_cgguid,
      time_interval: this.tmint ,
      meter:this.meter,
      maxitems:100000
    });
    this.cgtoppers_resp.keys = this.sort_hash(this.cgtoppers_resp,"metric");
    //reject sysgrup and xx
    this.cgtoppers_resp.keys = _.reject(this.cgtoppers_resp.keys,function(topper){
      return topper.key=="SYS:GROUP_TOTALS" || topper.key.includes("XX");
    });

    if(this.filter_text){
      this.cgtoppers_resp.keys = _.select(this.cgtoppers_resp.keys,function(topper){
        return topper.key.match(this.filter_text)
      },this);
    }

    this.draw_table()
    await this.draw_dount_chart();
    await this.draw_traffic_chart();
    await this.draw_sankey_chart();

  }
  async get_aggregated_flows(intf){
    let readable = this.dash_params.readable.split("\\");
    
    let opts = {flowtag:`[asn]${this.dash_params.key}`,time_interval:this.tmint,probe_id:this.probe_id};
    if(readable.length > 1){
      let interfaces = readable[1].split("_");
      opts["nf_routerid"] = TRP.KeyT.create({label:interfaces[0]});
      if(interfaces[1]){
        opts[`nf_ifindex_${intf}`]= TRP.KeyT.create({label:interfaces[1]});
      }
    }
    this.agg_flows.push(await fetch_trp(TRP.Message.Command.AGGREGATE_SESSIONS_REQUEST,opts));
    
  }

  draw_table(){
    var table = this.data_dom.find(`#peering_drilldown_${this.meter_name}`).find(".toppers_table").find("table");
    this.data_dom.find(`#peering_drilldown_${this.meter_name}`).find(".toppers_table").removeClass('animated-background');
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append("<tr><th>Item</th><th>Label</th><th sort='volume' barspark='auto'>Volume </th>></tr>");
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      let link_params =$.param({dash_key:"key",
                         guid:this.crosskey_cgguid,
                         key:topper.key,
                         statid:this.meter});
      let readable = topper.readable.split("\\").pop();
      let label = topper.label.split("\\").pop();
      var anchor =  `<a href=/newdash?${link_params} target='_blank'>${readable}</a>`;
      var anchor1 =  `<a href=/newdash?${link_params} target='_blank'>${label}</a>`;

      var key = topper.key.split("//").pop();
      table.find("tbody").append(`<tr>
                                <td>${anchor}</td>
                                <td>${anchor1}</td>
                                <td>${h_fmtvol(topper.metric*this.top_bucket_size)}${this.meter_types[this.meter].units.replace("ps","")}</td>
                                </tr>`);

    }
    add_barspark(table);
    table.tablesorter();
    
  }

  async draw_dount_chart(){
    this.dount_div_id = `peering_drilldown_${this.meter_name}_dount`;
    this.data_dom.find(`#peering_drilldown_${this.meter_name}`).find(".donut_chart").removeClass('animated-background');
    this.data_dom.find(`#peering_drilldown_${this.meter_name}`).find(".donut_chart").append($("<div>",{id:this.dount_div_id}));
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    var values = [];
    var labels = [];
    for(let i= 0 ; i <  cgtoppers.length  ; i++){
      values[i] =  cgtoppers[i].metric.toNumber()*this.top_bucket_size;
      labels[i] =  cgtoppers[i].label.replace(/:0|:1|:2/g,"");
    }
    var data = [{
      values:values,
      labels:labels,
      domain: {column: 0},
      hoverinfo: 'label+percent+name',
      hole: .4,
      type: 'pie'
    }];

    var layout = {
      title: 'Toppers',
      annotations: [
        {
          font: {
            size: 20
          },
          showarrow: false,
          text: '',
          x: 0.17,
          y: 0.5
        }
      ],
      height: 400,
      width:  $('#'+this.divid).find(".donut_chart").width(),
      showlegend: false,
    };
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };
    Plotly.newPlot(this.dount_div_id, data, layout,ploty_options);

    var keys = _.map(cgtoppers,function(ai){return ai.key});
    for(let i=0 ; i < keys.length;i++){
      if(keys[i].includes("\\")){
        keys[i]=keys[i].replace(/\\/g,"\\\\")
      }
    }
  }

  draw_aggregate_table(group){
    var table = this.data_dom.find(`.${group}`).find("table");
    this.data_dom.find(`.${group}`).removeClass('animated-background');
    var table_id = "agg_flows_tbl_"+Math.floor(Math.random()*100000);
    table.attr("id",table_id)
    table.addClass('table table-hover table-sysdata');
    let toppers = [];
    if(group=="internal_ip" || group == "external_ip"){
      toppers.push(this.agg_flows[0][group]);
      toppers.push(this.agg_flows[1][group]);
    }else if(group=="tag_asnumber"){
      if(this.agg_flows[0].tag_group.find(x=>x.group_name=="asn")){
        toppers.push(this.agg_flows[0].tag_group.find(x=>x.group_name=="asn").tag_metrics)
      }
      if(this.agg_flows[1].tag_group.find(x=>x.group_name=="asn")){
        toppers.push(this.agg_flows[1].tag_group.find(x=>x.group_name=="asn").tag_metrics)
      }
    }
    else if(group=="tag_prefixes"){
      if(  this.agg_flows[0].tag_group.find(x=>x.group_name=="prf")){
        toppers.push(this.agg_flows[0].tag_group.find(x=>x.group_name=="prf").tag_metrics);
      }
      if(  this.agg_flows[1].tag_group.find(x=>x.group_name=="prf")){
        toppers.push(this.agg_flows[1].tag_group.find(x=>x.group_name=="prf").tag_metrics);
      }
    }
    toppers =_.flatten(toppers).slice(0,50);
    let toppers_obj = {};
    for(let i=0 ; i < toppers.length; i++){
      let t = toppers[i];
      let k = t.key.key
      if(toppers_obj[k]){
        let  v = toppers_obj[k];
        v.count = parseInt(v.count) + parseInt(t.count) ;
        v.metric = v.metric.toNumber() + t.metric.toNumber() ;
      }else{
        toppers_obj[k] = t
      }
    }
    toppers = _.sortBy(_.values(toppers_obj),function(k){return -k.metric;});
    let rows = []
    for(let i=0; i< toppers.length;i++){
      var t = toppers[i];
      rows.push(`<tr>
                <td>${t.key.readable||t.key.key}</td>
                <td>${t.key.label}</td>
                <td>${t.count}</td>
                <td>${h_fmtvol(t.metric)}</td>
                </tr>`);
    } 

    new TrisTablePagination(table_id,{no_of_rows:10,rows:rows});
    table.tablesorter();
    new ExportToCSV({table_id:table_id,filename_prefix:"top_asn_panel",append_to:"panel"});

  }
    
  async draw_traffic_chart(){
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    let keys = _.map(cgtoppers,function(ai){return ai.key});
    for(let i=0 ; i < keys.length;i++){
      if(keys[i].includes("\\")){
        keys[i]=keys[i].replace(/\\/g,"\\\\")
      }
    }
    this.traf_chart_id = `peering_drilldown_${this.meter_name}_traffic_chart`
    this.data_dom.find(`#peering_drilldown_${this.meter_name}`).find(`.interfaces_traffic_chart`).attr("id",this.traf_chart_id);
    let ref_model = [this.dash_params.cgguid,this.dash_params.key,this.meter,"Total"]
    var model_data = {cgguid:this.crosskey_cgguid,
        meter:this.meter,
        key:keys.join(","),
        window_fromts:this.time_selector.start_time_db,
        window_tots:this.time_selector.end_time_db,
        valid_input:1,
        ref_model:ref_model
      };
    if(keys.length==0){
      $('#'+this.traf_chart_id).html("no data found");
      return
    }
    $.ajax({
      url:"/trpjs/generate_chart",
      data:model_data,
      context:this,
      success:function(resp){
        $('#'+this.traf_chart_id).html(resp);

      }
    });

  }
  async draw_sankey_chart(filter_cgbase){

    this.sankey_div_id = `peering_drilldown_${this.meter_name}_sankey`;
    this.data_dom.find(`#peering_drilldown_${this.meter_name}`).find(".interfaces_sankey_chart").append($("<div>",{id:this.sankey_div_id}));

    // Get Bytes Toppers
    this.cgtoppers_bytes = this.cgtoppers_resp.keys;
    this.cgtoppers_bytes = this.cgtoppers_bytes.slice(0,30);
    let keylookup = {};
    let idx=0;
    let links  = { source : [], target : [], value : [] };

    for (let i =0 ; i < this.cgtoppers_bytes.length; i++)
    {   
      //change label to :0,:1,:2
      //http host and host has same lable 
      let k=this.cgtoppers_bytes[i].label;
      let parts=k.split("\\");
      if(filter_cgbase == "Interfaces"){
        let router = parts[1].split("_").shift()
        parts = [parts[0],router,parts[1]];
      }

      parts = _.map(parts,function(ai,ind){
        return ai.replace(/:0|:1|:2/g,"")+":"+ind;
      });
      this.cgtoppers_bytes[i].label=parts.join("\\")
      keylookup[parts[0]] = keylookup[parts[0]]==undefined ? idx++ : keylookup[parts[0]];
      keylookup[parts[1]] = keylookup[parts[1]] || idx++;
      if (parts[2]) {
        keylookup[parts[2]] = keylookup[parts[2]] || idx++;
      }
        
    }

    for (let i =0 ; i < this.cgtoppers_bytes.length; i++)
    {
      let item=this.cgtoppers_bytes[i];
      let k=item.label;
      let parts=k.split("\\");
      if (parts[2]) {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric*this.top_bucket_size))
        links.source.push(keylookup[parts[1]])
        links.target.push(keylookup[parts[2]])
        links.value.push(parseInt(item.metric*this.top_bucket_size))

      } else {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric*this.top_bucket_size))
      }
    }
    let labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0].replace(/:0|:1|:2/g,"")).value()
  
    Plotly.purge(this.sankey_div_id);
    var data = {
      type: "sankey",
      orientation: "h",
      valuesuffix: this.meter_types[this.meter].units.replace("ps",""),
      node: {
        pad: 15,
        thickness: 30,
        line: {
          color: "black",
          width: 0.5
        },
        label: labels,
      },

      link: links
    }

    //width of div widht
    var width = this.data_dom.find(`#${this.sankey_div_id}`).width();
    width = parseInt(width)-50;
    var height = labels.length *25;
    if(height < 250){
      height =250;
    }
    var layout = {
      title: `${this.meter_name} Mappings`,
      width:width,
      height:height,
      font: {
        size: 10
      },
      
    }

    var data = [data]
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };

    Plotly.react(this.sankey_div_id, data, layout, ploty_options)
  }
  sort_hash(data,key){
    return data.keys.sort(function(a,b){
      let v1 = a["key"];
      let v2 = b["key"];
      if(key=="metric"){
        v1  = - a["metric"].toNumber();
        v2 =  - b["metric"].toNumber();
      }
      if (v1 < v2)
        return -1;
      if (v1 > v2)
        return 1;
      return 0;
    });
  }

};


function run(opts) {
  new ISPDrilldownMapping(opts);
}


  //# sourceURL=ips_drilldown_mappings.js

  