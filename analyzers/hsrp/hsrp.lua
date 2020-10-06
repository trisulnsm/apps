--
-- hsrp - HSRP parser 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     protocol handler, 
-- 
TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "HSRP",
    description = "HRSP parser to track active standby ", -- optional
  },
  
  -- protocol_handler  block
  -- 
  protocol_handler  = {

	  -- new protocol for FLOWDIR 
	  control = {
	    guid  = "{169D45A5-F304-434A-820F-C44C3956BA0B}", 
	    name  = "HSRP",  -- new protocol name 
	    host_protocol_guid = '{14D7AB53-CC51-47e9-8814-9C06AAE60189}', -- GUID for UDP
	    host_protocol_ports = { 1985 }                                 -- we want UDP 1985
	  },


	  -- WHEN CALLED: when lower layer is constructed and 
	  -- return  ( nEaten, nextProtID) 
	  parselayer = function(layer)

      return layer:layer_bytes(), nil 

    end,
  }
}
