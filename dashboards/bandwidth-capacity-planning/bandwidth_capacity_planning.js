class  BandwidthCapacityPlannig {
  constructor(opts) {
    this.dom = $(opts.divid);
    this.jsparams =(opts.jsparams);
    this.default_selected_time = opts.new_time_selector;
    this.logo_tlhs = opts.logo_tlhs;
    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.add_form(opts);

  }
   // load the frame 
  async load_assets(opts)
  {
    // load app.css file
    load_css_file(opts);

    // load template.haml file 
    let html_str = await get_html_from_hamltemplate(opts);
    this.haml_dom =$(html_str);
  }
  async add_form(opts){

    await this.load_assets(opts);
    //assign randid to form fields
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);
    
    //get router and interfaces details to show items in drodown
    new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            },this.callback_load_router_intfs,this);
    $('#from_date').val(this.default_selected_time.start_date);
    $('#to_date').val(this.default_selected_time.end_date);
    this.mk_time_interval();
    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    await this.load_routers_interfaces();
    this.form.submit($.proxy(this.submit_form,this));


  }
  mk_time_interval(){
    var selected_fromdate = this.form.find('#from_date').val();
    var selected_todate = this.form.find('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }

  async callback_load_router_intfs(s,e,args){
    await args.load_routers_interfaces();
  }

  async load_routers_interfaces(){
    this.speed_mappings = {};
    this.form.find("#btn_submit").addClass('disabled');
    this.form.find("#btn_submit").val('Please wait Loading data...');
    this.form.find('#select_interface_keys_left').empty();
    let req_opts = {maxitems:1000,counter_group:GUID.GUID_CG_FLOWGENS(),time_interval: this.tmint};
    let router_toppers=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,req_opts);
    this.opt_groups = {}
    for(let keyt of router_toppers.keys ){
      let label = keyt.readable;
      if(keyt.readable != keyt.label && keyt.label.length > 0){
        label = `${label}(${keyt.label})`;
        label = label.replace(/"/g, '');
      }
      
      this.opt_groups[keyt.key] = $(`<optgroup label='${label}'></optgroup>`);
    }

    let from_key = TRP.KeyT.create({label:"$0"});
    let to_key = TRP.KeyT.create({label:"$z"});
    let key_spaces = TRP.KeySpaceRequest.KeySpace.create({from_key:from_key,to_key:to_key})

    let interfaces_keys = [];
    req_opts = {counter_group:GUID.GUID_CG_FLOWINTERFACE(),
                time_interval: this.tmint,
                spaces:[key_spaces],
                maxitems:parseInt($('#show_intf_toppers').val())
              }

    let resp = await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST,req_opts);

    for(let j=0; j < resp.hits.length;j++){
      interfaces_keys.push(resp.hits[j].key)
    }
    resp = await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,req_opts);
    req_opts = {maxitems:parseInt($('#show_intf_toppers').val()),
                counter_group:GUID.GUID_CG_FLOWINTERFACE(),
                time_interval: this.tmint,
                keys:interfaces_keys,
                get_attributes:true};
    let interface_toppers=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,req_opts);
    for(let keyt of interface_toppers.keys ){
      let rkey = keyt.key.split("_")[0];
      let label = keyt.readable.split("_")[1];
      
      if(keyt.attributes.length > 0){
        let ifname = keyt.attributes.find(x=> x.attr_name=="snmp.ifname");
        let ifalias= keyt.attributes.find(x=> x.attr_name=="snmp.ifalias");
        let ifspeed= keyt.attributes.find(x=> x.attr_name=="snmp.ifspeed");
        if(ifname && ifname.attr_value &&  ifname.attr_value.trim().length > 0){
          ifname = ifname.attr_value.trim();
          label = `${label}(${ifname})`;
        }
        if(ifalias && ifalias.attr_value &&  ifalias.attr_value.trim().length > 0 && ifname!=ifalias.attr_value.trim()){
          label = `${label}(${ifalias.attr_value.trim()})`;
        }

        if (ifspeed && ifspeed.attr_value ){
         this.speed_mappings[keyt.readable] = ifspeed.attr_value;
        }else{
          this.speed_mappings[keyt.readable] = null;
        }

      }
      let option = $(`<option value='${keyt.key}'></option>`).text(label.replace(/"/g, ''));
      if(this.opt_groups[rkey]){
        this.opt_groups[rkey].append(option);
      }
    } 
    for(let [key, optgroup] of Object.entries(this.opt_groups)){
      if(optgroup.children().length > 0){
        this.form.find("#select_interface_keys_left").append(optgroup);
      }
    }
    multiple_cross_selects();
    this.form.find("#btn_submit").removeClass('disabled');
    this.form.find("#btn_submit").val('Submit');
  }

   submit_form(){
    this.reset_ui();
    this.mk_time_interval();
    this.get_data();
    return false;
  }
  reset_ui(){
    this.dom.find(".bw_planning_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.data_dom.hide();
    this.dom.append(this.data_dom);
    this.tris_pg_bar = new TrisProgressBar({max:1,
                                            divid:'bcp_progress_bar'});
    let selected_fromdate = this.form.find('#from_date').val();
    let selected_todate = this.form.find('#to_date').val();
    let fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    let toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);

    let duration  = `<i class='fa fa-clock-o fa-fw '></i>`+
                     `from ${selected_fromdate} to ${selected_todate}`+
                     `(${h_fmtduration(toTS-fromTS)})`
    
    $('small.duration').html(duration);

  }
  async get_data(){
    this.selected_interfaces = [];
    let bucket_size = this.cg_meters.all_cg_bucketsize[GUID.GUID_CG_FLOWINTERFACE()].bucket_size;
    //console.log("1")
    //$('#select_interface_keys_right').append(`<option value="B6.4B.F0.66_00000237">567(ae22.0)(##########---MX204-TO-MX104---##########)</option>`)
    let options = this.form.find("#select_interface_keys_right").find("option");
    if(options.length == 0 ){
      alert("No interfaces selected");
      this.tris_pg_bar.force_remove_progress_bar();
      return true;
    }
    this.tris_pg_bar.max = options.length
    this.data_dom.show();
    for(let i=0; i < options.length  ; i++){
      let option = $(options[i]);
      let req_opts = {
                counter_group:GUID.GUID_CG_FLOWINTERFACE(),
                time_interval: this.tmint,
                key:TRP.KeyT.create({key:`${option.val()}`}),
                volumes_only:1};
      let invol = 0,inavg = 0,outvol=0,outavg=0;
      let resp=await fetch_trp(TRP.Message.Command.COUNTER_ITEM_REQUEST,req_opts);
      if(resp.totals && resp.totals.values.length > 1){
        
        invol = resp.totals.values[1].toNumber();
        //invol=invol*bucket_size;
        inavg = invol/resp.samples.values[1].toNumber();

        outvol = resp.totals.values[2].toNumber();
        //outvol=outvol*bucket_size;
        outavg = outvol/(resp.samples.values[2].toNumber());


      }
      //byte to bits
     
      let keyt = resp.key;
      this.opt_groups[keyt.key.split("_")[0]].text();
      let ifspeed = "-";
      if(this.speed_mappings[keyt.readable]){
        ifspeed = `${h_fmtbw(this.speed_mappings[keyt.readable])}bps`;
      }
      this.selected_interfaces.push({
                  key:keyt.key,
                  ifindex:keyt.readable.split("_")[1],
                  router:this.opt_groups[keyt.key.split("_")[0]].attr('label'),
                  name:option.text(),
                  in : h_fmtbw(invol),
                  inavg : h_fmtbw(inavg*8),
                  out : h_fmtbw(outvol),
                  outavg : h_fmtbw(outavg*8),
                  ifspeed: ifspeed
                  });
      this.redraw_table();
      this.tris_pg_bar.update_progress_bar();
    }
    let table_id = `table_bw_planning`;
    $(`table#${table_id}`).tablesorter();
    $(`table#${table_id}`).find('.dropdown-menu').find('a').bind('click',$.proxy(function(event){
      this.dropdown_click(event);
    },this));
    this.enable_report();
    
  }
  redraw_table(){
      let dropdown = $(`<span class='dropdown'><a class='dropdown-toggle' data-bs-toggle='dropdown' href='javascript:;;' title='Click to get more options'><i class='fa fa-fw fa-bars'></i></a></span>`);
      let dropdown_menu = $("<ul class='dropdown-menu border-0 shadow'></ul>");
      dropdown_menu.append(`<li id='traffic_chart'><a class='dropdown-item' href='javascript:;;'>Traffic Chart</a></li>`);
      dropdown.append(dropdown_menu);

    let mustache_tmpl =`<td>{{ifindex}}</td>
                        <td>{{router}}</td>
                        <td style="max-width:200px">{{name}}</td>
                        <td>{{in}}B</td>
                        <td>{{inavg}}bps</td>
                        <td>{{out}}B</td>
                        <td>{{outavg}}bps</td>
                        <td>{{ifspeed}}</td>
                        <td data-key='{{key}}' data-label='{{name}}' data-router='{{router}}'>${dropdown[0].outerHTML}</td>`;

    let data = this.selected_interfaces;
    let cthis = this;
    let table_id = `table_bw_planning`;
    let trs = d3.select(`table#${table_id}`).selectAll("tbody").selectAll("tr")
          .data(data);

    trs.enter()
        .insert("tr")
        .html(function(d){
          return mustache.render(mustache_tmpl,d);
        });

    trs
        .html(function(d){
          return mustache.render(mustache_tmpl,d);
        });

    trs.exit().remove();
    
  }

  dropdown_click(event){
    console.log("ddd")
    let target = $(event.target);
    let td = target.closest("td");
    switch(target.parent().attr("id")){
      case "traffic_chart":
        let models=[[1,"Receive"],[2,"Transmit"]].map(m=>{
          return {counter_group:GUID.GUID_CG_FLOWINTERFACE(),meter:m[0],key:td.data("key"),label:m[1]}
        })
        var p = {
          models:JSON.stringify(models),
          show_default_title:1,
          surface:"MRTG",
          show_table:1,
          from_date:this.form.find("#from_date").val(),
          to_date:this.form.find("#to_date").val()
        }
        new ApexChartLB(p,{modal_title:"Interface Usage"});
      break;
    }
  }

  enable_report(){
    new ExportToPDF({add_button_to:".add_download_btn",
                    tint:this.tmint,
                    download_file_name:"bandwith_capacity_planning",
                    report_opts:{
                      header:{h1:"Bandwidth Capacity Planning"},
                      report_title:{h2:"Average,Total traffic for In and Out"},
                      nodes:[{type:"table",header_text:"auto",h1:"h3",h2:"h3 small",find_by:`#table_bw_planning`}]
                    }
    });
  }

}
    

function run(opts){
  new BandwidthCapacityPlannig(opts)
}

  //# sourceURL=bandwith_capacity_planning.js
