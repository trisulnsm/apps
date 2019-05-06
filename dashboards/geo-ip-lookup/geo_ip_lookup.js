/*
  IP_ASN_PATH.JS
  geo asn path  
*/


class IPGeoAsnPath{
  constructor(opts) {
    this.dom = $(opts.divid);
    this.probe = opts.probe_id;
    this.add_form();
  }
  add_form(){
    this.form = $("<div class='row ui_form'> <div class='col-xs-12'> <form class='form-horizontal'> <div class='row'> <div class='col-xs-12'> <div class='from-group'> <label class='control-label col-xs-2'>IPs</label> <div class='col-xs-10'> <textarea name='searchipasn' rows='10'></textarea> <span class='help-block text-left'>Please enter comma(,) seperated ips or one key per line.</span> </div> </div> </div> </div> <div class='row'> <div class='col-xs-10 col-md-offset-4' style='padding-top:10px'> <input class='btn-submit' id='btn_submit' name='commit' type='submit' value='Search'> </div> </div> </form> </div> </div>");
    this.dom.append(this.form);
    this.form.submit($.proxy(this.submit_form,this));
  }
  submit_form(){
    this.reset_ui();
    this.search_ip();
    return false;
  }
  reset_ui(){
    this.dom.find(".ui_data").html('');
    this.data_dom = $("<div class='ui_data'> <div class='row'> <div class='col-xs-12'> <h3>IP ASN Path</h3> <h4 class='notify'> <i class='fa fa-spinner fa-spin'></i> Please wait....  </h4> <table class='table'> <thead> <tr> <th>IP</th> <th>ASNumber Path</th> <th>Country</th> <th>ASNumber</th> <th>Prefix</th> </tr> </thead> <tbody></tbody> </table> </div> </div> </div>");
    this.dom.append(this.data_dom);
    this.data_dom.find('.table').hide();
  }
  async search_ip(){
    //0->ASN Path,1->Country 2->ASNumber
    this.data = {};

    //this.form.find("textarea").val("1.11.0.0");
    this.ip = this.form.find("textarea").val();
    if(_.isEmpty(this.ip)){
      alert("Search ip filed can't be empty.");
      return true;
    }
    this.data[this.ip]={};
    let geo_asn_path=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :`piranha-aspath.txt ${this.ip}`,
      destination_node:this.probe
    });
    await this.resolve_asnkey("asnpath",geo_asn_path);
    
    let geo_country=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :`GeoLite2-Country-Blocks-IPv4.csv ${this.ip}`,
      destination_node:this.probe
    });
    await this.update_table_data("country",geo_country);

    let geo_asn=await fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
      tool:3,
      tool_input :`GeoLite2-ASN-Blocks-IPv4.csv  ${this.ip}`,
      destination_node:this.probe
    });
    await this.update_table_data("asn",geo_asn);
    this.draw_table()
  }
  async resolve_asnkey(name,resp){
    if (resp.tool_output.match(/NOTFOUND/)){
      this.data[this.ip][name]=[[],""];
      return true;
    }
    let key = resp.tool_output.match(/Key=(.*) Userlabel/)[1];
    let keys = key.split(/ /);
    let subnet = keys.pop();
    keys = Array.from(new Set(keys));
    let resolved_keyts=await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, {
      counter_group: GUID.GUID_CG_ASN(),
      keys:keys
    });
    let resolved_keymap = {}
    for(let i=0;i<resolved_keyts.keys.length;i++){
      let keyt = resolved_keyts.keys[i]
      resolved_keymap[keyt.key] = keyt.label
    }
    
    this.data[this.ip][name] = [keys.map(x => resolved_keymap[x]),subnet];
    
  }

  update_table_data(name,data){
   this.data[this.ip][name]="";
   let output =data.tool_output.match(/Userlabel=(.*)/);
    if(output){
      this.data[this.ip][name]=output[1];
    }

    
  }

  draw_table(){
    this.data_dom.find(".notify").remove();
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

.ui_data
  .row
    .col-xs-12
      %h3 IP ASN Path
      %h4.notify
        %i.fa.fa-spinner.fa-spin
        Please wait....
      %table.table
        %thead
          %tr
            %th IP
            %th ASNumber Path
            %th Country
            %th ASNumber
            %th Prefix
        %tbody


*/