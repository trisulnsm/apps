


class NewProtoTree {

	constructor(opts) {
		this.divid = opts['divid']
		this.tree = { } 
		this.totals = { }

	}

	paintHeading(dom) {

		let div = document.createElement('div');
		div.className += 'col-xs-12 well' 
		dom.appendChild(div);

		div.innerHTML = `<h2>Protocol tree breakup</h2> \
			         <h4>Time interval ${new Date(this.fromTS * 1000)} to ${new Date(this.toTS * 1000)} </h4> \
				 <h4>Total bytes=${Number(this.totals.bytes).toLocaleString()}  packets=${Number(this.totals.packets).toLocaleString()}</h4>`


		let ul = document.createElement('ul');
			ul.className = 'text-danger'
			ul.innerHTML = `<li><span class="key">protocol</span> \
			                <span class="metric text-right">bytes  </span>\
			                <span class="percent text-right"> ( %total) </span> \
			                <span class="metric text-right">packets</span> \
			                <span class="percent text-right"> ( %total) </span>\
			                <span class="bytespkt text-right"> bytes/pkt </span></li>`
			ul.innerHTML += `<li><span class="key">total counts</span> \
			                <span class="metric text-right"> ${this.totals.bytes} </span>\
			                <span class="percent text-right"> ( 100% ) </span> \
			                <span class="metric text-right"> ${this.totals.packets} </span> \
			                <span class="percent text-right"> ( 100% ) </span>\
			                <span class="bytespkt text-right"> ${ (this.totals.bytes/this.totals.packets).toFixed(2)} </span></li>`
		dom.appendChild(ul);
	}

	paint(dom,subtree) {
		let ul = document.createElement('ul');
		dom.appendChild(ul);


		for ( let k of Object.entries(subtree)
                              .slice().filter( a => !['bytes','packets'].includes(a[0]) && a[1].bytes>0 && a[1].packets>0 )
                              .sort( (a,b) => b[1].bytes - a[1].bytes) ) {

			let li = document.createElement('li')
			li.innerHTML = `<span class="key">${k[0]}</span> \
			                <span class="metric text-right">${ k[1].bytes} </span>\
			                <span class="percent text-right"> (${ (k[1].bytes/this.totals.bytes*100).toFixed(2)} %)</span> \
			                <span class="metric text-right">${ k[1].packets}</span> \
			                <span class="percent text-right"> (${ (k[1].packets/this.totals.packets*100).toFixed(2)} %)</span>\
			                <span class="bytespkt text-right"> ${ (k[1].bytes/k[1].packets).toFixed(2)}</span>`
			ul.appendChild(li);

			if (k[1].nodetype !='leaf') {
				this.paint(li,k[1])
			} else {
				li.className="text-info"
			}
		}

	}


	layout() {
		document.querySelectorAll(`${this.divid} ul`).forEach( (f) => {f.style.fontFamily='monospace'} )
		document.querySelectorAll(`${this.divid} span.metric`).forEach( (f) => {f.style.minWidth='150px';f.style.display='inline-block'} )
		document.querySelectorAll(`${this.divid} span.key`).forEach( (f) => {f.style.minWidth='120px';f.style.display='inline-block'} )
		document.querySelectorAll(`${this.divid} span.bytespkt`).forEach( (f) => {f.style.minWidth='120px';f.style.display='inline-block'} )
		document.querySelectorAll(`${this.divid} span.percent`).forEach( (f) => {f.style.minWidth='80px';f.style.display='inline-block'} )
	}



	async run() {

		// just  a hello message to backend TRP
		let  resp= await fetch_trp(TRP.Message.Command.HELLO_REQUEST,{
			station_id : 	"Testing protobuf direct from js",
			message: 		"hello directly from the browser "
		});

		// get total available timewindow 
		let  ts= await fetch_trp(TRP.Message.Command.TIMESLICES_REQUEST, {
			get_total_window: true
		});
		this.fromTS = parseInt(ts.total_window.from.tv_sec)
		this.toTS = parseInt(ts.total_window.to.tv_sec)


		// Find "Protocol Tree" counter group 
		let  cginfo= await fetch_trp(TRP.Message.Command.COUNTER_GROUP_INFO_REQUEST);
		let cg=cginfo.group_details.find( (item) => item.name=="Protocol Tree" )
		if (cg==null) {
			alert("Cannot find counter group Protocol Tree")
			return;
		}

		// Get Bytes Toppers 
		let cgtoppers_bytes=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
			counter_group: cg.guid,
			time_interval: mk_time_interval([this.fromTS,this.toTS]),
			meter:0
		});
		this.loadtree( cgtoppers_bytes, "bytes");

		// Get packets Toppers 
		let cgtoppers_packets=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST, {
			counter_group: cg.guid,
			time_interval: mk_time_interval([this.fromTS,this.toTS]),
			meter:1
		});
		this.loadtree( cgtoppers_packets, "packets");

		this.totals= this.tree['SYS:GROUP_TOTALS']
		delete this.tree['SYS:GROUP_TOTALS']

		this.paintHeading(document.querySelector(this.divid));
		this.paint(document.querySelector(this.divid), this.tree);
		this.layout()

	}

	loadtree(cgtoppers,  meterid) {
		// load tree
		cgtoppers.keys.forEach( (ai) => {
	
			let h = this.tree;
			ai.label.split('/').forEach( (kp) => {
				h[kp] = h[kp] || { }
				h=h[kp]
				h[meterid] = ( h[meterid] || 0 ) +  parseInt(ai.metric)				
			});

			h.nodetype = 'leaf'

		});

	}
}

function run(opts)
{
	new NewProtoTree(opts).run() 	
}

//# sourceURL=new-prototree.js
