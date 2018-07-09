--
-- resource_monitor.lua skeleton
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     handle Resources extracted by Trisul 
-- DESCRIPTION: Trisul platform extracts resources (files,hashes,dns,ssl certs, etc)
--              they stream through the backend pipeline. Here is where you handle them
-- 
TrisulPlugin = { 

  -- id block
  --
  id =  {
    name = "DNS Intel Harvest",
    description = "Do stuff with DNS resources", 
  },

  -- resource_monitor block 
  --
  resource_monitor  = {

    resource_guid = '{D1E27FF0-6D66-4E57-BB91-99F76BB2143E}',

    -- Pull out DOMAINs and IP (from CNAME A AAAA records)  
    onflush = function(engine, resource) 

	  -- URI 
	  -- print(resource:uri())
	  engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
		resource:flow():id(),
		"INDICATOR:NAME", 
		resource:uri());

	  -- A records 
      for ip in  resource:label():gmatch("%sA%s+([%d%.]+)") do
        -- print(ip) 
		engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			resource:flow():id(),
			"INDICATOR:DNSIP", 
			ip);
      end

	  -- AAAA records 
      for ip in  resource:label():gmatch("%sAAAA%s+([%x%:]+)") do
        -- print(ip) 
		engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			resource:flow():id(),
			"INDICATOR:DNSIP6", 
			ip);

      end

	  -- CNAME  records 
      for cname in  resource:label():gmatch("CNAME%s+([%w%.%-]+)") do
        -- print(cname) 
		engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			resource:flow():id(),
			"INDICATOR:DNSCNAME", 
			cname);
	  end 
    end,
  },
}
