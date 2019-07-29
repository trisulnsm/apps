// IXP - L2 Analytics
class IXPPathAnalytics {

  constructor(opts){
    this.dom = $(opts.divid);
    this.rand_id=parseInt(Math.random()*100000);
    this.default_selected_time = opts.new_time_selector;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.cgguid = "{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}";
    if(opts.jsparams){
      this.cgguid = opts.jsparams.crosskey_interface || "{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}";
    }
    this.dash_params = opts.dash_params;
    this.remove_topper_count=0;
    this.max_crosskey_nodes=30;
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
    await this.load_assets(opts)
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);
    //we are updating router and meter based on id.
    this.form.find("select[name*='routers']").attr("id","routers_"+this.rand_id);
    this.form.find("select[name*='interfaces']").attr("id","interfaces_"+this.rand_id);
    this.form.find("input[name*='from_date']").attr("id","from_date_"+this.rand_id);
    this.form.find("input[name*='to_date']").attr("id","to_date_"+this.rand_id);
    this.form.find(".new_time_selector").attr("id","new_time_selector_"+this.rand_id);
    this.dom.append(this.form);
    //new time selector 
    let update_ids = "#from_date_"+this.rand_id+","+"#to_date_"+this.rand_id;
    new ShowNewTimeSelector({divid:"#new_time_selector_"+this.rand_id,
                               update_input_ids:update_ids,
                               default_ts:this.default_selected_time
                            });

    //loading router and interface in dropdown
    //get interface search key request
    this.mk_time_interval();
    await this.load_routers_interfaces();
    await this.get_cgmeters();

    let cthis = this;
    $( "#slider-remove-topn" ).slider({
      min: 0, max: 10, value:0, step:1,
      create: function() {
         $( "#remove-top-n" ).text( $( this ).slider( "value" ) );
      },
      slide: function( event, ui ) {
        $( "#remove-top-n" ).text( ui.value );
        cthis.remove_topper_count=ui.value;
        cthis.redraw_all();
      }
    });

   
    $( "#slider-max-nodes" ).slider({
      min: 20, max: 100, value:30, step:10,
      create: function() {
        $( "#max-nodes" ).text( $( this ).slider( "value" ) );
      },
      slide: function( event, ui ) {
        $( "#max-nodes" ).text( ui.value );
        cthis.max_crosskey_nodes=ui.value;
      }
    });
    this.form.submit($.proxy(this.submit_form,this));
    if(this.dash_params.valid_input == "1" || this.dash_params.valid_input==1){
      this.form.submit();
    }
  }
  async load_routers_interfaces(){
    //get routers from keyspace request
    let top_routers=await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST, {
      counter_group: GUID.GUID_CG_FLOWGENS(),
      time_interval:this.tmint,
      maxitems:1000
    });

    this.router_keymap ={}
    _.each(top_routers.hits,function(keyt){
      this.router_keymap[keyt.key] = keyt.label || keyt.readable;
    },this);


    let top_intfs=await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST, {
      counter_group: GUID.GUID_CG_FLOWINTERFACE(),
      time_interval:this.tmint,
      maxitems:1000
    });

    this.intf_keymap ={}
    _.each(top_intfs.hits,function(keyt){
      this.intf_keymap[keyt.key] = keyt.label || keyt.readable;
    },this);

    let drop_down_items = {"0":["Please select",[["0","Please select"]]]};

    let interface_keys = _.sortBy(top_intfs.hits,function(keyt) { return keyt.key })
    for(let i=0;i<interface_keys.length; i++){
      let intf_keyt = interface_keys[i];
      let router_key=intf_keyt.key.split("_")[0];
      let router_label = this.router_keymap[router_key];
      let intf_dropdown = [];
      if(_.has(drop_down_items,router_key)){
        intf_dropdown= drop_down_items[router_key];
      }else{
        drop_down_items[router_key]=[router_label,[["0","Please Select"]]];
        intf_dropdown = drop_down_items[router_key];
      }
      intf_dropdown[1].push([intf_keyt.key,this.intf_keymap[intf_keyt.key]]);
    }
    
    // if  already passed an interface filter
    let incoming_key = this.dash_params.key || ""
    incoming_key = incoming_key.split(/\\/);
    let selected_cg = null, selected_st=null;

    if(incoming_key.length == 2){
      this.form.find(".filter_asn").val(incoming_key[0]);
      let rout_intf = incoming_key[1].split("_");
      if(rout_intf.length == 2){
        selected_cg = rout_intf[0];
        selected_st = incoming_key[1];
      }else{
        selected_cg  = rout_intf[0];
      }
    }
    else if (incoming_key.length == 1){
      this.form.find(".filter_asn").val(incoming_key[0]);
    }
    var js_params = {meter_details:drop_down_items,
      selected_cg : selected_cg || localStorage.getItem("apps.pathanalytics.last-selected-router") || "",
      selected_st : selected_st || localStorage.getItem("apps.pathanalytics.last-selected-interface")||"",
      update_dom_cg : "routers_"+this.rand_id,
      update_dom_st : "interfaces_"+this.rand_id,
      chosen:true
    }
    new CGMeterCombo(JSON.stringify(js_params));

   }
  async get_cgmeters(){
    this.cg_meters={};
    await get_counters_and_meters_json(this.cg_meters);
  }
  mk_time_interval(){
    var selected_fromdate = $('#from_date_'+this.rand_id).val();
    var selected_todate = $('#to_date_'+this.rand_id).val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }

  submit_form(){

    // last used is the next default 
    localStorage.setItem("apps.pathanalytics.last-selected-router", 
                            $('.pathanalytics_form select[name="routers"] option:selected').val());

    localStorage.setItem("apps.pathanalytics.last-selected-interface", 
                            $('.pathanalytics_form select[name="interfaces"] option:selected').val());


    this.reset_ui();
    this.mk_time_interval();
    this.get_data();
    return false;
  }
 
  reset_ui(){
    this.dom.find(".path_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
    this.data_dom.find('.toppers_table').attr("id","toppers_table_"+this.rand_id);
  }
  async get_data(){
    this.data ={};
    let bucketsize = this.cg_meters.all_cg_bucketsize[this.cgguid].top_bucket_size;

    let req_opts = {
      counter_group: this.cgguid,
      time_interval: this.tmint,
      maxitems:100,
    }
    let selected_interface = $('#interfaces_'+this.rand_id).val();
    let selected_router = $('#interfaces_'+this.rand_id).val();
    let filter_asn = this.form.find(".filter_asn").val();
    this.update_target_text();
    if(selected_interface != 0)
    {
      req_opts["key_filter"]= selected_interface;
    }else if(selected_router !=0){
      req_opts["key_filter"]= selected_router;
    }
    if(filter_asn.length > 0){
      req_opts["key_filter"] = filter_asn;
    }
    req_opts["meter"] = 0;
    this.data[0]=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,req_opts );
    req_opts["meter"] = 1;
    this.data[1]=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,req_opts);

    // multiply by bucketsize 
    for (let i =0 ; i < this.data[0].keys.length; i++) {   
      this.data[0].keys[i].metric  *= bucketsize;
    }
    for (let i =0 ; i < this.data[1].length; i++) {   
      this.data[1].keys[i].metric  *= bucketsize;
    }
   

    //key_filter in trp support one like 
    //we can't combine router with asn to make key filter
    //so support added via code.
    let filter_value = ".*";
    if (selected_router && filter_asn){
      filter_value = selected_router;
    } else if (selected_interface && filter_asn){
      filter_value = selected_interface
    }
    // resolve to IXP 
    let asn_keys=await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST, {
      counter_group: GUID.GUID_CG_ASN(),
      time_interval:this.tmint,
      maxitems:10000
    });

    let asn_keymap = {}
    _.each(asn_keys.hits,function(keyt){
      asn_keymap[keyt.key] = keyt.label || keyt.readable;
    },this);
    let tot_volume =[0,0]
    for(let meterid in this.data){
      this.data[meterid].keys = _.chain(this.data[meterid].keys)
                                .select(function(topper){
                                  return topper.key.match(filter_value)
                                })
                                .reject(function(topper){
                                  return topper.key=="SYS:GROUP_TOTALS"
                                })
                                .each(function(keyt){
                                  // remove repated asn in single IXP 
                                  let readable = keyt.readable.split(/\/|\\/);
                                  let intf = _.last(readable);
                                  if(intf.match(/^[0-9]*$/)){
                                    intf=readable.shift();
                                  }else{
                                    intf=readable.pop();
                                  }
                                  let asn_path = _.unique(readable);
                                  let asn_resolved = asn_path.map(x=> this.fix_asname(asn_keymap[x] || x)).join("\\")
                                  keyt.label=[intf,asn_resolved].join("\\");
                                  keyt.readable=[intf,asn_path.join("\\")].join("\\");
                                  tot_volume[meterid] +=parseInt(keyt.metric);
                                },this)
                              .value();
    }
    $('.tot_upload_vol').text(` (${h_fmtvol(tot_volume[0])})`);
    $('.tot_download_vol').text(` (${h_fmtvol(tot_volume[1])})`);
    this.redraw_all();
  }

  redraw_all(){
    
    this.draw_path_table(this.data[0],'#nested-upload  table')
    this.draw_path_table(this.data[1],'#nested-download table')
  }


  update_target_text(){
    let selected_router = $('#routers_'+this.rand_id).val();
    let selected_interface = $('#interfaces_'+this.rand_id).val();
    let selected_router_text = $('#routers_'+this.rand_id +' option:selected').text();
    let selected_intf_text = $('#interfaces_'+this.rand_id +' option:selected').text();
    let  filter_asn = this.form.find(".filter_asn").val(); 
    this.target_text="";
    if(selected_router != "0"){
      this.target_text = `${selected_router_text}`;
    }
    if(selected_interface != "0"){
      this.target_text = `${this.target_text} -> ${selected_intf_text}`;
    }
    if(filter_asn != ""){
      this.target_text = `${this.target_text} -> ${filter_asn}`;
    }
    let selected_fromdate = $('#from_date_'+this.rand_id).val();
    let selected_todate = $('#to_date_'+this.rand_id).val();
    let fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    let toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);

    let duration  = `   <i class='fa fa-clock-o fa-fw '></i>
                     from ${selected_fromdate} to ${selected_todate}
                     (${h_fmtduration(toTS-fromTS)})`
    
    $('small.target').html(this.target_text + duration);
  }

  // draw a nested table view 
  draw_path_table(toppers,divid)
  {

    let cgtoppers_bytes = toppers.keys.slice(this.remove_topper_count,this.max_crosskey_nodes);


    let tree = { name: "root", key: "root", metric: 0, children : {} }

    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    {   
      let metric=parseInt(cgtoppers_bytes[i].metric);
      let labelparts=cgtoppers_bytes[i].label.split("\\");
      let keyparts=cgtoppers_bytes[i].readable.split("\\");
      let pos=tree;

      for (let i=0; i< keyparts.length; i++)
      {
        let k=keyparts[i];
        let l=labelparts[i];
        let c=pos.children[k];

        if (c==null)  {
          c={ name: l, key: k, metric: metric, children: {} }
          pos.children[k]=c;
        } else {
          c.metric += metric;
        }
        pos=c
      }
    }

    var cthis = this;
    let drawcell=function(tbl, node) {
      let tbody = $('<tbody>');

      // row for each child
      _.chain(node.children).values().sortBy((a)=>{return -a.metric}).each( (c) => {
        let tr=$('<tr>');
        tr.append(`<td> <h4>${c.key}  <span class="text-primary pull-right" title=${c.metric}>${h_fmtvol(c.metric)}</span></h4>${c.name.replace(/:\d$/,"")} peers: ${_.size(c.children)}</td>`);

        let td=$('<td>', {style:"padding:0px"});
        let subtbl=$('<table>',{class:"table table-condensed table-bordered", style:"margin-bottom:0px"});
        drawcell(subtbl,c);
        td.append(subtbl);
        tr.append(td);
        tbody.append(tr);
      });
      tbl.append(tbody);
    }

    let tbl = $(divid);
    tbl.html('');
    drawcell(tbl,tree);

  }
  fix_asname(str){
    return str
          .replace(/\W/g, ' ')
          .replace('  ',' ')
          .split(' ')
          .splice(0,2)
          .join(' ');
  }
}


 
 function run(opts){
  new IXPPathAnalytics(opts)
 }

//# sourceURL=ixp_analytics.js          
