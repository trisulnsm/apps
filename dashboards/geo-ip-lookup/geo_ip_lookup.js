/*
  IP_ASN_PATH.JS
  geo asn path  
*/


class IPGeoAsnPath{
  constructor(opts) {
    this.dom = $(opts.divid);
    this.probe = opts.probe_id;
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
    this.dom.append(this.form);
    this.form.submit($.proxy(this.submit_form,this));
  }
  submit_form(){
    this.reset_ui();
    this.search_ip();
    return false;
  }
  reset_ui(){
    this.dom.find(".ui_data").remove();
    this.data_dom = $(this.haml_dom[1]).clone();
    this.dom.append(this.data_dom);
    this.data_dom.find('.table').hide();
  }
  async search_ip(){
    this.data = {};
    //this.form.find("textarea").val("103.27.170.80,103.77.108.224,103.225.124.20,103.88.156.62");
    this.ips = this.form.find("textarea").val();
    if(_.isEmpty(this.ips)){
      alert("Search ip filed can't be empty.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    this.ips = this.ips.split(/\n|,/);
    for(let i=0; i < this.ips.length ; i ++){
      this.data[this.ips[i]] = {}
    }
    let query_text = this.ips.join(" ");
    let data=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :query_text,
      destination_node:this.probe
    });
    this.data_dom.find(".animated-background").remove();
    this.dom.find(".ui_data").find(".query_output").html(data.tool_output)
  }

  
 
}
function run(opts){
  new IPGeoAsnPath(opts)
}

//# sourceURL=ip_geo_asn_path.js


//HAML PART
/*
.row.ui_form
  .col-xs-12
    %form.form-horizontal
      .row
        .col-xs-12
          .from-group
            %label.control-label.col-xs-2 IPs
            .col-xs-10
              %textarea{name:"searchipasn",rows:10}
              %span.help-block.text-left Please enter comma(,) seperated ips or one key per line.
      .row
        .col-xs-10.col-md-offset-4{style:"padding-top:10px"}
          %input.btn-submit{id:"btn_submit",name:"commit",type:"submit",value:"Search"}
*/

/*




*/