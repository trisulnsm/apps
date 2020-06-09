//ASN Path analytics
class ASNPathAnalytics{

  constructor(opts){
    this.dom = $(opts.divid);
    this.rand_id=parseInt(Math.random()*100000);
    this.default_selected_time = opts.new_time_selector;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.cgguid = "{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}";
    if(opts.jsparams){
      this.cgguid = opts.jsparams.crosskey_interface || "{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}";
    }

    if(opts.remove_ls_items==true || opts.remove_ls_items=="true"){
      clear_localstorage_items({remove_keys:"apps.pathanalytics.last-selected*"});
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
                            },this.callback_load_routers,this);

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
        cthis.draw_sankey_chart(cthis.data[0],"upload");
        cthis.draw_sankey_chart(cthis.data[1],"download");
      }
    });
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
    //get routers from keyspace request
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
    //empty the router and interfaces for each time user changes time
    // Changing time will again reload the routers and interfaces

    $('#routers_'+this.rand_id).empty();
    $('#interfaces_'+this.rand_id).empty();
    let load_router_opts = {
      tmint : this.tmint,
      selected_cg : selected_cg || localStorage.getItem("apps.pathanalytics.last-selected-router") || "",
      selected_st : selected_st || localStorage.getItem("apps.pathanalytics.last-selected-interface")||"",
      update_dom_cg : "routers_"+this.rand_id,
      update_dom_st : "interfaces_"+this.rand_id,
      chosen:true
    }
    await load_routers_interfaces_dropdown(load_router_opts);
    //if previous selected router and interface not availble please select the first one
    if($('#routers_'+this.rand_id).val()==null){
      $('#routers_'+this.rand_id).val($(`#routers_${this.rand_id} option:first`).val());
      $('#routers_'+this.rand_id).trigger('change');
    }

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
    $('#app_error_box').addClass('hidden');
    this.dom.find(".path_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
    this.data_dom.find('.toppers_table').attr("id","toppers_table_"+this.rand_id);
    this.data_dom.find(".sankey_chart_upload").attr("id","sankey_chart_upload_"+this.rand_id);
    this.data_dom.find(".sankey_chart_download").attr("id","sankey_chart_download_"+this.rand_id);
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
      req_opts["key_filter"] = "[^0-9a-fA-F]"+filter_asn+"[^0-9a-fA-F]";
    }

    req_opts["meter"] = 0;
    this.data[0]=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,req_opts );
    req_opts["meter"] = 1;
    this.data[1]=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,req_opts);

    // Validate TRP 
    if (is_error_response(this.data[0])) {
      return show_app_error_box(this.data[0]);
    }
    if (is_error_response(this.data[1])) {
      return show_app_error_box(this.data[1]);
    }

    // multiply by bucketsize 
    for (let i =0 ; i < this.data[0].keys.length; i++) {   
      this.data[0].keys[i].metric  = this.data[0].keys[i].metric * bucketsize;
    }    
    for (let i =0 ; i < this.data[1].keys.length; i++) {   
      this.data[1].keys[i].metric  = this.data[1].keys[i].metric * bucketsize;
    }
   
    //key_filter in trp support one like 
    //we can't combine router with asn to make key filter
    //so support added via code.
    let filter_value = ".*";
    if(selected_router && filter_asn){
      filter_value = selected_router;
    }else if(selected_interface && filter_asn){
      filter_value = selected_interface
    }
    //resove asn path to label
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
                                  //remove repated asn in single path
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
    
    this.data[0].keys.sort( (a,b) => a.metric > b.metric?-1:1)
    this.data[1].keys.sort( (a,b) => a.metric > b.metric?-1:1)

    this.redraw_all();
  }

  redraw_all(){
    
    this.draw_table(this.data[0],"#table_upload");
    this.draw_table(this.data[1],"#table_download");
    this.draw_sankey_chart(this.data[0],"upload")
    this.draw_sankey_chart(this.data[1],"download")
    this.draw_path_table(this.data[0],'#nested-upload  table')
    this.draw_path_table(this.data[1],'#nested-download table')
  }


  draw_table(data,table_id){
    this.dom.find('.noitify').remove();
    let rows = [];
    var table = this.data_dom.find(table_id);
    table.find("tbody").html("");
    table.siblings("ul.pagination").remove();
    let cgtoppers =  data.keys.slice(this.remove_topper_count,100+this.remove_topper_count);
    table.closest('.panel').find("span.badge").html(cgtoppers.length);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      rows.push(`<tr data-key="${topper.label}"  data-label="${topper.label}" data-readable="${topper.readble}">
                                <td class='linkdrill'>${topper.readable}</a></td>
                                <td class='linkdrill'>${topper.label.replace(/:\d/g,"")}</a></td>
                                <td>${h_fmtvol(topper.metric)}</td>
                                </tr>`);


    }
    new TrisTablePagination(table_id.replace("#",""),{no_of_rows:10,rows:rows});
    table.tablesorter();
    new ExportToPDF({add_button_to:".add_download_btn",
                      tint:this.tmint,
                      logo_tlhs:this.logo_tlhs,
                      download_file_name:"path_analytics",
                      report_opts:{
                        header:{h1:"Path Analytics"},
                        section_headers:[{h1:"Upload"},{h1:"download"}],
                        nodes:[{find_by:`#table_upload`,type:"table",header_text:"auto",h1:"h3",h2:"h3 small",section_header:0},
                               {type:"page_break"},
                               {find_by:`.sankey_chart_upload`,type:"svg",header_text:"auto",h1:"h3",h2:"h3 small"},
                               {type:"page_break",add_header_footer:false},
                               {find_by:`#table_download`,type:"table",header_text:"auto",h1:"h3",h2:"h3 small",section_header:1},
                               {type:"page_break"},
                               {find_by:`.sankey_chart_upload`,type:"svg",header_text:"auto",h1:"h3",h2:"h3 small"}]
                      }
    });


  }

  draw_sankey_chart(toppers,id){
    this.sankey_div_id = `sankey_chart_${id}_${this.rand_id}`;
    let cgtoppers_bytes = toppers.keys.slice(this.remove_topper_count,this.max_crosskey_nodes);
    let keylookup = {};
    let idx=0;
    let links  = { source : [], target : [], value : [] };

    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    {   
      //change label to :0,:1,:2
      //http host and host has same lable 
      let k=cgtoppers_bytes[i].label;
      let parts=k.split("\\");

      
      parts = _.map(parts,function(ai,ind){
        return ai.replace(/:0|:1|:2|:3|:4|:5|:6|:7|:8|:9/g,"")+":"+ind;
      });

      cgtoppers_bytes[i].label=parts.join("\\")
      keylookup[parts[0]] = keylookup[parts[0]]==undefined ? idx++ : keylookup[parts[0]];
      keylookup[parts[1]] = keylookup[parts[1]] || idx++;
      for(let i=2 ; i < parts.length;i++){
        if (parts[i]) {
          keylookup[parts[i]] = keylookup[parts[i]] || idx++;
        }
      }
        
    }


    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    {
      let item=cgtoppers_bytes[i];
      let k=item.label;
      let parts=k.split("\\");
       for(let j=1;j < parts.length; j++){
        links.source.push(keylookup[parts[j-1]]);
        links.target.push(keylookup[parts[j]]);
        links.value.push(parseInt(item.metric))
      }

    }

    let labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0].replace(/:0|:1|:2|:3|:4|:5|:6|:7|:8|:9/g,"")).value()
    Plotly.purge(this.sankey_div_id);
    var data = {
      type: "sankey",
      orientation: "h",
      valuesuffix: "B",
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
    if(width < 900){
      width = 900;
    }
    var height = labels.length *25;
    if(height < 250 ){
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
  new ASNPathAnalytics(opts)
 }

//# sourceURL=path_analytics.js          
