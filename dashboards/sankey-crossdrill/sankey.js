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

    var js_params = {meter_details:this.cg_meters.all_cg_meters,
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
      maxitems:10000
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
        let k=item.label;
        if($("input[name*='invertfilter']").prop('checked')==true){
          return !k.match(reg_exp)
        }
        else{
          return k.match(reg_exp)
        }
      });
    }

    //always show top 30 
    cgtoppers_bytes = cgtoppers_bytes.slice(0,this.max_nodes)
    

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
    let tbl=this.data_dom.find('.toppers_table');
    tbl.addClass('table table-sysdata');
    _.each(cgtoppers_bytes, function(kt) {
        let r = $('<tr>')
        _.each(kt.label.split("\\"),function(ai){
           let l = ai.replace(/:0|:1|:2|:3|:4|:5|:6/g,"");
           r.append(`<td>${l}</td>`)
        });
        r.append(`<td>${h_fmtvol(kt.metric)}</td>`)
        tbl.find("tbody").append(r)
    });
    this.data_dom.find('.toppers_table').siblings('.animated-background').remove();
  }


}

function run(opts)
{
  new SankeyCrossDrill(opts)
}

//# sourceURL=sankey1.js

