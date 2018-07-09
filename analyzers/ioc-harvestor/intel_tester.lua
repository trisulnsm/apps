-- Intel_tester
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Dumps the Intel IOC harvested by the various poitns in stream 
-- 
TrisulPlugin = { 

  -- id block
  --
  id =  {
    name = "Intel Harvest Tester",
    description = "Dump the INTEL to stdout", 
  },

  -- dont store the Intel harvested in backend, save space 
  resource_monitor  = {

    resource_guid = '{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}', 

    flushfilter = function(engine, resource) 
	  print(resource:uri().. ' = ' .. resource:label() ) 
	  return true 
    end,

  },
}

