


class NewProtoTree {

	constructor(opts) {
		this.divid = opts['divid']
		this.tree = { } 
		this.totals = { }

	}


	paint(dom,subtree) {
		let ul = document.createElement('ul');
		dom.appendChild(ul);


		for ( let k of Object.entries(subtree).sort( (a,b) => b[1].bytes - a[1].bytes) )  {
			if ( k[0] == 'bytes' ||	 k[0] == 'packets') continue; 

			let li = document.createElement('li')
			li.innerHTML = `<span class="key">${k[0]}</span> \
			                <span class="metric text-right">${ k[1].bytes} </span>\
			                <span class="percent text-right"> (${ (k[1].bytes/this.totals.bytes*100).toFixed(2)} %)</span> \
			                <span class="metric text-right">${ k[1].packets}</span> \
			                <span class="percent text-right"> (${ (k[1].packets/this.totals.packets*100).toFixed(2)} %)</span>`
			ul.appendChild(li);

			if (k[1].nodetype !='leaf') {
				this.paint(li,k[1])
			}
		}

	}


	layout() {
		document.querySelectorAll(`${this.divid} ul`).forEach( (f) => {f.style.fontFamily='monospace'} )
		document.querySelectorAll(`${this.divid} span.metric`).forEach( (f) => {f.style.minWidth='200px';f.style.display='inline-block'} )
		document.querySelectorAll(`${this.divid} span.key`).forEach( (f) => {f.style.minWidth='150px';f.style.display='inline-block'} )
		document.querySelectorAll(`${this.divid} span.percent`).forEach( (f) => {f.style.minWidth='30px';f.style.display='inline-block'} )
	}



	async run() {

		// just  a hello message to backend TRP
		let  resp= await fetch_trp(TRP.Message.Command.HELLO_REQUEST,{
			station_id : 	"Testing protobuf direct from js",
			message: 		"hello directly from the browser "
		});

		// get total available timewindow 
		let  ts= await fetch_trp(TRP.Message.Command.TIMESLICES_REQUEST, {
			get_totalwindow: true
		});
		this.fromTS = parseInt(ts.slices[0].time_interval.from.tv_sec)
		this.toTS = parseInt(ts.slices[0].time_interval.to.tv_sec)


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
