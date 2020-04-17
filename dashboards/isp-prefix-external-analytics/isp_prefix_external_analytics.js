/*
  Explore router or interface usage details
*/
class ISPPrefixExternalMapping{
  constructor(opts) {

    this.dom = $(opts.divid);
    this.rand_id="";
    this.default_selected_time = opts.new_time_selector;
    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.filter_cgguid = "{00990011-44BD-4C55-891A-77823D59161B}";
    this.crosskey_router = null;
    this.crosskey_interface=null;
    this.meter_details_in = {upload:0,download:1,uniq_aspath:2,uniq_prefix:3}
    //filter by router and interface crosskey

    if(opts.jsparams &&  _.size(opts.jsparams)>0){
      this.crosskey_router = opts.jsparams.crosskey_router;
      this.crosskey_interface = opts.jsparams.crosskey_interface;
      this.meter_details_in = opts.jsparams.meters || this.meter_details_in
    } 
    this.probe_id = opts.probe_id;
    this.dash_params = opts.dash_params;
    this.add_form(opts);
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


  async compute_cg_by_name() {

    console.log("Checking for Auto_ ASN _ Router _Interface cross key groups");

    let cginfo= await fetch_trp(TRP.Message.Command.COUNTER_GROUP_INFO_REQUEST);
    let opts = {}

    try {
      opts= { 
          crosskey_router:    cginfo.group_details.find( (item) => item.name=="Auto_Routers_ASN").guid ,
          crosskey_interface: cginfo.group_details.find( (item) => item.name=="Auto_Interfaces_ASN").guid
      }
    } catch(err) {
      console.log("Unable to find counter group Auto_Routers_ASN needed for this app");
    }
    return opts;
  }

  async add_form(opts){

    await this.load_assets(opts);
    
    //assign randid to form fields
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);

    if (! _.isString(this.crosskey_router)) {
      let opts = await this.compute_cg_by_name();
      this.crosskey_router=opts.crosskey_router;
      this.crosskey_interface=opts.crosskey_interface;
    }

    //new time selector 
    new ShowNewTimeSelector({divid:"#new_time_selector"+this.rand_id,
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            });
    this.mk_time_interval();
    //get router toppers for drowdown in form
    var top_routers=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: "{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}",
      time_interval: this.tmint ,
      meter:0,
      maxitems:500
    });
    var router_key_map ={}
    for(let i= 0 ; i <  top_routers.keys.length  ; i++){
      if (top_routers.keys[i].key=="SYS:GROUP_TOTALS"){
        continue;
      }
      router_key_map[top_routers.keys[i].key] = top_routers.keys[i].label
    }
    //get interface toppers for dropdown in form
    var top_intfs=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: "{C0B04CA7-95FA-44EF-8475-3835F3314761}",
      time_interval: this.tmint ,
      meter:0,
      maxitems:1000
    });

    var interface_meters = {};
    var all_dropdown = {"0":["Please select",[["0","Please select"]]]};
    top_intfs.keys= this.sort_hash(top_intfs,"key");
    for(let i= 0 ; i <  top_intfs.keys.length  ; i++){
      if (top_intfs.keys[i].key=="SYS:GROUP_TOTALS"){
        continue;
      }
      let intf =top_intfs.keys[i].key;
      let router_key=intf.split("_")[0];
      if(interface_meters[router_key] == undefined){
        interface_meters[router_key] = [];
      }
      interface_meters[router_key].push([top_intfs.keys[i].key,top_intfs.keys[i].label]);
    }

    for (var key in interface_meters) {
      var meters = interface_meters[key];
      meters.unshift(["0","Please select"]);
      all_dropdown[key]=[router_key_map[key],meters];
    }

    let selected_router = null, selected_interface=null;
    let incoming_key = this.dash_params.key || ""
    let keyparts = incoming_key.split("_");
    if (keyparts.length==2) {
      selected_router = keyparts[0];
      selected_interface = keyparts.join("_");
    }

    var js_params = {meter_details:all_dropdown,
      selected_cg : selected_router || localStorage.getItem("apps.prefix_external_analytics.last-selected-router"),
      selected_st : selected_interface || localStorage.getItem("apps.prefix_external_analytics.last-selected-interface"),
      update_dom_cg : "routers"+this.rand_id,
      update_dom_st : "interfaces"+this.rand_id,
      chosen:true
    }
    //Load meter combo for routers and interfaces
    new CGMeterCombo(JSON.stringify(js_params));


    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    //find crosskeyguid is present automatically find base counter group
    if(this.crosskey_interface && this.cg_meters.crosskey[this.crosskey_interface]){
      this.filter_cgguid = this.cg_meters.crosskey[this.crosskey_interface][1];
    }

    this.form.submit($.proxy(this.submit_form,this));
    if(this.dash_params.valid_input == "1" || this.dash_params.valid_input==1){
      this.form.submit();
    }    
  }



  //make time interval to get toppers.
  mk_time_interval(){
    var selected_fromdate = $('#from_date'+this.rand_id).val();
    var selected_todate = $('#to_date'+this.rand_id).val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }
  submit_form(){

    // last used is the next default 
    localStorage.setItem("apps.prefix_external_analytics.last-selected-router", 
                            $('.prefix_external_analytics_form select[name="routers"] option:selected').val());

    localStorage.setItem("apps.prefix_external_analytics.last-selected-interface", 
                            $('.prefix_external_analytics_form select[name="interfaces"] option:selected').val());


    this.form.find("#btn_submit").prop('disabled', true);
    this.reset_ui();
    this.mk_time_interval();
    this.get_data_all_meters_data();
    return false;
  }
  async get_data_all_meters_data(){
    let keys = Object.keys(this.meter_details_in);
    keys = keys.slice(0,2);
    for (const [i, key] of keys.entries()) {
      this.meter_index = i;
      this.meter = this.meter_details_in[key];
      await this.get_data();
    };
    this.form.find("#btn_submit").prop('disabled', false);
  }

  // reset UI for every submit
  reset_ui(){
    this.dom.find(".ui_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
    this.maxitems=10;
    this.cgguid = null;
    this.crosskey_cgguid = null;
    this.filter_text=null;
      $('#isp_prefix_external_overview_tabs a').click(function (e) {
      e.preventDefault()
      $(this).tab('show')
    });
    //this.data_dom.find('.toppers_table_div').append("<span class='notify'><i class='fa fa-spinner fa-spin'></i>Please wait...</span>");
    //title part

  }

  
  update_target_text(){
    let selected_router = $('#routers'+this.rand_id).val();
    let selected_interface = $('#interfaces'+this.rand_id).val();
    let selected_router_text = $('#routers'+this.rand_id +' option:selected').text();
    let selected_intf_text = $('#interfaces'+this.rand_id +' option:selected').text();
    this.target_text="";
    if(selected_router != "0"){
      this.target_text = `${selected_router_text}`;
    }
    if(selected_interface != "0"){
      this.target_text = `${this.target_text}->${selected_intf_text}`;
    }
    let selected_fromdate = $('#from_date'+this.rand_id).val();
    let selected_todate = $('#to_date'+this.rand_id).val();
    let fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    let toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);

    let duration  = `   <i class='fa fa-clock-o fa-fw '></i>
                     from ${selected_fromdate} to ${selected_todate}
                     (${h_fmtduration(toTS-fromTS)})`
    
    $('small.target').html(this.target_text + duration);
  }

  // build model 
  async get_data()  {
    //find guid to load data
    let selected_router = $('#routers'+this.rand_id).val();
    let selected_interface = $('#interfaces'+this.rand_id).val();
    
    if(Object.keys(this.cg_meters.crosskey).length == 0){
      this.crosskey_cgguid = null;
    }
    this.update_target_text();
    if( selected_interface !="0"){
      this.cgguid = this.crosskey_interface;
      this.filter_text = selected_interface;
    }
    else if(selected_router != "0"){
      this.cgguid = this.crosskey_router;
      this.filter_text = selected_router;
    }
    else if(selected_router){
      this.cgguid = this.filter_cgguid
    }
    
    this.crosskey_cgguid =  this.cgguid;
    //find bucket size
    if(this.cg_meters.all_cg_bucketsize[this.cgguid]==undefined){
      this.data_dom.html('<div class="alert alert-info">Crosskey counter groups not created. Need crosskey counter groups to work with this app</div>');
      return
    }
   
    this.top_bucket_size = this.cg_meters.all_cg_bucketsize[this.cgguid].top_bucket_size;
    this.bucket_size = this.cg_meters.all_cg_bucketsize[this.cgguid].bucket_size;
    this.multiplier = 1;
    if(Object.keys(this.cg_meters.all_meters_type[this.cgguid]).length !=0 &&
        this.cg_meters.all_meters_type[this.cgguid][this.meter].type==4 &&
        this.cg_meters.all_meters_type[this.cgguid][this.meter].units=="Bps"){
          this.multiplier=8;
    }

    // crosskey bucket size 
    this.ck_top_bucket_size =  300;
    this.meter_types=this.cg_meters.all_meters_type[this.cgguid];
    if(this.crosskey_cgguid){
      this.ck_top_bucket_size=this.cg_meters.all_cg_bucketsize[this.crosskey_cgguid].top_bucket_size;
      this.meter_types = this.cg_meters.all_meters_type[this.crosskey_cgguid];
      if(_.size(this.meter_types) == 0 ){
        let parent_cgguid = this.cg_meters.crosskey[this.crosskey_cgguid][1];
        this.meter_types = this.cg_meters.all_meters_type[parent_cgguid];
      }
    }

    // load_toppers
    let req_opts = {
      counter_group: this.cgguid,
      time_interval: this.tmint ,
      meter:this.meter,
      maxitems:200
    }
    if(this.filter_text){
      req_opts["key_filter"]=this.filter_text
    }
    this.cgtoppers_resp=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, req_opts);
    this.cgtoppers_resp.keys = this.sort_hash(this.cgtoppers_resp,"metric");
    
    // reject sysgrup and xx
    this.cgtoppers_resp.keys = _.reject(this.cgtoppers_resp.keys,function(topper){
      return topper.key=="SYS:GROUP_TOTALS" || topper.key.includes("XX");
    });
    
    this.sys_group_totals = 1;
    _.each(this.cgtoppers_resp.keys,function(topper){
      this.sys_group_totals = this.sys_group_totals + topper.metric.toNumber(); 
    },this);
    this.sys_group_totals = this.sys_group_totals*this.top_bucket_size;
   

    // start this 
    await this.resolve_prefixes();
    await this.resolve_aspath();
    await this.draw_table();
    await this.draw_chart();
    await this.draw_sankey_chart();

  }


  async draw_table(){


    let rows = [];
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".toppers_table_div").find('.animated-background').remove();
    var table = this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".toppers_table").find("table");
    this.table_id = `table_${this.meter}${this.rand_id}`;
    table.attr("id",this.table_id)
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append(`<tr><th>Routed Prefix</th><th>BGP Prefix</th>
                                <th>Peer-AS</th>
                                <th>Origin-AS</th>
                                <th>Org</th>
                                <th sort='volume' barspark='auto'>Volume</th>
                                <th sort='volume'>Avg <br/>Bandwidth</th><th class='nosort'></th>
                                </tr>`);
    let totvol=this.cgtoppers_resp.keys.reduce((a,b)=>a +parseInt(b.metric),0);
    $('.volume_'+this.meter_index).text(` (${h_fmtvol(totvol*this.top_bucket_size)}) `);
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,100);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      
      let dropdown = $("<span class='dropdown'><a class='dropdown-toggle' data-toggle='dropdown' href='javascript:;;'><small>Options<i class='fa fa-caret-down fa-fw'></i></small></a></span>");
      let dropdown_menu = $("<ul class='dropdown-menu  pull-right'></ul>");
      dropdown_menu.append("<li><a href='javascript:;;'>Traffic Chart</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Key Dashboard</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Drilldown</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Lookup Peer AS</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Lookup Origin AS</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Lookup Prefix</a></li>");


      dropdown.append(dropdown_menu);

      let key = topper.key.split("\\").shift();
      let full_key= topper.key;

      let readable = topper.readable.split("\\").shift();
      let label = topper.label.split("\\").shift();
      let avg_bw = topper.metric_avg.toNumber(); 
      avg_bw = avg_bw*this.multiplier;
      let statids = Object.values(this.meter_details_in).slice(0,2)

      rows.push(`<tr data-key="${key}" data-statid=${this.meter} data-label="${topper.label}" 
                    data-readable="${topper.readable}" data-full_key="${full_key}"
                    data-statid-index=${this.meter_index} data-statids=${statids}>
                      <td class='linkdrill'><a href='javascript:;;'>${readable}</a></td>
                      <td>${topper.bgp_prefix}</a></td>
                      <td>${topper.peer_as} [${topper.peer_as_code}]</td>
                      <td>${topper.origin_as} [${topper.origin_as_code}]</td>
                      <td>${topper.org}</td>
                      <td>${h_fmtvol(topper.metric*this.top_bucket_size)}${this.meter_types[this.meter].units.replace("ps","")}</td>
                      <td>${h_fmtbw(avg_bw)}${this.meter_types[this.meter].units.replace("Bps","bps")}</td>
                      <td>${dropdown[0].outerHTML}</td>
                      </tr>`);


    }
    new TrisTablePagination(this.table_id,{no_of_rows:10,rows:rows,
                            sys_group_totals:this.sys_group_totals,
                            callback:$.proxy(function(){this.pagination_callback()},this)});
      table.find('.dropdown-menu').find('a').bind('click',$.proxy(function(event){
      this.dropdown_click(event);
    },this));
    table.find('.linkdrill').find('a').bind('click',$.proxy(function(event){
      this.dropdown_click(event);
    },this));
    table.tablesorter();
    table.closest('.panel').find(".badge").html(rows.length);
    new ExportToCSV({table_id:this.table_id,filename_prefix:"top_upload_asn",append_to:"panel"});
  }

  pagination_callback(){
    this.data_dom.find("table").find('.dropdown-menu').find('a').bind('click',$.proxy(function(event){
      this.dropdown_click(event);
    },this));
    this.data_dom.find("table").find('.linkdrill').find('a').bind('click',$.proxy(function(event){
      this.dropdown_click(event);
    },this));

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

  async draw_chart(){
    this.dount_div_id = `dount_chart${this.meter_index}_${this.rand_id}`;
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".donut_chart").append($("<div>",{id:this.dount_div_id}));
    this.trfchart_div_id = `traffic_chart_${this.meter_index}_${this.rand_id}`;
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".traffic_chart").append($("<div>",{id:this.trfchart_div_id}));
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".traffic_chart_div").find(".animated-background").remove();
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".donut_chart_div").find(".animated-background").remove();


    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    var values = [];
    var labels = [];
    let width =this.dom.find(".donut_chart").width();
    for(let i= 0 ; i <  cgtoppers.length  ; i++){
      values[i] =  cgtoppers[i].metric.toNumber()*this.top_bucket_size;
      labels[i] =  cgtoppers[i].label.replace(/:0|:1|:2/g,"").split("\\").shift();
      labels[i] = labels[i].substr(0,parseInt((width/100)*6))+"("+h_fmtvol(values[i])+")";
    }
    var data = [{
      values:values,
      labels:labels,
      hoverinfo: 'label+percent+name',
      hole: .4,
      type: 'pie'
    }];

    var layout = {
      title: '',
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
      width:  width,
      showlegend: true,
    };
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };
    Plotly.newPlot(this.dount_div_id, data, layout,ploty_options);

    if(cgtoppers.length==0){
      $('#'+this.dount_div_id).html("<div class='alert alert-info'>No data found.</div>"); 
    }

    var keys = _.map(cgtoppers,function(ai){return ai.key});
    for(let i=0 ; i < keys.length;i++){
      if(keys[i].includes("\\")){
        keys[i]=keys[i].replace(/\\/g,"\\\\")
      }
    }
    if(keys.length==0){
      $('#'+this.trfchart_div_id).html("<div class='alert alert-info'>No data found.</div>"); 
      return true;
    }
    let cgguid = this.cgguid;
    let key = this.filter_text;
    let meter = this.meter;
    let ref_model =[];
    if(this.filter_text==null || this.filter_text == undefined){
      cgguid = GUID.GUID_CG_AGGREGATE();
      key = ["DIR_OUTOFHOME","DIR_INTOHOME"][this.meter];
      meter=0;
    }else if(this.filter_text.match(/_/)){
      cgguid = GUID.GUID_CG_FLOWINTERFACE();
      meter = [2,1][this.meter_index];
    }
    ref_model = [cgguid,key,meter,"Total"]

    var model_data = {cgguid:this.cgguid,
        meter:this.meter,
        key:keys.join(","),
        from_date:this.form.find("#from_date"+this.rand_id).val(),
        to_date:this.form.find("#to_date"+this.rand_id).val(),
        valid_input:1,
        surface:"STACKEDAREA",
        ref_model:ref_model
    };
    await $.ajax({
      url:"/trpjs/generate_chart",
      data:model_data,
      context:this,
      success:function(resp){
        $('#'+this.trfchart_div_id).html(resp);

      }
    });

  }
  async draw_sankey_chart(){
    this.sankey_div_id = `sankey_chart_${this.meter_index}${this.rand_id}`;
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".sankey_chart").append($("<div>",{id:this.sankey_div_id}));
    if(this.crosskey_cgguid == this.filter_cgguid){
      this.crosskey_cgguid = this.crosskey_router;
    }

    // Get Bytes Toppers
    if(this.cgguid != this.crosskey_cgguid){
      this.crosskeytoppers=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
        counter_group: this.crosskey_cgguid,
        time_interval: this.tmint ,
        meter:this.meter,
        maxitems:1000
      });
      this.cgtoppers_bytes = $.merge([], this.crosskeytoppers.keys);
      this.cgtoppers_bytes = _.reject(this.cgtoppers_bytes, function(ai){
        return ai.key=="SYS:GROUP_TOTALS" || ai.key.includes("XX");
      });
    }else{
      this.cgtoppers_bytes = this.cgtoppers_resp.keys;
    }
    this.data_dom.find(`#prefix_external_overview_${this.meter_index}`).find(".sankey_chart_div").find(".animated-background").remove();

    this.cgtoppers_bytes = this.cgtoppers_bytes.slice(0,30);
    if(this.cgtoppers_bytes.length==0){
      $('#'+this.sankey_div_id).html("<div class='alert alert-info'>No data found.</div>"); 
      return true;
    }
    let keylookup = {};
    let idx=0;
    let links  = { source : [], target : [], value : [] };

    for (let i =0 ; i < this.cgtoppers_bytes.length; i++)
    {   
      //change label to :0,:1,:2
      //http host and host has same lable 
      let k=this.cgtoppers_bytes[i].label;
      let parts=k.split("\\");
     

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
        links.value.push(parseInt(item.metric*this.ck_top_bucket_size))
        links.source.push(keylookup[parts[1]])
        links.target.push(keylookup[parts[2]])
        links.value.push(parseInt(item.metric*this.ck_top_bucket_size))

      } else {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric*this.ck_top_bucket_size))
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
    var width = this.data_dom.find(".sankey_chart").width();
    width = parseInt(width)-50;
    var height = labels.length *25;
    if(height < 250){
      height =250;
    }
    var layout = {
      title: '',
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
  dropdown_click(event){
    var target = $(event.target);
    var tr = target.closest("tr");
    switch($.inArray(target.parent()[0],target.closest("td").find("li:not(.divider)"))){
      case 0:
      case -1:
        let params = {
          key: tr.data("full_key").toString().replace(/\\/g,"\\\\"),
          statids:tr.data("statid"),
          cgguid:this.cgguid,
          window_fromts:this.tmint.from.tv_sec,
          window_tots:this.tmint.to.tv_sec,
        }
        let url = "/trpjs/generate_chart_lb?"+$.param(params);
        load_modal(url);
        break;
        
      case 1:
         let link_params =$.param({dash_key:"key",
                         guid:this.cgguid,
                         key:tr.data("full_key"),
                         statid:tr.data("statid")
                        });
        window.open("/newdash/index?"+link_params);
        break;
      case 2:
        let ck_cgguid = this.crosskey_cgguid;
        if(this.selected_router=="0"){
          ck_cgguid=this.crosskey_interface;
        }
        window.open("/newdash/index?" + 
                    $.param({
                        key: tr.data("key"),
                        statids:tr.data("statids"),
                        label:`${tr.data("label")}`.toString().replace(/\\/g,"\\\\"),
                        readable:`${tr.data("readable")}`.toString().replace(/\\/g,"\\\\"),                        
                        cgguid:this.filter_cgguid,
                        ck_cgguid:ck_cgguid,
                        filter_cgname:this.filter_cgname,
                        window_fromts:this.tmint.from.tv_sec,
                        window_tots:this.tmint.to.tv_sec,
                        "dash_key_regex":"gitPrefixAnalyticsDrilldown"
                    }));
        break;
      case 3:
        let asn1=tr.find('td')[2].innerHTML;
        window.open("https://bgpview.io/asn/"+asn1,"_blank")
        break;
      case 4:
        let asn2=tr.find('td')[3].innerHTML;
        window.open("https://bgpview.io/asn/"+asn2,"_blank")
        break;
      case 5:
        let prefix1=tr.data('key');
        window.open("https://bgpview.io/prefix/"+prefix1,"_blank")
        break;
    } 
  }

  async get_top_prefixes(event){
    let target = $(event.target);
    let tr = target.closest("tr");
    let statid = tr.data("statid-index");
    var shell_modal = create_shell_modal();
    shell_modal.find(".modal-header h4").html("Top prefixes <small>Show top 100 prefixes </small><span class='badge'></span>");
    var message = "<h4><i class='fa fa-spin fa-spinner'></i> Please wait ... Getting data</h4>";
    shell_modal.find(".modal-body").html(message);
    $('#shortcut-div').html(shell_modal);
    $(shell_modal).modal({
      keyboard:true
    });
    let opts = {flowtag:`[asn]${tr.data("key")}`,
                  time_interval:this.tmint,
                  probe_id:this.probe_id,
                  group_by_fields:["flowtag"]};

    if(this.filter_text && this.filter_text.split("_").length >=1){
      let interfaces = this.filter_text.split("_");
      opts["nf_routerid"] = TRP.KeyT.create({key:interfaces[0]});
      if(interfaces[1]){
        if (statid == 0){
          shell_modal.find(".modal-header h4 span.badge").addClass('badge-success');
          opts[`nf_ifindex_out`]= TRP.KeyT.create({key:interfaces[1]});
        }else{
          shell_modal.find(".modal-header h4 span.badge").addClass('badge-warning');
          opts[`nf_ifindex_in`]= TRP.KeyT.create({key:interfaces[1]});
        }
      }
    }
    let resp = await fetch_trp(TRP.Message.Command.AGGREGATE_SESSIONS_REQUEST,opts);

    let prefix_toppers =resp.tag_group.find(x=>x.group_name=="prf")
    if(! prefix_toppers){
      shell_modal.find(".modal-body h4").html("<div class='alert alert-info'>No data found</div>");
      return true;
    }
    let tag_metrics = prefix_toppers.tag_metrics.slice(0,100);
    shell_modal.find(".modal-header h4 span.badge").html(tag_metrics.length);
    var table = $("<table>",{class:"table table-sysdata"});
    table.append("<thead><tr><th>Prefix</th><th>Count </th><th sort='volume'>Volume</th></thead>");
    table.append("<tbody></tbody>");
    _.each(tag_metrics,function(keyt){
      let tr = $("<tr>");
      tr.append(`<td>${keyt.key.key}</td>`);
      tr.append(`<td>${keyt.count}</td>`);
      tr.append(`<td>${h_fmtvol(keyt.metric.toNumber())}</td>`);
      table.append(tr);
    });
    let label = tr.data("label").split("\\")[0];
    this.target_text = `${this.target_text}->${tr.data("key")}(${label})`;
    shell_modal.find(".modal-body h4").html(this.target_text);
    shell_modal.find(".modal-body").append(table);
    table.tablesorter()
  }


async resolve_prefixes(event){


  let prefix_csv = _.chain(this.cgtoppers_resp.keys)
                     .collect((a)=>{ 
                        let key = a.key.split("\\").shift();
                        return key;})
                     .join('\n')
                     .value();

  // bgp query prefix to ORG 
  let resp = await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST,
                                {
                                  tool:3,
                                  tool_input: `-o -t -p  /tmp -P TOOL_INPUT_FILE`,
                                  destination_node:this.probe_id,
                                  tool_input_file_data: prefix_csv
                                });
  let lkp = {}
  let maparr = resp.tool_output.split("\n");
  maparr.forEach((a) => {
      let v=a.split('\t');
      lkp[v[0]]=v[1];
  });

  // update model
  this.cgtoppers_resp.keys.forEach((a) => {
    let key = a.key.split("\\").shift();
    let org=lkp[key];
    if(org) {
      a.org=org;
    } else {
      a.org="";
    }
  });

}

async resolve_aspath(event){

  let prefix_csv = _.chain(this.cgtoppers_resp.keys)
                     .collect((a)=>{ 
                        let key = a.key.split("\\").shift();
                        return key;})
                     .join('\n')
                     .value();

  // bgp query prefix to ORG 
  let resp = await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST,
                                {
                                  tool:5,
                                  tool_input: `-t -B -d -n 0 -P TOOL_INPUT_FILE`,
                                  destination_node:this.probe_id,
                                  tool_input_file_data: prefix_csv
                                });
  let lkp_aspath = {}
  let lkp_bgp_prefix= {}
  let lkp_ascodes = {}
  let maparr = resp.tool_output.split("\n");
  maparr.forEach((a) => {
      let v=a.split('\t');
      if (v.length>=3) {
        lkp_bgp_prefix[v[0]]=v[1];
        lkp_aspath[v[0]]=v[2];
        if (v.length>=4) {
          lkp_ascodes[v[0]]=v[3];
        }
      }
  });

  // update model
  this.cgtoppers_resp.keys.forEach((a) => {
    let key = a.key.split("\\").shift();
    let org=lkp_aspath[key];
    if(org) {
      let asnarr = org.split(' ');
      a.peer_as = _.first(asnarr);
      a.origin_as = _.last(asnarr);
    } else {
      a.peer_as="";
      a.origin_as="";
    }
    let bgpprefix = lkp_bgp_prefix[key];
    if (bgpprefix) {
      a.bgp_prefix=bgpprefix;
    } else {
      a.bgp_prefix="";
    }

    let ascodes=lkp_ascodes[key];
    if (ascodes) {
      let asnarr = ascodes.split(' ');
      a.peer_as_code = _.first(asnarr);
      a.origin_as_code = _.last(asnarr);
    } else {
      a.peer_as_code="";
      a.origin_as_code="";
    }

  });
}


  
}; // class 


function run(opts) {
  new ISPPrefixExternalMapping(opts);
}

//# sourceURL=prefix_external_analytics.js