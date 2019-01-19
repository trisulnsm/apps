-- ip2location.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Consumes the ip2location CSV databases and enriches ASN,Country,Region,Proxy 
-- DESCRIPTION: Four new counter groups & edges 
-- 
-- 
local ipprefixdb=require'ipprefixdb' 
local bit=require'bit'

TrisulPlugin = { 

  id =  {
    name = "IP2Location",
    description = "Uses IP2Location databases to enrich and meter Geo metrics to Trisul", 
  },

  onload = function() 

    -- required 
    T.ldb_root = T.env.get_config("App>DataDirectory") .. "/plugins"
  	T.ldb=nil 
	T.key_labels_added = { } 
  end,

  onunload=function()
  	if T.ldb then 
		T.ldb:close()  
		T.ldb=nil
	end 
  end,

  reload=function()
  	TrisulPlugin.onunload() 
	T.ldb = ipprefixdb.new()
	local f,err=T.ldb:open(T.ldb_path, true)
	if not f then 
		T.logerror("Error opening IPPrefix database err="..err.." path="..T.ldb_path)
		T.ldb=nil
	end
  end,


  -- 
  -- sg_monitor block
  sg_monitor  = {

	-- load only during the flush interval 
	-- 
    onbeginflush = function(engine)
		T.ldb_path = T.ldb_root.."/trisul-ip2loc-"..engine:id()..".level"
		TrisulPlugin.reload() 
	end,

	onendflush = function()
		if T.ldb then T.ldb:close()  end 
		T.ldb=nil
	end,


	-- do the metering for IP endpoints  
	--
    onflush = function(engine, flow) 

		if not T.ldb then return end 

		-- 
		-- homenetworks not considered for Geo
		--
		local ip=flow:flow():ipz_readable()
		if T.host:is_homenet(ip) then 
			ip=flow:flow():ipa()
		else 
			ip=flow:flow():ipz()
	 	end 	

		-- filter out multicast and broadcast
		if ip > "E0" then return end


		
		T.ldb:set_databasename("ASN")
		local val = T.ldb:lookup_prefix(ip)
		if val then 
			local key,label = val:match("(%d+)%s*(.*)")
			TrisulPlugin.update_metrics(engine, flow, "{EF44F11F-B90B-4B24-A9F5-86482C51D125}",  key, label) 
		end 

		T.ldb:set_databasename("CTRY")
		local val = T.ldb:lookup_prefix(ip)
		if val then 
			local key,label = val:match("(%S+)%s*(.*)")
			TrisulPlugin.update_metrics(engine, flow, "{F962527D-985D-42FD-91D5-DA39F4D2A222}",  key, label) 
		end

		T.ldb:set_databasename("CITY")
		local val = T.ldb:lookup_prefix(ip)
		if val then 
			local key,label = val:match("(%S+)%s*(.*)")
			TrisulPlugin.update_metrics(engine, flow, "{E85FEB77-942C-411D-DF12-5DFCFCF2B932}",  key, label) 
		end


		T.ldb:set_databasename("STATE")
		local val = T.ldb:lookup_prefix(ip)
		if val then 
			local key,label = val:match("(%S+)%s*(.*)")
			TrisulPlugin.update_metrics(engine, flow, "{5C28445E-19E3-499E-E14D-E4CC7128B62B}",  key, label) 
		end

		T.ldb:set_databasename("PROXY")
		local val = T.ldb:lookup_prefix(ip)
		if val then 
			local key,label = val:match("(%S+)%s*(.*)")
			TrisulPlugin.update_metrics(engine, flow, "{2DCA13EB-0EB3-46F6-CAA2-9989EA904051}",  key, label) 
		end

    end,

  },


	-- metrics updated
	update_metrics=function(engine, flow, guid, key, label) 

		local dir=0
		if T.host:is_homenet(flow:flow():ipz_readable()) then 
			dir=1
		end 

		engine:update_counter ( guid ,  key, 3, 1)

		engine:update_counter( guid,  key, 0, flow:az_bytes()+flow:za_bytes());
		if dir==0 then 
			engine:update_counter ( guid ,  key, 1, flow:az_bytes())
			engine:update_counter ( guid ,  key, 2, flow:za_bytes())
		else 
			engine:update_counter ( guid ,  key, 2, flow:az_bytes())
			engine:update_counter ( guid ,  key, 1, flow:za_bytes())
		end

		if label and not T.key_labels_added[key] then 
			engine:update_key_info (guid ,  key, label) 
			T.key_labels_added[key]=true 
		end

		engine:add_flow_edges(flow:key(), guid, key) 

	end 
}
