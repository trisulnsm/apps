--
-- counter_monitor.lua skeleton  
-- NEEDS TLS-Print Trisul APP 
-- 
TrisulPlugin = { 

  -- id block 
  id =  {
    name = "JA3 harvest",
    description = "Harvest JA3",   -- optional
  },

  -- cg_monitor block
  -- 
  cg_monitor  = {

    counter_guid = "{E8D5E68F-B320-49F3-C83D-66751C3B485F}", 

    onnewkey = function(engine, timestamp, key)
		engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			"06A:00.00.00.00:p-0000_00.00.00.00:p-0000",
			"INDICATOR:JA3", 
			key);
    end,
  },

}
