/*
  key_usage_heatmap.js
  Get the usage of key in last 1 week in d3 heatmap type chart
  http://bl.ocks.org/tjdecke/5558084
  domid - You can interact with dom by using this dom id
*/

// Run function should automatically called when page is loaded.

var KeyActivityUsage = $.klass({
  init:function(opts){
    //
    this.domid = opts["divid"];
    if(typeof get_dirname == "undefined"){
      this.show_error_box();
      return true;
    }
    this.dirname = get_dirname(opts.jsfile);
    this.available_time = opts.available_time;
    this.tint_arr = [];
    this.data = [];
    this.map_days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
    this.days = [];
    this.no_of_days=7;
    deferq = $.Deferred();
    prom = deferq.promise();
    // build a callback chain
    var cthis = this;
    if(typeof get_counters_and_meters_json == "undefined"){
      this.show_error_box();
      return true;
    }
    prom = prom.then( function( f) {
      return get_counters_and_meters_json(opts);
    }).then ( function(f) {
      cthis.cg_meter_json=opts["all_cg_meters"];
      cthis.all_meters_type = opts["all_meters_type"];
      cthis.all_cg_bucketsize = opts["all_cg_bucketsize"]
      cthis.add_form();
    });
    deferq.resolve();
  },
  //add the from for user to select guid and meter
  add_form:function(){
    var form = $("<form class='form-horizontal'> <div class='row'> <div class='col-xs-4'> <div class='form-group'> <label class='control-label col-xs-4'> Counter Group </label> <div class='col-xs-8'> <select name='cgguid' id='hm_cg_id'></select> </div> </div> </div> <div class='col-xs-4'> <div class='form-group'> <label class='control-label col-xs-4'> Meter</label> <div class='col-xs-8'> <select name='meter' id='hm_meter_id'></select> </div> </div> </div> <div class='col-xs-4'> <div class='form-group'> <label class='control-label col-xs-4'> Key </label> <div class='col-xs-8'> <input type='text' name='key1' id='hm_key'> </div> </div> </div> </div> <div class='form-group'> <div class='col-xs-10 col-md-offset-4'> <input type='submit' name='commit' value='Show heatmap' class='btn-submit'> </div> </div> </form> <div id='hm_trp_data'> <div id='hm_status_bar'> <i class='fa fa-spin fa-spinner fa-fw hide'></i> <span id='hm_status_bar_text'></span> </div> </div>");

    $(this.domid).append(form);
    var js_params = {meter_details:this.cg_meter_json,
      selected_cg : "",
      selected_st : "0",
      update_dom_cg : "hm_cg_id",
      update_dom_st : "hm_meter_id"    
    }
    new CGMeterCombo(JSON.stringify(js_params));
    auto_complete('hm_key',{"update":"autocomplete_key","top_count":20},{"txt_id":"hm_key","cg_id":"hm_cg_id"});
    form.submit($.proxy(this.load_tint_array,this));
  },

  //calculate last 7 days time interval from the avialable time interval
  load_tint_array:function(){
    this.reset_ui();
    this.key= $('#hm_key').val().trim();
    if(this.key.length ==  0 ){
      alert("Key field can't be empty.")
      return false;
    }
    this.guid = $('#hm_cg_id').val();
    this.meter = parseInt($('#hm_meter_id').val());
    var date = new Date((this.available_time.window_tots-60)*1000);
    date.setHours(0,0,0,0);
    for(i = 0; i < this.no_of_days; i++){
      var tv_sec = date.getTime()-(i*86400000);
      var d = new Date(tv_sec);
      // d3 heat map example always day starts from 0
      // [3,2,1,0,4,5,6]
      if(this.days.length != 7 ){
        this.days.push(d.getDay());
      }
      this.tint_arr.push([tv_sec,tv_sec+86400000]);
    }
    $('#hm_status_bar').find("i").removeClass('hide');
    this.get_trp_data();
    return false;
  },
  //get trp resppnse
  get_trp_data:function(tint){
    //for last 7 days
    if(this.tint_arr.length <=0 ){
      $('#hm_status_bar').find("i").addClass('hide');
      $('#hm_status_bar_text').html('Completed.')
      setTimeout(function() {

        $('#hm_status_bar_text').html( '' );
      }, 5000);
      return true;
    }
    var tint = this.tint_arr.shift();
    var group_by_hour = {}
    var time_interval = TRP.TimeInterval.create();
    time_interval.from= TRP.Timestamp.create({tv_sec:tint[0]/1000});
    time_interval.to= TRP.Timestamp.create({tv_sec:tint[1]/1000});
    var date  = new Date(tint[0])
    var day = date.getDay();
    // d3 heat map example day  always start from monday 
    // In our example it may start from any day
    var day = this.days[day]+1;
    var req = mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,
              {
                counter_group: this.guid,
                key:  TRP.KeyT.create({label:this.key}),
                time_interval:time_interval
              });
    $('#hm_status_bar_text').html('Updating '+(this.no_of_days - this.tint_arr.length)+"/"+(this.no_of_days));
    get_response(req,$.proxy(function(resp){
      //initialize 0 to get empty rect box
      //data grouped by hour
      for(i=1 ; i <=24 ; i++){
        group_by_hour[i] = [0]
      }
      _.each(resp.stats,function(ai){
        var hour = new Date(ai.ts_tv_sec*1000).getHours()+1;
        group_by_hour[hour] = group_by_hour[hour] || [0];
        var val = this.rate_to_volume(ai.values[this.meter].low);
        group_by_hour[hour].push(val);
      },this);
      _.each(group_by_hour,function(val,hour){
        this.data.push({day:day,hour:parseInt(hour),value:_.reduce(val,function(ai,memo){return memo+ai},0),tv_sec:date.getTime()});
      },this)
      this.draw_heatmap();
      this.get_trp_data();
    },this));
    return false;
  },
  //reset ui for keys
  reset_ui:function(){
    this.data = [];
    this.days = [];
    $(this.domid).find('#hm_trp_data').find('svg').remove();
  },
  //drawing heatmap
  draw_heatmap:function(){
    // d3 heat map has come css
    $("<link/>", {
       rel: "stylesheet",
       type: "text/css",
       href: "/plugins/"+this.dirname +"/key_usage_heatmap.css"
    }).appendTo("head");
    var cthis = this;
    const margin = { top: 50, right: 0, bottom: 100, left: 30 },
      width = $('#hm_trp_data').width() - margin.left - margin.right,
      height = (width/1.7) - margin.top - margin.bottom,
      gridSize = Math.floor(width / 24),
      legendElementWidth = gridSize*2,
      buckets = 9,
      colors = ["#ffffd9","#edf8b1","#c7e9b4","#7fcdbb","#41b6c4","#1d91c0","#225ea8","#253494","#081d58"], // alternatively colorbrewer.YlGnBu[9]
      days = _.map(this.days,function(ai){return cthis.map_days[ai]}),
      times = ["1a", "2a", "3a", "4a", "5a", "6a", "7a", "8a", "9a", "10a", "11a", "12a", "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p", "10p", "11p", "12p"];

      var heatmap_dom = $(this.domid).find('#hm_trp_data');
      heatmap_dom.find('svg').remove();
      const svg = d3.select('#hm_trp_data').append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      const dayLabels = svg.selectAll(".dayLabel")
        .data(days)
        .enter().append("text")
          .text(function (d) { return d; })
          .attr("x", 0)
          .attr("y", (d, i) => i * gridSize)
          .style("text-anchor", "end")
          .attr("transform", "translate(-6," + gridSize / 1.5 + ")")
          .attr("class", function (d, i) { i = cthis.days[i];return ((i-1 >= 0 && i-1 <= 4) ? "dayLabel mono axis axis-workweek" : "dayLabel mono axis")});

      const timeLabels = svg.selectAll(".timeLabel")
        .data(times)
        .enter().append("text")
          .text((d) => d)
          .attr("x", (d, i) => i * gridSize)
          .attr("y", 0)
          .style("text-anchor", "middle")
          .attr("transform", "translate(" + gridSize / 2 + ", -6)")
          .attr("class", (d, i) => ((i >= 7 && i <= 16) ? "timeLabel mono axis axis-worktime" : "timeLabel mono axis"));

    var formatTime = d3.timeFormat("%Y-%m-%d");


    $('.d3_heatmap_tooltip').remove();
    var div = d3.select("body").append("div") 
    .attr("class", "d3_heatmap_tooltip")       
    .style("opacity", 0);

    var heatmapChart = function(data){
      var max = d3.max(data, (d) => d.value)
      if (max == 0 ){
        max = 8;
      }
      const colorScale = d3.scaleQuantile()
        .domain([d3.min(data, (d) => d.value), buckets - 1, max])
        .range(colors);

      const cards = svg.selectAll(".hour")
          .data(data, (d) => d.day+':'+d.hour);

      cards.append("title");

      cards.enter().append("rect")
        .attr("x", (d) => (d.hour - 1) * gridSize)
        .attr("y", (d) => (d.day - 1) * gridSize)
        .attr("rx", 4)
        .attr("ry", 4)
        .attr("class", "hour bordered")
        .attr("width", gridSize)
        .attr("height", gridSize)
        .style("fill", colors[0])
        .on("mouseover", function(d) {   
          div.transition()    
              .duration(200)    
              .style("opacity", .9);    
          div .html(formatTime((new Date(d.tv_sec)))+" "+  times[d.hour-1].toUpperCase() +"M"+ "<br/>"  + h_fmtvol(d.value))  
              .style("left", (d3.event.pageX) + "px")   
              .style("top", (d3.event.pageY - 28) + "px");
          })          
        .on("mouseout", function(d) {   
          div.transition()    
              .duration(500)    
              .style("opacity", 0)
        })
        .on('click',function(d){
          window.open("/manage_keys/business_hour_chart?" + 
            $.param({
              cgguid:cthis.guid,
              meter:cthis.meter,
              key:cthis.key,
              day:1,
              drawchart:true,
              from:(d.hour-1)+":00:00",
              to:d.hour+":00:00",
              from_date:formatTime((new Date(d.tv_sec))),
              to_date:formatTime((new Date(d.tv_sec))),
              hide_search_bar:1
            }),"_blank");
        })
      .merge(cards)
        .transition()
        .duration(1000)
        .style("fill", (d) => colorScale(d.value));


      cards.select("title").text((d) => d.value);

      cards.exit().remove();

      const legend = svg.selectAll(".legend")
        .data([0].concat(colorScale.quantiles()), (d) => d);

      const legend_g = legend.enter().append("g")
        .attr("class", "legend");

      legend_g.append("rect")
        .attr("x", (d, i) => legendElementWidth * i)
        .attr("y", height)
        .attr("width", legendElementWidth)
        .attr("height", gridSize / 2)
        .style("fill", (d, i) => colors[i]);

      legend_g.append("text")
        .attr("class", "mono")
        .text((d) => "≥ " + h_fmtvol(d))
        .attr("x", (d, i) => legendElementWidth * i)
        .attr("y", height + gridSize);

      legend.exit().remove();

    };
    heatmapChart(this.data);
  },

  rate_to_volume:function(val){
    var meter_type = this.all_meters_type[this.guid][this.meter];
    var bs = this.all_cg_bucketsize[this.guid]
    if(meter_type.type == 4 ) 
    {
      return val * parseInt(bs.bucket_size)
    }else{
      return val
    }
  },

  show_error_box:function(){
    var span = "<span>Please click <a href='https://trisul.org/download' target='_blank'> here </a> to  download lastest package. </span>";
    var error_box = "<div class = 'alert alert-danger'>You need to update your webtrisul package to use this feature.<br/>"+span+"</div>";

    $(this.domid).html(error_box);
    return true;
  }

});
function run(opts){
  
  new KeyActivityUsage(opts);
  
}
