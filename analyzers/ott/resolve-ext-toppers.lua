--
-- try to resolve TOP N hosts 
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Lookup passive DNS and update key 
-- 
local leveldb=require'tris_leveldb'
local lmap = require'appmap'

local CGOPTS  = {
	GUID      = "{00AA77BB-0063-11A5-8380-FEBDBABBDBEA}",
	INTERFACE = "",
	INTFKEY   = ""
}

TrisulPlugin = { 

  -- id block 
  id =  {
    name = "New Ext Hosts ",
    description = "Listen and process events in 'Hosts' counter group",   -- optional
  },

  -- 
  -- common functions onload, onunload, onmessage()..

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
  	T.LevelDB = nil 

	local tbl={}

	for k,v in pairs(lmap) 
	do
		table.insert(tbl,k)
	end 
	T.ahoCora = T.ac(tbl)
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
  	if T.LevelDB then
		T.LevelDB:close()
		T.LevelDB=nil
	end
	T.ahoCora=nil 
  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    --  EXTERNAL HOSTS 
    -- counter_guid = "{6D87918F-05E9-DECF-879D-B1C9468EEDC3}", 
	counter_guid = CGOPTS.GUID, 

	-- topper
	onbegintopperflush = function(engine, timestamp, meter)


		if meter==1 or meter==2  then
			if T.LevelDB==nil then 
			  local dbfile = T.env.get_config("App>DBRoot").."/config/PassiveDNSDB.level."..engine:instanceid();
			  T.LevelDB = leveldb.new()

			  local ret,errmsg = T.LevelDB:open(dbfile); 
			  if ret==false then
				T.logerror("Unable to open the level DB file ".. errmsg)
				T.LevelDB=nil
				return false
			  end 
			end
			T.meter_flushing=meter-1
			return true
		else
			-- we DONT want ontopperflush for other meters  
			return false
		end


	end,

    --  topper flush 
    ontopperflush  = function(engine, key, metric )

		-- need DB 
        if T.LevelDB==nil then  return; end 

		-- only IPv4 
		if #key ~= 11 then return; end 

		local ip="" ..tonumber(key:sub(1,2),16).."."
					..tonumber(key:sub(4,5),16).."."
					..tonumber(key:sub(7,8),16).."."
					..tonumber(key:sub(10,11),16)

		local dns=T.LevelDB:getval(ip)

		if dns then 

			local m = T.ahoCora:match_one(dns)
			if next(m)  then
				for k,v in pairs(m) do 
					local app = lmap[k]

					-- print("dns="..dns..' app='..app)

					if app then 
						engine:update_counter("{0D5FFF94-BDA1-4BDB-A13D-A5AED7D6A96C}", app, T.meter_flushing, metric*300) 
					else
						engine:update_counter("{0D5FFF94-BDA1-4BDB-A13D-A5AED7D6A96C}", k, T.meter_flushing, metric*300) 
					end
				end
			else
					engine:update_counter("{0D5FFF94-BDA1-4BDB-A13D-A5AED7D6A96C}", dns, T.meter_flushing, metric*300) 
			end
		else
			engine:update_counter("{0D5FFF94-BDA1-4BDB-A13D-A5AED7D6A96C}", "INTERNET", T.meter_flushing, metric*300) 
		end 
    end,

	-- end
	onendtopperflush = function(engine,meter)
		if T.LevelDB then
			T.LevelDB:close()
			T.LevelDB=nil
		end
	end,
  },
}
