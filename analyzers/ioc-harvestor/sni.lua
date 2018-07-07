--
-- counter_monitor.lua skeleton  
-- NEEDS TLS-SNI Trisul APP 
-- 
TrisulPlugin = { 

  id =  {
    name = "SNI harvest",
    description = "Harvest SNI ",   -- optional
  },

  cg_monitor  = {

    counter_guid = "{38497403-23FB-4206-65C2-0AD5C419DD53}", 

    onnewkey = function(engine, timestamp, key)
		engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			"06A:00.00.00.00:p-0000_00.00.00.00:p-0000",
			"INDICATOR:SNI", 
			key);
    end,
  },
}
