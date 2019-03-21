//ASN Path analytics
class ASNPathAnalytics{
  constructor(opts){
    let js_file =opts.jsfile;
    let file_path = js_file.split("/")
    file_path.pop()
    file_path = file_path.join("/");
    let css_file = `/plugins/${file_path}/app.css`;
    $('head').append(`<link rel="stylesheet" type="text/css" href="${css_file}">`);
    this.dom = $(opts.divid);
    this.rand_id=parseInt(Math.random()*100000);
    this.default_selected_time = opts.new_time_selector;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.add_form();
  }
  //add form 
  async add_form(){
    this.form = $("<div class='row path_form'> <div class='col-xs-12'> <form class='form-horizontal'> <div class='row'> <div class='col-xs-6'> <div class='form-group'> <div class='new_time_selector'></div> </div> </div> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Routers</label> <div class='col-xs-8'> <select name='routers'></select> </div> </div> </div> </div> <div class='row'> <div class='col-xs-10 col-md-offset-4' style='padding-top:10px'> <input name='from_date' type='hidden'> <input name='to_date' type='hidden'> <input class='btn-submit' id='btn_submit' name='commit' type='submit' value='Submit'> </div> </div> </form> </div> </div>");
    this.form.find("select[name*='routers']").attr("id","routers_"+this.rand_id);
    this.form.find(".new_time_selector").attr("id","new_time_selector_"+this.rand_id);
    this.form.find("input[name*='from_date']").attr("id","from_date_"+this.rand_id);
    this.form.find("input[name*='to_date']").attr("id","to_date_"+this.rand_id);
    this.dom.append(this.form);
    var update_ids = "#from_date_"+this.rand_id+","+"#to_date_"+this.rand_id;
    //new time selector 
    new ShowNewTimeSelector({divid:"#new_time_selector_"+this.rand_id,
                               update_input_ids:update_ids,
                               default_ts:this.default_selected_time
                            });
    
    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    this.form.submit($.proxy(this.submit_form,this));
  }
  //time intetval
  mk_time_interval(){
    var selected_fromdate = $('#from_date_'+this.rand_id).val();
    var selected_todate = $('#to_date_'+this.rand_id).val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
  }

  reset_ui(){
    this.dom.find(".path_data").html('');
    this.data_dom = $("<div class='path_data'> <div class='row'> <div class='col-xs-12'> <div class='panel panel-info'> <div class='panel-body'> <div class='col-xs-12 toppers_table_div'> <h2> <i class='fa fa-table'></i> Busiest Routes <small> Shows the top used AS PATHS </small> </h2> <div class='toppers_table'> <table> <thead></thead> <tbody></tbody> </table> </div> </div> <div class='col-xs-12 sankey_asn_upload sankey_chart'> <h2> <i class='fa fa-random'></i> Route Per Hop Analytics - Transmit <small> Usage of busiest route segments </small> </h2> <div class='sankey_chart_upload'></div> </div> <div class='col-xs-12 sankey_asn_download sankey_chart'> <h2> <i class='fa fa-random'></i> Route Per Hop Analytics - Receive <small> Usage of busiest route segments - Download </small> </h2> <div class='sankey_chart_download'></div> </div> </div> </div> </div> </div> </div>");
    this.dom.append(this.data_dom);
    this.data_dom.find('.toppers_table_div').attr("id","toppers_table_"+this.rand_id)
    this.data_dom.find(".sankey_chart_upload").attr("id","sankey_chart_upload_"+this.rand_id);
    this.data_dom.find(".sankey_chart_download").attr("id","sankey_chart_download_"+this.rand_id)
  }

  submit_form(){
    this.reset_ui();
    this.mk_time_interval();
    this.get_data();
    return false;
  }
  async get_data(){
    this.cgguid = "{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}";
    if(this.cg_meters.all_cg_meters[this.cgguid]==undefined){
      this.data_dom.html("<div class='alert alert-info'>ASN Path Analytics lua is not installed</div>")
      return true;
    }
    //upload toppers
    let upload_bytes=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.cgguid,
      time_interval: this.tmint,
      maxitems:1000,
      meter:0
    });

    let download_bytes=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.cgguid,
      time_interval: this.tmint,
      maxitems:1000,
      meter:1
    });

    this.bucket_size = this.cg_meters.all_cg_bucketsize[this.cgguid].top_bucket_size;
    let unresolved_keys = [];
    unresolved_keys.push(this.get_unresolved_keys(upload_bytes));
    unresolved_keys.push(this.get_unresolved_keys(download_bytes));
    //changed to single array
    let keys = [].concat.apply([], unresolved_keys);
    //remove duplicates
    keys = Array.from(new Set(keys));

    //get name for keys
    let resolved_keyts=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, {
      counter_group: GUID.GUID_CG_ASN(),
      keys:keys
    });
    let resolved_keymap = {}
    for(let i=0;i<resolved_keyts.keys.length;i++){
      let keyt = resolved_keyts.keys[i]
      resolved_keymap[keyt.key] = keyt.label
    }
    //change label to resolved labels
    this.change_keys_label(upload_bytes,resolved_keymap);
    this.change_keys_label(download_bytes,resolved_keymap);
    
    //convert data to table
    var table_data = {}
    for(let i=0;i<upload_bytes.keys.length;i++){
      let keyt = upload_bytes.keys[i];
      let label = keyt.label;
      if (label=="SYS:GROUP_TOTALS"){
        continue;
      }
      if(table_data[label]==undefined){
        table_data[label] = [keyt.key,keyt.readable,label,0,0]
      }
      table_data[label][3]=table_data[label][3] + (keyt.metric.toNumber()*this.bucket_size)
    }

    for(let i=0;i<download_bytes.keys.length;i++){
      let keyt = download_bytes.keys[i];
      let label = keyt.label;
      if (label=="SYS:GROUP_TOTALS"){
        continue;
      }
      if(table_data[label]==undefined){
        table_data[label] = [keyt.key,keyt.readable,label,0,0]
      }
      table_data[label][4]=table_data[label][4] + (keyt.metric.toNumber()*this.bucket_size)
    }
    this.draw_table(table_data);
    this.draw_sankey_chart(upload_bytes,"upload")
    this.draw_sankey_chart(download_bytes,"download")

  }

  get_unresolved_keys(data){
    let arrays = []
    for(let i=0;i<data.keys.length;i++){
      let key = data.keys[i].key;
      if (key=="SYS:GROUP_TOTALS"){
        continue;
      }
      arrays.push(key.split("/"))
    }
    return [].concat.apply([], arrays);
  }

  change_keys_label(data,keymap){
    for(let i=0;i<data.keys.length;i++){
      let key = data.keys[i].key;

      if (key=="SYS:GROUP_TOTALS"){
        continue;
      }
      key = Array.from(new Set(key.split("/")));
      var labels=[];
      for(let j=0; j<key.length ; j++){
        labels.push(keymap[key[j]] || key[j])
      }
      data.keys[i].readable = key.join("\\");
      data.keys[i].label = labels.join("\\");
    }
  }

  draw_table(table_data){
    let rows = [];
    var table = this.data_dom.find(`#toppers_table_${this.rand_id}`).find(".toppers_table").find("table");
    this.table_id = `table_${this.rand_id}`;
    table.attr("id",this.table_id)
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append(`<tr><th>ASN Path</th><th style='width:400px'>Label</th><th sort='volume'>Upload </th><th sort='volume'>Download</th></tr>`);
    let cgtoppers =  Object.values(table_data).slice(0,100);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      rows.push(`<tr data-key="${topper[0]}"  data-label="${topper[2]}" data-readable="${topper[1]}">
                                <td class='linkdrill'>${topper[1]}</a></td>
                                <td class='linkdrill'>${topper[2]}</a></td>
                                <td>${h_fmtvol(topper[3])}</td>
                                <td>${h_fmtvol(topper[4])}</td>
                                </tr>`);


    }
    new TrisTablePagination(this.table_id,{no_of_rows:10,rows:rows});
    table.tablesorter();

  }

  draw_sankey_chart(toppers,id){
    this.sankey_div_id = `sankey_chart_${id}_${this.rand_id}`;
    let cgtoppers_bytes = toppers.keys.slice(1,30);
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
        return ai.replace(/:0|:1|:2/g,"")+":"+ind;
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
        links.value.push(parseInt(item.metric*this.bucket_size))
      }

    }
    let labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0].replace(/:0|:1|:2/g,"")).value()
  
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
    var height = labels.length *50;
    if(height < 500){
      height =500;
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

}

function run(opts){
  new ASNPathAnalytics(opts)
}

//# sourceURL=path_analytics.js


// HAML for from
/*
.row.path_form
  .col-xs-12
    %form.form-horizontal
      .row
        .col-xs-6
          .form-group
            .new_time_selector
        .col-xs-6 
          .form-group 
            %label.control-label.col-xs-4 Routers         
            .col-xs-8 
              %select{name:'routers'} 
      .row
        .col-xs-10.col-md-offset-4{style:"padding-top:10px"}
          %input{type:"hidden",name:"from_date"}
          %input{type:"hidden",name:"to_date"}
          %input.btn-submit{id:"btn_submit",name:"commit",type:"submit",value:"Submit"}
*/

/*
.path_data
  .row
    .col-xs-12
      .panel.panel-info
        .panel-body
          .col-xs-12.toppers_table_div
            %h2 
              %i.fa.fa-table
              Busiest Routes
              %small
                Shows the top used AS PATHS 
            .toppers_table
              %table
                %thead
                %tbody
          .col-xs-12.sankey_asn_upload.sankey_chart
            %h2 
              %i.fa.fa-random
              Route Per Hop Analytics - Transmit 
              %small
                Usage of busiest route segments
            .sankey_chart_upload
          .col-xs-12.sankey_asn_download.sankey_chart
            %h2 
              %i.fa.fa-random
              Route Per Hop Analytics - Receive
              %small
                Usage of busiest route segments - Download 
            .sankey_chart_download
            
*/