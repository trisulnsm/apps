class MulticastView {
  constructor(opts) {
    this.divid = document.querySelector(opts.divid);
    this.containerId = "multicast-diagram-container";
    this.expandTabId = "expand-tab";
    this.collapseTabId = "collapse-tab";
    this.baseWidth = 1200;
    this.baseHeight = 200;
    this.diagrams = [];
    this.multicast_mode = false;
    this.setup(opts);
  }

  async setup(opts) {
    await this.addForm(opts);
    this.container = document.getElementById(this.containerId);
    this.expandTab = document.getElementById(this.expandTabId);
    this.collapseTab = document.getElementById(this.collapseTabId);
  }

  async addForm(opts) {
    const htmlStr = await get_html_from_hamltemplate(opts);
    const template = document.createElement('template');
    template.innerHTML = htmlStr;
    this.form = template.content.children[0];
    this.data_dom = template.content.children[0];
    this.divid.appendChild(this.form);
    this.divid.appendChild(this.data_dom);


    //loadonly crosskey counter groups
    this.cg_meters={};
    await get_counters_and_meters_json(this.cg_meters);

    //only crosskey guid
    let all_crosskey_cgguids = Object.keys(this.cg_meters.crosskey)
    let guid_with_meters ={}
    let cthis = this;

    _.forEach(this.cg_meters.all_cg_meters, function(v, k) {
      if (all_crosskey_cgguids.includes(k) && cthis.cg_meters.crosskey[k][3].length != 0) {        
        guid_with_meters[k] = v;
      }
    });

    this.exchange_xflow_guid = "{942AB99F-7A65-4B2E-6F6C-A3050F0F7B35}";

    // add Exchange XFlow guid
    if(this.cg_meters.all_cg_meters[this.exchange_xflow_guid]){
      guid_with_meters[this.exchange_xflow_guid] = ["Exchange XFlow",[[2,"Multicast"]]]
    }
    
    let js_params = {
      meter_details:guid_with_meters,
      selected_cg : "",
      selected_st : "0",
      update_dom_cg : "cgguid",
      update_dom_st : "meters"
    }
    new CGMeterCombo(JSON.stringify(js_params));

    // set last 1 hrs in time selector
    let total_time = await fetch_trp(TRP.Message.Command.TIMESLICES_REQUEST,{get_total_window:true});
    let default_ts = {
      start_date:new Date((total_time.total_window.to.tv_sec.toNumber()-3600)*1000),
      end_date:new Date((total_time.total_window.to.tv_sec.toNumber()*1000))
    }

    new ShowNewTimeSelector({divid: "#new_time_selector",update_input_ids: "#from_date,#to_date",default_ts: default_ts,send_recentsecs:true});
    show_hide_form();


    document.getElementById("multicast_search_form").addEventListener("submit", async (e) => {
      e.preventDefault();
      this.container.innerHTML = "";
      this.diagrams = [];
      this.setupTabListeners();
      await this.init();
      document.querySelector("#show_hide_btn a").click();
      document.getElementById("result_div").classList.remove("hide");
    });
  }


  async init() {
    this.cg_meters = {};
    this.selected_guid = document.getElementById("cgguid").value;
    let selected_meters = document.getElementById("meters").value;
    this.multicast_mode = this.selected_guid === this.exchange_xflow_guid;

    this.selected_key = document.getElementById("key_filter").value.trim();
    if(! this.multicast_mode){
      this.selected_key = convert_to_key_format(this.selected_key);
    }

    this.time_interval = mk_time_interval({
      from_date: document.getElementById("from_date").value,
      to_date: document.getElementById("to_date").value
    });

    const xflow_resp = await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: this.selected_guid,
      meter: selected_meters,
      time_interval: this.time_interval,
      key_filter: this.selected_key ,
      maxitems: 1000
    });

    this.cginfo= await fetch_trp(TRP.Message.Command.COUNTER_GROUP_INFO_REQUEST);

    // this.multicast_hosts_guid = "{CD2F4C1D-688F-4B7C-AF50-A92B2280BF16}";

    let multicast_hosts_guid;

    await get_counters_and_meters_json(this.cg_meters);
    
    if(this.multicast_mode) {
      multicast_hosts_guid = "{CD2F4C1D-688F-4B7C-AF50-A92B2280BF16}"
    } else {
      multicast_hosts_guid = this.cginfo.group_details.find( (item) => item.guid==this.selected_guid).crosskey.crosskeyguid_1
    }
    
    this.multipliers = get_multipliers(this.cg_meters, multicast_hosts_guid , 0);

    let multicast_hosts_resp = await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: multicast_hosts_guid,
      meter: 0,
      time_interval: this.time_interval,
      maxitems: 5000
    });

    var multicastList = xflow_resp.keys
    .filter(t => {
      const count = (t.label.match(/\\/g) || []).length;
      return count >= 2 && count <= 3;
    })
      .reduce((list, t) => {
        let sender, receiver, multicast_ip, port;
        const parts = t.label.split("\\");
        
        if (parts.length === 4) {
          [receiver, sender, port, multicast_ip] = parts;
        } else if (parts.length === 3) {
          [sender, multicast_ip, receiver] = parts;
          port = null;
        }
        
        let entry = list.find(e => e.multicast_ip === multicast_ip);
        if (!entry) {
          let multicast_host = multicast_hosts_resp.keys.find(k => k.label === multicast_ip);

          // If no multicast host found, skip this entry
          if(!multicast_host) {return list;}
          
          entry = {
            multicast_ip,
            port,
            senders: [],
            receivers: [],
            metrics: {
              volume: h_fmtvol(multicast_host.metric * this.multipliers.topper_bucketsize),
              max: h_fmtbw(multicast_host.metric_max * this.multipliers.bits_multiplier),
              min: h_fmtbw(multicast_host.metric_min * this.multipliers.bits_multiplier),
              avg: h_fmtbw(multicast_host.metric_avg * this.multipliers.bits_multiplier)
            }
          };

          list.push(entry);
        }
        if (!entry.senders.includes(sender)) entry.senders.push(sender);
        if (!entry.receivers.includes(receiver)) entry.receivers.push(receiver);
        return list;
      }, []);
    
    multicastList.sort((a, b) => human_to_volume(b.metrics.volume) - human_to_volume(a.metrics.volume));

    // Filter out the given key
    multicastList = multicastList.filter(item => item.multicast_ip.startsWith(document.getElementById("key_filter").value.trim()));

    document.getElementById("total-multicast-count").textContent = multicastList.length;
    document.getElementById("duration").innerHTML = `<b>Selected Time Frame: </b>${fmt_ts(this.time_interval.from.tv_sec).replace(/\s[A-Z]+$/, '')} To ${fmt_ts(this.time_interval.to.tv_sec).replace(/\s[A-Z]+$/, '')} </br> </br> `
    multicastList.forEach((m, i) => this.container.appendChild(this.createCard(m, i)));
  }

  setupTabListeners() {
    this.expandTab.addEventListener("click", e => {
      e.preventDefault();
      this.diagrams.forEach(d => d.setVisibility(true, true));
      this.setActiveTab(this.expandTabId);
    });
    this.collapseTab.addEventListener("click", e => {
      e.preventDefault();
      this.diagrams.forEach(d => d.setVisibility(false, false));
      this.setActiveTab(this.collapseTabId);
    });
    this.collapseTab.classList.add("active")
    this.expandTab.classList.remove("active")
  }

  setActiveTab(id) {
    [this.expandTab, this.collapseTab].forEach(tab => {
      const active = tab.id === id;
      tab.classList.toggle("active", active);
      tab.setAttribute("aria-selected", active);
      tab.tabIndex = active ? 0 : -1;
    });
  }

  createCard({ multicast_ip, port, senders, receivers, metrics }, index) {
    const wrapper = document.createElement("div");
    wrapper.className = `multicast_${index}`;
    wrapper.style.width = "100%";

    const card = document.createElement("div");
    card.className = "card mb-3 py-1";


    card.appendChild(wrapper);
    let metrics_str = `Max: ${metrics.max},  Min: ${metrics.min},  Avg: ${metrics.avg},  Volume: ${metrics.volume}`;
    // const diagram = new this.Diagram(wrapper, multicast_ip, port, senders, receivers, metrics_str, this.time_interval);
    let multicast_hosts_guid = "{CD2F4C1D-688F-4B7C-AF50-A92B2280BF16}"
    let host_x_multicast_guid = "{84EC1A12-E77D-4299-87B1-50FC6FDB3F2B}"
    let senders_guid, receivers_guid;

    if(this.multicast_mode) {
      senders_guid = host_x_multicast_guid;
      receivers_guid = host_x_multicast_guid;
    } else {
      let crosskey = this.cginfo.group_details.find( (item) => item.guid==this.selected_guid).crosskey
      senders_guid = crosskey.parentguid;
      multicast_hosts_guid = crosskey.crosskeyguid_1
      receivers_guid = crosskey.crosskeyguid_2;
    }
    let opts = { 
      container: wrapper,
      multicastIP: multicast_ip,
      port: port,
      senders: senders,
      receivers: receivers,
      metricsStr: metrics_str,
      time_interval: this.time_interval,
      senders_guid: "",
      receivers_guid: "",
      senders_guid: senders_guid,
      receivers_guid: receivers_guid,
      multicast_hosts_guid: multicast_hosts_guid,
      multicast_mode: this.multicast_mode
    }
    const diagram = new this.Diagram(opts);

    this.diagrams.push(diagram);
    return card;
  }

  Diagram = class {
    constructor(opts) {
      this.container = opts.container;
      this.multicastIP = opts.multicastIP;
      this.port = opts.port || null ;
      this.senders = opts.senders;
      this.receivers = opts.receivers;
      this.metricsStr = opts.metricsStr;
      this.time_interval = opts.time_interval;
      this.senders_guid = opts.senders_guid;
      this.receivers_guid = opts.receivers_guid;
      this.multicast_hosts_guid = opts.multicast_hosts_guid;
      this.multicast_mode = opts.multicast_mode;
      this.senderVisible = false;
      this.receiverVisible = false;

      this.baseWidth = 1200;
      this.baseHeight = 100;
      // this.multicast_hosts_guid = "{CD2F4C1D-688F-4B7C-AF50-A92B2280BF16}"
      this.host_x_multicast_guid = "{84EC1A12-E77D-4299-87B1-50FC6FDB3F2B}"

      this.svg = d3.select(this.container).append("svg")
        .attr("viewBox", `0 0 ${this.baseWidth} ${this.baseHeight}`)
        .attr("preserveAspectRatio", "xMidYMid meet")
        .style("width", "100%").style("height", "auto");
      this.senderGroup = this.svg.append("g");
      this.receiverGroup = this.svg.append("g");
      this.draw(this.multicastIP, this.port, this.metricsStr);
      window.addEventListener("resize", () => this.updateHeight());
    }

    draw(multicastIP, port, metricsStr) {
      const [cx, cy] = [this.baseWidth / 2, 2];
      this.svg.append("defs").html(`
        <linearGradient id="multicastGradient" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#66bb6a"/>
          <stop offset="100%" stop-color="#388e3c"/>
        </linearGradient>
        <filter id="boxShadow">
          <feDropShadow dx="1.5" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.25"/>
        </filter>
        <marker id="arrow" viewBox="0 -5 10 10" refX="10" refY="0" markerWidth="6" markerHeight="6" orient="auto">
          <path d="M0,-5L10,0L0,5" fill="#555"/>
        </marker>
      `);

      // Multicast port
      if (port) {
        this.svg.append("rect")
          .attr("x", cx - 40)
          .attr("y", cy - 1)
          .attr("width", 80)
          .attr("height", 20)
          .attr("rx", 12)
          .attr("fill", "#02a682")
          .attr("filter", "url(#boxShadow)")
          .on("click", () => {
            window.open("/newdash?" + $.param({
              dash_key: "key",
              guid: "{C51B48D4-7876-479E-B0D9-BD9EFF03CE2E}",
              key: this.portInvertXform(port)
            }), "_blank");
          })
          .attr("cursor", "pointer");
      }


      this.svg.append("text")
        .attr("x", cx)
        .attr("y", cy + 14)
        .attr("text-anchor", "middle")
        .attr("fill", "white")
        .style("font-size", "15px")
        .style("font-weight", "600")
        .text(port)
        .on("click", () => {
          window.open("/newdash?" + $.param({
            dash_key: "key",
            guid: "{C51B48D4-7876-479E-B0D9-BD9EFF03CE2E}",
            key: this.portInvertXform(port)
          }), "_blank");
        })
        .attr("cursor", "pointer");


      // Multicast ip
      this.svg.append("rect")
        .attr("x", cx - 75)
        .attr("y", cy + 23)
        .attr("width", 150)
        .attr("height", 40)
        .attr("rx", 12)
        .attr("fill", "#02a84d")
        .attr("filter", "url(#boxShadow)")
        .on("click", () => {
          window.open("/newdash?" + $.param({
            dash_key: "key",
            guid: this.multicast_hosts_guid,
            key: convert_dotted_int_to_hex(multicastIP)
          }), "_blank");
        })
        .attr("cursor", "pointer");
        
      
        this.svg.append("text")
        .attr("x", cx)
        .attr("y", cy + 48)
        .attr("text-anchor", "middle")
        .attr("fill", "#fff")
        .style("font-size", "17px")
        .style("font-weight", "600")
        .text(multicastIP)
        .on("click", () => {
          window.open("/newdash?" + $.param({
            dash_key: "key",
            guid: this.multicast_hosts_guid,
            key: convert_dotted_int_to_hex(multicastIP)
          }), "_blank");
        })
        .attr("cursor", "pointer");

  
      // Metrics
      this.svg.append("text")
        .attr("x", cx)
        .attr("y", cy +85)
        .attr("text-anchor", "middle")
        .attr("fill", "#388e3c")
        .style("font-size", "17px")
        .style("font-weight", "600")
        .text(metricsStr);
      
      // Arrows and Counts
      this.drawEndpoints(cx, cy + 13);
    }

    portInvertXform(dstring) {
      const input = dstring.toUpperCase().startsWith("PORT-") ? dstring.slice(5) : dstring;
      const hex = parseInt(input, 10).toString(16).toUpperCase().padStart(4, '0');
      return "p-" + hex;
    }
    
  
    drawEndpoints(cx, cy) {
      const senderX = this.baseWidth * 0.125;
      const receiverX = this.baseWidth * 0.875 - 100;
      this.drawCircle(senderX, cy, this.senders.length, "#2196F3", () => this.toggleSender());
      this.drawCircle(receiverX, cy, this.receivers.length, "#FF9800", () => this.toggleReceiver());
      this.drawArrow(senderX + 80, cx - 75, cy, "#2196F3");
      this.drawArrow(cx + 75, receiverX + 20, cy, "#FF9800");
    }
  
    drawCircle(x, y, count, color, onClick) {
      this.svg.append("circle")
        .attr("cx", x + 50)
        .attr("cy", y + 30)
        .attr("r", 30)
        .attr("fill", color)
        .attr("cursor", "pointer")
        .on("click", onClick);
  
      this.svg.append("text")
        .attr("x", x + 50)
        .attr("y", y + 37)
        .attr("text-anchor", "middle")
        .attr("fill", "#fff")
        .style("font-size", "25px")
        .text(count)
        .attr("cursor", "pointer")
        .on("click", onClick);
    }
  
    drawArrow(x1, x2, y, color) {
      this.svg.append("line")
        .attr("x1", x1)
        .attr("y1", y + 30)
        .attr("x2", x2)
        .attr("y2", y + 30)
        .attr("stroke", color)
        .attr("stroke-width", 2)
        .attr("marker-end", "url(#arrow)");
    }
  
    toggleSender() {
      this.setSenderVisible(!this.senderVisible);
    }
  
    toggleReceiver() {
      this.setReceiverVisible(!this.receiverVisible);
    }
  
    setVisibility(sender, receiver) {
      this.setSenderVisible(sender);
      this.setReceiverVisible(receiver);
    }
  
    setSenderVisible(visible) {
      this.senderVisible = visible;
      this.renderLists();
    }
  
    setReceiverVisible(visible) {
      this.receiverVisible = visible;
      this.renderLists();
    }
  
    renderLists() {
      const existingWrapper = this.container.querySelector("#list-wrapper");
      if (existingWrapper) existingWrapper.remove();
    
      if (!this.senderVisible && !this.receiverVisible) {
        this.updateHeight();
        return;
      }
    
      const wrapper = document.createElement("div");
      wrapper.id = "list-wrapper";
      wrapper.style.display = "flex";
      wrapper.style.marginTop = "0px";
      wrapper.style.minHeight = "100px";
      wrapper.style.position = "relative";
    
      // Placeholder for spacing even if one is missing
      if (this.senderVisible) {
        const senderDiv = document.createElement("div");
        senderDiv.style.flex = "1";
        senderDiv.style.maxWidth = "50%";
        senderDiv.style.textAlign = "left";
        senderDiv.innerHTML = this.generateListHtml(this.senders, "left", this.senders_guid);

        wrapper.appendChild(senderDiv);
      } else {
        const placeholder = document.createElement("div");
        placeholder.style.flex = "1";
        wrapper.appendChild(placeholder);
      }
    
      if (this.receiverVisible) {
        const receiverDiv = document.createElement("div");
        receiverDiv.style.flex = "1";
        receiverDiv.style.maxWidth = "50%";
        receiverDiv.style.textAlign = "right";
        receiverDiv.innerHTML = this.generateListHtml(this.receivers, "right", this.receivers_guid);

        wrapper.appendChild(receiverDiv);
      } else {
        const placeholder = document.createElement("div");
        placeholder.style.flex = "1";
        wrapper.appendChild(placeholder);
      }
      
      this.container.appendChild(wrapper);
      this.updateHeight();
    }
    
  
    generateListHtml(items, position, guid) {
      const listHtml = items.map(item => {
        let margin;
        if (position === "left") {
          margin = "margin-left: 23%; margin-right: 47%;";
        } else {
          margin = "margin-left: 50%; margin-right: 20%;";
        }

        let key;
        if (this.multicast_mode) {
          key = `${convert_dotted_int_to_hex(item)}\\${convert_dotted_int_to_hex(this.multicastIP)}`
        }else {
          key = convert_to_key_format(item)
        }
        
        var opts = {
          models:JSON.stringify([{counter_group:guid ,meter:0,key: key}]),
          show_table:1,
          surface:"SQUARESTACKEDAREA",
          show_default_title:1,
          window_fromts:this.time_interval.from.tv_sec,
          window_tots:this.time_interval.to.tv_sec
        }


        return `
          <li style="line-height: 1.5; font-size: 0.9vw; text-align: ${position};" class="mb-1">
            <div class="row">
              <span class="col" style="display: inline-block; ${margin}">
                <span class="float-start" style="padding-right: 10px;">${item}</span>
                <span class="dropdown float-end">
                  <a class="dropdown-toggle" data-bs-toggle="dropdown" href="javascript:;" title="Click to get more options" aria-expanded="false">
                    <i class="fa fa-fw fa-server"></i>
                  </a>
                  <ul class="dropdown-menu">
                    <li>
                      <a class="dropdown-item" onclick="window.open('/newdash?' + '${$.param({dash_key: 'key',guid: guid , key: key})}')">
                        Key Dashboard
                      </a>
                    </li>
                    <li>
                      <a class="dropdown-item" onclick='new ApexChartLB(${JSON.stringify(opts)}, {modal_title: "Explore Traffic History"})'>
                        Traffic Chart
                        </a>
                    </li>
                  </ul>
                </span>
              </span>
            </div>
          </li>
        `;
      }).join("");

      return `<ul style="list-style-type: none; padding: 0; margin: 0;">${listHtml}</ul>`;
    }

    updateHeight() {
      const sH = this.senderVisible ? this.senders.length * 30 : 0;
      const rH = this.receiverVisible ? this.receivers.length * 30 : 0;
      const extra = Math.max(sH, rH);
    }
  };
}

async function run(opts) {
  let rc = new MulticastView(opts);
}
