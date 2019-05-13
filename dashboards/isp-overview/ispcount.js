// ISP KPI top level dashboard
const kGUIDS  = [
	[ 'aspath',				'{47F48ED1-C3E1-4CEE-E3FA-E768558BC07E}'],
	[ 'flowas',				'{120A3124-E2BB-47BD-6C64-71BBB861C428}'],
	[ 'external_prefix',	'{C26520C4-DB9D-49EC-5D8B-35AD39951E36}'],
	[ 'internal_prefix',	'{C6D9D91D-7020-404D-C99E-7032455E6244}'],
	[ 'routers',			'{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}'],
	[ 'interfaces',			'{C0B04CA7-95FA-44EF-8475-3835F3314761}'],
];

// enter 
async function run(opts)
{
	let activeitems  = 	await refresh_model(opts);

	await load_assets(opts);
	repaint(activeitems,opts);
}

// get the data items 
async function refresh_model(opts)
{
	let activeitems = {};

	let  ti= await fetch_trp(TRP.Message.Command.TIMESLICES_REQUEST, {
		get_total_window: true
	});

	// clip to last 5 mins
	ti.total_window.from.tv_sec = ti.total_window.to.tv_sec-300;


	for(let i = 0; i < kGUIDS.length; i++){

		let field_name = kGUIDS[i][0];
		let cg_guid = kGUIDS[i][1];

		// get Master Size from META COUNTER GROUP 
		let ciresp = await fetch_trp(TRP.Message.Command.COUNTER_ITEM_REQUEST, {
								counter_group: '{4D88CC23-2883-4DEA-A313-A23B60FE8BDA}',
								time_interval: mk_time_interval(ti.total_window),
								key: TRP.KeyT.create({key:cg_guid})});


		activeitems[field_name]=  _.chain(ciresp.stats)
							 	   .collect( a=> a.values[0].toNumber())
							       .reduce( (memo,n)  => memo+n, 0)
							       .value() / ciresp.stats.length || 1 ;
	};

	return activeitems;
}

// load the frame 
async function load_assets(opts)
{
	// load app.css file
	load_css_file(opts);

	// load template.haml file 
	let html_str = await get_html_from_hamltemplate(opts);
   
	$(opts.divid).html(html_str);
}


// paint the model
function repaint(datamodel,opts)
{
	$('#flowas').html( parseInt(datamodel.flowas));
	$('#external_prefix').html( parseInt(datamodel.external_prefix));
	$('#internal_prefix').html( parseInt(datamodel.internal_prefix));
	$('#aspath').html( parseInt(datamodel.aspath));
	$('#routers').html( parseInt(datamodel.routers));
	$('#interfaces').html( parseInt(datamodel.interfaces));

	$('a#trends').bind('click', function(evt) {
		clicktrends( evt, datamodel);
	})

}

// handle clickmeta, shows Lightbox chart of trends
function clicktrends(evt, datamodel)
{
	let userlabel = $(evt.currentTarget).siblings('h2').attr('id');

	let dm = _.find(kGUIDS, a => a[0]==userlabel)

    let params = {
      cgguid:'{4D88CC23-2883-4DEA-A313-A23B60FE8BDA}',
      key: dm[1],
      statids:0,
    }
    let url = "/trpjs/generate_chart_lb?"+$.param(params);
    load_modal(url);

}