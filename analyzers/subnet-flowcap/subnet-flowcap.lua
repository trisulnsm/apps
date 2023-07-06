--
-- subnet-flowcapp.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Enforces flow cap except for a multiple subnet 
-- 
require 'mkconfig' 
require 'iputils'

TrisulPlugin = { 

  id =  {
    name = "Subnet Flowcap",
    description = "Monitor IP flows and enforce flow cap except some subnets",
  },



  -- config load 
  onload = function()

    -- override by trisulnsm_subnet-flowcap.lua 
    -- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
    --  
    T.active_config = make_config(
            T.env.get_config("App>DBRoot").."/config/trisulnsm_subnet-flowcap.lua",
            {   
                -- which subnets
                Subnets =  { },
        
                -- volume cutoff
                VolumeCutOff =0,

				-- numbers
				SubnetNumbers = { } 
            })
  

  	-- convert to ipnum range
	for _,ipcidr in pairs(T.active_config.Subnets) do 
		local ns, ne = cidr_range( ipcidr) 
		table.insert(T.active_config.SubnetNumbers, { numstart=ns, numend=ne } ) 
	end 

  end,

  sg_monitor  = {

    session_guid = '{99A78737-4B41-4387-8F31-8077DB917336}', -- optional

    flushfilter = function(engine, flow) 
	
		local ipna = key_toipnum(flow:flow():ipa())
		local ipnz = key_toipnum(flow:flow():ipz())

		for _,iprange in ipairs(T.active_config.SubnetNumbers) do 

			if (ipna >= iprange.numstart and ipna <= iprange.numend ) or
			   (ipnz >= iprange.numstart and ipnz <= iprange.numend ) then 
				return true
			end 
		end 
		return flow:az_bytes() + flow:za_bytes() > T.active_config.VolumeCutOff
    end,


  },

}
