--
-- firehol.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Scan using FIREHOL IP CRIME list http://iplists.firehol.org/
-- DESCRIPTION: Install this script scan all their Traffic against the excellent 
--              (low false positive)  FIREHOL list
--
-- DEV NOTE:    We use a very fast custom built IP Range Map in LUA to match entire
--              ip spaces. 
--
-- OUTPUT:      Low priority alert when IP hits, Level 1 alert when Data transfer happens 
--              in both directions. 
-- 

local FH = require'iprangemap'

local FIREHOL_FILENAME="firehol_level1.netset" 
local CHECK_SECONDS=1800			
local VOL_SEV1_ALERT_RECV=10000
local VOL_SEV1_ALERT_XMIT=20000


-- converts key in trisul format to readable 
function readable_ip(key)
    local pmatch,_, b1,b2,b3,b4= key:find("(%x+)%.(%x+)%.(%x+)%.(%x+)")
    return string.format("%d.%d.%d.%d",tonumber(b1,16),tonumber(b2,16),tonumber(b3,16),tonumber(b4,16) )
end


TrisulPlugin = { 

  id =  {
    name = "FireHOL tracker",
    description = "Scans host traffic vs this excellent list ", 
  },

  -- load the list 
  onload = function()
	T.fhole = FH.new()
    local firehol_intel_file  = T.env.get_config("App>DataDirectory") .. "/plugins/" ..  FIREHOL_FILENAME
    local status,errormsg = T.fhole:load(firehol_intel_file)
    if status == false then 
      T.logerror("Error loading filehol list msg="..errormsg)
      return false
    end
	T.last_load=os.time() 
  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    -- monitor all hosts 
    counter_guid = "{00AA77BB-0063-11A5-8380-FEBDBABBDBEA}", 

    -- As soon as a new key is seen , new keys repeat every X hours 
	-- real time
    onnewkey = function(engine, timestamp, key)
      local m = T.fhole:lookup_trisul(key)
      if m then 
        T.log("ONNEWKEY Found IP in FireHOL Blacklist"..key)
        engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
            "06A:"..key..":p-0000_"..key..":p-0000","FireHOL",3,"IP "..readable_ip(key).." in FireHOL range "..tostring(m))
      end
    end,

    -- onflush - used to check if data transfer happend , major alert 
	-- near real time 1-minute 
    onflush = function(engine, timestamp, key, arrayofmetrics )
      local m = T.fhole:lookup_trisul(key)
      if m then 
	    local priority = 3 
		if arrayofmetrics[2] > VOL_SEV1_ALERT_RECV  and arrayofmetrics[3] > VOL_SEV1_ALERT_XMIT then
			priority=1
		end
        T.log("ONFLUSH Found IP in FireHOL Blacklist "..readable_ip(key))
        engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
            "06A:"..key..":p-0000_"..key..":p-0000","FireHOL",priority,"IP "..readable_ip(key).." in FireHOL range "..tostring(m))
      end
    end,

	-- beginflush : reload the list every 30 minutes
	onbeginflush = function(engine,timestamp)
		if os.time() - T.last_load  > CHECK_SECONDS then 
			T.last_load=os.time()
			T.log("Reloading FireHOL list after interval "..CHECK_SECONDS)
			TrisulPlugin.onload()
		end
	end

  },
}

