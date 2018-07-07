--
-- ssl certificate SHA1 intel 
-- Extracts SHA1 sign of certificates 
-- 
TrisulPlugin = { 

  -- id block
  -- 
  id =  {
    name = "Cert SHA1 Harvestor",
    description = "harvest SHA1 cert prints ",
  },

  fts_monitor  = {

    fts_guid = '{5AEE3F0B-9304-44BE-BBD0-0467052CF468}', 

    onflush = function(engine, fts) 

		local text = fts:text()

		if not text:find("GET",1,true)  then return end 

		local _,_,uri = text:find("%s([^%s?]+)")

		local _,_,host = text:find("Host:%s(%S+)")
	    engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
			flow:id(),
			"INDICATOR:HTTPURL", 
			host..uri) 

    end,


  },
}
