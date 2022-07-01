/*- 
  Peering Analytics(ASN)
  Show detailed ASN Usage
    // User selectes router and interfaces - Show ASNumber usage for crosskey interface ASN
    // User selectes only router - Show ASNumber usage for crosskey routers ASN
    // User selectes none show deafult ASNumber from default ASNumber couter group

  Explore router or interface usage details
*/
class ISPOverviewMapping{
  constructor(opts) {
    this.dom = $(opts.divid);
    this.default_selected_time = opts.new_time_selector;
    this.logo_tlhs = opts.logo_tlhs;
    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    //crosskey for flowasn/lroutergroup
    this.counter_group = opts.jsparams.counter_group
     //parent countergroup crosskey for flowasn/lroutergroup
    this.parent_counter_group = opts.jsparams.parent_counter_group
   
    this.meter_details_in = {upstream_receive:1,upstream_transmit:2,
                             downstream_receive:3,downstream_transmit:4,
                             uniq_aspath:5,uniq_prefix:6}
    //filter by router and interface crosskey
    if(opts.jsparams &&  _.size(opts.jsparams)>0){
      
      this.meter_details_in = opts.jsparams.meters || this.meter_details_in
    } 

    if(opts.remove_ls_items==true || opts.remove_ls_items=="true"){
      clear_localstorage_items({remove_keys:"apps.locationasnanalytics.last-selected*"});
    }
    this.probe_id = opts.probe_id;
    this.dash_params = opts.dash_params;
    this.percentile = opts.percentile;
    this.rand_id="";
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

    console.log("Checking for FlowGens_Location_x_ASNe cross key groups");

    let cginfo= await fetch_trp(TRP.Message.Command.COUNTER_GROUP_INFO_REQUEST);
    let opts = {}
    
    try {
      opts= { 
          crosskey_router:    cginfo.group_details.find( (item) => item.name=="FlowGens_Location_x_ASN").guid ,
      }
    } catch(err) {
      console.log("Unable to find counter group FlowGens_Location_x_ASN needed for this app");
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
    }

    //new time selector 
    new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            },this.callback_load_routers,this);
    $('#from_date').val(this.default_selected_time.start_date);
    $('#to_date').val(this.default_selected_time.end_date);
    this.mk_time_interval();

    await this.load_routers_interfaces();

    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    

    this.form.submit($.proxy(this.submit_form,this));
    if(this.dash_params.valid_input == "1" || this.dash_params.valid_input==1){
      this.form.submit();
    }    
  }

  async callback_load_routers(s,e,args){
    await args.load_routers_interfaces();
  }

  async load_routers_interfaces(){
    this.mk_time_interval();
    //load keys from key request
    // load_toppers
    let key_space=TRP.KeySpaceRequest.KeySpace.create();
    key_space.from_key=TRP.KeyT.create({key:"0"})
    key_space.to_key=TRP.KeyT.create({key:"Z"})
    let req_opts = {
      counter_group: this.parent_counter_group,
      time_interval: this.tmint ,
      maxitems:100,
      spaces:[key_space]
    }
   
    let resp =await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST, req_opts);
    let sel = document.getElementById('routers');
    sel.innerHTML='';
    let opt = document.createElement("option");
    opt.value="0";
    opt.text="Please select";
    sel.add(opt,null);
    resp.hits.forEach(keyt=>{
      
      opt = document.createElement("option");
      opt.value=keyt.key;
      opt.text=keyt.label || keyt.readable;
      sel.add(opt,null)
    });
  }



  //make time interval to get toppers.
  mk_time_interval(){
    var selected_fromdate = $('#from_date').val();
    var selected_todate = $('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }
  submit_form(){

    // last used is the next default 
    localStorage.setItem("apps.peeringanalytics.last-selected-router", 
                            $('.peeringanalytics_form select[name="routers"] option:selected').val());

    this.form.find("#btn_submit").prop('disabled', true);
    this.reset_ui();
    this.mk_time_interval();
    this.get_data_all_meters_data();
    return false;
  }
  async get_data_all_meters_data(){
    await this.draw_router_traffic_chart()

    let keys = Object.keys(this.meter_details_in);
    keys = keys.slice(0,4);  
    for (const [i, key] of keys.entries()) {
      this.meter_index = i;
      this.meter = this.meter_details_in[key];
      await this.get_data();
    };
    this.form.find("#btn_submit").prop('disabled', false);
    new ExportToPDF({add_button_to:".add_download_btn",
                      tint:this.tmint,
                      logo_tlhs:this.logo_tlhs,
                      download_file_name:"location_analytics",
                      report_opts:{
                        header:{h1:"Location Traffic(Routers)"},
                        report_title:{h1:this.target_text},
                        nodes:this.report_nodes 
                      }
                    });
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
      $('#isp_overview_tabs a').click(function (e) {
      e.preventDefault()
      $(this).tab('show')
    });
    this.report_nodes = [];
    this.section_headers=[];
      this.report_nodes.push({type:"svg",header_text:"auto",h1:"h5",find_by:`#router_loc_traffic`});
      this.report_nodes.push({type:"page_break"});
    _.each([this.meter_details_in.upstream_receive,this.meter_details_in.upstream_transmit,this.meter_details_in.downstream_receive,this.meter_details_in.downstream_transmit],$.proxy(function(idx,ai){
      this.report_nodes.push({type:"table",header_text:"auto",h1:"h5",h2:"h5 small",section_header:ai,find_by:`#table_${ai}`});
      this.report_nodes.push({type:"page_break"});
      this.report_nodes.push({type:"svg",header_text:"auto",h1:"h5",h2:"h5 small",find_by:`#traffic_chart_${ai}_`});
      this.report_nodes.push({type:"svg",header_text:"auto",h1:"h5",h2:"h5 small",find_by:`#donut_chart${ai}_`});
      this.report_nodes.push({type:"page_break"});
      this.report_nodes.push({type:"svg",header_text:"auto",h1:"h5",h2:"h5 small",find_by:`#sankey_chart_${ai}`});
      if(ai!=3){
        this.report_nodes.push({type:"page_break",add_header_footer:false});
      }

    },this));
  }

  async draw_router_traffic_chart(){

    let models = [];
    let routerDrop = document.querySelector(`#routers`);
    let routerKey=routerDrop.options[routerDrop.selectedIndex].value;
    if(routerKey==0){
      routerKey="SYS:GROUP_TOTALS";
    }

    models.push({counter_group:this.parent_counter_group,key:routerKey,meter:0,label:"Total"});
    let opts ={
      models:JSON.stringify(models),
      surface:"MRTG",
      show_table:1,
      window_fromts:this.tmint.from.tv_sec,
      window_tots:this.tmint.to.tv_sec,
      divid:"#router_loc_traffic",
      title:$('#routers').val()==0 ?"Total Traffic":$('#routers').val(),
      height:250
    }

    draw_apex_chart(opts);



  }
  update_target_text(){
    let selected_router = $('#routers').val();
    let selected_router_text = $('#routers option:selected').text();
    this.target_text="";
    if(selected_router != 0){
      this.target_text = `${selected_router_text}`;
    }
    
    let selected_fromdate = $('#from_date').val();
    let selected_todate = $('#to_date').val();
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
    this.selected_router = $('#routers').val();
    if(this.selected_router!=0){
      this.filter_text=this.selected_router;
    }
    this.update_target_text();
    
    if(this.cg_meters.all_cg_bucketsize[this.counter_group]==undefined){
      this.data_dom.html('<div class="alert alert-info">Crosskey counter groups not created. Need crosskey counter groups to work with this app</div>');
      return
    }
   
    this.top_bucket_size = this.cg_meters.all_cg_bucketsize[this.counter_group].top_bucket_size;
    this.bucket_size = this.cg_meters.all_cg_bucketsize[this.counter_group].bucket_size;
    this.multiplier = 1;
    if(Object.keys(this.cg_meters.all_meters_type[this.counter_group]).length !=0 &&
        this.cg_meters.all_meters_type[this.counter_group][this.meter].type==4 &&
        this.cg_meters.all_meters_type[this.counter_group][this.meter].units=="Bps"){
          this.multiplier=8;
    }
    this.meter_types = this.cg_meters.all_meters_type[this.counter_group];


    // crosskey bucket size 
    this.ck_top_bucket_size =  300;
   
    // load_toppers
    let req_opts = {
      counter_group: this.counter_group,
      time_interval: this.tmint ,
      meter:this.meter,
      maxitems:100,
      
    }
    if(this.percentile > 0){
      req_opts["get_percentiles"]=[this.percentile];
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

    await this.draw_table();
    await this.draw_chart();
    //await this.draw_sankey_chart();
  }


  async draw_table(){


    let rows = [];
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".toppers_table_div").find('.animated-background').remove();
    var table = this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".toppers_table").find("table");
    this.table_id = `table_${this.meter_index}${this.rand_id}`;
    table.attr("id",this.table_id)
    table.addClass('table table-hover table-sysdata');
    let percentile_th = ``;
    if(this.percentile > 0){
    percentile_th = `<th sort='volume'>${this.percentile}th</th>`;

    }
    table.find("thead").append(`<tr><th>ASN</th><th>Name</th>
                                <th sort='volume' barspark='auto'>Volume</th><th sort='volume'>Max <br/>Bandwidth</th>
                                <th sort='volume'>Avg <br/>Bandwidth</th>${percentile_th}<th class='nosort'></th>
                                </tr>`);
    let totvol=this.cgtoppers_resp.keys.reduce((a,b)=>a +parseInt(b.metric),0);
    $('.volume_'+this.meter_index).text(` (${h_fmtvol(totvol*this.top_bucket_size)}) `);
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,100);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      
      let dropdown = $("<span class='dropdown float-end'><a class='dropdown-toggle' data-bs-toggle='dropdown' href='javascript:;; data-bs-toggle='tooltip' title='Click to get more options'><i class='fa fa-fw fa-server'></i></a></span>");
      let dropdown_menu = $("<ul class='dropdown-menu'></ul>");
      dropdown_menu.append("<li><a class='dropdown-item' href='javascript:;;'>Traffic Chart</a></li>");
      dropdown_menu.append("<li><a class='dropdown-item' href='javascript:;;'>Key Dashboard</a></li>");
      dropdown_menu.append("<li><a class='dropdown-item' href='javascript:;;'>ASN Lookup</a></li>");
      dropdown.append(dropdown_menu);

      let key = topper.key.split("\\").shift();
      let full_key= topper.key;

      let readable = topper.readable.split("\\").shift();
      let label = topper.label.split("\\").shift();
      let desc = topper.description.replace("\\\\","")
      let avg_bw = topper.metric_avg.toNumber(); 
      avg_bw = avg_bw*this.multiplier;
      let max_bw = topper.metric_max.toNumber()*this.multiplier; 
    
      let intf_readable = topper.readable.split("\\").pop();
      let router_ip = intf_readable.split("_")[0];

      let statids = Object.values(this.meter_details_in).slice(0,2);
      let percentile_td = '';
      if(this.percentile > 0 && topper.percentiles.length >0 ){
        let percentile_val=topper.percentiles[0].value.toNumber()*this.multiplier;
        percentile_td=`<td>${h_fmtbw(percentile_val)}${this.meter_types[this.meter].units.replace("Bps","bps")}</td>`

      }
      rows.push(`<tr data-key="${key}" data-statid=${this.meter} data-label="${topper.label}" 
                    data-readable="${topper.readable}" data-full_key="${full_key}"
                    data-statids="${statids}" data-statid-index=${this.meter_index}
                    data-router_ip="${router_ip}">
                      <td class='linkdrill'><a href='javascript:;;'>${readable}</a></td>
                      <td class='linkdrill'><a href='javascript:;;'>${label}</a><p class='small'>${desc}</p></td>
                      <td>${h_fmtvol(topper.metric*this.top_bucket_size)}${this.meter_types[this.meter].units.replace("ps","")}</td>
                      <td>${h_fmtbw(max_bw)}${this.meter_types[this.meter].units.replace("Bps","bps")}</td>
                      <td>${h_fmtbw(avg_bw)}${this.meter_types[this.meter].units.replace("Bps","bps")}</td>
                      ${percentile_td}
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
    table.closest('.card').find(".badge").html(rows.length);
   
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
    this.donut_div_id = `donut_chart${this.meter_index}_${this.rand_id}`;
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".donut_chart").append($("<div>",{id:this.donut_div_id}));
    this.trfchart_div_id = `traffic_chart_${this.meter_index}_${this.rand_id}`;
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".traffic_chart").append($("<div>",{id:this.trfchart_div_id}));
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".traffic_chart_div").find(".animated-background").remove();
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".donut_chart_div").find(".animated-background").remove();


    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    var values = [];
    var labels = [];
    let width =this.dom.find(".donut_chart").width();
    for(let i= 0 ; i <  cgtoppers.length  ; i++){
      values[i] =  cgtoppers[i].metric.toNumber()*this.top_bucket_size;
      labels[i] =  cgtoppers[i].label.replace(/:0|:1|:2/g,"").split("\\").shift();
      labels[i] = labels[i].substr(0,parseInt((width/100)*6))+"("+h_fmtvol(values[i])+")";
    }
    
    var options = {
      series: values.flat(),
      chart: {
        height:250,
        type: "pie",
      },
      dataLabels: {
        enabled: true,
        formatter: function (val,i) {
          
          return `${h_fmtvol(i.w.globals.seriesTotals[i.seriesIndex])}(${val.toFixed(1)})%`
        },
      },
      
      labels: labels,
      responsive: [{
        breakpoint: 480,
        options: {
          chart: {
            width: 200
          },
            legend: {
              position: "bottom"
            }
        }
      }]
    };
    let ele = document.querySelector(`#${this.donut_div_id}`);
    if(ele.offsetWidth==0){
      let width = ele.closest('.tab-pane').parentElement.offsetWidth;
      options.chart.width=width;
    }
    var chart = new ApexCharts(ele, options);


    chart.render();

    if(cgtoppers.length==0){
      $('#'+this.donut_div_id).html("<div class='alert alert-info'>No data found.</div>"); 
    }

    var keys = _.map(cgtoppers,function(ai){return [ai.key,ai.label]});
    for(let i=0 ; i < keys.length;i++){
      if(keys[i][0].includes("\\")){
        keys[i][0]=keys[i][0].replace(/\\/g,"\\\\");
        keys[i][1]=keys[i][1].split("\\")[0];
      }
    }
    if(keys.length==0){
      $('#'+this.trfchart_div_id).html("<div class='alert alert-info'>No data found.</div>"); 
      return true;
    }
   
    let models=[];
    keys.forEach(k=>{
      models.push({counter_group:this.counter_group,meter:this.meter,key:k[0],label:k[1]})
    })

    var model_data = {
        models:JSON.stringify(models),
        from_date:this.form.find("#from_date"+this.rand_id).val(),
        to_date:this.form.find("#to_date"+this.rand_id).val(),
        surface:"STACKEDAREA",
        legend_position:"bottom",
        divid:`#${this.trfchart_div_id}`
    };
    draw_apex_chart(model_data);
  }
  async draw_sankey_chart(){
    this.sankey_div_id = `sankey_chart_${this.meter_index}${this.rand_id}`;
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".sankey_chart").append($("<div>",{id:this.sankey_div_id}));
    
    // Get Bytes Toppers
    if(this.cgguid != this.crosskey_cgguid){
      this.crosskeytoppers=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
        counter_group: this.counter_group,
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
    this.data_dom.find(`#isp_overview_${this.meter_index}`).find(".sankey_chart_div").find(".animated-background").remove();

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
        pad: 12,
        thickness: 20,
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
    width = parseInt(width)-20;
    var height = labels.length *26;
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
        let desc = this.form.find("#routers option:selected").text();
        desc = `Traffic chart for ${tr.data("label")}`;
        let models=[{counter_group:this.counter_group,
                    key:tr.data("full_key").toString().replace(/\\/g,"\\\\"),
                    meter:tr.data("statid")}]
        let params = {
          window_fromts:this.tmint.from.tv_sec,
          window_tots:this.tmint.to.tv_sec,
          models:JSON.stringify(models),
          show_table:1,
          surface:"mrtg"
        }
        new ApexChartLB(params,{modal_title:desc});
        break;
      case 2:
        let link_params =$.param({dash_key:"key",
                         guid:this.cgguid,
                         key:tr.data("full_key"),
                         statid:tr.data("statid")
                        });
        window.open("/newdash/index?"+link_params);
        break;
      
      case 3:
        let asn=tr.data('full_key').match(/\w+/)[0]
        window.open("https://bgpview.io/asn/"+asn,"_blank")
        break;
    


    } 
  }

};



function run(opts) {
  new ISPOverviewMapping(opts);
}



//# sourceURL=isp_location_analytics.js
