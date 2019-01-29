
class SankeyCrossDrill  {

  constructor(opts) {
    this.divid   = opts['divid'].replace("#","")
    this.cgguid  = opts['cgguid']
    this.meter   = opts['meter']
    this.tmint   = opts['time_interval']
    this.labels = [];
    this.remove_topper_count = 0;
    //we need it for time zone conversion
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    //append form in the div
    this.append_form();
  }
  async append_form(){

    this.rand_id=parseInt(Math.random()*100000);
    this.form = $("<form class='form-horizontal'> <div class='row'> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Counter Group</label> <div class='col-xs-8'> <select name='cgguid'></select> </div> </div> </div> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Meter</label> <div class='col-xs-8'> <select name='meter'></select> </div> </div> </div> </div> <div class='row'> <div class='col-xs-6'> <div class='form-group'> <div class='new_time_selector'></div> </div> </div> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Remove Toppers</label> <div class='col-xs-8' style='padding-top:10px'> <div id='slider'> <div class='ui-slider-handle' id='custom-handle'></div> </div> </div> </div> </div> </div> <div class='row'> <div class='col-xs-6'> <div class='form-group'> <label class='control-label col-xs-4'>Filter Item</label> <div class='col-xs-8'> <input name='fltr_crs_items' type='text'> <div class='span help-block text-left'>Type text to filter crosskey items</div> </div> </div> </div> </div> <div class='row'> <div class='col-xs-10 col-md-offset-4' style='padding-top:10px'> <input name='from_date' type='hidden'> <input name='to_date' type='hidden'> <input class='btn-submit' id='btn_submit' name='commit' type='submit' value='Show Chart'> </div> </div> </form>");
    //all are randomid only
    this.form.find("select[name*='cgguid']").attr("id","cg_id_"+this.rand_id);
    this.form.find("select[name*='meter']").attr("id","meter_id_"+this.rand_id);
    this.form.find(".new_time_selector").attr("id","new_time_selector_"+this.rand_id);
    this.form.find("input[name*='from_date']").attr("id","from_date_"+this.rand_id);
    this.form.find("input[name*='to_date']").attr("id","to_date_"+this.rand_id);
     this.form.find("input[name*='fltr_crs_items']").attr("id","fltr_crs_"+this.rand_id);

    $('#'+this.divid).append(this.form);
    

    //time selector
    var update_ids = "#from_date_"+this.rand_id+","+"#to_date_"+this.rand_id;
    new ShowNewTimeSelector({divid:"#new_time_selector_"+this.rand_id,
                              update_input_ids:update_ids});
    //handle slider to remove toppers
    var handle = $( "#custom-handle" );
    var cthis = this;
    $( "#slider" ).slider({
      min: 0,
      max: 10,
      value:0,
      step:1,
      create: function() {
        handle.text( $( this ).slider( "value" ) );
      },
      slide: function( event, ui ) {
        handle.text( ui.value );
        cthis.remove_topper_count=ui.value;
        cthis.prase_toppers();

      }
    });

    //loadonly crosskey counter groups
    this.cg_meters={};
    await get_counters_and_meters_json(this.cg_meters);
    if(_.size(this.cg_meters.crosskey)  ==0 ){
      $('#'+this.divid).html("<div class='alert alert-info'>No crosskey counter groups found</div>");
      return true;
    }
    var crosskey_meters = _.chain(this.cg_meters.all_cg_meters)
                            .pick(function(a,b){
                              //select only crosskey countet group
                              return _.keys(cthis.cg_meters.crosskey).includes(b)
                            }).each(function(a,b){
                              //if meter is empty get if from parent counter group
                            if(a[1].length==0){
                             var parent_cgguid = cthis.cg_meters.crosskey[b][0];
                             a[1] = cthis.cg_meters.all_cg_meters[parent_cgguid][1];
                            }
                          })
                          .value();


    var js_params = {meter_details:crosskey_meters,
      selected_cg : "",
      selected_st : "0",
      update_dom_cg :"cg_id_"+this.rand_id,
      update_dom_st :"meter_id_"+this.rand_id  
    }

    new CGMeterCombo(JSON.stringify(js_params));

    //submitform
    this.form.submit($.proxy(this.submitform,this));
  }
  //bind the form values to get toppers
  submitform(){
    this.reset();
    var selected_fromdate = $('#from_date_'+this.rand_id).val();
    var selected_todate = $('#to_date_'+this.rand_id).val();
    var fromTS = parseInt((new Date(selected_fromdate).getTime()/1000)-this.tzadj);
    var toTS = parseInt((new Date(selected_todate).getTime()/1000)-this.tzadj);
    this.tmint = mk_time_interval([fromTS,toTS]);
    this.cgguid = $('#cg_id_'+this.rand_id).val();
    this.meter = $('#meter_id_'+this.rand_id).val();
    this.filter_text=$('#fltr_crs_'+this.rand_id).val();
    this.run();
    return false;
  }
  reset(){
    $('#'+this.divid).find(".panel").remove();
    $('#'+this.divid).append("<div class='panel panel-info'> <div class='panel-body'> <h4> <i class='fa fa-spinner fa-spin'></i> Pleae wait ....  </h4> </div> </div>");
    this.chart_div_id = 'sankey_chart_'+this.rand_id;
    $('#'+this.divid).find(".panel-body").append($("<div>",{id:this.chart_div_id}));
  }


  async run() {
    // Get Bytes Toppers 
    this.cgtoppers_bytes=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.cgguid,
      time_interval: this.tmint ,
      meter:this.meter,
      maxitems:1000
    });
    this.prase_toppers();
  }

 async prase_toppers(){
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
     this.meter_types = this.cg_meters.all_meters_type[crosskey_cgguids[0]];
    }
    //multiply by bucket_size if type = "Bps" or 4
    if(this.meter_types[this.meter].type!=4 && this.meter_types[this.meter].units=="Bps"){
      bucket_size=1;
    }
    this.links  = { source : [], target : [], value : [] };
    var cgtoppers_bytes = $.merge([], this.cgtoppers_bytes.keys);
    cgtoppers_bytes = _.reject(cgtoppers_bytes, function(ai){
      return ai.key=="SYS:GROUP_TOTALS" || ai.key.includes("_XX");
    });
    //remove n.of toppers for slider
    if(this.remove_topper_count  > 0){
      cgtoppers_bytes = cgtoppers_bytes.slice(this.remove_topper_count+1,cgtoppers_bytes.length);
    }

    let keylookup = {};
    let idx=0;
    
    //resolve keys  to show name
    //get all itmes to resolve
    //unresolved_keys=[["C0.A8.01.01"...],["p-0050"...],["34.AF.34.4F"..]]
    //resolved_keys=[{C0.A8.01.01:localmcahine}]
    var unresolved_keys = [[],[],[]];
    var resolved_keys = [{},{},{}];
    for (let i =0 ; i < cgtoppers_bytes.length; i++) 
    {  
        let k=cgtoppers_bytes[i].label;

        let parts=k.split("_");
        unresolved_keys[0].push(parts[0]);
        unresolved_keys[1].push(parts[1]);
        if (parts[2]) {
         unresolved_keys[2].push(parts[2]);
        }
    }
    
    for(let i =0; i < unresolved_keys.length ; i++){
      var req_opts = {
        counter_group:crosskey_cgguids[i],
        keys:_.uniq(unresolved_keys[i])
      }
      var resp=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,req_opts);
      _.each(resp.keys,function(keyt){
        resolved_keys[i][keyt.key] = keyt.label.replace("_","-");
      });
    }
      
    //cgtopers convert to label to resolved item
    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    { 
        //convert label to resolved lable
        let k=cgtoppers_bytes[i].label;
        let parts=k.split("_");
        parts=[resolved_keys[0][parts[0]],resolved_keys[1][parts[1]],parts[2]]
        if (parts[2]) {
          parts[2]=resolved_keys[2][parts[2]];
        }
        cgtoppers_bytes[i].label=parts.join("_");
    }
    if(this.filter_text){
      var reg_exp = new RegExp(this.filter_text,"i")
      cgtoppers_bytes = _.select(cgtoppers_bytes,function(item){
        let k=item.label;
        return k.match(reg_exp)
      });
    }

    //always show top 25 
    cgtoppers_bytes = cgtoppers_bytes.slice(0,30)
    
    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    { 
        //convert label to resolved lable
        let k=cgtoppers_bytes[i].label;
        let parts=k.split("_");
        keylookup[parts[0]] = keylookup[parts[0]]==undefined ? idx++ : keylookup[parts[0]];
        keylookup[parts[1]] = keylookup[parts[1]] || idx++;
        if (parts[2]) {
          keylookup[parts[2]] = keylookup[parts[2]] || idx++;
        }
        
    }

    for (let i =0 ; i < cgtoppers_bytes.length; i++)
    {
        let item=cgtoppers_bytes[i];
        let k=item.label;
        let parts=k.split("_");
        if (parts[2]) {
          this.links.source.push(keylookup[parts[0]])
          this.links.target.push(keylookup[parts[1]])
          this.links.value.push(parseInt(item.metric*bucket_size))
          this.links.source.push(keylookup[parts[1]])
          this.links.target.push(keylookup[parts[2]])
          this.links.value.push(parseInt(item.metric*bucket_size))

        } else {
          this.links.source.push(keylookup[parts[0]])
          this.links.target.push(keylookup[parts[1]])
          this.links.value.push(parseInt(item.metric*bucket_size))
        }

    }
    this.labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0]).value()
    // convert this into this.
    this.repaint();
  }

  repaint() {
    $('#'+this.divid).find(".panel-body h4").remove();
    Plotly.purge(this.chart_div_id);
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
        label: this.labels,
      },

      link: this.links
    }

    //width of div widht
    var width = $('#'+this.divid).width();
    width = parseInt(width)-50;
    var height = this.labels.length *50;
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

    var data = [data]
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };

    Plotly.react(this.chart_div_id, data, layout, ploty_options)


  }


}

function run(opts)
{
  new SankeyCrossDrill(opts)
}

//# sourceURL=sankey1.js

//from

/*
%form.form-horizontal
  .row
    .col-xs-6 
      .form-group 
        %label.control-label.col-xs-4 Counter Group         
        .col-xs-8 
          %select{name:'cgguid'} 
    .col-xs-6 
      .form-group 
        %label.control-label.col-xs-4 Meter 
        .col-xs-8 
          %select{name:'meter'}
  .row
    .col-xs-6
      .form-group
        .new_time_selector

    .col-xs-6
      .form-group
        %label.control-label.col-xs-4 Remove Toppers
        .col-xs-8{style:"padding-top:10px"}
          #slider
            %div#custom-handle.ui-slider-handle
  .row 
    .col-xs-6
      .form-group
        %label.control-label.col-xs-4 Filter Item
        .col-xs-8
          %input{type:"text",name:"fltr_crs_items"}
          .span.help-block.text-left Type text to filter crosskey items

  .row
    .col-xs-10.col-md-offset-4{style:"padding-top:10px"}
      %input{type:"hidden",name:"from_date"}
      %input{type:"hidden",name:"to_date"}
      %input.btn-submit{id:"btn_submit",name:"commit",type:"submit",value:"Show Chart"}

  
*/

/*
.panel.panel-info
  .panel-body
    %h4
      %i.fa.fa-spinner.fa-spin
      Pleae wait ....

*/