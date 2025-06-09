class MulticastView {
  constructor(opts) {
    this.divid = document.querySelector(opts.divid);
    this.containerId = "multicast-diagram-container";
    this.expandTabId = "expand-tab";
    this.collapseTabId = "collapse-tab";
    this.baseWidth = 1200;
    this.baseHeight = 200;
    this.diagrams = [];
    this.setup(opts);
  }

  async setup(opts) {
    await this.addForm(opts);
    this.container = document.getElementById(this.containerId);    
    this.expandTab = document.getElementById(this.expandTabId);
    this.collapseTab = document.getElementById(this.collapseTabId);
    this.setupTabListeners();
    this.init();
  }

  async addForm(opts) {
    const htmlStr = await get_html_from_hamltemplate(opts);
    const template = document.createElement('template');
    template.innerHTML = htmlStr;
    this.form = template.content.children[0];
    this.data_dom = template.content.children[0];
    this.divid.appendChild(this.form);
    this.divid.appendChild(this.data_dom);
  }

  async init() {
    this.tmint = await new TimeInterval({}).get_total_window();
    let cg_meters = {};
    let exchange_xflow_guid = "{942AB99F-7A65-4B2E-6F6C-A3050F0F7B35}";
    await get_counters_and_meters_json(cg_meters);
    this.multipliers = get_multipliers(cg_meters,exchange_xflow_guid,2);

    
    const resp = await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
      counter_group: exchange_xflow_guid,
      time_interval: this.tmint,
      meter: 2,
      maxitems: 1000
    });



    const multicastList = resp.keys
      .filter(t => (t.label.match(/\\/g) || []).length === 3)
      .reduce((list, t) => {
        const [receiver, sender, , multicast_ip] = t.label.split("\\");
        let entry = list.find(e => e.multicast_ip === multicast_ip);
        if (!entry) {
          entry = { multicast_ip, senders: [], receivers: [], volume: 0 };
          list.push(entry);
        }
        if (!entry.senders.includes(sender)) entry.senders.push(sender);
        if (!entry.receivers.includes(receiver)) entry.receivers.push(receiver);
        entry.volume += parseInt(t.metric) * this.multipliers.topper_bucketsize;

        return list;
      }, []);

    multicastList.sort((a, b) => b.volume - a.volume);
    document.getElementById("total-multicast-count").textContent = multicastList.length;    
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
  }

  setActiveTab(id) {
    [this.expandTab, this.collapseTab].forEach(tab => {
      const active = tab.id === id;
      tab.classList.toggle("active", active);
      tab.setAttribute("aria-selected", active);
      tab.tabIndex = active ? 0 : -1;
    });
  }

  createCard({ multicast_ip, senders, receivers, volume }, index) {
    const wrapper = document.createElement("div");
    wrapper.className = `multicast_${index}`;
    wrapper.style.width = "100%";
    wrapper.style.overflowX = "auto";

    const card = document.createElement("div");
    card.className = "card mb-3";
    card.innerHTML = `
      <div class="card-header">
        <div class="card-title">
          <span class="badge bg-info">${index + 1}</span>
          <span> Multicast Group: ${multicast_ip}</span>
        </div>
      </div>
    `;
    card.appendChild(wrapper);
    
    const diagram = new this.Diagram(wrapper, multicast_ip, senders, receivers, h_fmtvol(volume));
    this.diagrams.push(diagram);

    return card;
  }

  Diagram = class {
    constructor(container, multicastIP, senders, receivers, volume) {
      Object.assign(this, { container, senders, receivers, senderVisible: false, receiverVisible: false });
      this.baseWidth = 1200;
      this.baseHeight = 200;
      this.svg = d3.select(container).append("svg")
        .attr("viewBox", `0 0 ${this.baseWidth} ${this.baseHeight}`)
        .attr("preserveAspectRatio", "xMidYMid meet")
        .style("width", "100%").style("height", "auto");
      this.senderGroup = this.svg.append("g");
      this.receiverGroup = this.svg.append("g");
      this.draw(multicastIP, volume);
      window.addEventListener("resize", () => this.updateHeight());
    }

    draw(multicastIP, volume) {
      const [cx, cy] = [this.baseWidth / 2, 50];
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
      this.svg.append("rect")
        .attr("x", cx - 75)
        .attr("y", cy)
        .attr("width", 150)
        .attr("height", 60)
        .attr("rx", 12)
        .attr("fill", "url(#multicastGradient)")
        .attr("filter", "url(#boxShadow)")
        .on("click", () => {window.open("/newdash?" + $.param({dash_key: "key",guid: "{2792D434-496E-40C9-5E2D-73B60623A631}",key: convert_dotted_int_to_hex(multicastIP)}), "_blank")})
        .attr("cursor", "pointer");

      this.svg.append("text")
        .attr("x", cx)
        .attr("y", cy + 35)
        .attr("text-anchor", "middle")
        .attr("fill", "#fff")
        .style("font-size", "17px")
        .style("font-weight", "600")
        .text(multicastIP)
        .on("click", () => {window.open("/newdash?" + $.param({dash_key: "key",guid: "{2792D434-496E-40C9-5E2D-73B60623A631}",key: convert_dotted_int_to_hex(multicastIP)}), "_blank")})
        .attr("cursor", "pointer");

      this.svg.append("text")
        .attr("x", cx)
        .attr("y", cy + 90)
        .attr("text-anchor", "middle")
        .attr("fill", "#388e3c")
        .style("font-size", "17px")
        .style("font-weight", "600")
        .text(volume);
      this.drawEndpoints(cx, cy);
    }

    drawEndpoints(cx, cy) {
      const senderX = this.baseWidth * 0.125;
      const receiverX = this.baseWidth * 0.875 - 100;
      this.drawCircle(senderX, cy, this.senders.length, "#2196F3", () => this.toggleSender());
      this.drawCircle(receiverX, cy, this.receivers.length, "#FF9800", () => this.toggleReceiver());
      this.drawArrow(senderX + 100, cx - 75, cy, "#2196F3");
      this.drawArrow(cx + 75, receiverX, cy, "#FF9800");
    }

    drawCircle(x, y, count, color, onClick) {
      this.svg.append("circle")
        .attr("cx", x + 50)
        .attr("cy", y + 30)
        .attr("r", 50)
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

    toggleSender() { this.setSenderVisible(!this.senderVisible); }
    toggleReceiver() { this.setReceiverVisible(!this.receiverVisible); }
    setVisibility(sender, receiver) {
      this.setSenderVisible(sender);
      this.setReceiverVisible(receiver);
    }

    setSenderVisible(visible) {
      this.senderVisible = visible;
      this.senderGroup.selectAll("*").remove();
      if (visible) this.renderList(this.senderGroup, this.senders, this.baseWidth * 0.125 + 50, 150, "#2196F3");
      this.updateHeight();
    }

    setReceiverVisible(visible) {
      this.receiverVisible = visible;
      this.receiverGroup.selectAll("*").remove();
      if (visible) this.renderList(this.receiverGroup, this.receivers, this.baseWidth * 0.875 - 50, 150, "#FF9800");
      this.updateHeight();
    }

    renderList(group, items, x, startY, color) {
      const boxW = 220, boxH = 40, spaceY = 12, gradientId = `grad-${Math.random().toString(36).substr(2, 5)}`;
      const grad = group.append("defs")
        .append("linearGradient")
        .attr("id", gradientId)
        .attr("x1", "0%")
        .attr("y1", "0%")
        .attr("x2", "100%")
        .attr("y2", "100%");
      grad.append("stop")
        .attr("offset", "0%")
        .attr("stop-color", d3.color(color)
        .brighter(1));
      grad.append("stop")
        .attr("offset", "100%")
        .attr("stop-color", d3.color(color)
        .darker(0.5));

      items.forEach((text, i) => {
        const y = startY + i * (boxH + spaceY), xBox = x - boxW / 2;
        group.append("rect")
        .attr("x", xBox)
        .attr("y", y)
        .attr("width", boxW)
        .attr("height", boxH)
        .attr("rx", 20)
        .attr("fill", `url(#${gradientId})`);
        group.append("text")
        .attr("x", x)
        .attr("y", y + boxH / 2 + 5)
        .attr("text-anchor", "middle")
        .attr("fill", "#fff")
        .style("font-size", "15px")
        .style("font-family", "monospace")
        .text(text);
      });
    }

    updateHeight() {
      const sH = this.senderVisible ? this.senders.length * 51 : 0;
      const rH = this.receiverVisible ? this.receivers.length * 51 : 0;
      this.svg.attr("viewBox", `0 0 ${this.baseWidth} ${this.baseHeight + Math.max(sH, rH)}`);
    }
  };
}




async function run(opts) {
  let rc = new MulticastView(opts);
}
