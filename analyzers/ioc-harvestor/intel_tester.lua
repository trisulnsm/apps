-- Intel_tester
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Dumps the Intel IOC harvested by the various poitns in stream 
-- 
-- This is Just a STUB tester does nothing other than print the intel items  
-- 
require'mkconfig' 

TrisulPlugin = { 

  -- id block
  --
  id =  {
    name = "Intel Harvest Tester",
    description = "Dump the INTEL to stdout", 
  },

  onload = function()

    -- load custom config if present 
    T.active_config = make_config(
						T.env.get_config("App>DBRoot").."/config/trisulnsm_ioc-harvestor.lua",
						{
						  -- Save these to backend DB (can take up significant disk space) 
						  -- in production override this to false  in 
						  -- /usr/local/var/lib/trisul-probe/d0/p0/cX/config/trisulnsm_ioc-harvestor.lua config file 
						  SaveHarvestedItems=false,
						} )

  end,

  -- dont store the Intel harvested in backend, save space 
  resource_monitor  = {

    resource_guid = '{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}', 

	-- 
	-- do you want to save these Harvested resources on the Hub
	-- 
    flushfilter = function(engine, resource) 
	  -- print(resource:uri().. ' = ' .. resource:label() ) 
	  return T.active_config.SaveHarvestedItems 
    end,

  },
}

