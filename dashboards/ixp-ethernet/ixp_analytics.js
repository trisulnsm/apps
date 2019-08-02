// IXP - L2 Analytics

const GUID_DIRMAC='{79F60A94-44BD-4C55-891A-77823D59161B}'
const GUID_MAC=   '{4B09BD22-3B99-40FC-8215-94A430EA0A35}'

class IXPPathAnalytics {

  // setup members 
  constructor(opts){
    this.dom = $(opts.divid);
    this.default_selected_time = opts.new_time_selector;
    this.model={}
    this.setup_form(opts);
  }

   // load the UI frame 
  async load_assets(opts)
  {
    load_css_file(opts);
    let html_str = await get_html_from_hamltemplate(opts);
    this.haml_dom =$(html_str)
  }

  // setup theform
  async setup_form(opts){
    await this.load_assets(opts)
    this.form = $(this.haml_dom[0]);
    this.dom.append(this.form);

    //new time selector 
    this.timeSelect = new ShowNewTimeSelector({divid:"#new_time_selector",
                               update_input_ids:"#from_date,#to_date",
                               default_ts:this.default_selected_time
                            });

    this.form.submit($.proxy(this.submit_form,this));    
  }

  // on submit .
  submit_form(){
    this.reset_ui();
    this.query_trp();
    return false;
  }
 
  // called onsubmit:  clear UI elements 
  reset_ui(){
    $('#ixp-matrix table tbody').remove();
  }

  // called : onsubmit - query using TRP and update model 
  async query_trp(){

    // get the topper bucketsize 
    let cginfo = await fetch_trp(TRP.Message.Command.COUNTER_GROUP_INFO_REQUEST,{
      counter_group: GUID_DIRMAC,
    } );
    let topper_bucket_size = parseInt( cginfo.group_details[0].topper_bucket_size)


    // load the raw model 
    this.data ={};
    this.data['raw']=await fetch_trp(TRP.Message.Command.COUNTER_GROUP_TOPPER_REQUEST,{
      counter_group: GUID_DIRMAC,
      meter:0,
      time_interval:this.timeSelect.to_trp_time_interval(),
      key_filter: ''
    } );
    for (let i =0 ; i < this.data['raw'].keys.length; i++) {   
      this.data['raw'].keys[i].metric  *= topper_bucket_size;
    }

    // create the map
    let keydata = this.data['raw'].keys; 
    let allkeys  = _.chain(keydata)
                    .map( function(ai) {
                        let k = ai.key.split('->');
                        if (k.length==2) {
                          return [k[0].trim(),k[1].trim()];
                        }
                    })
                    .flatten()                    
                    .uniq()
                    .sort( (a,b) => a.metric < b.metric )
                    .compact()
                    .value();

    this.model = Array(allkeys.length)
                 .fill(0)
                 .map( x => Array(allkeys.length));

    // helper 
    let metric_lookup =  _.object(
                            _.collect(this.data['raw'].keys, x => x.key),
                            this.data['raw'].keys);

    // start filling  x -> y
    for (let r = 0; r < allkeys.length; r++) {
      for (let c=0; c < allkeys.length; c++) {
        this.model[r][c]=[0,0]
        // rowcol
        let k = `${allkeys[r]} ->${allkeys[c]}`
        let hit = metric_lookup[k]
        if (hit) {
          this.model[r][c][0]=hit.metric
        }
        // colrow
        k = `${allkeys[c]} ->${allkeys[r]}`
        hit = metric_lookup[k]
        if (hit) {
          this.model[r][c][1]=hit.metric
        }
      }
    }

    this.allkeys=allkeys

    // resolve the IX member addresses
    let keyinfo = await fetch_trp(TRP.Message.Command.SEARCH_KEYS_REQUEST,{
      counter_group: GUID_MAC,
      keys: allkeys
    } );
    this.labels = _.object(keyinfo.keys.map( x => x.key),
                           keyinfo.keys.map( x => x.label));

    this.draw_matrix_table();

  }


  // return a TD 
  mk_cell(row,col) 
  {
    let tx=this.model[row][col][0] ,
        rx=this.model[row][col][1];

    if (tx+rx==0) {
      return $('<td>',{class:'zerovalue'});
    } else {
      let txtxt=h_fmtvol(tx) . toString() . replace(/ /g,''),
          rxtxt=h_fmtvol(rx) . toString() . replace(/ /g,'');

      let tools= []
      tools.push( [ "Peer A Name", this.labels[this.allkeys[row]]])
      tools.push( [ "Peer A MAC",  this.allkeys[row]])
      tools.push( [ "-- to --",  ''])
      tools.push( [ "Peer Z Name", this.labels[this.allkeys[col]]])
      tools.push( [ "Peer Z MAC",  this.allkeys[col]])
      tools.push( [ "-- vol --",  ''])
      tools.push( [ "Peer A --> Peer Z (TX/A) ",  txtxt])
      tools.push( [ "Peer Z --> Peer A (RX/A) ",  rxtxt])
      tools.push( [ "-- Explore --",  ''])
      //traffic chart
      let onclicktext=`load_modal('${this.get_trpchart_url(row,col)}');`;
      var anchor = $("<a>",{href:"javascript:;;",onclick:onclicktext}).text("Traffic Chart");
      tools.push( [ "",anchor.prop('outerHTML')]);

      let td=$('<td>', { class: "matrix-cell"});
      td.html(`${txtxt}<br/>${rxtxt}`)
      td.attr("data-key-popover", JSON.stringify(tools))
      return td;
    }
  }

  // draw a nested table view 
  draw_matrix_table(toppers,divid)
  {

    let tbl=$('#ixp-matrix table')
    let tbody=tbl.append("<tbody>")

    // 1st row = MAC Columns
    let tr=$('<tr>');
    tr.append($('<td>'));
    for (let r=0;r<this.model.length;r++) {
        tr.append($('<td>',{class:'vertical-title'}).text(this.labels[this.allkeys[r]]));
    }
    tbody.append(tr)

    // matrix cells - use mk_cell to paint the cell.. 
    for (let r=0;r<this.model.length;r++) {
      let tr=$('<tr>');
      tr.append($('<td>').text(this.labels[this.allkeys[r]]))
      for(let c=0;c<this.model.length;c++) {
        tr.append(this.mk_cell(r,c));
      }
      tbody.append(tr)
    }

    key_popover( {timeout_secs: 2});
  }
  get_trpchart_url(row,col){
    let chart_models = [
                          [GUID_DIRMAC,
                          `${this.allkeys[row]} ->${this.allkeys[col]}`,
                           0,
                           `${this.labels[this.allkeys[row]]} ->${this.labels[this.allkeys[col]]}`
                          ],
                          [GUID_DIRMAC,
                          `${this.allkeys[col]} ->${this.allkeys[col]}`,
                           0,
                           `${this.labels[this.allkeys[col]]} ->${this.labels[this.allkeys[row]]}`
                          ],
                      ]

    let params = {
      models:JSON.stringify(chart_models),
      valid_input:1,
      auto_label:false,
      window_fromts:this.timeSelect.to_trp_time_interval().from.tv_sec,
      window_tots:this.timeSelect.to_trp_time_interval().to.tv_sec
    }
    return "/trpjs/generate_chart_lb?"+$.param(params);
  }
}

 
function run(opts){
  new IXPPathAnalytics(opts)
}

//# sourceURL=ixp_analytics.js          
