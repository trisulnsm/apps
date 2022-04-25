/*- 
  Customer  ASN traffic
 
*/
class CustomerASNTraffic{
  constructor(opts) {

    this.dom = $(opts.divid);
    this.rand_id="";
   
    this.default_selected_time = opts.new_time_selector;
    this.logo_tlhs = opts.logo_tlhs;
    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    //if user doesn't select router and interfaces use this
    this.filter_cgguid = "{03E016FC-46AA-4340-90FC-0E278B93C677}";
    this.crosskey_router = null;
    this.crosskey_interface=null;
    this.meter_details_in = {receive:[1,3],transmit:[2,4]}
    //filter by router and interface crosskey
    if(opts.jsparams &&  _.size(opts.jsparams)>0){
      this.crosskey_router = opts.jsparams.crosskey_router;
      this.crosskey_interface = opts.jsparams.crosskey_interface;
      this.meter_details_in = opts.jsparams.meters || this.meter_details_in
    } 

    if(opts.remove_ls_items==true || opts.remove_ls_items=="true"){
      clear_localstorage_items({remove_keys:"apps.peeringanalytics.last-selected*"});
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
                            },this.callback_load_routers,this);
    $('#from_date').val(this.default_selected_time.start_date);
    $('#to_date').val(this.default_selected_time.end_date);
    this.mk_time_interval();
    await this.get_user_resources();
    this.load_routers_interfaces();

    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    //Default is ASNumber 
    //If crosskey is created take the parent cgguid from counter group cross key(flow-asn)
    
    if(this.crosskey_interface && this.cg_meters.crosskey[this.crosskey_interface]){
      this.filter_cgguid = this.cg_meters.crosskey[this.crosskey_interface][1];
    }
    this.form.submit($.proxy(this.submit_form,this));
    if(this.dash_params.valid_input == "1" || this.dash_params.valid_input==1){
      this.form.submit();
    }    
  }

  async get_user_resources(){
    this.user_resouces=[];
    await $.getJSON("/trisul_web_user/get_resources",
                    {filter_guid:GUID.GUID_CG_FLOWINTERFACE()}, $.proxy(function (resouces) {
      this.user_resouces = resouces[GUID.GUID_CG_FLOWINTERFACE()] || [];
    },this));
  }


  async callback_load_routers(s,e,args){
    await args.load_routers_interfaces();
  }

  async load_routers_interfaces(){
    this.mk_time_interval();
    let selected_router = null, selected_interface=null;
    let incoming_key = this.dash_params.key || ""
    let keyparts = incoming_key.split("_");
    if (keyparts.length==2) {
      selected_router = keyparts[0];
      selected_interface = keyparts.join("_");
    }

    var load_router_opts = {
      tmint : this.tmint,
      filter_interface:this.user_resouces,
      selected_cg : selected_router || localStorage.getItem("apps.peeringanalytics.last-selected-router") ||0,
      selected_st : selected_interface || localStorage.getItem("apps.peeringanalytics.last-selected-interface"),
      update_dom_cg : "routers"+this.rand_id,
      update_dom_st : "interfaces"+this.rand_id,
      chosen:true
    }
    $(`#routers${this.rand_id}`).find("option").remove();
    await load_routers_interfaces_dropdown(load_router_opts);
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
    localStorage.setItem("apps.peeringanalytics.last-selected-router", 
                            $('.peeringanalytics_form select[name="routers"] option:selected').val());

    localStorage.setItem("apps.peeringanalytics.last-selected-interface", 
                            $('.peeringanalytics_form select[name="interfaces"] option:selected').val());


    this.form.find("#btn_submit").prop('disabled', true);
    this.reset_ui();
    this.mk_time_interval();
    this.get_data_all_meters_data();
    return false;
  }

  async get_data_all_meters_data(){
    let keys = Object.keys(this.meter_details_in);
    this.toppers_data = {}
    this.combined_totals = [0,0]
    for (const [i, key] of keys.entries()) {
      this.meter_index = i;
      this.meter_details_in[key].forEach(async(m)=>{
        this.meter = m;
        await this.get_data();
        this.tris_pg_bar.update_progress_bar();
        this.combined_totals[i]= this.combined_totals[i]+this.sys_group_totals
        this.cgtoppers_resp.keys.forEach(async(keyt)=>{
          if(! (keyt.key in this.toppers_data)){
            this.toppers_data[keyt.key]={keyt:keyt,data:[0,0]}
          }

          this.toppers_data[keyt.key].data[i]=this.toppers_data[keyt.key].data[i]+keyt.metric.toNumber()
        },this);

        if(i==1 && m==4){
          this.draw_table();
        }
      },this);
      
    };
    this.form.find("#btn_submit").prop('disabled', false);
    new ExportToPDF({add_button_to:".add_download_btn",
                      tint:this.tmint,
                      logo_tlhs:this.logo_tlhs,
                      download_file_name:"ASN Traffic",
                      report_opts:{
                        header:{h1:"ASN Traffic"},
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
    this.tris_pg_bar = new TrisProgressBar({max:4,
                                            divid:'pg_bar' });
    this.maxitems=10;
    this.cgguid = null;
    this.crosskey_cgguid = null;
    this.filter_text=null;
      $('#isp_overview_tabs a').click(function (e) {
      e.preventDefault()
      $(this).tab('show')
    });
    this.report_nodes = [];
    this.report_nodes.push({type:"table",header_text:"auto",h1:"h5",h2:"h5 small",find_by:`#asn_toppers`});
     
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
    this.selected_router = $('#routers'+this.rand_id).val();
    let selected_interface = $('#interfaces'+this.rand_id).val();
    
    if(Object.keys(this.cg_meters.crosskey).length == 0){
      this.crosskey_cgguid = null;
    }
    this.update_target_text();
    if( selected_interface !="0"){
      this.cgguid = this.crosskey_interface;
      this.filter_text = selected_interface;
    }
    else if(this.selected_router != "0"){
      this.cgguid = this.crosskey_router;
      this.filter_text = this.selected_router;
    }
    else if(this.selected_router){
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
      maxitems:5000
    }
    if(this.filter_text){
      req_opts["key_filter"]=this.filter_text
    }
    this.cgtoppers_resp=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, req_opts);
    
    // reject sysgrup and xx
    this.cgtoppers_resp.keys = _.reject(this.cgtoppers_resp.keys,function(topper){
      return topper.key=="SYS:GROUP_TOTALS" || topper.key.includes("XX");
    });
    
    this.sys_group_totals = 1;
    _.each(this.cgtoppers_resp.keys,function(topper){
      this.sys_group_totals = this.sys_group_totals + topper.metric.toNumber(); 
    },this);
    this.sys_group_totals = this.sys_group_totals*this.top_bucket_size;

  }


  async draw_table(){
    document.querySelector(".animated-background").remove();
    // get uniq prefix and interfaces
    let rows=[];
    var table = this.data_dom.find(".toppers_table").find("table");
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append(`<tr><th>ASN</th><th style="width:200px">Name</th>
                                <th>Full name</th>
                                <th sort='volume' barsparkrecv='auto'>Receive</th>
                                <th sort='volume' barsparktrans='auto'>Transmit</th>
                                <th></th>
                                </tr>`);
    //this.cgtoppers_resp.keys = this.sort_hash(this.cgtoppers_resp,"metric");
    let cgtoppers =  Object.values(this.toppers_data).sort((b,a)=>{return (a.data[0]+a.data[1])-(b.data[0]+b.data[1])});
    cgtoppers = cgtoppers.slice(0,100)
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i].keyt;
      
      let key = topper.key.split("\\").shift();
      
      let readable = topper.readable.split("\\").shift();
      let label = topper.label.split("\\").shift();
      let desc = topper.description.replace("\\\\","")

      let dropdown = `<span class='dropdown'>
                        <a class='dropdown-toggle asn_dropdown' data-bs-toggle='dropdown' href='javascript:;;'  title='Click to get more options'>
                          <i class='fa fa-server'></i>
                          </a>
                        <ul class='dropdown-menu  pull-right shadow border-0'>
                          <li><a href='javascript:;;' class='dropdown-item'>Traffic Chart</a></li>
                        </ul>
                      </span>`;

      let statids = Object.values(this.meter_details_in).slice(0,2)
      rows.push(`<tr data-key="${topper.key}" data-label="${readable}(${label})">
                      <td class='linkdrill'><a href='javascript:;;'>${readable}</a></td>
                      <td class='linkdrill'><a href='javascript:;;'>${label}</a></td>
                      <td>${desc}</td>
                      <td>${h_fmtvol(cgtoppers[i].data[0]*this.top_bucket_size)}${this.meter_types[this.meter].units.replace("ps","")}</td>
                      <td>${h_fmtvol(cgtoppers[i].data[1]*this.top_bucket_size)}${this.meter_types[this.meter].units.replace("ps","")}</td>
                      <td>${dropdown}</td>
                      </tr>`);

    }

    show_bs5_dropdown('.asn_dropdown');


    new TrisTablePagination("asn_toppers",{no_of_rows:10,rows:rows,
                            add_barspark:false,
                            callback:$.proxy(function(){this.pagination_callback()},this)});
   
    table.tablesorter();
    table.closest('.card').find(".badge").html(rows.length);
    this.pagination_callback();
    
   
  }
  dropdown_click(event){
    let tr = event.target.closest('tr');
    let key = tr.dataset.key.replace(/\\/g,"\\\\");
    let guid = this.crosskey_interface;
    let models = Object.values(this.meter_details_in).flat().map(m=>{
      return [guid,key,m,key]
    });
    
    var model_data = {
      models:JSON.stringify(models),
      from_date:this.form.find("#from_date").val(),
      to_date:this.form.find("#to_date").val(),
      valid_input:1,
      expression:"Receive=(1+2),Transmit=(3+4)",
      surface:"MRTGTABLE",
      title:key = tr.dataset.label,
      legend_position:"bottom"
    };
    let url = "/trpjs/generate_chart_lb?"+$.param(model_data);
    load_modal(url);
  }
  pagination_callback(){
    add_barspark("#asn_toppers",{barspark_id:"barsparkrecv",sys_group_totals:this.combined_totals[0] ,width:50,height:16});
    add_barspark("#asn_toppers",{barspark_id:"barsparktrans",sys_group_totals:this.combined_totals[1],width:50,height:16});
    for ( const link of [...document.querySelectorAll('#asn_toppers ul.dropdown-menu li a')] )  {
      link.addEventListener("click",this.dropdown_click.bind(this));
    };
    
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
  new CustomerASNTraffic(opts);
}



//# sourceURL=customer_as_traffic.js
