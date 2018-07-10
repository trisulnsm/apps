-- fts_monitor.lua skeleton
-- Extracts URL and HTTP-Host and HTTP-Referer for INTEL 
-- 
TrisulPlugin = { 

  -- id block
  -- 
  id =  {
    name = "HTTP Harvestor",
    description = "harvest from HTTP headers",
  },

  fts_monitor  = {

    fts_guid = '{28217924-E7A5-4523-993C-44B52758D5A8}',

    onflush = function(engine, fts) 

		local text = fts:text()

		if not text:find("GET",1,true)  then return end 

		local _,_,uri = text:find("%s([^%s?]+)")

		local _,_,host = text:find("Host%s*:%s*(%S+)")
		if not host then
			T.logwarn("No Host header found for url: ".. uri) 
		else
			engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
				fts:flow():id(),
				"INDICATOR:HTTPURL", 
				host..uri) 
		end

		local _,_,referer = text:find("Referer%s*:%s*(%S+)")
		if referer then
			engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
				fts:flow():id(),
				"INDICATOR:HTTPREFERER", 
				referer) 
		end
    end,
  },
}
