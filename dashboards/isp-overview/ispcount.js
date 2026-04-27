// ISP KPI top level dashboard
import {load_css_file,get_html_from_hamltemplate,mk_time_interval,load_routers_interfaces_dropdown,get_counters_and_meters_json,fetch_trp} from "trp_base";
import {ApexChartLB} from "trp_apexcharts";
import {draw_apex_chart} from "utils";



const kGUIDS  = [
  [ 'aspath',             '{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}'],
  [ 'flowas',             '{120A3124-E2BB-47BD-6C64-71BBB861C428}'],
  [ 'prefix',             '{2BE2A3B6-613D-4216-0737-3684E824EA33}'],
  [ 'routers',            '{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}'],
  [ 'interfaces',         '{C0B04CA7-95FA-44EF-8475-3835F3314761}'],
  [ 'countries',          '{00990011-44BD-4C55-891A-77823D59161B}'],  
];

// enter 
export async function run(opts)
{
  let activeitems  =  await refresh_model(opts);

  await load_assets(opts);
  repaint(activeitems,opts);
  await draw_asn_traffic_chart(opts);
}

// get the data items 
async function refresh_model(opts)
{
  let activeitems = {};

  let  ti= await fetch_trp(TRP.Message.Command.TIMESLICES_REQUEST, {
      get_total_window: true
  });

  // clip to last 5 mins
  ti.total_window.from.tv_sec = ti.total_window.to.tv_sec-300;


  for(let i = 0; i < kGUIDS.length; i++){

    let field_name = kGUIDS[i][0];
    let cg_guid = kGUIDS[i][1];

    // get Master Size from META COUNTER GROUP 
    let ciresp = await fetch_trp(TRP.Message.Command.COUNTER_ITEM_REQUEST, {
                            counter_group: '{4D88CC23-2883-4DEA-A313-A23B60FE8BDA}',
                            time_interval: mk_time_interval(ti.total_window),
                            key: TRP.KeyT.create({key:cg_guid})});


    activeitems[field_name]=  _.chain(ciresp.stats)
                               .collect( a=> a.values[0].toNumber())
                               .reduce( (memo,n)  => memo+n, 0)
                               .value() / ciresp.stats.length || 1 ;
};

  return activeitems;
}

// load the frame 
async function load_assets(opts)
{
  // load app.css file
  load_css_file(opts);

  // load template.haml file 
  let html_str = await get_html_from_hamltemplate(opts);
 
  $(opts.divid).html(html_str);
}


// paint the model
function repaint(datamodel,opts)
{
  $('#flowas').find('a').html( parseInt(datamodel.flowas));
  $('#prefix').find('a').html( parseInt(datamodel.prefix));
  $('#aspath').find('a').html( parseInt(datamodel.aspath));
  $('#routers').find('a').html( parseInt(datamodel.routers));
  $('#interfaces').find('a').html( parseInt(datamodel.interfaces));
  $('#countries').find('a').html( parseInt(datamodel.countries));

  $('a.trends').bind('click', function(evt) {
    clicktrends( evt, datamodel);
  });
  $('a.count').bind('click', function(evt) {
    clickcount( evt);
  });

}

// handle clickmeta, shows Lightbox chart of trends
function clicktrends(evt, datamodel)
{
  let userlabel = evt.target.parentNode.parentElement.querySelector('h2').id;
  let dm = _.find(kGUIDS, a => a[0]==userlabel)

  let models = [{counter_group:'{4D88CC23-2883-4DEA-A313-A23B60FE8BDA}',key:dm[1],meter:0}]
  let params = {
    models:JSON.stringify(models),
    show_table:1
  }
          
   
  new ApexChartLB(params,{modal_title:`${userlabel} Trends`})

}

//handle click count redirect to various dashboards
function clickcount(evt){
  let url = $(evt.currentTarget).data("url");
  window.open(url);
}

async function draw_asn_traffic_chart(opts){
  let cgguid = GUID.GUID_CG_ASN();
  let top_bucket = 300;
  let cginfo= await fetch_trp(TRP.Message.Command.COUNTER_GROUP_INFO_REQUEST);
  let cg=cginfo.group_details.find( (item) => item.guid == cgguid );
  if(cg){
    top_bucket = cg.topper_bucket_size.toNumber();
  }
  for(let i=0; i< 2; i++){
    let models = [];

    let cgtoppers=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,{
      counter_group: cgguid,
      meter:i,
      time_interval:mk_time_interval(opts.new_time_selector),
      maxitems:15
    });
    if(cgtoppers.keys.length == 0){
      $(`#asn_traffic_chart_${i}`).html("<div class='alert alert-info'>No data found</div>");
      continue;
    }
    _.each(cgtoppers.keys,function(keyt,idx){
      if(keyt.key!="SYS:GROUP_TOTALS" && idx <=10){
        models.push({counter_group:cgguid,meter:i,key:keyt.key,label:keyt.label});
      }
    });
    let model = models[0];
    let refmodel = [{counter_group:model[0],meter:model[2],key:"SYS:GROUP_TOTALS",label:"TOTAL"}];

    let data={models:JSON.stringify(models),
      valid_input:1,
      surface:"STACKEDAREA",
      show_legend:false,
      chart_height:350,
      refmodel:JSON.stringify("refmodel"),
      divid:`#asn_traffic_chart_${i}`
    }
    draw_apex_chart(data);
    _.each(cgtoppers.keys,function(keyt,idx){
      if(keyt.key!="SYS:GROUP_TOTALS" && idx <=9){
        let tr = `<tr><td>${keyt.label.substr(0,35)}</td><td>${h_fmtvol(keyt.metric.toNumber()*top_bucket )}</td></tr>`;
        $(`#asn_toppers_table_${i}`).find("table tbody").append(tr);
      }
    });

  }
 

  
}

//# sourceURL=ispcount.js
