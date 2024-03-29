// Skeleton program to exchange a hello TRP Request and print response 

class RollingCard {
  constructor(opts) {
    this.divid = document.querySelector(opts.divid);
    this.cg_meters_opts={};
    this.topper_keys={};
    this.add_form(opts);
    this.card_color_array=["primary","success","info","secondary"];
    //asnumber like 16159 mapping to google
    this.ASN_TO_FA_MAPPING={"15169":"google","8075":"windows","399104":"twitter","8068":"windows",
                            "16509":"amazon","17488":"twitter","13414":"twitter","14618":"amazon",
                            "13335":"cloud","396982":"cloud"}
  }

  get_color(index){
    return this.card_color_array[index%this.card_color_array.length];
  }

  async load_map_assets(opts,fname){
    let js_file =opts.jsfile;
    let file_path = js_file.split("/");
    file_path.pop();
    file_path = file_path.join("/");
    let file_full_path = `/plugins/${file_path}/${fname}`;
    if(fname.match(/\.js$/)){
      await jQuery.ajax({
        url: file_full_path,
        dataType: 'script',
        async: true
      });
    }
    else{
      $('head').append(`<link rel="stylesheet" type="text/css" href="${file_full_path}">`);
    }
  }
  

  //adding the form to the document
  async add_form(opts){
    await this.load_map_assets(opts,"owl.carousel.min.js");
    load_css_file(opts);

    let html_str = await get_html_from_hamltemplate(opts);
    let template = document.createElement('template');
    template.innerHTML=html_str;
    
    this.form=template.content.children[0];
    this.divid.appendChild(this.form);
    this.data_dom=template.content.children[0];
    this.divid.appendChild(this.data_dom);

    this.load_cg_meters(opts);

    this.form.addEventListener("submit", (e) => {
      e.preventDefault();
      this.submit_form();
    });

  }

  //loading the dropdown items to the cg and meters menu
  async load_cg_meters(){
    await get_counters_and_meters_json(this.cg_meters_opts);
    let js_params = {
      meter_details:this.cg_meters_opts["all_cg_meters"],
      selected_cg : "",
      selected_st : "0",
      update_dom_cg : "rc_counter_group",
      update_dom_st : "rc_meters"
    }
    new CGMeterCombo(JSON.stringify(js_params));
  }

  


  //displaying the selected meters in the slider
  async submit_form(){
    let selected_cguid = this.form.querySelector('#rc_counter_group').value;
    let meters_dropdown = this.form.querySelector('#rc_meters');
    let meter_count = this.form.querySelector('#meter_count').value;
    let selected_meters_value = [];
    let selected_meters_text = [];
    [...meters_dropdown.options].filter(option => option.selected).forEach(function(option){
      selected_meters_text.push(option.text);
      selected_meters_value.push(option.value);
    });

    //clearing the previous results
    document.getElementById('rolling_card').innerHTML = "";


    //adding slider for each meters
    await Promise.all(selected_meters_value.map(async (meter, index) => {
      //fecthing the data
      let req_opts = {counter_group: selected_cguid,maxitems:meter_count || 10,meter:meter,get_meter_info:true};
      let resp = await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,req_opts);

      //creating slider template
      let owl_card_template = document.createElement('template');

      owl_card_template.innerHTML=`<div class="card fieldset bg-${this.get_color(index)} border-${this.get_color(index)} mb-3">
                                    <div class="fieldset-tile bg-${this.get_color(index)} text-white border rounded-pill"> ${selected_meters_text[index]}</div>
                                    <div class="owl-carousel" id="slider${index+1}">
                                    </div>
                                  </div>
                                  `;
      
      //finding the meter type
      let meter_type = this.cg_meters_opts.all_meters_type[selected_cguid][meter].type;
      let meter_units = this.cg_meters_opts.all_meters_type[selected_cguid][meter].units;


      //adding each items in the slider
      resp.keys.forEach(topper => {
        if(topper.key=="SYS:GROUP_TOTALS"){
          return;
        }
        //calculating the bandwidth with the meter type
        let bandwidth=meter_type == 4 ? parseInt(topper.metric.low)*8 : parseInt(topper.metric.low);

        //creating each item in a card
        let card_item_template = document.createElement('template');

        card_item_template.innerHTML=`<a class="topper_${topper.key.replace(/\./g, "-")}">
                                        <div class="neon alert alert-${this.get_color(index)} rounded-4 mt-2 mb-1">
                                          <div class="d-flex align-items-center">
                                            <div class="avatar rounded no-thumbnail bg-${this.get_color(index)} text-light"><i class="fa fa-${this.ASN_TO_FA_MAPPING[topper.key] || 'question-circle'} fa-lg"></i></div>
                                            <div class="flex-fill ms-3 text-truncate">
                                              <div class="h6 mb-0">${topper.label}</div>
                                              <span class="rounded small">${formatBW(bandwidth,1, meter_units)}</span>
                                            </div>
                                          </div>
                                        </div>
                                      </a>`;

        //appending item to the slider
        owl_card_template.content.querySelector('.owl-carousel').appendChild(card_item_template.content.firstElementChild);
      });//topers

      //appending slider to the web page
      this.data_dom.appendChild(owl_card_template.content.firstElementChild);

      //calculating the speed for slider
      let min_speed = 2000;
      let max_speed = 7000;
      let current_speed = Math.floor(min_speed+(max_speed-min_speed)/(selected_meters_value.length-1)*index) || min_speed;

      
      // animating the rolling cards
      $(`#slider${index+1}`).owlCarousel({
        loop:true,
        center:true,
        margin:10,
        autoplayHoverPause:true,
        dots: false,
        autoplay:true,
        autoplayTimeout: current_speed,
        autoplaySpeed: current_speed,
        touchDrag: false,
        slideTransition: 'linear',
        responsive:{
          0:{items:1},
          600:{items:3},
          1000:{items:5}
        }
      });

      //collecting the topper keys
      resp.keys.forEach(t => {
        if(!(t.key in this.topper_keys) && t.key!="SYS:GROUP_TOTALS"){
          this.topper_keys[t.key] = t.label
        }
      });

    }));//meters


    //adding event listener
    Object.keys(this.topper_keys).forEach(key => {
      document.querySelectorAll(`.topper_${key.replace(/\./g, "-")}`).forEach(element => {
        element.addEventListener('click', ()=>{
          let models = [];
          selected_meters_value.forEach(meter=>{
            models.push({counter_group:selected_cguid,meter:meter,key:key});
          });
          let queryparams = {models:JSON.stringify(models),"show_default_title": 1,"surface": "line","show_table": 1};
          new ApexChartLB(queryparams,{modal_title:`Traffic Chart - ${this.topper_keys[key]}`});
        });
      });
    });


  }//submit form

 
}//class

async function run(opts) {
  let rc = new RollingCard(opts);
}



