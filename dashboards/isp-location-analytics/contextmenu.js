function getattachmentpoints(){
  return [{
    cgguid: "{C0B04CA7-95FA-44EF-8475-3835F3314761}",
    meterids:[0,1,2],
    menuname:"Peering Analytics",
    id:0
  }]
}

function onclick(opts){
  let lp=$.param({dash_key_regex:"gitPeeringAnalytics",
                   key:opts.key.key,
                   valid_input:1,
                   window_fromts:opts.time_interval.window_fromts,
                   window_seconds:opts.time_interval.window_secs
                });
  window.open("/newdash/index?"+lp);
}

