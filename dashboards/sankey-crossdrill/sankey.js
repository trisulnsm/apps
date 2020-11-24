class SankeyCrossDrill  {

  constructor(opts) {
    this.divid   = opts['divid'].replace("#","")
    this.cgguid  = opts['cgguid']
    this.meter   = opts['meter']
    this.tmint   = opts['time_interval']
    this.remove_topper_count = 0;
    this.max_nodes=30;
    this.select_cgname=opts.jsparams.default_cgname
    this.dom = $(opts.divid);

    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;

    //append form in the div
    this.append_form(opts);

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

  async append_form(opts){
    await this.load_assets(opts)
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);
    //time selector
    var update_ids = "#from_date_sk"+",#to_date_sk";
    new ShowNewTimeSelector({divid:"#new_time_selector_sk",
                              update_input_ids:update_ids});


    //handle slider to remove toppers
    var cthis = this;
    $( "#slider-remove-topn" ).slider({
      min: 0, max: 10, value:0, step:1,
      create: function() {
         $( "#remove-top-n" ).text( $( this ).slider( "value" ) );
      },
      slide: function( event, ui ) {
         $( "#remove-top-n" ).text( ui.value );
        cthis.remove_topper_count=ui.value;
        cthis.prase_toppers();

      }
    });

   
    $( "#slider-max-nodes" ).slider({
      min: 20, max: 100, value:30, step:10,
      create: function() {
        $( "#max-nodes" ).text( $( this ).slider( "value" ) );
      },
      slide: function( event, ui ) {
        $( "#max-nodes" ).text( ui.value );
        cthis.max_nodes=ui.value;
        cthis.prase_toppers();

      }
    });


    //loadonly crosskey counter groups
    this.cg_meters={};
    await get_counters_and_meters_json(this.cg_meters);
    
    for (var key in this.cg_meters.all_cg_meters) {
      let v = this.cg_meters.all_cg_meters[key];
      if(v[1].length==0 &&  this.cg_meters.crosskey[key]){
        var parent_cgguid = this.cg_meters.crosskey[key][1];
        v[1] = cthis.cg_meters.all_cg_meters[parent_cgguid][1];
      }
    }


    let selectcgguid = _.findKey(this.cg_meters.all_cg_meters, (v,k) => { return v[0] == this.select_cgname  } ) 
    //only only crosskey guid
    let all_crosskey_cgguids = Object.keys(this.cg_meters.crosskey)
    let guid_with_meters ={}
    _.select(this.cg_meters.all_cg_meters,function(v,k){
      if(all_crosskey_cgguids.includes(k)){
        guid_with_meters[k] = v;
      }
    });
    var js_params = {meter_details:guid_with_meters,
      selected_cg : selectcgguid,
      selected_st : "0",
      update_dom_cg :"cg_id",
      update_dom_st :"meter_id",  
    }

    new CGMeterCombo(JSON.stringify(js_params));

    //submitform
    this.form.submit($.proxy(this.submitform,this));
  }
  //bind the form values to get toppers
  submitform(){


    this.reset();
    var selected_fromdate = this.form.find('#from_date_sk').val();
    var selected_todate = this.form.find('#to_date_sk').val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    let duration  = `   <i class='fa fa-clock-o fa-fw '></i>
                     from ${selected_fromdate} to ${selected_todate}
                     (${h_fmtduration(toTS-fromTS)})`
    this.dom.find(".target").html(duration)
    this.tmint = mk_time_interval([fromTS,toTS]);
    this.cgguid = this.form.find('#cg_id').val();
    this.meter = this.form.find('#meter_id').val();
    this.filter_text=this.form.find('#fltr_crs').val();
    this.run();
    return false;
  }

  reset(){
    
    this.dom.find(".ui_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
   
  }

  async run() {
    //find volume for selected meter ids
    //need to multiply by bucket_size to get volume
    var bucket_size = 1;
    var crosskey_cgguids = this.cg_meters.crosskey[this.cgguid];
    if (this.cg_meters.all_cg_bucketsize[this.cgguid]){
      bucket_size=this.cg_meters.all_cg_bucketsize[this.cgguid].top_bucket_size;
    }

    //find statid type 
    this.meter_types = this.cg_meters.all_meters_type[this.cgguid];
    if(_.size(this.meter_types) == 0 ){
     this.meter_types = this.cg_meters.all_meters_type[crosskey_cgguids[1]];
    }

    //multiply by bucket_size if type = "Bps" or 4
    if(this.meter_types[this.meter].type!=4 && this.meter_types[this.meter].units!="Bps"){
      bucket_size=1;
    }


    // Get Bytes Toppers 
    this.cgtoppers_bytes=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.cgguid,
      time_interval: this.tmint ,
      meter:parseInt(this.meter),
      maxitems:1000
    }); 

    this.cgtoppers_bytes = _.each(this.cgtoppers_bytes.keys, (k)=> { k.metric = parseInt(k.metric)*bucket_size; return k})

    this.prase_toppers();
  }

 async prase_toppers(){


    var cgtoppers_bytes = $.merge([], this.cgtoppers_bytes);
    cgtoppers_bytes = _.sortBy(cgtoppers_bytes,function(ck){return -ck.metric})
    cgtoppers_bytes = _.reject(cgtoppers_bytes, function(ai){
      return ai.key=="SYS:GROUP_TOTALS" || ai.key.includes("XX");
    });


    //remove n.of toppers for slider
    if(this.remove_topper_count  > 0){
      cgtoppers_bytes = cgtoppers_bytes.slice(this.remove_topper_count+1,cgtoppers_bytes.length);
    }
    
   
    if(this.filter_text){
      var reg_exp = new RegExp(this.filter_text,"i")
      cgtoppers_bytes = _.select(cgtoppers_bytes,function(item){
        if($("input[name*='invertfilter']").prop('checked')==true){
          return !item.label.match(reg_exp) && ! item.readable.match(reg_exp)
        }
        else{
          return item.label.match(reg_exp) || item.readable.match(reg_exp)
        }
      });
    }

    //always show top 30 
    cgtoppers_bytes = cgtoppers_bytes.slice(0,this.max_nodes)
    
    this.dom.find(".badge-count").text(cgtoppers_bytes.length)

    // convert this into this.
    this.repaint_sankey(cgtoppers_bytes);

    // table
    this.repaint_table(cgtoppers_bytes);
  }





  // sankey 
  repaint_sankey(cgtoppers_bytes) {

    let chart_div_id = 'sankey_chart';
    let keylookup = {};
    let idx=0;

    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    {   
        //change label to :0,:1,:2
        //http host and host has same lable 
        let k=cgtoppers_bytes[i].label;
        let parts=k.split("\\");
        parts = _.map(parts,function(ai,ind){
          return ai.replace(/:0|:1|:2|:3|:4|:5|:6/g,"")+":"+ind;
        });
        cgtoppers_bytes[i].label=parts.join("\\")
        keylookup[parts[0]] = keylookup[parts[0]]==undefined ? idx++ : keylookup[parts[0]];
        keylookup[parts[1]] = keylookup[parts[1]] || idx++;
        for(let i=2 ; i < parts.length;i++){
          if (parts[i]) {
            keylookup[parts[i]] = keylookup[parts[i]] || idx++;
          }
        }
      $()
    }


    // convert cg topper array into sankey links 
    let links  = { source : [], target : [], value : [] };

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
    let labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0].replace(/:0|:1|:2|:3|:4|:5|:6/g,"")).value()

    Plotly.purge(chart_div_id);
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
    var width = $('#'+this.divid).width();
    width = parseInt(width)-50;
    var height = labels.length *50;
    if(height < 500){
      height =500;
    }
    var layout = {
      title: this.cg_meters.all_cg_meters[this.cgguid][0],
      width:width,
      height:height,
      font: {
        size: 10
      },
      
    }
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };

    Plotly.react(chart_div_id, [data], layout, ploty_options)
    $(`#${chart_div_id}`).siblings('.animated-background').remove();

  }


  // table : show filtered toppers in a table 
  repaint_table(cgtoppers_bytes) {
    let table_header = $("<tr>");
    let ck_parents = this.cg_meters.crosskey[this.cgguid].slice(1,4);
    for(let i=0 ;i < ck_parents.length;i++){
      
      if(this.cg_meters.all_cg_meters[ck_parents[i]]){
        let header = this.cg_meters.all_cg_meters[ck_parents[i]][0] || "";
        table_header.append($("<th>").text(header));
      }
    }

    table_header.append("<th sort='volume'> Volume </th>");
    table_header.append("<th sort='nosort'> </th>");
    let tbl=this.data_dom.find('.toppers_table');
    tbl.find("thead").append(table_header)
    tbl.addClass('table table-sysdata');
    tbl.tablesorter();

    _.each(cgtoppers_bytes, $.proxy(function(kt) {
        let r = $('<tr>')
        r.data("cgguid",this.cgguid);
        r.data("meter",this.meter);
        r.data("key",kt.key);
        r.data("label",kt.label.replace(/:0|:1|:2|:3|:4|:5|:6/g,""));
        let readable = kt.readable.split("\\");
        _.each(kt.label.split("\\"),function(ai,idx){
          let t = ai.replace(/:0|:1|:2|:3|:4|:5|:6/g,"");
          if(t != readable[idx])
          {
            t = `${t}(${readable[idx]})`
          }
          r.append(`<td>${t}</td>`)
        });
        r.append(`<td>${h_fmtvol(kt.metric)}</td>`)
        r.append('<td><a class="sk_opts" href="javascript:;;"><i class="fa fa-fw fa-ellipsis-h fa-lg"></i></a></td>')
        tbl.find("tbody").append(r)
    },this));
    this.data_dom.find('.toppers_table').siblings('.animated-background').remove();
    tbl.find(".sk_opts").click($.proxy(function(){
      this.add_dropdown_menu(event);
    },this));
  }

  add_dropdown_menu(event){

    let target= $(event.target);
    let anchor = target.closest("a");
    if(anchor.attr("data-toggle") == "dropdown"){
      return;
    }
    anchor.attr("data-toggle","dropdown");
    anchor.wrap("<span class='dropdown'>");
    let omenu=`<ul class="dropdown-menu pull-right">
                <li id='key_dash'><a tabindex="-1" href="javascript:;">Key Dashboard</a></li>
                <li id='traffic_chart'><a tabindex="-1" href="javascript:;">Traffic Chart</a></li>
                <li id='longterm_traffic'><a tabindex="-1" href="javascript:;">Long Term Traffic</a></li>
              </ul>`
    anchor.after(omenu);
    anchor.closest("td").find("ul.dropdown-menu li a").click($.proxy(function(event){
      this.option_click(event,this.tmint)
    },this));
           

  }
  option_click(event,tmint){
    let target=$(event.target);
    let tr = target.closest("tr");
    var h = {
      cgguid:tr.data("cgguid"),
      key: tr.data("key"),
      readable:tr.data("label"),
      day:1,
      drawchart:true,
      meter:tr.data("meter"),
      hide_search_bar:1
    }
    
    switch(target.parent().attr("id")){
      case "key_dash":
        window.open("/newdash/index?" + 
          $.param({
              guid:tr.data("cgguid"),
              key: tr.data("key"),
              statid:tr.data("meter"),
              "dash_key":"key"
          }));
         break; 
      case "longterm_traffic":
        
        window.open("/manage_keys/business_hour_chart?" + 
                  $.param(h));
        break;

      case "traffic_chart":
        let p =_.extend({},h)
        p["key"]= p["key"].replace(/\\/g,"\\\\");
        p["description"]=tr.data("label").replace(/\\/g,"\\\\");
        p["name"] = $('#cg_id').find('option:selected').text();
        p["window_fromts"]=tmint.from.tv_sec;
        p["window_tots"]=tmint.to.tv_sec;
        load_modal("/trpjs/generate_chart_lb?" + $.param(p));
        break;
    }
  }

}

function run(opts)
{
  new SankeyCrossDrill(opts)
}

//# sourceURL=sankey1.js

