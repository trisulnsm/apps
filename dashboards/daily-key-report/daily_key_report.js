var DailyKeyUsage = $.klass({

  init:function(opts){
    let card =$(get_card_shell());
    card.addClass('mb-3');
    card.find(".card-body").addClass('form-dots');
    card.find(".card-header h4").html("<i class='fa fa-search fa-fw'></i> Search Criteria")
    $(opts["divid"]).append(card);
    card.attr("id","dail_key_key_report_form");
    opts["card_id"]="#dail_key_key_report_form";
    this.trp_form = new TrpFormClass(opts,$.proxy(function(){this.reset_ui()},this));

  },

  //reset the ui
  reset_ui:function(){
    if(this.trp_form.key == "" || this.trp_form.key == undefined){
      alert("Key filed can't be blank");
      return true;
    }
    $(this.trp_form.domid).find('#mmm_data_card').remove();
    var card =$(get_card_shell());
    card.attr("id","mmm_data_card");
    card.find(".card-body").attr("id","mma_data");
    card.find(".card-header h4").text("Day wise key report");
    $(this.trp_form.domid).append(card);

    var table = $("<table>",{id:"mma_data_table",class:"table table-sysdata"});
    table.append($("<thead>",{}));
    table.find("thead").append("<tr><th>Date</th><th>Min</th><th>Max</th><th>Average</th><th>Total</th></tr>");
    table.append($("<tbody>",{}));
    table.tablesorter();
    $('#mma_data').append(table);
    new ExportToCSV({table_id:"mma_data_table",filename_prefix:"daily-key-report"});

    this.load_tint_array();

  },

  //get dates between to dates
  load_tint_array:function(){
   this.dates = get_dates(new Date(this.trp_form.from_date),new Date(this.trp_form.to_date));
   this.tris_pg_bar = new TrisProgressBar({max:this.dates.length,
                                            divid:'sq_content',
                                            slim: true});
   this.get_data();
  },

  //send trp request to get data from trp server
  get_data:function(){

    if(this.dates.length  == 0){
      return true;
    }
    var t = this.dates.shift();

    t = [t.getTime()/1000,(t.getTime()/1000)+86400];

    var meter = parseInt(this.trp_form.meters.split(",")[0]);

    var data = {counter_group:this.trp_form.counter_group,
                key:TRP.KeyT.create({label:this.trp_form.key}),
                time_interval:mk_time_interval(t)}

    var req = mk_trp_request(TRP.Message.Command.COUNTER_ITEM_REQUEST,data);

    get_response(req,$.proxy(function(resp){
      var data = _.chain(resp.stats)
                  .collect(function(ai){
                    return ai.values[meter].toNumber();
                  })
              .value();
      $('#mmm_data_card').find(".card-header h4").text("Day wise key usage report for "+resp.key.readable);
      this.update_table(resp.counter_group,meter,data,t[0]);
      this.get_data();
    },this));
  
  },

  //update the table to show data
  update_table(cgguid,meter,data,date){
    
    var meter_type = this.trp_form.all_meters_type[cgguid][meter];
    var rate_counter =1 ;
    var bucket_size = 1;

    //ratecounter and bucketsize for key
    if(data.length == 0 ){
      var max=0,min=0,total=0,average=0
    }else{
      var max = _.max(data);
      var min = _.min(data);
      var total = _.reduce(data, function(memo, num){ return memo + num; }, 0);
      var average = total/data.length;
      
     
      if(meter_type.type  == 4){
        rate_counter = 8;
        bucket_size  = this.trp_form.all_cg_bucketsize[cgguid].bucket_size;
      }

      total = total*bucket_size;
    }
    //format date to yyyy-mm-dd
    var date = new Date(date*1000),
        month = '' + (date.getMonth() + 1),
        day = '' + date.getDate(),
        year = date.getFullYear();

    if (month.length < 2) month = '0' + month;
    if (day.length < 2) day = '0' + day;


    var td  = "<td>"+[year, month, day].join('-')+"</td>";
    _.each([min,max,average],function(ai){
      td = td +  "<td>"+h_fmtbw(ai*rate_counter)+meter_type.units.toLowerCase()+"</td>";
    });
    td = td + "<td>"+h_fmtvol(total)+meter_type.units.slice(0,1)+"</td>"
 
    $('#mma_data').find("tbody").append("<tr>"+td+"</tr>");
    this.tris_pg_bar.update_progress_bar();

  },

  

});

function run(opts) {
 new DailyKeyUsage(opts); 
}

//# sourceURL=daily_key_report.js