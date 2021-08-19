--
-- IGMP Protocol 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     protocol handler, 
-- 
TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "IGMPProt",
    description = "Protocol handler", 
  },
  
  -- protocol_handler  block
  -- 
  protocol_handler  = {

	  -- new protocol for FLOWDIR 
	  control = {
	    guid  = "{D3E8D72E-48ED-43F9-1E8C-DD5FED84E830}", 
	    name  = "IGMP3",  -- new protocol name 
	    host_protocol_guid = '{0A2C724B-5B9F-4ba6-9C97-B05080558574}', -- GUID for IP
	    host_protocol_ports = { 2 }                                    -- we want Prot 2 
	  },


	  -- WHEN CALLED: when lower layer is constructed and 
	  -- return  ( nEaten, nextProtID) 
	  parselayer = function(layer)

      return layer:layer_bytes(), nil 

    end,
  }
}
