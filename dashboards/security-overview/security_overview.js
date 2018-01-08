
//security overview 
SecurityOverview = $.klass({
  init:function(opts){
    this.available_time = opts["available_time"];
    this.domid = opts["divid"];
    //convert homenetworks into ineterget arrau
    this.home_networks_arr = this.convert_iparr_to_intergerarr(opts["home_networks"]);

    //build trp time interval
    this.tmint = new TRP.TimeInterval();
    var recentsecs = 86400;
    this.topcount = 100;

    var key = "/dash_extra_json/"+opts["dash_id"];
    var dash_json = JSON.parse(localStorage.getItem(key));

    if(dash_json.recentsecs > 0 ){
      recentsecs = parseInt(dash_json.recentsecs);
    }
    if(dash_json.topcount > 0 ){
      this.topcount = parseInt(dash_json.topcount);
    }
    this.tmint.from= new TRP.Timestamp({tv_sec:this.available_time.window_tots - recentsecs});
    this.tmint.to= new TRP.Timestamp({tv_sec:this.available_time.window_tots});
    
    // all the UI data will be stored
    this.alerts_data = {};
    this.scores = {}
    this.scores[GUID.GUID_AG_IDS()]={1:10000000,2:10000,3:1};
    this.scores[GUID.GUID_AG_BLACKLIST()]={0:1,1:1,2:1,3:1};
    this.scores[GUID.GUID_AG_USERALERTS()]={0:1,1:1,2:1,3:1};
    this.updatestatus = this.mkstatusupdater();


    deferq = $.Deferred();
    prom = deferq.promise();

    // build a callback chain
    //
    var cthis = this;
    this.reset_ui();
    prom = prom.then( function( f) {
      cthis.updatestatus("IDS High priority alerts")
      return cthis.ax_get_all_alerts(GUID.GUID_AG_IDS(),1)
    }).then( function( f) {
      cthis.updatestatus("IDS Medium priority alerts")
      return cthis.ax_get_all_alerts(GUID.GUID_AG_IDS(),2)
    }).then( function( f) {
      cthis.updatestatus("IDS low priority alerts")
      return cthis.ax_get_all_alerts(GUID.GUID_AG_IDS(),3)
    }).then( function( f) {
      cthis.updatestatus("Blacklist alerts")
      return cthis.ax_get_all_alerts(GUID.GUID_AG_BLACKLIST(),1)
    }).then( function( f) {
      cthis.updatestatus("FireHOL alerts")
      //return cthis.ax_get_all_alerts(GUID.GUID_AG_USERALERTS(),3)
    }).then(function(f){
      return cthis.update_UI();
    });
    deferq.resolve();
  },
  //convert homenetworks ip to integer
  // We can easily check wheater the ip belongs to home networks or not
  convert_iparr_to_intergerarr:function(home_networks){
    var home_networks_arr= _.collect(home_networks,function(hn){
        return _.collect(hn,function(ip){
          return this.convert_ip_to_integer(ip)
        },this);
      },this);
    return home_networks_arr
  },
  //conveet single ip to integer
  convert_ip_to_integer:function(ip){
    return ip.split('.').reduce(function(ipInt, octet) { return (ipInt<<8) + parseInt(octet, 10)}, 0) >>> 0;
  },

  //get the data from trp.
  ax_get_all_alerts:function(guid,priority)
  {
    var req = mk_trp_request(TRP.Message.Command.QUERY_ALERTS_REQUEST,
      {
        alert_group: guid,
        priority: new TRP.KeyT({key:priority.toString()}),
        time_interval:this.tmint,
        maxitems:1000
      });
    var cthis = this;
    return get_response(req,function(resp){
     cthis.process_alerts(resp);
    });
  },

  //count = [0,0,0,0,0]
  //Aarry pos 0 - IDS HIGH,IDS MEDIUM,IDS LOW,BADFELLAS,FireHOL

  process_alerts:function(resp){
    var guid = resp.alert_group;
    _.each(resp.alerts,function(alert){
      var keyt = this.get_internal_key(alert);
      //new interanl ip initialize for the ip
      if(this.alerts_data[keyt.key] == undefined ){
        this.alerts_data[keyt.key] = {keyt:keyt,score:0,counts:[0,0,0,0,0],sigids:{}}
      };
      //get the internal ip hash
      var h = this.alerts_data[keyt.key]
      var priority = parseInt(alert.priority.key);
      h.score = h.score + (1 * this.scores[guid][priority]);
      //all the response called the process alerts 
      // so take the corret index to put the count
      var idx = 0
      if(guid == GUID.GUID_AG_IDS()){
        idx = priority -1 
      }
      if(guid == GUID.GUID_AG_BLACKLIST()){
        idx =3
      }
      if(guid == GUID.GUID_AG_USERALERTS()){
        idx = 4
      }
      h.counts[idx] =  h.counts[idx] + 1;
      h_sigid = h.sigids[alert.sigid.key]
      if(h_sigid == undefined){
        //[key,label,count for sigid]
        h.sigids[alert.sigid.key] = {aguid:guid,key:alert.sigid.key,label:alert.sigid.label,
                                    dispatch_message1:alert.dispatch_message1,
                                    priority:alert.priority.key,
                                    count:0,score:0};
        h_sigid = h.sigids[alert.sigid.key]
      }
      //increase the score and count
      h_sigid.score = h_sigid.score +(1 * this.scores[guid][priority]);
      h_sigid.count = h_sigid.count + 1
    },this)
    
  },

  // return internal ip
  get_internal_key:function(alert){
    var dip_int = this.convert_ip_to_integer(alert.destination_ip.readable);
    var internal_keyt = alert.source_ip;
    _.each(this.home_networks_arr,function(ai){
      if(dip_int >= ai[0] && dip_int <= ai[1] ){
        internal_keyt =alert.destination_ip;
        return false
      }
    });
    return internal_keyt;
   
  },


  reset_ui:function(){
    $(this.domid).html("<span id = 'statusline'></span>");
    this.panel = $("<div id='sec_ip_overview'> <div class='row' id='sec_top_header'> <div class='col-xs-12'> <small class='pull-right text-muted' id='sec_tint_duration'></small> </div> </div> <div class='row total_alerts'> <div class='col-xs-3'> <div class='panel panel-default'> <div class='panel-body'> <small class='text-muted'>High Priority IDS</small> <h2> <span class='pull-left'> <i class='fa fa-snowflake-o fa-lg text-danger'></i> </span> <span class='pull-right' id='total_ids_p1'></span> </h2> </div> </div> </div> <div class='col-xs-3'> <div class='panel panel-default'> <div class='panel-body'> <small class='text-muted'>Medium Priority IDS</small> <h2> <span class='pull-left'> <i class='fa fa-snowflake-o fa-lg text-info'></i> </span> <span class='pull-right' id='total_ids_p2'></span> </h2> </div> </div> </div> <div class='col-xs-3'> <div class='panel panel-default'> <div class='panel-body'> <small class='text-muted'>Low Priority IDS</small> <h2> <span class='pull-left'> <i class='fa fa-snowflake-o fa-lg'></i> </span> <span class='pull-right' id='total_ids_p3'></span> </h2> </div> </div> </div> <div class='col-xs-3'> <div class='panel panel-default'> <div class='panel-body'> <small class='text-muted'>Badfellas</small> <h2> <span class='pull-left'> <i class='fa fa-bug fa-lg'></i> </span> <span class='pull-right' id='total_badfellas_p0'></span> </h2> </div> </div> </div> </div> <div class='col-xs-4 breakup_ip'> <div class='panel panel-info'> <div class='panel-heading'> <div class='panel-title'> <h4> <span class='ip_readable'></span> <span class='ip_score label label-success pull-right' style='font-size:20px'></span> </h4> <small class='clearfix ip_label text-muted'></small> </div> </div> <div class='panel-body'> <table class='table table-bordered'> <tbody> <tr> <td class='priority_count'> <h4> <span class='ids_p1 label label-danger'></span> </h4> </td> <td class='priority_count'> <h4> <span class='ids_p2 label label-warning'></span> </h4> </td> <td class='priority_count'> <h4> <span class='ids_p3 label label-info'></span> </h4> </td> <td class='priority_count'> <h4> <span class='badfellas_p0 label label-primary'></span> </h4> </td> </tr> <tr> <td colspan='5'> <ul class='sigids_ids list-unstyled border_bottom'> <li class='info_text text-center'>TOP IDS</li> </ul> <ul class='sigids_badfellas list-unstyled'> <li class='info_text text-center'>TOP Badfells</li> </ul> </td> </tr> </tbody> </table> </div> </div> </div> </div>");
  },

  update_UI:function(){
    var idx = 0;
    $('#statusline').remove();
    var header_panel = this.panel.find('#sec_top_header').clone();
    var duration = "<i  class='fa fa-clock-o'></i> Duration - "+h_fmtduration(this.tmint.to.tv_sec -this.tmint.from.tv_sec );
    duration = duration + " Starting from "+ new Date(this.tmint.from.tv_sec*1000);

    header_panel.find('#sec_tint_duration').html(duration);
    $(this.domid).append(header_panel);

    var total_panel = this.panel.find('.total_alerts');
    total_panel.find('.col-xs-3 .panel-body').css('min-height','90px');
                  
   
    var total_count =_.zip.apply(_,_.pluck(this.alerts_data,'counts'));
    var total_count = _.map(total_count,function(ai){
                        return _.reduce(ai, function(memo, num){ return memo + num; }, 0);
                      });
    if(_.isEmpty(total_count)){
      total_count = [0,0,0,0,0]
    }
    total_panel.find('h2').css('margin-top','5px');
    total_panel.find("#total_ids_p1").html(total_count[0]);
    total_panel.find("#total_ids_p2").html(total_count[1]);
    total_panel.find("#total_ids_p3").html(total_count[2]);
    total_panel.find("#total_badfellas_p0").html(total_count[3]);
    total_panel.find("#total_firehol_p0").html(total_count[4]);
    
    $(this.domid).append(total_panel);
    var  alerts_data = _.sortBy(this.alerts_data,function(b){return - b.score});
    alerts_data = _.values(alerts_data).slice(0,this.topcount);

    var  max_score = _.max(alerts_data,function(b){return  b.score});
    var  min_score = _.min(alerts_data,function(b){return  b.score});

    var ldomain = [min_score.score,max_score.score]    
    if(min_score.score == max_score.score){
      ldomain = [0,max_score.score];
    }
    var score_convert = d3.scaleLinear()
        .range([0,100])
        .domain(ldomain);

    _.each(alerts_data,function(data){
      if(idx%3==0){
        $(this.domid).append($("<div>",{class:"row",id:"row_"+idx/3}));
      }
      var panel = this.panel.find('.breakup_ip').clone();

      var params = {guid:GUID.GUID_CG_INTERNAL_HOSTS(),key:data.keyt.key};
      var href = "/newdash/index?dash_key=key&"+$.param(params);
      var anchor = $("<a>",{href:href,target:'_blank'}).html(data.keyt.readable)

      panel.find('.panel-title .ip_readable').html(anchor);
      panel.find('.panel-title .ip_score').html(Math.ceil(score_convert(data.score)));
      panel.find('.panel-title small').html(data.keyt.label);
      
      params = {agguid:GUID.GUID_AG_IDS(),ip:data.keyt.key,priority:1};
      href = "/trisul_ids_alerts/show_by_priority?"+$.param(params);
      anchor = $("<a>",{href:href,target:'_blank'}).html(data.counts[0]);

      panel.find('.ids_p1').html(anchor);
      params = {agguid:GUID.GUID_AG_IDS(),ip:data.keyt.key,priority:2};
      href = "/trisul_ids_alerts/show_by_priority?"+$.param(params);
      anchor = $("<a>",{href:href,target:'_blank'}).html(data.counts[1]);
      panel.find('.ids_p2').html(anchor);

      params = {agguid:GUID.GUID_AG_IDS(),ip:data.keyt.key,priority:3};
      href = "/trisul_ids_alerts/show_by_priority?"+$.param(params);
      anchor = $("<a>",{href:href,target:'_blank'}).html(data.counts[2]);
      panel.find('.ids_p3').html(anchor);

      params = {agguid:GUID.GUID_AG_BLACKLIST(),ip:data.keyt.key};
      href = "/trisul_ids_alerts/index?"+$.param(params);
      anchor = $("<a>",{href:href,target:'_blank'}).html(data.counts[3]);
      panel.find('.badfellas_p0').html(anchor);
     

      var top_sigids = {};
      top_sigids[GUID.GUID_AG_IDS()]=[]
      top_sigids[GUID.GUID_AG_BLACKLIST()]=[]
      top_sigids[GUID.GUID_AG_USERALERTS()]=[]
      var top_sigids_count = 3;

      _.chain(data.sigids)
        .values()
        .sortBy(function(ai){return - ai.score})
        .each(function(sigid){
          if(top_sigids[sigid.aguid].length < top_sigids_count){
            top_sigids[sigid.aguid].push(sigid);
          }
         })
        .value();
      //top 4 for all guids
      _.each(top_sigids,function(sigids,k){
        _.each(sigids,function(alert){
          var ulclass = '.sigids_ids';
          var textclass = ""
          if(alert.priority == 1){
            textclass = "";
          }
          var label = alert.label
          if(alert.aguid == GUID.GUID_AG_BLACKLIST()){
            ulclass = '.sigids_badfellas'
            label = alert.label +"-" +alert.dispatch_message1
          }
          if(alert.aguid == GUID.GUID_AG_USERALERTS()){
            ulclass = '.sigids_firehol'
            label = alert.label +"-" +alert.dispatch_message1
          }
          panel.find(ulclass).append($("<li>",{class:textclass}).text(label + " (" + alert.count + ")"));
        });
      })
      var id = Math.floor(idx/3)
      $(this.domid).find('#row_'+id).append(panel);
      idx = idx+1;
    },this);
    
  },

  mkstatusupdater:function()
  {
    var   max=5,
          cnt=0;

    return function( msg) {
      ++cnt;
      $('#statusline').text("Please wait. Getting alerts. Step: " + msg + " " + Math.floor(cnt/max*100) + "%");
    }

  }

})

function run(opts)
{
  new SecurityOverview(opts);
}

//# sourceURL=security_overview.js
