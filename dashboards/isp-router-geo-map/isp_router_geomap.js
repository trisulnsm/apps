//Show the router in geo country map

class RouterGeoMap{

  constructor(opts) {
    this.dom = $(opts.divid);
    this.load_assets(opts);
  }
  // load the frame 
  async load_assets(opts)
  {
    // load app.css file
    load_css_file(opts);
    // load template.haml file 
    let html_str = await get_html_from_hamltemplate(opts);
    this.haml_dom =$(html_str);
    //load map js and css file
    await this.load_map_assets(opts,"jvector_map.min.js");
    await this.load_map_assets(opts,"jvector-in-mill.js");
    await this.load_map_assets(opts,"jvector_map.css");
    await this.geo_map();
  }
  //load the jvector map dependency
  async load_map_assets(opts,fname){
    let js_file =opts.jsfile;
    let file_path = js_file.split("/")
    file_path.pop()
    file_path = file_path.join("/");
    let file_full_path = `/plugins/${file_path}/${fname}`;
    if(fname.match(/\.js$/)){
      await jQuery.ajax({
        url: file_full_path,
        dataType: 'script',
        async: true
      });
    }
    else{
      $('head').append(`<link rel="stylesheet" type="text/css" href="${file_full_path}">`);
    }
  }
  async geo_map(){

    let routerkeys =await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST, {
      counter_group: "{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}",
      get_attributes:true
    });
    this.dom.html("");
    this.data_dom = $(this.haml_dom[0]).clone();
    this.dom.append(this.data_dom);
    this.dom.find('.badge').html(routerkeys.keys.length);
    let markers = [];
    let palette = [].concat.apply([], [d3.schemeCategory10,d3.schemeCategory20,d3.schemeCategory20b,d3.schemeCategory20c]);
    let colors = {};
    for (let i=0 ; i < routerkeys.keys.length;i++) { 
      let rattr = routerkeys.keys[i].attributes;
      let rattr_obj = {}
      _.each(rattr,function(attr){rattr_obj[attr.attr_name]=attr.attr_value});
      markers.push({latLng:[rattr_obj["geo.lat"],rattr_obj["geo.long"]],name:routerkeys.keys[i].readable,offsets:[0, 2]});
      var region_key = `${rattr_obj["geo.country"]}-${rattr_obj["geo.city"]}`;
      colors[region_key]=palette[i%palette.length];
    }

    let map_div =  this.dom.find(".geo_map");
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
                                },
                                legend: {
                                  horizontal: true,
                                  cssClass: 'jvectormap-legend-icons',
                                  title: 'Business type'
                                }
                              }
                            },
                            onRegionClick: function (event, code) {
                              window.open("/nflow/gen_drilldown/","_blank");
                            },
                            onMarkerClick: function (event, index) {
                              window.open("/nflow/gen_drilldown/","_blank");
                            }
                          });
     map.series.regions[0].setValues(colors);
  }
}

function run(opts)
{
  new RouterGeoMap(opts)
}

//# sourceURL=router_geomap.js
