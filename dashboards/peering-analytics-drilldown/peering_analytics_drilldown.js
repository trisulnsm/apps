class ISPDrilldownMapping{
  constructor(opts) {
    let js_file =opts.jsfile;
    let file_path = js_file.split("/")
    file_path.pop()
    file_path = file_path.join("/");
    let css_file = `/plugins/${file_path}/app.css`;
    $('head').append(`<link rel="stylesheet" type="text/css" href="${css_file}">`);
    this.dash_params = opts.dash_params;
    this.dom = $(opts.divid);
    this.time_selector = opts.new_time_selector;
    this.rand_id=parseInt(Math.random()*100000);
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.meter = this.dash_params.statid;
    this.maxitems=10;
    this.probe_id = opts.probe_id;
    this.load_meters();
  }
  
  async load_meters(){
    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    var fromTS = this.time_selector.start_time_db
    var toTS = this.time_selector.end_time_db
    this.tmint = mk_time_interval([fromTS,toTS]);
    this.reset_ui();


  }
  async reset_ui(){
    this.data_dom=$("<div class='drilldown_data'> <h2 class='drilldown_title'></h2> <div class='row'> <div class='col-xs-12'> <div class='drill_traffic_chart_div traffic_chart_div'> <h3> <i class='fa fa-line-chart'></i> Overall Usage Traffic Chart </h3> <div class='drill_traffic_chart'></div> </div> </div> </div> <div class='row'> <div class='col-xs-12 routers_drilldown'> <div class='col-xs-7 toppers_table_div'> <h3> <i class='fa fa-table'></i> Routers Toppers </h3> <div class='toppers_table'> <table> <thead></thead> <tbody></tbody> </table> </div> </div> <div class='col-xs-5 donut_chart_div'> <h3> <i class='fa fa-pie-chart'></i> Toppers Chart </h3> <div class='donut_chart'></div> </div> <div class='col-xs-12 routers_traffic_div traffic_chart_div'> <h3> <i class='fa fa-area-chart'></i> Traffic chart for Routers </h3> <div class='routers_traffic_chart'></div> </div> <div class='col-xs-12 routers_sankey_div sankey_chart_div'> <h3> <i class='fa fa-random'></i> Routers Sankey Chart </h3> <div class='routers_sankey_chart'></div> </div> </div> <div class='col-xs-12 interfaces_drilldown'> <div class='col-xs-6 toppers_table_div'> <h3> <i class='fa fa-table'></i> Interface Toppers </h3> <div class='toppers_table'> <table> <thead></thead> <tbody></tbody> </table> </div> </div> <div class='col-xs-6 donut_chart_div'> <h3> Toppers Chart </h3> <div class='donut_chart'></div> </div> <div class='col-xs-12 interface_traffic_div traffic_chart_div'> <h3> <i class='fa fa-area-chart'></i> Traffic chart for interfaces </h3> <div class='interfaces_traffic_chart'></div> </div> <div class='col-xs-12 interfaces_sankey_div sankey_chart_div'> <h3> <i class='fa fa-random'></i> Interfaces Sankey Chart </h3> <div class='interfaces_sankey_chart'></div> </div> <div class='col-xs-6 toppers_table_div'> <h3>Top Internal Hosts</h3> <div class='internal_ip'> <table> <thead> <tr> <th>Item</th> <th>Label</th> <th>FLows</th> <th sort='volume'>Volume</th> </tr> </thead> <tbody></tbody> </table> </div> </div> <div class='col-xs-6 toppers_table_div'> <h3>Top External Hosts</h3> <div class='external_ip'> <table> <thead> <tr> <th>Item</th> <th>Label</th> <th>Flows</th> <th sort='volume'>Volume</th> </tr> </thead> <tbody></tbody> </table> </div> </div> <div class='col-xs-6 toppers_table_div'> <h3>Top ASNumber</h3> <div class='tag_asnumber'> <table> <thead> <tr> <th>Item</th> <th>Label</th> <th>Flows</th> <th sort='volume'>Volume</th> </tr> </thead> <tbody></tbody> </table> </div> </div> <div class='col-xs-6 toppers_table_div'> <h3>Top Prefixes</h3> <div class='tag_prefixes'> <table> <thead> <tr> <th>Item</th> <th>Label</th> <th>Flows</th> <th sort='volume'>Volume</th> </tr> </thead> <tbody></tbody> </table> </div> </div> </div> </div> </div>");
    this.dom.find(".drilldown_data").html('');
    this.dom.append(this.data_dom);
    this.dom.find(".drill_traffic_chart").attr("id","drill_traffic_chart_"+this.rand_id);
    var title = `${this.dash_params.readable}(${this.dash_params.label})`
    this.data_dom.find(".drilldown_title").html(`Mappings for ${title}`)

    this.draw_drill_chart();
    this.filter_text = this.dash_params.key;
    this.agg_flows = [];
    await this.get_toppers("Routers")
    await this.get_toppers("Interfaces")
    await this.get_aggregated_flows("in");
    await this.get_aggregated_flows("out");
    this.draw_aggregate_table('internal_ip');
    this.draw_aggregate_table('external_ip');
    this.draw_aggregate_table('tag_asnumber');
    this.draw_aggregate_table('tag_prefixes');
  }

  draw_drill_chart(){
    let traf_chart_id = `drill_traffic_chart_${this.rand_id}`;
    var model_data = {cgguid:this.dash_params.cgguid,
        meter:this.meter,
        key:this.dash_params.key,
        window_fromts:this.time_selector.start_time_db,
        window_tots:this.time_selector.end_time_db,
        valid_input:1
      };
    $.ajax({
      url:"/trpjs/generate_chart",
      data:model_data,
      context:this,
      success:function(resp){
        $('#'+traf_chart_id).html(resp);

      }
    });

  }

  async get_toppers(filter_cgbase){
    this.selected_crosskey=_.pick(this.cg_meters.crosskey,function(a,b){
      let reg_exp = new RegExp(`Auto_${filter_cgbase}_${this.dash_params.filter_cgname}`,"i")
      return a[0].match(reg_exp);
    },this);
    this.crosskey_cgguid =  Object.keys(this.selected_crosskey)[0];
    this.top_bucket_size =  300;
    this.meter_types=this.cg_meters.all_meters_type[this.dash_params.cgguid];
    if(this.crosskey_cgguid){
      this.top_bucket_size=this.cg_meters.all_cg_bucketsize[this.crosskey_cgguid].top_bucket_size;
      this.meter_types = this.cg_meters.all_meters_type[this.crosskey_cgguid];
      if(_.size(this.meter_types) == 0 ){
        let parent_cgguid = this.selected_crosskey[this.crosskey_cgguid][1];
        this.meter_types = this.cg_meters.all_meters_type[parent_cgguid];
      }
    }
    this.cgtoppers_resp=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.crosskey_cgguid,
      time_interval: this.tmint ,
      meter:this.dash_params.meter,
      maxitems:100000
    });
    this.cgtoppers_resp.keys = this.sort_hash(this.cgtoppers_resp,"metric");
    //reject sysgrup and xx
    this.cgtoppers_resp.keys = _.reject(this.cgtoppers_resp.keys,function(topper){
      return topper.key=="SYS:GROUP_TOTALS" || topper.key.includes("XX");
    });

    if(this.filter_text){
      this.cgtoppers_resp.keys = _.select(this.cgtoppers_resp.keys,function(topper){
        return topper.key.match(this.filter_text)
      },this);
    }

    this.draw_table(filter_cgbase)
    await this.draw_dount_chart(filter_cgbase);
    await this.draw_traffic_chart(filter_cgbase);
    await this.draw_sankey_chart(filter_cgbase);

  }
  async get_aggregated_flows(intf){
    let readable = this.dash_params.readable.split("\\");
    
    let opts = {flowtag:`[asn]${this.dash_params.key}${this.dash_params.key}`,time_interval:this.tmint,probe_id:this.probe_id};
    if(readable.length > 1){
      let interfaces = readable[1].split("_");
      opts["nf_routerid"] = TRP.KeyT.create({label:interfaces[0]});
      if(interfaces[1]){
        opts[`nf_ifindex_${intf}`]= TRP.KeyT.create({label:interfaces[1]});
      }
    }
    this.agg_flows.push(await fetch_trp(TRP.Message.Command.AGGREGATE_SESSIONS_REQUEST,opts));
    
  }

  draw_table(filter_cgbase){
    let cgbasename = filter_cgbase.toLocaleLowerCase();
    var table = this.data_dom.find(`.${cgbasename}_drilldown`).find(".toppers_table").find("table");
    table.addClass('table table-hover table-sysdata');
    table.find("thead").append("<tr><th>Item</th><th>Label</th><th sort='volume' barspark='auto'>Volume </th>></tr>");
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    for(let i= 0 ; i < cgtoppers.length  ; i++){
      let topper = cgtoppers[i];
      let link_params =$.param({dash_key:"key",
                         guid:this.crosskey_cgguid,
                         key:topper.key,
                         statid:this.meter});
      let readable = topper.readable.split("\\").pop();
      let label = topper.label.split("\\").pop();
      var anchor =  `<a href=/newdash?${link_params} target='_blank'>${readable}</a>`;
      var anchor1 =  `<a href=/newdash?${link_params} target='_blank'>${label}</a>`;

      var key = topper.key.split("//").pop();
      table.find("tbody").append(`<tr>
                                <td>${anchor}</td>
                                <td>${anchor1}</td>
                                <td>${h_fmtvol(topper.metric*this.top_bucket_size)}${this.meter_types[this.meter].units.replace("ps","")}</td>
                                </tr>`);

    }
    add_barspark(table);
    table.tablesorter();
    
  }

  draw_aggregate_table(group){
    var table = this.data_dom.find(`.${group}`).find("table");
    table.addClass('table table-hover table-sysdata');
    let toppers = [];
    if(group=="internal_ip" || group == "external_ip"){
      toppers.push(this.agg_flows[0][group]);
      toppers.push(this.agg_flows[1][group]);
    }else if(group=="tag_asnumber"){
      if(! this.agg_flows[0].tag_group.find(x=>x.group_name=="asn")){
        return true
      }
     toppers.push(this.agg_flows[0].tag_group.find(x=>x.group_name=="asn").tag_metrics)
     toppers.push(this.agg_flows[1].tag_group.find(x=>x.group_name=="asn").tag_metrics)
    }
    else if(group=="tag_prefixes"){
      if(! this.agg_flows[0].tag_group.find(x=>x.group_name=="prf")){
        return true
      }
      toppers.push(this.agg_flows[0].tag_group.find(x=>x.group_name=="prf").tag_metrics)
      toppers.push(this.agg_flows[1].tag_group.find(x=>x.group_name=="prf").tag_metrics)
    }
    toppers =_.flatten(toppers).slice(0,50);
    let toppers_obj = {};
    for(let i=0 ; i < toppers.length; i++){
      let t = toppers[i];
      let k = t.key.key
      if(toppers_obj[k]){
        let  v = toppers_obj[k];
        v.count = parseInt(v.count) + parseInt(t.count) ;
        v.metric = v.metric.toNumber() + t.metric.toNumber() ;
      }else{
        toppers_obj[k] = t
      }
    }
    toppers = _.sortBy(_.values(toppers_obj),function(k){return -k.metric;});
    for(let i=0; i< toppers.length;i++){
      var t = toppers[i];

      table.find("tbody").append(`<tr>
                                  <td>${t.key.readable||t.key.key}</td>
                                  <td>${t.key.label}</td>
                                  <td>${t.count}</td>
                                  <td>${h_fmtvol(t.metric)}</td>
                                  </tr>`);
    }

  }
  async draw_dount_chart(filter_cgbase){
    let cgbasename = filter_cgbase.toLocaleLowerCase();
    this.dount_div_id = `${filter_cgbase}_dount_chart_${this.rand_id}`;
    this.data_dom.find(`.${cgbasename}_drilldown`).find(".donut_chart").append($("<div>",{id:this.dount_div_id}));
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
 
    var values = [];
    var labels = [];
    for(let i= 0 ; i <  cgtoppers.length  ; i++){
      values[i] =  cgtoppers[i].metric.toNumber()*this.top_bucket_size;
      labels[i] =  cgtoppers[i].label.replace(/:0|:1|:2/g,"");
    }
    var data = [{
      values:values,
      labels:labels,
      domain: {column: 0},
      hoverinfo: 'label+percent+name',
      hole: .4,
      type: 'pie'
    }];

    var layout = {
      title: 'Toppers',
      annotations: [
        {
          font: {
            size: 20
          },
          showarrow: false,
          text: '',
          x: 0.17,
          y: 0.5
        }
      ],
      height: 400,
      width:  $('#'+this.divid).find(".donut_chart").width(),
      showlegend: false,
    };
    var ploty_options = { modeBarButtonsToRemove: ['hoverClosestCartesian','toggleSpikelines','hoverCompareCartesian',
                               'sendDataToCloud'],
                          showSendToCloud:false,
                          responsive: true };
    Plotly.newPlot(this.dount_div_id, data, layout,ploty_options);

    var keys = _.map(cgtoppers,function(ai){return ai.key});
    for(let i=0 ; i < keys.length;i++){
      if(keys[i].includes("\\")){
        keys[i]=keys[i].replace(/\\/g,"\\\\")
      }
    }
  }
  async draw_traffic_chart(filter_cgbase){
    let cgtoppers =  this.cgtoppers_resp.keys.slice(0,this.maxitems);
    let cgbasename = filter_cgbase.toLocaleLowerCase();
    let keys = _.map(cgtoppers,function(ai){return ai.key});
    for(let i=0 ; i < keys.length;i++){
      if(keys[i].includes("\\")){
        keys[i]=keys[i].replace(/\\/g,"\\\\")
      }
    }
    this.traf_chart_id = `${cgbasename}_traffic_chart_${this.rand_id}`;
    this.data_dom.find(`.${cgbasename}_traffic_chart`).attr("id",this.traf_chart_id);
    var model_data = {cgguid:this.crosskey_cgguid,
        meter:this.dash_params.statid,
        key:keys.join(","),
        window_fromts:this.time_selector.start_time_db,
        window_tots:this.time_selector.end_time_db,
        valid_input:1
      };
    if(keys.length==0){
      $('#'+this.traf_chart_id).html("no data found");
      return
    }
    $.ajax({
      url:"/trpjs/generate_chart",
      data:model_data,
      context:this,
      success:function(resp){
        $('#'+this.traf_chart_id).html(resp);

      }
    });

  }
  async draw_sankey_chart(filter_cgbase){

    let cgbasename = filter_cgbase.toLocaleLowerCase();
    this.sankey_div_id = `${cgbasename}_sankey_chart_${this.rand_id}`;
    this.data_dom.find(`.${cgbasename}_sankey_chart`).append($("<div>",{id:this.sankey_div_id}));

    // Get Bytes Toppers
    this.cgtoppers_bytes = this.cgtoppers_resp.keys;
    this.cgtoppers_bytes = this.cgtoppers_bytes.slice(0,30);
    let keylookup = {};
    let idx=0;
    let links  = { source : [], target : [], value : [] };

    for (let i =0 ; i < this.cgtoppers_bytes.length; i++)
    {   
      //change label to :0,:1,:2
      //http host and host has same lable 
      let k=this.cgtoppers_bytes[i].label;
      let parts=k.split("\\");
      if(filter_cgbase == "Interfaces"){
        let router = parts[1].split("_").shift()
        parts = [parts[0],router,parts[1]];
      }

      parts = _.map(parts,function(ai,ind){
        return ai.replace(/:0|:1|:2/g,"")+":"+ind;
      });
      this.cgtoppers_bytes[i].label=parts.join("\\")
      keylookup[parts[0]] = keylookup[parts[0]]==undefined ? idx++ : keylookup[parts[0]];
      keylookup[parts[1]] = keylookup[parts[1]] || idx++;
      if (parts[2]) {
        keylookup[parts[2]] = keylookup[parts[2]] || idx++;
      }
        
    }

    for (let i =0 ; i < this.cgtoppers_bytes.length; i++)
    {
      let item=this.cgtoppers_bytes[i];
      let k=item.label;
      let parts=k.split("\\");
      if (parts[2]) {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric*this.top_bucket_size))
        links.source.push(keylookup[parts[1]])
        links.target.push(keylookup[parts[2]])
        links.value.push(parseInt(item.metric*this.top_bucket_size))

      } else {
        links.source.push(keylookup[parts[0]])
        links.target.push(keylookup[parts[1]])
        links.value.push(parseInt(item.metric*this.top_bucket_size))
      }
    }
    let labels=_.chain(keylookup).pairs().sortBy( (ai) => ai[1]).map( (ai) => ai[0].replace(/:0|:1|:2/g,"")).value()
  
    Plotly.purge(this.sankey_div_id);
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
    var width = this.data_dom.find(`#${this.sankey_div_id}`).width();
    width = parseInt(width)-50;
    var height = labels.length *50;
    if(height < 500){
      height =500;
    }
    var layout = {
      title: `${cgbasename} Mappings`,
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
  sort_hash(data,key){
    return data.keys.sort(function(a,b){
      let v1 = a["key"];
      let v2 = b["key"];
      if(key=="metric"){
        v1  = - a["metric"].toNumber();
        v2 =  - b["metric"].toNumber();
      }
      if (v1 < v2)
        return -1;
      if (v1 > v2)
        return 1;
      return 0;
    });
  }

};


function run(opts) {
  new ISPDrilldownMapping(opts);
}


//# sourceURL=ips_drilldown_mappings.js

// HAML
/*
.drilldown_data
  %h2.drilldown_title
  .row
    .col-xs-12
      .drill_traffic_chart_div.traffic_chart_div
        %h3
          %i.fa.fa-line-chart 
          Overall Usage Traffic Chart 
        .drill_traffic_chart
  .row
    .col-xs-12.routers_drilldown
      .col-xs-7.toppers_table_div
        %h3
          %i.fa.fa-table 
          Routers Toppers
        .toppers_table
          %table
            %thead
            %tbody
      .col-xs-5.donut_chart_div
        %h3
          %i.fa.fa-pie-chart 
          Toppers Chart
        .donut_chart
      .col-xs-12.routers_traffic_div.traffic_chart_div
        %h3
          %i.fa.fa-area-chart 
          Traffic chart for Routers
        .routers_traffic_chart
      .col-xs-12.routers_sankey_div.sankey_chart_div
        %h3
          %i.fa.fa-random 
          Routers Sankey Chart
        .routers_sankey_chart

    .col-xs-12.interfaces_drilldown
      .col-xs-6.toppers_table_div
        %h3
          %i.fa.fa-table 
          Interface Toppers
        .toppers_table
          %table
            %thead
            %tbody
      .col-xs-6.donut_chart_div
        %h3 
          Toppers Chart
        .donut_chart

      .col-xs-12.interface_traffic_div.traffic_chart_div
        %h3
          %i.fa.fa-area-chart 
          Traffic chart for interfaces
        .interfaces_traffic_chart
      .col-xs-12.interfaces_sankey_div.sankey_chart_div
        %h3 
          %i.fa.fa-random
          Interfaces Sankey Chart
        .interfaces_sankey_chart
      
      .col-xs-6.toppers_table_div
        %h3 Top Internal Hosts
        .internal_ip
          %table
            %thead
              %tr
                %th Item
                %th Label
                %th FLows
                %th{sort:"volume"} Volume
            %tbody
      .col-xs-6.toppers_table_div
        %h3 Top External Hosts
        .external_ip
          %table
            %thead
              %tr
                %th Item
                %th Label
                %th Flows
                %th{sort:"volume"} Volume
            %tbody
      .col-xs-6.toppers_table_div
        %h3 Top ASNumber
        .tag_asnumber
          %table
            %thead
              %tr
                %th Item
                %th Label
                %th Flows
                %th{sort:"volume"} Volume
            %tbody
      f.col-xs-6.toppers_table_div
        %h3 Top Prefixes
        .tag_prefixes
          %table
            %thead
              %tr
                %th Item
                %th Label
                %th Flows
                %th{sort:"volume"} Volume
            %tbody




*/


