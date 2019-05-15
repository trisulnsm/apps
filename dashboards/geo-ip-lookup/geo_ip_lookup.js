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
    this.data_dom = $("<div class='ui_data'> <div class='row'> <div class='col-xs-12'> <h3>IP Lookup</h3> <h4 class='notify'> <i class='fa fa-spinner fa-spin'></i> Please wait....  </h4> <table class='table'> <thead> <tr> <th>IP</th> <th>ASNumber Path</th> <th>Country</th> <th>ASNumber</th> <th>Prefix</th> </tr> </thead> <tbody></tbody> </table> </div> <div class='col-xs-12'> <h4>Map Visualization</h4> <h4 class='nofity'> <i class='fa fa-spinner fa-spin'></i> Please wait ....  </h4> <div class='jvector_map' style='height:500px'></div> </div> </div> </div>");
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
    this.geo_map();
  } 
 async geo_map(){
    let markers = [];
    let palette = [].concat.apply([], [d3.schemeCategory10,d3.schemeCategory20,d3.schemeCategory20b,d3.schemeCategory20c]);
    let colors = {};
    for (var k in this.data) { 
      let url = "http://ip-api.com/json/" + k;
      await $.getJSON(url, null, $.proxy(function (data) {
        markers.push({latLng:[data.lat,data.lon],name:k,offsets:[0, 2]});
        var region_key = `${data.countryCode}-${data.region}`;
        colors[region_key]=palette[Math.floor(Math.random()*palette.length)];
      },this))
    }

    let map_div =  this.data_dom.find(".jvector_map");
    map_div.css({height:"500px"});
    let map = new jvm.Map({ map: 'in_mill',
                            container:map_div,
                            backgroundColor: null,
                            regionStyle:{
                              initial: {
                                fill: '#8d8d8d',
                              }
                            },
                            scaleColors: ['#C8EEFF', '#0071A4'],
                            normalizeFunction: 'polynomial',
                            hoverOpacity: 0.7,
                            hoverColor: false,
                            markers:markers,
                            markerStyle: {
                              initial: {
                                fill: '#F8E23B',
                                stroke: '#383f47'
                              }
                            },  
                            series: {
                              regions: [{
                                attribute: 'fill',
                              }]
                            },
                            labels: {
                              markers: {
                                render: function(index){
                                  return markers[index].name;
                                },
                                offsets: function(index){
                                  var offset = markers[index]['offsets'] || [0, 0];
                                  return [offset[0] - 7, offset[1] + 3];
                                }
                              }
                            },
                            onRegionClick: function (event, code) {
                              console.log(code);
                            },
                          });
     map.series.regions[0].setValues(colors);
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
      %h3 IP Lookup
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
    .col-xs-12
      %h4 Map Visualization
      %h4.nofity
        %i.fa.fa-spinner.fa-spin
        Please wait ....
      .jvector_map{style:"height:500px"}


*/