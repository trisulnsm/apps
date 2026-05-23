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
  parse_geo_output(text){
    const byIp = {};
    for (const line of text.split(/\r?\n/)) {
      if (!line.trim()) continue;
      const cols = line.split("\t");
      if (cols.length < 3) continue;
      const type = cols[0].trim();
      const ip = cols[1].trim();
      if (!byIp[ip]) byIp[ip] = {};
      if (type.includes("ASN-Blocks")) {
        if (cols[2] && cols[2] !== "-") byIp[ip].asn = cols[2];
        if (cols[3]) byIp[ip].asn_name = cols[3];
        if (cols[4]) byIp[ip].organization = cols[4];
      } else if (type.includes("Country-Blocks")) {
        if (cols[2]) byIp[ip].country_code = cols[2];
        byIp[ip].country = cols[4] || cols[3] || "";
      }
    }
    return byIp;
  }
  normalize_ip(ip){
    return ip.split("/")[0].toLowerCase();
  }
  matches_ip_block(blockIp, queryIp){
    const block = this.normalize_ip(blockIp);
    const query = this.normalize_ip(queryIp);
    if (block === query) return true;
    if (query.startsWith(block)) return true;
    if (block.endsWith("::")) {
      const blockPrefix = block.slice(0, -1);
      if (query.startsWith(blockPrefix)) return true;
    }
    return false;
  }
  find_map_key(map, queryIp){
    if (map[queryIp]) return queryIp;
    const queryNorm = this.normalize_ip(queryIp);
    for (const key of Object.keys(map)) {
      if (this.normalize_ip(key) === queryNorm) return key;
    }
    for (const key of Object.keys(map)) {
      if (this.matches_ip_block(key, queryIp) || this.matches_ip_block(queryIp, key)) return key;
    }
    return null;
  }
  collect_result_rows(ips, geoMap, bgpMap){
    const rows = [];
    const usedGeoKeys = new Set();
    const usedBgpKeys = new Set();

    for (const ip of ips) {
      const geoKey = this.find_map_key(geoMap, ip);
      const bgpKey = this.find_map_key(bgpMap, ip);
      if (geoKey) usedGeoKeys.add(geoKey);
      if (bgpKey) usedBgpKeys.add(bgpKey);
      rows.push({
        ip,
        geo: geoKey ? geoMap[geoKey] : {},
        bgp: bgpKey ? bgpMap[bgpKey] : {}
      });
    }

    for (const geoKey of Object.keys(geoMap)) {
      if (usedGeoKeys.has(geoKey)) continue;
      const bgpKey = this.find_map_key(bgpMap, geoKey);
      if (bgpKey) usedBgpKeys.add(bgpKey);
      rows.push({
        ip: geoKey,
        geo: geoMap[geoKey],
        bgp: bgpKey ? bgpMap[bgpKey] : {}
      });
    }

    for (const bgpKey of Object.keys(bgpMap)) {
      if (usedBgpKeys.has(bgpKey)) continue;
      rows.push({
        ip: bgpKey,
        geo: {},
        bgp: bgpMap[bgpKey]
      });
    }

    return rows;
  }
  parse_bgp_output(text){
    const byIp = {};
    for (const line of text.split(/\r?\n/)) {
      if (!line.trim()) continue;
      const cols = line.split("\t");
      if (cols.length < 2) continue;
      const ip = cols[0].trim();
      byIp[ip] = {
        bgp_prefix: cols[1] || "",
        as_path: cols[2] || "",
        as_codes: cols[3] || ""
      };
    }
    return byIp;
  }
  build_results_table(ips, geoMap, bgpMap){
    const table = $("<table>", {class: "table table-hover table-sysdata"});
    const thead = $("<thead>").append(
      $("<tr>").append(
        $("<th>").text("IP"),
        $("<th>").text("Country"),
        $("<th>").text("Country Name"),
        $("<th>").text("ASN"),
        $("<th>").text("ASN Name"),
        $("<th>").text("Organization"),
        $("<th>").text("BGP Prefix"),
        $("<th>").text("AS Path")
      )
    );
    const tbody = $("<tbody>");
    const rows = this.collect_result_rows(ips, geoMap, bgpMap);
    for (const row of rows) {
      const geo = row.geo || {};
      const bgp = row.bgp || {};
      tbody.append(
        $("<tr>").append(
          $("<td>").text(row.ip),
          $("<td>").text(geo.country_code || "-"),
          $("<td>").text(geo.country || "-"),
          $("<td>").text(geo.asn || "-"),
          $("<td>").text(geo.asn_name || "-"),
          $("<td>").text(geo.organization || "-"),
          $("<td>").text(bgp.bgp_prefix || "-"),
          $("<td>").text(bgp.as_path || "-")
        )
      );
    }
    table.append(thead, tbody);
    return table;
  }
  render_results_table(geo_output, bgp_output){
    const geoMap = this.parse_geo_output(geo_output || "");
    const bgpMap = this.parse_bgp_output(bgp_output || "");
    const results = this.data_dom.find(".query_results");
    results.empty();
    const wrapper = $("<div>", {class: "table-responsive"});
    const table = this.build_results_table(this.ips, geoMap, bgpMap);
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
      alert("Search ip field can't be empty.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    this.ips = this.extract_ips(raw_text);
    if(_.isEmpty(this.ips)){
      alert("No IPv4, IPv6, or CIDR subnets found in the pasted text.");
      this.dom.find(".ui_data").remove();
      return true;
    }
    for(let i=0; i < this.ips.length ; i ++){
      this.data[this.ips[i]] = {}
    }
    let query_text = this.ips.join(" ");
    const [geo_data, bgp_data] = await Promise.all([
      fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
        tool:3,
        tool_input :`--tsv --no-banner -d ${query_text}`,
        destination_node:this.probe
      }),
      fetch_trp(TRP.Message.Command.RUNTOOL_REQUEST, {
        tool:5,
        tool_input :`-t -d -B -p ${query_text}`,
        destination_node:this.probe
      })
    ]);
    this.data_dom.find("#geo_bgp_lookup").find(".animated-background").remove();
    this.render_results_table(geo_data.tool_output, bgp_data.tool_output);
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