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
    //0->ASN Path,1->Country 2->ASNumber
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
    let geo_asn_path=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :`piranha-aspath.txt ${query_text}`,
      destination_node:this.probe
    });
    await this.resolve_asnkey("asnpath",geo_asn_path);
    
    let geo_country=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :`GeoLite2-Country-Blocks-IPv4.csv ${query_text}`,
      destination_node:this.probe
    });
    await this.update_table_data("country",geo_country);

    let geo_asn=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :`GeoLite2-ASN-sBlocks-IPv4.csv  ${query_text}`,
      destination_node:this.probe
    });
    await this.update_table_data("asn",geo_asn);
    this.draw_table();
  }
  async resolve_asnkey(name,resp){

    
    let tool_output = resp.tool_output.split("\n");
    let unresolved_keys = [];
    for(var i=0 ; i < tool_output.length-1;i++){
      this.data[this.ips[i]][name]=[[],""];
      if (! tool_output[i].match(/NOTFOUND/)){
        let key = tool_output[i].match(/Key=(.*) Userlabel/)[1];
        let keys = key.split(/ /);
        let subnet = keys.pop();
        keys = Array.from(new Set(keys));
        this.data[this.ips[i]][name]=[keys,subnet];
        for(let j=0; j < keys.length ; j++){
          if(! unresolved_keys.includes(keys[j])){
            unresolved_keys.push(keys[j])
          }
        }
      }
    }
   
    let resolved_keyts=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, {
      counter_group: GUID.GUID_CG_ASN(),
      keys:unresolved_keys
    });
    let resolved_keymap = {}
    for(let i=0;i<resolved_keyts.keys.length;i++){
      let keyt = resolved_keyts.keys[i]
      resolved_keymap[keyt.key] = keyt.label
    }
    for(var i=0 ; i < this.ips.length;i++){
      let data = this.data[this.ips[i]][name];
      let keys = data[0].map(x => resolved_keymap[x]);
      data[0] = keys;
    }
    
  }

  update_table_data(name,data){
   let tool_output = data.tool_output.split("\n");
    for(var i=0 ; i < tool_output.length-1;i++){
      this.data[this.ips[i]][name]="";
      let output =tool_output[i].match(/Userlabel=(.*)/);
        if(output){
        this.data[this.ips[i]][name]=output[1];
      }
    }
  }

  draw_table(){
    this.data_dom.find(".animated-background").remove();
    let table = this.data_dom.find("table");
    table.show();
    table.addClass('table table-sysdata');
    for (var k in this.data) {
      let tr = $("<tr>");
      tr.append(`<td>${k}</td>`);
      let asn_path = this.data[k]["asnpath"][0];
      let ul =$("<ul>",{class:"list-inline piped"});
      let li = asn_path.map(x => `<li>${x}</li>`);
      ul.append(li.join(""));
      tr.append($("<td>").append(ul));
      tr.append(`<td>${this.data[k]["country"]}</td>`)
      tr.append(`<td>${this.data[k]["asn"]}</td>`)
      tr.append(`<td>${this.data[k]["asnpath"][1]}</td>`)
      table.append(tr);
    }
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