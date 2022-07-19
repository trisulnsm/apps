
async function getattachmentpoints(){

  const xdetails = await get_all_xkeys();

  const menuarr = xdetails.map( (x,idx) => {
    return {
      cgguid: x.parentcgguid,
      meterids:[0,1,2],
      menuname:`Sankey drilldown into ${x.xkeycgname}`,
      id:x.cgguid
    }
  })

  return menuarr;
}

async function get_all_xkeys() {
  // all active xkeys
  const response = await fetch("/admin/trisul_counter_group_crosskeys/ax_all_active_crosskey_details", 
                      { method: "POST",
                        headers: {
                          'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({})
                      });
  if (!response.ok) {
      const message = `An error has occured: ${response.status}`;
      console.log("Error in fetch crosskey details");
      throw new Error(message);
  }

  const details = await response.json();
  return details;
}


async function onclick(opts){
  let lp=$.param({dash_key_regex:"gitSankeyCrossdrill",
				           cgguid: opts.menu.id,
                   key:'$'+opts.key.key,
                   valid_input:1,
                   meter:opts.meterid,
                   window_fromts:opts.time_interval.window_fromts,
                   window_seconds:opts.time_interval.window_secs
                });
  window.open("/newdash/index?"+lp);
}

