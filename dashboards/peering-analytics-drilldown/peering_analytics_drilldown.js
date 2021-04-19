/*

  Drilldown for  Peering analytics app
  View detailed usage for asn number across all interfaces
*/
class ISPDrilldownMapping{
  constructor(opts){
    //load app.css file 
    load_css_file(opts);
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.crosskey_router = opts.jsparams.crosskey_router;
    this.crosskey_interface = opts.jsparams.crosskey_interface;
    this.meters=opts.jsparams.meters;
    this.dom = $(opts.divid);
    this.probe_id=opts.probe_id; 
    this.load_cg_meters(opts);
    this.logo_tlhs=opts.logo_tlhs;
    this.toppers_table=100;
  }
  async load_cg_meters(opts){
    this.cg_meters={};
    await get_counters_and_meters_json(this.cg_meters);
    await this.load_assets(opts);
  }
  async load_assets(opts)
  {
    // load app.css file
    await load_css_file(opts);
    // load template.haml file 
    let html_str = await get_html_from_hamltemplate(opts);
    this.haml_dom =$(html_str)
    //add the form
    this.form=$(this.haml_dom[0]);
    this.dom.append(this.form);
    new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:opts.new_time_selector
                            });
    this.form.submit($.proxy(this.submit_form,this));
    this.parent_cgguid = this.cg_meters.crosskey[this.crosskey_interface][1];
    auto_complete('drilldown_asn',{update:'autocomplete_asn',cgguid:this.parent_cgguid},{});
    if(opts.dash_params.valid_input=="1"){
      this.form.find('#drilldown_asn').val(opts.dash_params.key);
      this.submit_form();
    }
   
  }
  //reset ui for every form submit
  reset_ui(){
    this.maxitems=10;
    this.agg_flows={};
    this.dom.find(".drilldown_data").remove();
    this.dom.append($(this.haml_dom[1]).clone());
  }
  submit_form(){
    this.form.find(".btn-submit").attr("disabled",true);
    //this.form.find('#drilldown_asn').val('9498');
    this.key=this.form.find('#drilldown_asn').val();
    if(this.key.length ==0 ){
      alert("ASNumber filed can't be empty.");
      this.form.find(".btn-submit").removeAttr("disabled");

      return false;
    }
    this.mk_time_interval();
    this.reset_ui();
    this.get_keyt();//starting point for the request
    return false;
  }


  //construct time interval for trp_request
  mk_time_interval(){
    var selected_fromdate = $('#from_date').val();
    var selected_todate = $('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }
  async get_keyt(){
    let resp=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, {
      counter_group: GUID.GUID_CG_ASN(),
      label:this.key,
    });
    this.keyt=resp.keys[0];
    this.update_description();
    let nodes = [];
    let section_headers=[];
    for(let meter in this.meters){
      await this.get_toppers(meter);
      let idx = Object.keys(this.meters).findIndex(k=>k==meter);
      section_headers.push({h1:meter});
      nodes.push({find_by:`#table_${idx}`,type:"table",header_text:"auto",h1:"h3",section_header:idx});
      nodes.push({type:"page_break"});
      nodes.push({find_by:`#peering_drilldown_${idx}_donut`,type:"svg",header_text:"auto",h1:"h3",float:"right"});
      nodes.push({find_by:`#peering_drilldown_${idx}_traffic_chart`,type:"svg",header_text:"auto",h1:"h3",float:"right"});
      nodes.push({type:"page_break"});
      nodes.push({find_by:`#peering_drilldown_${idx}_sankey`,type:"svg",header_text:"auto",h1:"h3",float:"right"});
      nodes.push({type:"page_break",add_header_footer:false});
    }
    await this.get_aggregated_flows();
    this.draw_aggregate_table('internal_ip');
    this.draw_aggregate_table('external_ip');
    this.draw_aggregate_table('tag_asnumber');
    this.draw_aggregate_table('tag_prefixes');


    section_headers.push({h1:"Top Prefixes and Hosts"});
    let prefixes = ['.tag_asnumber','.tag_prefixes','.internal_ip','.external_ip'];
    for(let i=0; i<prefixes.length; i++ ){
      nodes.push({type:"table",find_by:`${prefixes[i]} table`,header_text:"auto",h1:"h3"});
      if(i!=prefixes.length-1){
        nodes.push({type:"page_break",add_header_footer:false});
      }
    }


    new ExportToPDF({add_button_to:".add_download_btn",
                      tint:this.tmint,
                      logo_tlhs:this.logo_tlhs,
                      download_file_name:"peering_analytics_drilldown",
                      report_opts:{
                        section_headers:section_headers,
                        header:{h1:"Peering Analytics Report Drilldown"},
                        report_title:{h1:this.description},
                        nodes:nodes
                      }
    });
    this.form.find(".btn-submit").removeAttr("disabled");


  }
  async get_toppers(meter_name){
    this.meter_types=this.cg_meters.all_meters_type[this.crosskey_interface];
    let top_bucket_size=this.cg_meters.all_cg_bucketsize[this.crosskey_interface].top_bucket_size;
    //if no meter found get it from the parent counter group
    if(_.size(this.meter_types) == 0 ){
      
      this.meter_types = this.cg_meters.all_meters_type[this.parent_cgguid];
    }
    let cgtoppers_resp=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.crosskey_interface,
      time_interval: this.tmint ,
      key_filter:`^${this.keyt.key}\\\\`, 
      meter:this.meters[meter_name],
      maxitems:100
    });
    this.toppers_data = [];
    for(let i=0;i<cgtoppers_resp.keys.length;i++)
    {
      let kt = cgtoppers_resp.keys[i];
      if(kt.key=="SYS:GROUP_TOTALS"){
        continue;
      }
      this.toppers_data.push({keyt:kt,metric:kt.metric.toNumber()*top_bucket_size});
    }
    this.toppers_data=this.toppers_data.sort((a, b) => (a.metric > b.metric) ? -1 : 1);
    await this.redraw_all(meter_name);
  }
   async get_aggregated_flows(){
    let opts = {flowtag:`[asn]${this.keyt.key}`,time_interval:this.tmint,probe_id:this.probe_id,maxcount:100};
    this.agg_flows=await fetch_trp(TRP.Message.Command.AGGREGATE_SESSIONS_REQUEST,opts);
    
  }

  async redraw_all(meter_name){
    let idx = Object.keys(this.meters).findIndex(k=>k==meter_name);
    await this.draw_toppers_table(meter_name,idx);
    await this.draw_traffic_chart(meter_name,idx);
    this.draw_donut_chart(meter_name,idx);
    this.draw_sankey_chart(meter_name,idx);
  }

  async draw_toppers_table(meter_name,idx){
    let meter = this.meters[meter_name];
    let rows = [];

    var table = this.dom.find(`#peering_drilldown_${idx}`).find(".toppers_table").find("table");
    table.attr("id",`table_${idx}`);
    this.dom.find(`#peering_drilldown_${idx}`).find(".toppers_table_div").find('.animated-background').remove();
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append("<tr><th>Router</th><th>Interface</th><th sort='volume' barspark='auto'>Volume </th>></tr>");
    let cgtoppers =  this.toppers_data;
    let totvol = 0;
    totvol=cgtoppers.reduce((a,b)=>a +parseInt(b.metric),0);
    $('.volume_'+idx).text(` (${h_fmtvol(totvol)}) `);
    this.routers_keymap={};
    let routers=[];
    let interfaces=[];
    for (let i =0 ; i < cgtoppers.length; i++)
    {   
      
      let r = cgtoppers[i].keyt.key;
      let intf_key=r.split('\\').slice(-1)[0]
      r=intf_key.split("_")[0];
      if(! routers.includes(r)){
        routers.push(r)
      }
      if(! interfaces.includes(intf_key)){
        interfaces.push(intf_key)
      }
      
    }
    cgtoppers =  cgtoppers.slice(0,this.maxitems)
    let rkeyts = await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,{
      counter_group:GUID.GUID_CG_FLOWGENS(),
      keys:routers
    });

    let ikeyts = await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,{
      counter_group:GUID.GUID_CG_FLOWINTERFACE(),
      get_attributes:true,
      keys:interfaces
    });
    for(let i=0 ; i < rkeyts.keys.length; i++){
      let r = rkeyts.keys[i];
      this.routers_keymap[r.key]=r;
    }
    this.interfaces_ifalias = {};
    for(let i=0 ; i < ikeyts.keys.length; i++){
      let keyt = ikeyts.keys[i];
      let intf_label = keyt.label || keyt.readable;
      let alias = intf_label;
      let attr =_.select(keyt.attributes,function(e){return e.attr_name=='snmp.ifalias'})[0];
      if (attr && attr.attr_value.length > 0){
        alias = attr.attr_value;
      }
      if(keyt.description.length > 0){
        alias = keyt.description;
      }
      if (alias != intf_label){
        intf_label = `${intf_label}(${alias})`;
      }
      this.interfaces_ifalias[keyt.key]=intf_label;
    }
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      let link_params =$.param({dash_key:"key",
                         guid:this.crosskey_interface,
                         key:topper.keyt.key,
                         statid:meter});
      let intfkey = topper.keyt.key.split("\\").pop();
      let rkey = intfkey.split("_")[0];
      let router_label = this.routers_keymap[rkey].label;
      if(router_label != this.routers_keymap[rkey].readable){
        router_label = `${router_label}(${this.routers_keymap[rkey].readable})`;
      }
      let interface_label = topper.keyt.label.split("\\").pop();
      var anchor =  `<a href=/newdash?${link_params} target='_blank'>${router_label}</a>`;
      var anchor1 =  `<a href=/newdash?${link_params} target='_blank'>${this.interfaces_ifalias[intfkey]}</a>`;

      var key = topper.keyt.key.split("//").pop();

      rows.push(`<tr>
                                <td>${anchor}</td>
                                <td>${anchor1}</td>
                                <td>${h_fmtvol(topper.metric)}</td>
                                </tr>`);
      

    }
    add_barspark(table);
    table.tablesorter();
    new TrisTablePagination(`table_${idx}`,{no_of_rows:10,rows:rows,
                            sys_group_totals:totvol});


  }
  async draw_donut_chart(meter_name,idx){
    this.donut_div_id = `peering_drilldown_${idx}_donut`;
    this.dom.find(`#peering_drilldown_${idx}`).find(".donut_chart_div").find('.animated-background').remove();
    this.dom.find(`#peering_drilldown_${idx}`).find(".donut_chart").append($("<div>",{id:this.donut_div_id}));
    let cgtoppers =  this.toppers_data.slice(0,this.maxitems);
    var values = [];
    var labels = [];
    for(let i= 0 ; i <  cgtoppers.length  ; i++){
      values[i] =  cgtoppers[i].metric;
      labels[i] =  cgtoppers[i].keyt.label.replace(/:0|:1|:2/g,"");
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
      showlegend: true,
    };
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };
    Plotly.newPlot(this.donut_div_id, data, layout,ploty_options);
  }
  async draw_traffic_chart(meter_name,idx){
    let cgtoppers =  this.toppers_data.slice(0,this.maxitems);
    let keys = cgtoppers.map(x=>x.keyt.key);
    for(let i=0 ; i < keys.length;i++){
      if(keys[i].includes("\\")){
        keys[i]=keys[i].replace(/\\/g,"\\\\")
      }
    }
    this.traf_chart_id = `peering_drilldown_${idx}_traffic_chart`
    this.dom.find(`#peering_drilldown_${idx}`).find(`.traffic_chart`).attr("id",this.traf_chart_id);
    let ref_model = [this.parent_cgguid,this.keyt.key,this.meters[meter_name],"Total"];
    var model_data = {cgguid:this.crosskey_interface,
        meter:this.meters[meter_name],
        key:keys.join(","),
        from_date:this.form.find("#from_date").val(),
        to_date:this.form.find("#to_date").val(),
        valid_input:1,
        ref_model:ref_model,
        show_title:false,
        legend_position:"bottom"
      };
    this.dom.find(`#peering_drilldown_${idx}`).find(`.traffic_chart_div`).find(".animated-background").remove();

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
   async draw_sankey_chart(meter_name,midx){

    this.sankey_div_id = `peering_drilldown_${midx}_sankey`;
    this.dom.find(`#peering_drilldown_${midx}`).find(".interfaces_sankey_chart").append($("<div>",{id:this.sankey_div_id}));
    this.dom.find(`#peering_drilldown_${midx}`).find('.sankey_chart_div').find(".animated-background").remove();
    // Get Bytes Toppers
    let tdata = this.toppers_data.slice(0,30);
    let keylookup = {};

    let idx=0;
    let links  = { source : [], target : [], value : [] };
    for (let i =0 ; i < tdata.length; i++)
    {   
      //change label to :0,:1,:2
      //http host and host has same label 
      
      let k=tdata[i].keyt.label;
      let parts=k.split("\\");
      let key = tdata[i].keyt.key;
      key=key.split('\\').slice(-1)[0];
      let r = key.split("_")[0];
      parts[1] = this.interfaces_ifalias[key]
      parts = [parts[0],this.routers_keymap[r].label,parts[1]];
      parts = _.map(parts,function(ai,ind){
        return ai.replace(/:0|:1|:2/g,"")+":"+ind;
      });
      tdata[i].keyt.label=parts.join("\\")
      keylookup[parts[0]] = keylookup[parts[0]]==undefined ? idx++ : keylookup[parts[0]];
      keylookup[parts[1]] = keylookup[parts[1]] || idx++;
      if (parts[2]) {
        keylookup[parts[2]] = keylookup[parts[2]] || idx++;
      }
        
    }

    for (let i =0 ; i <tdata.length; i++)
    {
      let item=tdata[i];
      let k=item.keyt.label;
      let parts=k.split("\\");
      if (parts[2]) {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric))
        links.source.push(keylookup[parts[1]])
        links.target.push(keylookup[parts[2]])
        links.value.push(parseInt(item.metric))

      } else {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric))
      }
    }
    let labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0].replace(/:0|:1|:2/g,"")).value()
    Plotly.purge(this.sankey_div_id);
    var data = {
      type: "sankey",
      orientation: "h",
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
    var width = this.dom.find(`#${this.sankey_div_id}`).width();
    width = parseInt(width)-50;
    var height = labels.length *25;
    if(height < 250){
      height =250;
    }
    if(width<1000){
      width =1000;
    }
    var layout = {
      title: `${meter_name} Mappings`,
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
  async draw_aggregate_table(group){
    var table = this.dom.find(`.${group}`).find("table");
    this.dom.find(`.${group}`).removeClass('animated-background');
    var table_id = "agg_flows_tbl_"+Math.floor(Math.random()*100000);
    table.attr("id",table_id)
    table.addClass('table table-hover table-sysdata');
    let toppers = [];
    if(group=="internal_ip" || group == "external_ip"){
      toppers.push(this.agg_flows[group]);
      toppers.push(this.agg_flows[group]);
    }else if(group=="tag_asnumber"){
      toppers.push(this.agg_flows.tag_group.find(x=>x.group_name=="asn").tag_metrics)
    }
    else if(group=="tag_prefixes"){
      toppers.push(this.agg_flows.tag_group.find(x=>x.group_name=="prf").tag_metrics)
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
    let rows = [];
    let all_keys = toppers.map(ai=>ai.key.key);
    let key_label_mappings = {};
    if (all_keys.length > 0 && group=="tag_asnumber"){
      let req_opts = {counter_group:this.parent_cgguid,keys:all_keys}
      let resp=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,req_opts);
      for(let i=0 ; i < resp.keys.length; i++){
        let kt = resp.keys[i];
        let label = kt.label;
        key_label_mappings[kt.key] = kt.label;
      }
    }
    for(let i=0; i< toppers.length;i++){
      var t = toppers[i];
      let label = key_label_mappings[t.key.key] || t.key.label;
      if(label == t.key.readable){
        label = "";
      }
      rows.push(`<tr>
                <td>${t.key.readable||t.key.key}</td>
                <td>${label}</td>
                <td>${t.count}</td>
                <td>${h_fmtvol(t.metric)}</td>
                </tr>`);
    } 

    new TrisTablePagination(table_id,{no_of_rows:10,rows:rows});
    table.tablesorter();

  }
  update_description(){
    let description = "Drilldown for ASN"
    let label = this.keyt.label;
    let readable = this.keyt.readable;

    if (readable != label){
      description = `${description}  ${readable} (${label})`;
    }else{
      description = `${description}   ${readable}`
    }
    this.description = description;
    description = `${description} <i class='fa fa-clock-o fa-fw'></i> ${h_fmtduration(this.tmint.to.tv_sec- this.tmint.from.tv_sec)}`
    $('.target').html(description)
  }

};


function run(opts) {
  new ISPDrilldownMapping(opts);
}


  //# sourceURL=isp_drilldown_mappings.js

  