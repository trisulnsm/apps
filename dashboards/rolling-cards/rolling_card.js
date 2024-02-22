// Skeleton program to exchange a hello TRP Request and print response 

class RollingCard {
  constructor(opts) {
    this.divid = document.querySelector(opts.divid);
    this.cg_meters_opts={};
    this.add_form(opts);
    this.card_color_array=["primary","success","info","secondary"];
    //asnumber like 16159 mapping to google
    this.ASN_TO_FA_MAPPING={"15169":"google","8075":"windows","399104":"twitter","8068":"windows",
                            "16509":"amazon","17488":"twitter","14618":"amazon","13335":"cloud","396982":"cloud"}
  }

  get_color(index){
    return this.card_color_array[index%this.card_color_array.length]

  }


  //adding the form to the document
  async add_form(opts){
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
    let meters_dropdown = this.form.querySelector('#rc_meters')
    let meter_count = this.form.querySelector('#meter_count').value
    console.log(meter_count);
    let selected_meters_value = [];
    let selected_meters_text = [];
    [...meters_dropdown.options].filter(option => option.selected).forEach(function(option){
      selected_meters_text.push(option.text);
      selected_meters_value.push(option.value);
    });
    
    //clearing the previous results
    document.getElementById('rolling_card').innerHTML = "";


    //adding slider for each meters
    selected_meters_value.forEach(async (meter, index) => {
      //fecthing the data
      let req_opts = {counter_group: selected_cguid,maxitems:meter_count || 10,meter:meter,get_meter_info:true};
      let resp = await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,req_opts);

      //creating slider template
      let owl_card_template = document.createElement('template');
      owl_card_template.innerHTML=`<div class="card fieldset border-${this.get_color(index)} mb-3">
                                    <div class="fieldset-tile bg-${this.get_color(index)} text-white "> ${selected_meters_text[index]}</div>
                                    <div class="owl-carousel" id="slider${index+1}">
                                    </div>
                                    </div>`
      
      // owl_card_template.innerHTML=`<div class="card border-${this.get_color(index)} p-0 mb-3">
      //                                 <div class='card-header pt-3'>
      //                                   <h5 class='card-title'>${selected_meters_text[index]}</h5>
      //                                 </div>
      //                                 <div class='card-body pt-0'>
      //                                   <div class="owl-carousel" id="slider${index+1}"></div>
      //                                 </div>
      //                               </div>`;
      
      //finding the meter type
      let meter_type = this.cg_meters_opts.all_meters_type[selected_cguid][meter].type;
      //adding each items in the slider
      resp.keys.forEach(topper => {
        if(topper.key=="SYS:GROUP_TOTALS"){
          return;
        }
        //calculating the bandwidth with the meter type
        let bandwidth=meter_type == 4 ? parseInt(topper.metric.low)*8 : parseInt(topper.metric.low);


      

        //creating each item in a card
        let card_item_template = document.createElement('template');
        // card_item_template.innerHTML=`<div class='item'>
        //                                 <div class="card-body d-flex align-items-center p-2 bg-${this.get_color(index)}">
        //                                 <i class="fs-4 fa fa-${this.ASN_TO_FA_MAPPING[topper.key] || 'question-circle'}"></i>                        
        //                                 <div class="flex-fill ms-3 text-truncate">
        //                                   <span class="small text-uppercase">${topper.label}</span><br>
        //                                   <div class="d-flex justify-content-between align-items-center">
        //                                     <span class="fs-6 fw-bold">${formatBW(bandwidth,1,"bps")}</span>
        //                                   </div>
        //                                 </div>
        //                               </div>
        //                               </div>`;

        card_item_template.innerHTML=`<div class="alert alert-${this.get_color(index)} rounded-4 mt-2 mb-1">
                                        <div class="d-flex align-items-center">
                                          <div class="avatar rounded no-thumbnail bg-${this.get_color(index)} text-light"><i class="fa fa-${this.ASN_TO_FA_MAPPING[topper.key] || 'question-circle'} fa-lg"></i></div>
                                          <div class="flex-fill ms-3 text-truncate">
                                            <div class="h6 mb-0">${topper.label}</div>
                                            <span class="counter_bandwidth rounded small">${formatBW(bandwidth,1,"bps").split(' ')[0]}</span><span>${formatBW(bandwidth,1,"bps").split(' ').pop()}</span>
                                          </div>
                                        </div>
                                      </div>`;

                          //<span class="bg-light text-dark px-1 rounded small">${formatBW(bandwidth,1,"bps")}</span>

        owl_card_template.content.querySelector('.owl-carousel').appendChild(card_item_template.content.firstElementChild);
        
      });
      this.data_dom.appendChild(owl_card_template.content.firstElementChild);

      
      let min_speed = 2000;
      let max_speed = 7000;
      let current_speed = Math.floor(min_speed+(max_speed-min_speed)/(selected_meters_value.length-1)*index) || min_speed
      let new_current_speed = Math.max(selected_meters_value.length*(index+1))

      console.log(current_speed);
      
      // animating the rolling cards
      $(`#slider${index+1}`).owlCarousel({
        loop:true,
        center:true,
        margin:10,
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

      $('.counter_bandwidth').counterUp({
        delay: 10,
        time:   1000,
        triggerOnce:true
        })


    });
  }
}

async function run(opts) {
  let rc = new RollingCard(opts);
}



