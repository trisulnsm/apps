/*
 * Interface Utilization Filter  
 */



class InterfaceUtilizationFilter{
  constructor(opts) {

    this.dom = $(opts.divid);
    this.rand_id="";
    this.default_selected_time = opts.new_time_selector;

    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;

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

    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);


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
    this.form.find("#btn_submit").prop('disabled', true);
    this.reset_ui();
    this.mk_time_interval();
    this.query_trp();
    this.form.find("#btn_submit").prop('disabled', false);

    return false;
  }

  reset_ui() {
    const parent = document.getElementById('results');
    while (parent.firstChild) {
      parent.firstChild.remove();
    } 
  }
  
  // build model 
  async query_trp(filter_pattern)  {
  
    let iftoppers_recv=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: '{C0B04CA7-95FA-44EF-8475-3835F3314761}',
      time_interval: this.tmint ,
      meter:0,
      maxitems:20,
      get_key_attributes:true
    });

    let iftoppers_xmit=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: '{C0B04CA7-95FA-44EF-8475-3835F3314761}',
      time_interval: this.tmint ,
      meter:1,
      maxitems:20,
      get_key_attributes:true
    });

    let merged = new Map(); // k => [recv,xmit]

    for (let k of iftoppers_recv.keys ) {
      if(k.key=="SYS:GROUP_TOTALS"){
        continue;
      }
      let m  = new Map();
      m.set('recv',k)
      merged.set(k.key, m);
    }

    for (let k of iftoppers_xmit.keys ) {
       if(k.key=="SYS:GROUP_TOTALS"){
        continue;
      }
      let m = merged[k.key];
      if (m) {
        m.set('xmit',k)
      } else {
        let m= new Map();
        m.set('xmit',k);
        merged.set(k.key,m);
      }
    }



	this.redraw(merged);
 }


 redraw( biDirectionalMap) {

  const topper_bucket_size=300;
  let table = document.createElement('table'); 
  table.classList.add("table")
  table.classList.add("table-condensed")
  table.classList.add("small")
  table.classList.add("add_table_filter")
 
  let thead = document.createElement('thead');
  let tbody = document.createElement('tbody');
  thead.innerHTML=`<tr>
                    <th></th>
                    <th class='filter' > Router </th>
                    <th class='filter'> Ifindex</th>
                    <th class='filter'> Ifname</th>
                    <th class='filter'> Ifalias </th>
                    <th> Speed </th>
                    <th>Max<br/>Recv</th>
                    <th>Avg<br/> Recv</th>
                    <th>Max<br/> Recv<br/> Util</th>
                    <th>Avg<br/> Recv<br/> Util</th>
                    <th>Max<br/> Xmit</th>
                    <th>Avg<br/> Xmit</th>
                    <th>Max<br/> Xmit<br/> Util</th>
                    <th>Avg<br/> Xmit <br/>Util</th>

                  <tr>`
  table.appendChild(thead);
  table.appendChild(tbody);

  for (const [key, value] of biDirectionalMap) { 

    let usek = value.get("recv") || value.get("xmit"); // whatever is set 
    let recvk = value.get("recv");
    let xmitk = value.get("xmit");

    let router_ip = usek.readable.split('_')[0];
    let ifindex = usek.readable.split('_')[1];
    let speed  = usek.attributes.find( (nm) => nm.attr_name == "snmp.ifspeed" )
    let alias  = usek.attributes.find( (nm) => nm.attr_name == "snmp.ifalias" )
    let name  = usek.attributes.find( (nm) => nm.attr_name == "snmp.ifname" )
    let ipaddr  = usek.attributes.find( (nm) => nm.attr_name == "snmp.interface_ip_addr" )


    let util_recv_max = 0, util_recv_avg = 0, util_xmit_max = 0,util_xmit_avg=0, speed_val =0;
    if (speed) {
      speed_val = parseInt(speed.attr_value);
    }
    if (speed_val != 0 && recvk) {
      util_recv_max = 100  * parseInt(recvk.metric_max)*8 / speed_val;
      util_recv_avg = 100  * parseInt(recvk.metric_avg)*8 / speed_val;
    }
    if (speed_val != 0 && xmitk) {
      util_xmit_max = 100  * parseInt(xmitk.metric_max)*8 / speed_val;
      util_xmit_avg = 100  * parseInt(xmitk.metric_avg)*8 / speed_val;
    }

    let templ = document.createElement('template');
    let fa = document.createElement("i");
    if((util_recv_avg && util_recv_avg > 75) || (util_xmit_avg && util_xmit_avg > 75)){
      fa.classList.add('fa', 'fa-circle','text-danger');
    }
    else if((util_recv_avg && util_recv_avg > 50) || (util_xmit_avg && util_xmit_avg > 50)){
      fa.classList.add('fa', 'fa-circle','text-warning');
    }
    templ.innerHTML = 
    `<tr> 
        <td>${fa.outerHTML}</td>
        <td>${router_ip}</td>
        <td>${ifindex}</td>
        <td>${name? name.attr_value: ""}</td>
        <td>${alias? alias.attr_value.slice(0,20): "" }</td>
        <td>${speed? formatBW(parseInt(speed.attr_value),1,"bps"): 0}</td>
        <td>${recvk? formatBW(parseInt(recvk.metric_max)*8,1,"bps"): ""}</td>
        <td>${recvk? formatBW(parseInt(recvk.metric_avg)*8,1,"bps"): ""}</td>
        <td>${util_recv_max? Math.round(util_recv_max): ""}</td>
        <td>${util_recv_avg? Math.round(util_recv_avg): ""}</td>
        <td>${xmitk? formatBW(parseInt(xmitk.metric_max)*8,1,"bps"): ""}</td>
        <td>${xmitk? formatBW(parseInt(xmitk.metric_avg)*8,1,"bps"): ""}</td>
         <td>${util_xmit_max? Math.round(util_xmit_max): ""}</td>
        <td>${util_xmit_avg? Math.round(util_xmit_avg): ""}</td>
    </tr>`;
     tbody.appendChild(templ.content);
  }

  document.getElementById('results').appendChild(table);
  enable_table_filter();

 }
 
}; // class


function run(opts) {
  new InterfaceUtilizationFilter(opts);
}

//# sourceURL=interface_filter.js
