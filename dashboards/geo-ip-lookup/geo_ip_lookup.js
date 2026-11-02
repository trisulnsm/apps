/*
  IP_ASN_PATH.JS
  geo asn path  
*/

import {load_css_file,get_html_from_hamltemplate,mk_time_interval,load_routers_interfaces_dropdown,get_counters_and_meters_json,fetch_trp} from "trp_base";

const IP_EXTRACT_REGEX = /(?:(?:25[0-5]|2[0-4]\d|[01]?\d{1,2})(?:\.(?:25[0-5]|2[0-4]\d|[01]?\d{1,2})){3}(?:\/(?:3[0-2]|[12]?\d))?|(?:(?:[a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}|(?:[a-fA-F0-9]{1,4}:){1,6}:[a-fA-F0-9]{1,4}|(?:[a-fA-F0-9]{1,4}:){1,5}(?::[a-fA-F0-9]{1,4}){1,2}|(?:[a-fA-F0-9]{1,4}:){1,4}(?::[a-fA-F0-9]{1,4}){1,3}|(?:[a-fA-F0-9]{1,4}:){1,3}(?::[a-fA-F0-9]{1,4}){1,4}|(?:[a-fA-F0-9]{1,4}:){1,2}(?::[a-fA-F0-9]{1,4}){1,5}|[a-fA-F0-9]{1,4}:(?::[a-fA-F0-9]{1,4}){1,6}|:(?:(?::[a-fA-F0-9]{1,4}){1,7}|:)|(?:[a-fA-F0-9]{1,4}:){1,7}:)(?:\/(?:12[0-8]|1[0-1]\d|[1-9]?\d))?)/g;

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
  extract_ips(text){
    const ips = [];
    const seen = new Set();
    for (const match of text.matchAll(IP_EXTRACT_REGEX)) {
      const ip = match[0];
      if (!seen.has(ip)) {
        seen.add(ip);
        ips.push(ip);
      }
    }
    return ips;
  }
  lookup_host(ip){
    return ip.split("/")[0];
  }
  async get_geoserver_endpoint(){
    if (!window.default_geo_id) return null;
    const cfg = await fetch_trp(TRP.Message.Command.NODE_CONFIG_REQUEST, {
      destination_node: window.default_geo_id,
      query_config: [{ name: "//GeoServer/ZmqConnection" }]
    });
    if (!cfg || !cfg.config_values) return null;
    const entry = cfg.config_values.find(nv => nv.name == "//GeoServer/ZmqConnection");
    return (entry && entry.value) ? entry.value : null;
  }
  format_as_path(aspath){
    if (!aspath || !aspath.length) return "";
    return aspath.map(hop => {
      if (hop.ascode) return `${hop.asn} (${hop.ascode})`;
      return String(hop.asn);
    }).join(" ");
  }
  collect_result_rows(ips, geoDetails, bgpRoutes){
    const geoByHost = {};
    for (const detail of geoDetails || []) {
      if (detail && detail.ipaddress) geoByHost[detail.ipaddress] = detail;
    }
    const bgpByHost = {};
    for (const route of bgpRoutes || []) {
      if (!route || !route.input) continue;
      if (!bgpByHost[route.input]) bgpByHost[route.input] = [];
      bgpByHost[route.input].push(route);
    }
    return ips.map(ip => {
      const host = this.lookup_host(ip);
      const routes = bgpByHost[host] || [];
      return {
        ip,
        geo: geoByHost[host] || {},
        bgp_prefix: routes.map(r => r.prefix).filter(Boolean).join(", "),
        as_path: routes.map(r => this.format_as_path(r.aspath)).filter(Boolean).join(", ")
      };
    });
  }
  build_results_table(ips, geoDetails, bgpRoutes){
    const table = $("<table>", {class: "table table-hover table-sysdata"});
    const thead = $("<thead>").append(
      $("<tr>").append(
        $("<th>").text("IP"),
        $("<th>").text("Country"),
        $("<th>").text("Country Name"),
        $("<th>").text("ASN"),
        $("<th>").text("ASN Name"),
        $("<th>").text("BGP Prefix"),
        $("<th>").text("AS Path")
      )
    );
    const tbody = $("<tbody>");
    const rows = this.collect_result_rows(ips, geoDetails, bgpRoutes);
    for (const row of rows) {
      const geo = row.geo || {};
      tbody.append(
        $("<tr>").append(
          $("<td>").text(row.ip),
          $("<td>").text(geo.country_code || "-"),
          $("<td>").text(geo.country_name || "-"),
          $("<td>").text(geo.asn_code || "-"),
          $("<td>").text(geo.asn_name || "-"),
          $("<td>").text(row.bgp_prefix || "-"),
          $("<td>").text(row.as_path || "-")
        )
      );
    }
    table.append(thead, tbody);
    return table;
  }
  render_results_table(geo_resp, bgp_resp){
    const results = this.data_dom.find(".query_results");
    results.empty();
    const wrapper = $("<div>", {class: "table-responsive"});
    const table = this.build_results_table(
      this.ips,
      geo_resp && geo_resp.details,
      bgp_resp && bgp_resp.routes
    );
    wrapper.append(table);
    results.append(wrapper);
    if (typeof table.tablesorter === "function") {
      table.tablesorter();
    }
  }
  async search_ip(){
    this.data = {};
    const raw_text = this.form.find("textarea").val();
    if(_.isEmpty(raw_text)){
      console.log("Search ip field can't be empty.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    this.ips = this.extract_ips(raw_text);
    if(_.isEmpty(this.ips)){
      console.log("No IPv4, IPv6, or CIDR subnets found in the pasted text.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    for(let i=0; i < this.ips.length ; i ++){
      this.data[this.ips[i]] = {}
    }
    const hosts = this.ips.map(ip => this.lookup_host(ip));
    const geoserver_endpoint = await this.get_geoserver_endpoint();
    if (!geoserver_endpoint) {
      console.log("Geo server is not available.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    const [geo_data, bgp_data] = await Promise.all([
      fetch_trp(TRP.Message.Command.IP_LOOKUP_REQUEST, {
        IPList: hosts,
        zmq_endpoint: geoserver_endpoint
      }),
      fetch_trp(TRP.Message.Command.BGP_QUERY_REQUEST, {
        query_type: TRP.BGPQueryRequest.QueryType.BEST_MATCH,
        prefixes: hosts,
        zmq_endpoint: geoserver_endpoint
      })
    ]);
    this.data_dom.find("#geo_bgp_lookup").find(".animated-background").remove();
    if (!geo_data || geo_data.error_message) {
      console.log((geo_data && geo_data.error_message) || "Geo lookup failed.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    const bgp_error = bgp_data && (bgp_data.error || bgp_data.error_message);
    if (bgp_error) {
      console.log(bgp_error);
    }
    this.render_results_table(geo_data, bgp_error ? null : bgp_data);
  }


  
 
}
export function run(opts){
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
              %span.help-block.text-left Paste any text; IPv4, IPv6, and CIDR subnets are extracted automatically.
      .row
        .col-xs-10.col-md-offset-4{style:"padding-top:10px"}
          %input.btn-submit{id:"btn_submit",name:"commit",type:"submit",value:"Search"}
*/

/*




*/