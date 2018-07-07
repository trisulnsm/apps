--
-- counter_monitor.lua skeleton
--
-- harvest Hosts
-- 
TrisulPlugin = { 

  -- id block 
  id =  {
    name = "Hosts IP ",
    description = "Hosts IP NewIP",   -- optional
  },

  cg_monitor  = {

    counter_guid = "{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}",

    onnewkey = function(engine, timestamp, key)

		local pmatch,_, b1,b2,b3,b4= key:find("(%x+)%.(%x+)%.(%x+)%.(%x+)")
		local dottedip = string.format("%d.%d.%d.%d", tonumber(b1,16),tonumber(b2,16), 
		                                              tonumber(b3,16),tonumber(b4,16))

		engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			"06A:00.00.00.00:p-0000_00.00.00.00:p-0000",
			"INDICATOR:HOST", 
			dottedip);
    end,

  },

}
