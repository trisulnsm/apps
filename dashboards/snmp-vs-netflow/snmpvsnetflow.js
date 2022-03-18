//Compare Netflow interface traffic with snmp interface traffic
//Dependency - We need SNMPPoller app 

class SNMPVSNetflow{
  constructor(opts) {
    this.dom = $(opts.divid);
    this.default_selected_time = opts.new_time_selector;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.add_form(opts);
    this.jsparams = opts.jsparams||{}
  }
   async add_form(opts){

    await this.load_assets(opts);
    //assign randid to form fields
    this.form = $(this.haml_dom[0]);
    this.form.find("#interfaces").attr("data-placeholder","Type to view interfaces");
    this.dom.append(this.form);
    new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            },this.callback_load_routers,this);
    $('#from_date').val(this.default_selected_time.start_date);
    $('#to_date').val(this.default_selected_time.end_date);
    this.mk_time_interval();
    this.load_routers_interfaces();
    this.form.submit($.proxy(this.submit_form,this));

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

  //make time interval to get toppers.
  mk_time_interval(){
    var selected_fromdate = $('#from_date').val();
    var selected_todate = $('#to_date').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }

  async load_routers_interfaces(){
    this.mk_time_interval();

    var load_router_opts = {
      tmint : this.tmint,
      selected_cg : "",
      selected_st : "",
      update_dom_cg : "routers",
      update_dom_st : "interfaces",
      chosen:true,
      chosen_args:{height:{'interfaces':"100px"}}
    }
    $(`#routers`).find("option").remove();
    await load_routers_interfaces_dropdown(load_router_opts);
  }
  submit_form(){
    this.reset_ui();
    this.get_router_and_interface_keyts();
    //get selected router and interfaces
    return false;
  }
  reset_ui(){
    this.dom.find(".ui_data").remove();
    this.dom.append($(this.haml_dom[1]).clone());
    this.report_nodes=[];
   
  }
  async get_router_and_interface_keyts(){
    let selected_router_key = this.form.find("#routers").val();
    let selected_interface_keys = this.form.find("#interfaces").val();
    if(selected_interface_keys.length ==0 || (selected_interface_keys.length == 1 && selected_interface_keys[0]=="0") ){
      this.show_alert_box();
      return true;
    }
    let no_of_keys = selected_interface_keys.length*2;
    if($('#show_netflow_only').prop('checked')){
      no_of_keys = selected_interface_keys.length
    }
    this.tris_pg_bar=new TrisProgressBar({max:no_of_keys,divclass:'ui_data'});
    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    //get selected router and interfaces details
    this.router_keyt=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, 
                    {counter_group:GUID.GUID_CG_FLOWGENS(),
                     keys:[selected_router_key],
                      get_attributes:true});
    this.show_router_details()
    this.intf_keyts=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, 
                    {counter_group:this.jsparams.netflow_guid,
                     keys:selected_interface_keys,
                      get_attributes:true});
    //for each interface show snmp and netflow traffic start
    for(let i =0; i<this.intf_keyts.keys.length;i++){
      await this.draw_traffic_charts(this.intf_keyts.keys[i],i);
      if(i < this.intf_keyts.keys.length-1 ){
        this.report_nodes.push({type:"page_break"}); 
      }
    }
    this.add_download_pdf();
  }
  show_router_details(){
    let base_div = $(this.haml_dom[2]).clone();
    let keyt = this.router_keyt.keys[0];
    base_div.find(".card-header h5").text(`Router Details -${keyt.readable}`);
    let dl=base_div.find("dl")
    dl.append(`<dt class='col-3'> IP </dt>
              <dd class='col-9'>${keyt.readable}</dd>`);
    if(keyt.label != keyt.readable){
      dl.append(`<dt class='col-3'> Name </dt> <dd class='col-9'>${keyt.label}</dd>`);
    }
    let sysdesc = keyt.attributes.find(x=> x.attr_name=="snmp.sys_descr");
    if(sysdesc){
      dl.append(`<dt class='col-3'> Desc </dt> <dd class='col-9'>${sysdesc.attr_value}</dd>`);
    }
    base_div.find("dl").append(dl)
    $('.ui_data').append(base_div);
  }
  async draw_traffic_charts(keyt,i){
    let desc = "";
    let port = keyt.readable.split("_")[1];
    if(keyt.attributes.length > 0){
      let ifname = keyt.attributes.find(x=> x.attr_name=="snmp.ifname")
      let ifalias= keyt.attributes.find(x=> x.attr_name=="snmp.ifalias")
      let mapped_port= keyt.attributes.find(x=> x.attr_name=="snmp.netstream_ifindex_map")
      if(ifname)
      {
        desc = desc + ifname.attr_value;
      }
      if(ifalias && ifalias.attr_value != desc && ifalias.attr_value.trim().length > 0 ){
        desc = desc + `(${ifalias.attr_value})`
      }
      //Huwai has diffent port for snmp
      if(mapped_port){
        port = mapped_port.attr_value;
      }

    }
    if(desc.length==0){
      desc = keyt.readable;
    }
    let meters = this.jsparams.meters;
    let base_div = $(this.haml_dom[3]).clone();
    debugger
    let chart_to_show=["netflow","snmp"];
    if($('#show_netflow_only').prop('checked')){
      chart_to_show=["netflow"];
      base_div.find(".snmp").remove();
      base_div.find(".netflow").closest('.col-xs-6').removeClass('col-xs-6');
    }
    $('.ui_data').append(base_div);
    chart_to_show.forEach(async function(ai){
      this.report_nodes.push({type:"svg",header_text:"auto",find_by:`#${ai}_chart_${i}`,parent:"panel",h1:"h5",h2:"h5 small"});
      let div = $(`.${ai}`);
      base_div.find(`.${ai} .card-header h5 small`).text(desc);
      base_div.find(`.${ai}_chart`).attr("id",`${ai}_chart_${i}`);
      let intfkey = keyt.key;

      if(ai=="snmp"){
        let router_ip = keyt.readable.split("_")[0]
        intfkey = `$${router_ip}_${port}`
        if(! this.cg_meters.all_cg_meters[this.jsparams.snmp_guid]){
          let alert_msg = `<div class='alert alert-danger'>
                            SNMP Poller App is not installed 
                            <ul class='list-inline'>
                            <li>If you have already installed please restart the probe</li>
                            </ul>
                            </div>`

          $(`#${ai}_chart_${i}`).html(alert_msg)
          return;
        }

      }
      let model_data = {cgguid:this.jsparams[`${ai}_guid`],
        key:intfkey,
        meter:Object.values(this.jsparams.meters[ai]),
        from_date:this.form.find("#from_date").val(),
        to_date:this.form.find("#to_date").val(),
        valid_input:1,
        mrtg:true,
        show_title:false,
        auto_label:false,
        chart_legend_names:Object.keys(this.jsparams.meters[ai])
      };
      await $.ajax({
        url:"/trpjs/generate_chart",
        data:model_data,
        context:this,
        success:function(resp){
          $(`#${ai}_chart_${i}`).html(resp);
          this.tris_pg_bar.update_progress_bar(); 
        }
      });

    },this);
    
  }
  add_download_pdf(){
    let keyt = this.router_keyt.keys[0];
    let h1 = keyt.readable;
    if(keyt.label != keyt.readable){
      h1 =`${h1}(${keyt.label})`
    }
    new ExportToPDF({add_button_to:".add_download_btn",
                      tint:this.tmint,
                      download_file_name:"snmpvsnetflow",
                      report_opts:{
                        header:{h1:"SNMP Vs Netflow"},
                        report_title:{h1:h1},
                        nodes:this.report_nodes
                      }
                    });
  }
  show_alert_box(){
    $('.ui_data').html("<div class='alert alert-danger'>Please select atleast a interface to continue.</div>")
  }
};



function run(opts) {
  new SNMPVSNetflow(opts);
}



//# sourceURL=snmp_vs_netflow.js
