/*
 * Interface Matrix 
 */
class ISPOverviewMapping{
  constructor(opts) {

    this.dom = $(opts.divid);
    this.rand_id="";
    this.default_selected_time = opts.new_time_selector;

    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.crosskey_cgguid="{CD8F3FB3-A3DA-8A58-25E0-E0A6F8ED6854}";

    //filter by router and interface crosskey
    if(opts.jsparams &&  _.size(opts.jsparams)>0){
      this.crosskey_cgguid = opts.jsparams.crosskey_interface;
    } 
    this.probe_id = opts.probe_id;
    this.dash_params = opts.dash_params;
    this.aliastable={};
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

  async add_form(opts){

    await this.load_assets(opts);
    
    //assign randid to form fields
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);

    //new time selector 
    new ShowNewTimeSelector({divid:"#new_time_selector"+this.rand_id,
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            },this.callback_load_routers,this);
    this.mk_time_interval();

    this.load_routers_interfaces();

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
    let selected_router = null, selected_interface=null;
    let incoming_key = this.dash_params.key || ""
    let keyparts = incoming_key.split("_");
    if (keyparts.length==2) {
      selected_router = keyparts[0];
      selected_interface = keyparts.join("_");
    }

    var load_router_opts = {
      tmint : this.tmint,
      selected_cg : selected_router || localStorage.getItem("apps.interface-matrix.last-selected-router"),
      selected_st : selected_interface || localStorage.getItem("apps.interface-matrix.last-selected-interface"),
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
    localStorage.setItem("apps.interface-matrix.last-selected-router", 
                            $('.interfacematrix_form select[name="routers"] option:selected').val());

    localStorage.setItem("apps.interface-matrix.last-selected-interface", 
                            $('.interfacematrix_form select[name="interfaces"] option:selected').val());
    this.form.find("#btn_submit").prop('disabled', true);
    this.reset_ui();
    this.mk_time_interval();
    this.get_data_all_meters_data();
    return false;
  }

  // reset UI for every submit
  reset_ui(){
    this.dom.find(".ui_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
    this.maxitems=50;
    this.filter_text=null;
      $('#isp_ifmatrix_overview_tabs a').click(function (e) {
      e.preventDefault()
      $(this).tab('show')
    });
  }

  
  update_target_text(){
    let selected_router = $('#routers'+this.rand_id).val();
    let selected_interface = $('#interfaces'+this.rand_id).val();
    let selected_router_text = $('#routers'+this.rand_id +' option:selected').text();
    let selected_intf_text = $('#interfaces'+this.rand_id +' option:selected').text();
    
    let selected_fromdate = $('#from_date'+this.rand_id).val();
    let selected_todate = $('#to_date'+this.rand_id).val();
    let fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    let toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    let duration  = `<i class='fa fa-clock-o fa-fw '></i>
                     from ${selected_fromdate} to ${selected_todate}
                     (${h_fmtduration(toTS-fromTS)})`
    
    $('span#target_interface').text(selected_intf_text); 
    $('p#target_timewindow').html(duration);
  }

  async get_data_all_meters_data(){
    let selected_interface = $('#interfaces'+this.rand_id).val();
    if (selected_interface=='0') {
      this.data_dom.html('<div class="alert alert-danger">You must select an interface to view interface matrix traffic flows</div>');
      this.form.find("#btn_submit").prop('disabled', false);
      return;
    }
    await this.get_data(0, selected_interface + "\\S+");
    await this.get_data(1, "\\S+"+ selected_interface);
    this.form.find("#btn_submit").prop('disabled', false);
  }

  // build model 
  async get_data(tabindex, filter_pattern)  {
  
    this.update_target_text();

    //find bucket size
    if(this.cg_meters.all_cg_bucketsize[this.crosskey_cgguid]==undefined){
      this.data_dom.html('<div class="alert alert-info">Crosskey counter groups not created. Need crosskey counter groups to work with this app</div>');
      return;
    }
   
    this.top_bucket_size = this.cg_meters.all_cg_bucketsize[this.crosskey_cgguid].top_bucket_size;
    this.bucket_size = this.cg_meters.all_cg_bucketsize[this.crosskey_cgguid].bucket_sizge;
    if(Object.keys(this.cg_meters.all_meters_type[this.crosskey_cgguid]).length !=0 &&
        this.cg_meters.all_meters_type[this.crosskey_cgguid][0].type==4 &&
        this.cg_meters.all_meters_type[this.crosskey_cgguid][0].units=="Bps"){
    }

    // crosskey bucket size 
    this.ck_top_bucket_size =  300;
    this.meter_types=this.cg_meters.all_meters_type[this.crosskey_cgguid];
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
      counter_group: this.crosskey_cgguid,
      time_interval: this.tmint ,
      meter:0,
      maxitems:5000,
      key_filter: filter_pattern

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
   
    // key to alias
    // resolve from snmp.ifalias 
    let interface_keys=
      _.chain(this.cgtoppers_resp.keys)
       .collect( fullkey => fullkey.key.split('\\'))
       .flatten()
       .uniq()
       .value();

    _.each(interface_keys, (k) => {
      if (!_.has(this.aliastable,k)) {
        this.aliastable[k]="";
      }
    },this);
    
    let keyinfo=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,
      { counter_group: '{C0B04CA7-95FA-44EF-8475-3835F3314761}',
        get_attributes:true,
        keys: _.chain(this.aliastable)
               .omit( (val,key) => val.length>0)
               .keys()
               .value()
      });

    _.each( keyinfo.keys,  function(keyt) {
        for (let i=0;i<keyt.attributes.length;i++) {
          if (keyt.attributes[i].attr_name=="snmp.ifalias") {
            this.aliastable[keyt.key]=keyt.attributes[i].attr_value;
          }
        }
     },this);
    
    await this.draw_table(tabindex);
  }


  async draw_table(tabindex){

    let rows = [];
    this.data_dom.find(`#ifmatrix_overview_${tabindex}`).find(".toppers_table_div").find('.animated-background').remove();
    var table = this.data_dom.find(`#ifmatrix_overview_${tabindex}`).find(".toppers_table").find("table");
    this.table_id = `table_${tabindex}${this.rand_id}`;
    table.attr("id",this.table_id)
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append(`<tr><th>Key</th>
                                <th>Label</th>
                                <th>Alias</th>
                                <th sort='volume' barspark='auto'>Volume</th>
                                <th sort='volume'>Avg <br/>Bandwidth</th><th class='nosort'></th>
                                </tr>`);
    let totvol=this.cgtoppers_resp.keys.reduce((a,b)=>a +parseInt(b.metric),0);
    $('.volume_'+tabindex).text(` (${h_fmtvol(totvol*this.top_bucket_size)}) `);
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,100);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      
      let dropdown = $("<span class='dropdown'><a class='dropdown-toggle' data-toggle='dropdown' href='javascript:;;'><small><i class='fa fa-fw fa-ellipsis-h fa-lg'></i></small></a></span>");
      let dropdown_menu = $("<ul class='dropdown-menu  pull-right'></ul>");
      dropdown_menu.append("<li><a href='javascript:;;'>Traffic Chart</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Key Dashboard</a></li>");
      dropdown_menu.append("<li><a href='javascript:;;'>Explore Flows</a></li>");
      dropdown.append(dropdown_menu);

      let statids = [0];
      let full_key= topper.key;
      
      let crosskey_part=tabindex==0?1:0;
      let key= topper.key.split("\\")[crosskey_part]
      let readable= topper.readable.split("\\")[crosskey_part];
      let alias=this.aliastable[key];
      let label= topper.label.split("\\")[crosskey_part];

      let avg_bw= 8*topper.metric_avg.toNumber(); 
      
      rows.push(`<tr data-key="${key}" data-statid=${tabindex} data-label="${topper.label}" 
                    data-readable="${topper.readable}" data-full_key="${full_key}"
                    data-statid-index=${tabindex} data-statids=${statids}>
                      <td class='linkdrill'><a href='javascript:;;'>${readable}</a></td>
                      <td class='linkdrill'><a href='javascript:;;'>${label}</a></td>
                      <td class='linkdrill'><a href='javascript:;;'>${alias}</a></td>
                      <td>${h_fmtvol(topper.metric*this.top_bucket_size)}B</td>
                      <td>${h_fmtbw(avg_bw)}bps</td>
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

  dropdown_click(event){
    var target = $(event.target);
    var tr = target.closest("tr");
    switch($.inArray(target.parent()[0],target.closest("td").find("li:not(.divider)"))){
      case 0:
      case -1: /* traffic chart */
        {
          let kparts= tr.data('full_key').split('\\');
          let lparts= tr.data('label').split('\\');
          let aliasparts=[this.aliastable[kparts[0]], this.aliastable[kparts[1]] ]

          let desc = `<b>Router:</b> ${this.form.find("#routers option:selected").text()}<br/>
           <b>From Interface:</b> ${kparts[0]} : ${lparts[0]} : ${aliasparts[0]} <br/>
           <b>To Interface:</b> ${kparts[1]} : ${lparts[1]} : ${aliasparts[1]}`;

          let params = {
            key: tr.data("full_key").toString().replace(/\\/g,"\\\\"),
            statids:'0',
            cgguid:this.crosskey_cgguid,
            window_fromts:this.tmint.from.tv_sec,
            window_tots:this.tmint.to.tv_sec,
            description:desc,
            surface:'LINETABLE'
          }
          let url = "/trpjs/generate_chart_lb?"+$.param(params);
          load_modal(url);
        }
        break;
        
      case 1: /* key dashboard */
        {
          let link_params =$.param({dash_key:"key",
                           guid:this.crosskey_cgguid,
                           key:tr.data("full_key"),
                           statid:tr.data("statid")
                          });
          window.open("/newdash/index?"+link_params);
        }
        break;

      case 2: /* explore flows */
        {
          let tr = target.closest("tr");
          let kparts = tr.data('full_key').split('\\');
          let query = `router=${kparts[0].split('_')[0]},ifin=${kparts[0].split('_')[1]},ifout=${kparts[1].split('_')[1]}`;
          let qp = {exp_query: query,
                    valid_input:1,
                    quick_search:1,
                    window_fromts:this.tmint.from.tv_sec,
                    window_tots:this.tmint.to.tv_sec}
          window.open("/sessions/explore?"+$.param(qp));
        }
        break;
    } 
  }
};


function run(opts) {
  new ISPOverviewMapping(opts);
}

//# sourceURL=interface_matrix.js
