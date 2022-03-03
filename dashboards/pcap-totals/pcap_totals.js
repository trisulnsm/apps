//
// pcap_total.js - Totals of Alerts,Resources,FTS,Flows,Packets,Bandwidht,and counter groups
//

//TEMPLATE

const HTML_TEMPLATE_O =Haml.render(`
  .card
    .card-header
      %h4
        Totals
        %small Click the counts to see data
    #overall_totals.card-body
      #statusline
      .row#chart_data.mb-3
      .row#badge_data`);
const CHART_TEMPLATE = Haml.render(`
    .col-6
      .card
        .card-body`);
const CARD_TEMPLATE = Haml.render(`
  .col-2.mb-3
    .card{style:"min-height:110px"}
      .card-body{style:"padding:10px"}
  `)
var TotalsModel = $.klass({
  init : function() {
    this.time_duration = {title:"Total Duration",from_ts:0,to_ts:0,duration:0};
    this.totals = [
     {title:"Total Bytes",guid:GUID.GUID_CG_AGGREGATE(),key:"TOTALBW",meter:0,data:0,chart_data:[],ratecounter:true,url:"/newdash?dash_key=retrousage"},
     {title:"Total Packets",guid:GUID.GUID_CG_AGGREGATE(),key:"TOTALBW",meter:1,data:0,chart_data:[],ratecounter:true,url:"/newdash?dash_key=retrousage"},
    ];
    this.metrics = [
     // Alerts
     {title:"Total Flows",key:GUID.GUID_SG_SESS(),data:0,url:"/sessions/explore"},
     {title:"IDS",key:"{9AFD8C08-07EB-47E0-BF05-28B4A7AE8DC9}",data:0,class:"danger",url:this.mk_idsalerturl("{9AFD8C08-07EB-47E0-BF05-28B4A7AE8DC9}")},
     {title:"Blacklist",key:"{5E97C3A3-41DB-4E34-92C3-87C904FAB83E}",data:0,class:"danger",url:this.mk_idsalerturl("{5E97C3A3-41DB-4e34-92C3-87C904FAB83E}")},
     {title:"Threshold Crossing",key:"{03AC6B72-FDB7-44c0-9B8C-7A1975C1C5BA}",data:0,class:"danger",url:"/alerts/tca_ci_dispatch/list_by_tcaid"},
     {title:"Flow Tracker",key:"{BE7F367F-8533-45F7-9AE8-A33E5E1AA783}",data:0,class:"danger",url:"/alerts/tca_st_dispatch/list_by_tcaid?"},
     {title:"System Alerts",key:"{F69C2462-ECEA-45B8-B1CB-F90342D37A4F}",data:0,class:"danger",url:this.mk_idsalerturl("{F69C2462-ECEA-45B8-B1CB-F90342D37A4F}")},
     {title:"Threshold Band",key:"{0E7E367D-4455-4680-BC73-699D81B7CBE0}",data:0,class:"danger",url:"/admin/threshold_band/list_alerts?"},
     //Resources
     {title:"HTTP URIs",key:"{4EF9DEB9-4332-4867-A667-6A30C5900E9E}",data:0,class:"success",url:this.mk_resurl("{4EF9DEB9-4332-4867-A667-6A30C5900E9E}")},
     {title:"DNS Resources",key:"{D1E27FF0-6D66-4E57-BB91-99F76BB2143E}",data:0,class:"success",url:this.mk_resurl("{D1E27FF0-6D66-4E57-BB91-99F76BB2143E}")},
     {title:"SSL Certs",key:"{5AEE3F0B-9304-44BE-BBD0-0467052CF468}",data:0,class:"success",url:this.mk_resurl("{5AEE3F0B-9304-44BE-BBD0-0467052CF468}")},
     {title:"File Hashes",key:"{9781DB2C-F78A-4F7F-A7E8-2B1A9A7BE71A}}",data:0,class:"success",url:this.mk_resurl("{9781DB2C-F78A-4F7F-A7E8-2B1A9A7BE71A}")},
     //FTS
     {title:"HTTP Headers",key:"{28217924-E7A5-4523-993C-44B52758D5A8}",data:0,class:"warning",url:this.mk_ftsurl("{28217924-E7A5-4523-993C-44B52758D5A8}")},
     {title:"FTS SSL Certs",key:"{9FEB8ADE-ADBB-49AD-BC68-C6A02F389C71}",data:0,class:"warning",url:this.mk_ftsurl("{9FEB8ADE-ADBB-49AD-BC68-C6A02F389C71}")},
     {title:"FTS DNS Records",key:"{09B305DF-078C-4B9E-8E2F-EA64B7326880}",data:0,class:"warning",url:this.mk_ftsurl("{09B305DF-078C-4B9E-8E2F-EA64B7326880}")}
    ];

  },
  //Different url for totals
  mk_idsalerturl:function(guid){
    return "/trisul_ids_alerts/show_by_sigid?"+$.param({agguid:guid});
  },
  mk_resurl:function(guid){
    return "/resource/index?"+$.param({rguid:guid});
  },
  mk_ftsurl:function(guid){
     return "ts/getfacets?"+$.param({fguid:guid});
  }
  
});


// Start to  get totals for items defined in modal
function run_model(mod,opts){
  deferq = $.Deferred();
  prom = deferq.promise();
  var kMod = mod;
  var kOpts = opts;
  prom = prom.then( function( f) {
    return get_counters_and_meters_json(kOpts);
  }).then( function( f) {
    return kMod.status_updater=mkstatusupdater(kMod,kOpts);
  }).then( function( f){
    return load_timeslices(kMod,kOpts); //time duration
  }).then( function( f) {
    return load_totals(kMod,kOpts); // total of rate_counter
  }).then( function( f) {
    return load_metrics(kMod,kOpts); // total of alert,resources,fts
  }).then( function(f){
    return load_cg_uniques(kMod,kOpts); //total of all cgs
  }); 
  deferq.resolve();
}

//get total for each counter group
function load_cg_uniques(mod, opts) {
  var kMod  = mod;
  _.each(opts['all_cg_meters'], function(ai,key) {
    var guid = key;

    var req = mk_trp_request(TRP.Message.Command.KEYSPACE_REQUEST,
            {counter_group:guid,
            time_interval:mod.active_interval(),
            totals_only:true});
    var kMod = mod;
    var kCGName = ai[0];
    // get slice intervals 
    prom=prom.then ( function(f){
      return get_response(req,function(resp){
        kMod.status_updater("Unique "+kCGName);
        if(resp.total_hits != undefined  && resp.total_hits.toNumber() !=0){
          var url = "/newdash?dash_key=retrousage&selected_cgguid="+guid;
          update_totals(kMod,{ title: "Unique " + kCGName,data: resp.total_hits.toNumber(),class:"secondary",url:url})
        }
        
      });
    });
  });

}

//total for time duration
function load_timeslices(mod,opts){
  var req = mk_trp_request(TRP.Message.Command.TIMESLICES_REQUEST,{get_total_window:true});
  var kMod = mod;

  // get slice intervals 
  return get_response(req,function(resp){
    kMod.status_updater(kMod.time_duration.title);
    kMod.time_duration.from_ts = resp.total_window.from.tv_sec.low;
    kMod.time_duration.to_ts = resp.total_window.to.tv_sec.low;
    kMod.time_duration.duration = h_fmtduration(resp.total_window.to.tv_sec.low - resp.total_window.from.tv_sec.low);
    update_duration(kMod,opts)
  });

}

// total for counter item 
function load_totals(mod,opts)
{
  var kMod=mod;
  //load toppers for every 5mins
  _.each( kMod.totals, function (k,i) {
    var kUp= k;
    k.bucket_size = kMod.get_bucketsize(k.guid);
    var req = mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,
    {
      counter_group: k.guid,
      key: TRP.KeyT.create({key:k.key}),
      time_interval:kMod.active_interval()
    });
    
    prom=prom.then ( function(f){
      return get_response(req,function(resp){
        kMod.status_updater(kUp.title);
        var multiplier = kUp.ratecounter ? kUp.bucket_size:1; // per second counter
        

        var total=_.chain(resp.stats)
                   .reduce( function(memo,ai) { return memo + multiplier*ai.values[kUp.meter].toNumber();}, 0 )
                   .value();
        kUp.data += total;
        update_totals(kMod,kUp);
        if(_.has(kUp,"chart_data")){
          kUp.chart_data = _.chain(resp.stats)
                           .collect(function(ai){
                            return {x:new Date(ai.ts_tv_sec.toNumber()*1000),y:ai.values[kUp.meter]*8}
                           })
                          .value();
          update_chart(kMod,kUp,i)
        } 
      });
    });
  });
}

//total for alerts,fts,resources
function load_metrics(mod,opts)
{
  var kMod=mod;
  //load toppers for every 5mins
  _.each( kMod.metrics, function (k) {
    var kUp= k;
    var req = mk_trp_request(TRP.Message.Command.METRICS_SUMMARY_REQUEST,
    {
      metric_name: k.key,
      totals_only:true
    });
    prom=prom.then ( function(f){
      return get_response(req,function(resp){
        kMod.status_updater(kUp.title);

        var total= _.chain(resp.vals)
           .reduce( function(memo,ai) { return memo + ai.val.toNumber();}, 0 )
           .value();
        kUp.data += total;
        update_totals(kMod,kUp); 
      });
    });
  });
}


//update duration data
function update_duration(mod,opts)
{
  var cls = "info"
  var kMod = mod;
  var pt = $(CARD_TEMPLATE);
  pt.addClass('col-4').removeClass('col-2');
  pt.find('.card').addClass('border-info');
  var header = $("<h4>",{class:"card-title text-"+cls}).text(kMod.time_duration.title)
  var t = $("<span>",{class:"text-"+cls}).text(kMod.time_duration.duration + " Starting from " + fmt_ts(kMod.time_duration.from_ts));
  pt.find('.card-body').append(header);
  pt.find('.card-body').append(t);
  $('#badge_data').append(pt);



}

// update total data common
function update_totals(mod,k)
{
  var cls = "info";
  var kMod  = mod;
  if(k.class){
    cls = k.class;
  }

  var pt = $(CARD_TEMPLATE);
  pt.find('.card').addClass('border-'+cls);
  var header = $("<h4>",{class:"card-title text-"+cls}).text(k.title);
  var data = h_fmtvol(k.data)
  if(_.has(k,"url")){
    var t = $("<a>",{class:"badge bg-"+cls,style:"font-size:130%",href:k.url,target:"_blank"}).text(data);
	t.attr('title',k.data);
  }
  else{
    var t = $("<span>",{class:"badge bg-"+cls,style:"font-size:130%"}).text(fmt_number(data));
	t.attr('title',k.data);
  }
  pt.find('.card-body').append(header);
  pt.find('.card-body').append(t);
  $('#badge_data').append(pt);
}

// for updater status

function mkstatusupdater(mod,opts)
{
  var kMod = mod;
  var max = 1 + kMod.totals.length + kMod.metrics.length + _.size(opts['all_cg_meters']) 
  var cnt=0;

  return function( msg) {
    ++cnt;
    if(Math.floor(cnt/max*100) >= 100){
      $('#statusline').remove();
    }
    $('#statusline').text("Please wait. Building totals. Step: " + msg + " " + Math.floor(cnt/max*100) + "%");
  }

}

function update_chart(mod,k,i){ 
  var kMod = mod;
  var kUp = k;
  var pt = $(CHART_TEMPLATE);
  pt.find('.card').addClass('card-secondary');
  $('#chart_data').append(pt);



  var chart_width = pt.width() - 20 ;
  var aspect_ratio = 3;
  var chart_height = parseInt(chart_width/aspect_ratio);
  chart_width = parseInt(chart_width);
  var canvas = $("<canvas>",{width:chart_width,height:chart_height,id:'canvas_'+i});

  pt.find('.card-body').append(canvas)

  var zoom = {
    // Boolean to enable zooming
    enabled: true,

    // Enable drag-to-zoom behavior
    drag: true,

    // Zooming directions. Remove the appropriate direction to disable 
    // Eg. 'y' would only allow zooming in the y direction
    mode: 'x',
    limits: {
      max: 10,
      min: 0.5
    }
  }


  var c10 = d3.schemeCategory10;
  
  var chart_datasets = [];
  //collecting the data
  
  chart_datasets.push({
    label:kUp.title,
    borderWidth: 1 ,
    fill:false,
    backgroundColor:c10[i],
    borderColor:c10[i],
    data:kUp.chart_data,
    steppedLine: true
  });
    
  
  var ctx = document.getElementById('canvas_'+i);
  var label_string = "";
  if(i==0){
    label_string = "bps"
  }else{
    label_string = "pps"
  }

  window.pcap_totals_canvas =  new Chart(ctx, {
    type:'line',
    data:{
      datasets:chart_datasets,
    },
    options: {
      responsive:false,

      scales: {
        xAxes: [{
          type: 'time',
          time: {
            displayFormats: {
              'day': 'MMM DD',
              'hour': 'hA MMM DD'
            }
          },
          
        }],
        yAxes: [{
          display:true,
            scaleLabel: {
              display: true,
              labelString: 'Units '+label_string
            },
            ticks: {
            autoSkip: true,
            maxTicksLimit: 8,
            callback: function(value, index, values) {
              return h_fmtbw(value);
            },
          }
        }]
      },
      tooltips: {
        callbacks: {
        label: function (tooltipItem, data) {
          return [names[tooltipItem.datasetIndex]+" : "+h_fmtbw(tooltipItem.yLabel)];
          }
        }
      },
      animation:false,
      elements: { point: { radius: 0 } },
      zoom:zoom,
      // Container for zoom options
     
    }
    
  });
  
}

//called from trp js base
function run(opts)
{
  var tmodel =  new TotalsModel();
  var domid = opts["divid"];
  tmodel.active_interval = function(){
    return mk_time_interval({window_fromts:tmodel.time_duration.from_ts,window_tots:tmodel.time_duration.to_ts})
  }
  tmodel.get_bucketsize = function(guid){
    if( opts["all_cg_bucketsize"][guid] == undefined)
    {
      return 60;
    }
    else{
      return opts["all_cg_bucketsize"][guid].bucket_size;
   }
  }
  $(domid).append( $(HTML_TEMPLATE_O));
  run_model(tmodel,opts)
}

//# sourceURL=pcap_totals.js
