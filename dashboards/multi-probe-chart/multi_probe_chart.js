class ProbesChart {
  constructor(opts  ){
    this.divid = opts['divid'];
    this.jsparams = opts['jsparams'] || {};
    this.new_time_selector = opts["new_time_selector"];
    this.context_name = opts["context"];
    this.randomid = parseInt(Math.random()*100000);
    //fulldiv 
    var timerowdiv =  document.createElement('DIV');
    this.set_attributes(timerowdiv,{class:"col-12 form-dots"});

    var timeselctor = document.createElement('DIV');
    this.set_attributes(timeselctor,{id:`new_time_selector_${this.randomid}`,class:"col-8"});

    var default_node = document.getElementById(this.divid.replace("#",''));
    timerowdiv.appendChild(timeselctor);
    default_node.appendChild(timerowdiv);

   var from_date = document.createElement("INPUT");

    this.set_attributes(from_date,
                        {name:`from_date_${this.randomid}`,
                        type:"hidden",
                        value:this.new_time_selector.start_date,
                        id:`from_date_${this.randomid}`
                        });
    default_node.appendChild(from_date);


    var to_date = document.createElement("INPUT")
    this.set_attributes(to_date,
                        {name:`to_date_${this.randomid}`,
                        type:"hidden",
                        value:this.new_time_selector.end_date,
                        id:`to_date_${this.randomid}`
                        });
    default_node.appendChild(to_date);

    new ShowNewTimeSelector({divid:`#new_time_selector_${this.randomid}`,
                            update_input_ids:`#from_date_${this.randomid},#to_date_${this.randomid}`,
                            default_ts:this.new_time_selector},this.time_selector_callback());

    var chart_div = document.createElement("DIV")
    chart_div.style.paddingTop="7%";
    chart_div.style.backgroundColor="#FFF"; 
    this.set_attributes(chart_div,{id:`chart_data_${this.randomid}`,class:"clearfix"});
    default_node.append(chart_div)


  }

  set_attributes(ele,attrs){
    for(var key in attrs) {
      ele.setAttribute(key, attrs[key]);
    }
  }

  time_selector_callback(start,end){
    var cthis = this;
    return(function(){
      cthis.run();
    });
  }

  async run(){
    document.getElementById(`chart_data_${this.randomid}`).innerHTML = "";
    var context_name=this.context_name;
    let  resp= await fetch_trp(TRP.Message.Command.CONTEXT_CONFIG_REQUEST,{
      context_name : context_name,
      destination_node:"hub0"
    });
    resp.layers.forEach(function(probe,index){

      $.ajax({
        url:"/trpjs/generate_chart",
        context:this,
        data:{
          models:JSON.stringify(this.jsparams.models),
          probe_id:probe.probe_id,
          auto_label:false,
          from_date:$(`#from_date_${this.randomid}`).val(),
          to_date:$(`#to_date_${this.randomid}`).val(),
          valid_input:1,
          surface:this.jsparams.surface || "LINE",
          title:this.jsparams.title || null
        },
        beforeSend:function(){
          if(index%2==0){
            var rowdiv = $("<div>",{class:"row"});
            
          }else{
            rowdiv = $(`#chart_data_${this.randomid}`).find('.row:last');
            
          }
          var coldiv = $("<div>",{class:"col-6"});

          var carddiv = $(get_card_shell());
          carddiv.addClass('border-info mt-3');
          carddiv.find(".card-header").remove();
          carddiv.append(`<h5 class='text-center card-title'>${probe.probe_id}</h4>`);
          carddiv.append($("<div>",{id:`${probe.probe_id}_${this.randomid}`}));


          coldiv.append(carddiv);
          rowdiv.append(coldiv);
          $(`#chart_data_${this.randomid}`).append(rowdiv);

          $(`#${probe.probe_id}_${this.randomid}`,"").html("<i class='fa fa-spinner fa-spin fa-fw'></i> Please wait .... Fetching data...");
        },
        success:function(resp){
          $(`#${probe.probe_id}_${this.randomid}`).html(resp);
          
        }
      });
    },this);
  
  }
}
function run(opts){
  new ProbesChart(opts).run();
}