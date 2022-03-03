/*
  // File Name   : key_space_explorer.js
  // Author      : Unleash Networks
  // Version     : 0.1
  // Description : Check the usage activity for selected time
*/

class KeySpaceExplorer{
  constructor(opts) {
    this.dom = $(opts.divid);
    this.rand_id=parseInt(Math.random()*100000);
    this.default_selected_time = opts.new_time_selector;
    this.tzadj = window.trisul_tz_offset  + (new Date()).getTimezoneOffset()*60 ;
    this.add_form(opts);

  }
   // load the frame 
  async load_assets(opts)
  {
    // load app.css file
    load_css_file(opts);
    // load template.haml file 
    let html_str = await get_html_from_hamltemplate(opts);
    this.haml_dom =$(html_str)
  }
  async add_form(opts){

    await this.load_assets(opts)
    this.form = $(this.haml_dom[0]);
    this.form.find("select[name*='countergroup']").attr("id","cg_"+this.rand_id);
    this.form.find("textarea[name*='searchkey']").attr("id","keys_"+this.rand_id);
    this.form.find(".new_time_selector").attr("id","new_time_selector_"+this.rand_id);
    this.form.find("input[name*='from_date']").attr("id","from_date_"+this.rand_id);
    this.form.find("input[name*='to_date']").attr("id","to_date_"+this.rand_id);
    this.dom.append(this.form);
    //new time selector 
    let  update_ids = "#from_date_"+this.rand_id+","+"#to_date_"+this.rand_id;
    new ShowNewTimeSelector({divid:"#new_time_selector_"+this.rand_id,
                              update_input_ids:update_ids,
                              default_ts:this.default_selected_time,
                              add_class:"pull-right"
                            });
    this.form.submit($.proxy(this.submit_form,this));
    this.cg_meters = {};
    await get_counters_and_meters_json(this.cg_meters);
    let  js_params = {meter_details:this.cg_meters.all_cg_meters,
      selected_cg : GUID.GUID_CG_INTERNAL_HOSTS(),
      selected_st : "0",
      update_dom_cg : "cg_"+this.rand_id,
      update_dom_st : "hm_meter_id"    
    }
    new CGMeterCombo(JSON.stringify(js_params));
  }
  reset_ui(){
    this.dom.find(".ui_data").remove();
    this.data_dom =$(this.haml_dom[1]).clone();
    this.data_dom.find(".progress_bar").attr("id","pg_bar_"+this.rand_id);
    this.dom.append(this.data_dom);
    this.tint_arr = [];

  }
   submit_form(){
    this.reset_ui();
    this.load_tint_array();
    this.tris_pg_bar = new TrisProgressBar({max:this.tint_arr.length,
                                            divid:"pg_bar_"+this.rand_id,
                                            slim: true });
    this.get_usage_data();
    return false;
  }
  load_tint_array(){
    let start_date = moment($('#from_date_'+this.rand_id).val());
    let end_date = moment($('#to_date_'+this.rand_id).val());
    start_date = start_date.startOf('day');
    end_date = end_date.endOf('day');
    let days = end_date.diff(start_date,'days')+1;
    for(let i=0; i <days ; i++){
      let s = start_date.clone().add(i,'day');
      let e = s.clone().endOf('day');
      var fromTS = parseInt((new Date(s.toString()).getTime()/1000)-this.tzadj);
      var toTS = parseInt((new Date(e.toString()).getTime()/1000)-this.tzadj);
      this.tint_arr.push([mk_time_interval([fromTS,toTS]),s]);
    }
  }
  async get_usage_data(){
    let keys = $('#keys_'+this.rand_id).val();
    keys = keys.split(/\n|,/);
    let keyspaces = [];
    for(let i =0 ; i< keys.length; i++){
      let fk = keys[i];
      let tk = keys[i];
      if(fk.match(/~/)){
        fk  = fk.split("~")[0];
        tk  = tk.split("~")[1];
      }
      let from_keyt = TRP.KeyT.create();
      from_keyt.label = fk;
      let to_keyt = TRP.KeyT.create();
      to_keyt.label=tk;
      let key_space = TRP.KeySpaceRequest.KeySpace.create();
      key_space.from_key = from_keyt;
      key_space.to_key = to_keyt;
      keyspaces.push(key_space)
    }
    for(let i = 0 ;i < this.tint_arr.length ; i++){
     let tint = this.tint_arr[i];
      let resp=await fetch_trp(TRP.Message.Command.KEYSPACE_REQUEST, {
        counter_group: $('#cg_'+this.rand_id).val(),
        time_interval:tint[0] ,
        spaces:keyspaces,
        maxitems:1000
      });
      this.tris_pg_bar.update_progress_bar();
      this.update_table(resp,tint)
    }
  }
  update_table(resp,tint){
    let tr = $("<tr>");
    let t = tint[1].format('LL');
    tr.append(`<td>${t}</td>`);
    let ul = $('<ul>',{class:"list-inline"});
    for(let i=0; i< resp.hits.length;i++){
      let keyt = resp.hits[i];
      let readable = keyt.readable;
      if(readable != keyt.label && keyt.label.length > 0){
        readable = `${readable}(${keyt.label})`
      }
      let params =$.param({dash_key:"retrotools",guid:$('#cg_'+this.rand_id).val(),
                          key:keyt.key,statid:0,
                          window_fromts:tint[0].from.tv_sec,
                          window_tots:tint[0].to.tv_sec
                          });
      ul.append(`<li><a href="/newdash/index?${params}" target="_blank">${readable}<a></li>`);
    }
    let td = $("<td>").append(ul);
    tr.append(td)
    tr.append(`<td>${resp.hits.length}</td>`)
    this.data_dom.find("table").find("tbody").append(tr)

  }
}

function run(opts){
  new KeySpaceExplorer(opts)
}

//# sourceURL=key_space_explorer.js
