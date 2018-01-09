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


function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end


-- --------------------------------------------
-- override by trisul_apps_save_exe.config.lua 
-- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
--
DEFAULT_CONFIG = {

  -- filename of FireHOL Feed 
  Firehol_Filename ="firehol_level1.netset",

  -- How frequently to check for new files, sync with your cron update 
  Check_Seconds=1800,

  -- How much should blacklisted IP Recv for Priority elevation to MAJOR (1)
  Vol_Sev1_Alert_Recv=10000,

  -- How much should blacklisted IP Transmit for Priority elevation to MAJOR (1)
  Vol_Sev1_Alert_Xmit=20000,
}
-- --------------------------------------------



-- converts key in trisul format to readable 
function readable_ip(key)
  local pmatch,_, b1,b2,b3,b4= key:find("(%x+)%.(%x+)%.(%x+)%.(%x+)")
  if b1 == nil then return "invalid-ip"; end  
  return string.format("%d.%d.%d.%d",tonumber(b1,16),tonumber(b2,16),tonumber(b3,16),tonumber(b4,16) )
end


TrisulPlugin = { 

  id =  {
    name = "FireHOL tracker",
    description = "Scans host traffic vs this excellent list ", 
  },

  -- load the list 
  onload = function()

    -- load custom config if present 
    T.active_config = DEFAULT_CONFIG
    local custom_config_file = T.env.get_config("App>DBRoot").."/config/trisulnsm_firehol.lua"

    if file_exists(custom_config_file) then 
      local newsettings = dofile(custom_config_file) 
      T.log("Loading custom settings from ".. custom_config_file)
      for k,v in pairs(newsettings) do 
        T.active_config[k]=v
        T.log("Loaded new setting "..k.."="..v)
      end
    else 
      T.log("Loaded default settings")
    end


    -- load the FireHOL into IP Range Map datastruct
    T.fhole = FH.new()
    local firehol_intel_file  = T.env.get_config("App>DataDirectory") .. "/plugins/" ..  T.active_config.Firehol_Filename
    local status,errormsg = T.fhole:load(firehol_intel_file)
    if status == false then 
	  T.last_load=0
      T.logerror("Error loading FireHOL list msg="..errormsg)
      return false
    end
    T.last_load=os.time() 

  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    -- monitor all external hosts 
    counter_guid = "{00AA77BB-0063-11A5-8380-FEBDBABBDBEA}", 

    -- As soon as a new key is seen , new keys repeat every X hours 
    -- real time
    onnewkey = function(engine, timestamp, key)
      local m = T.fhole:lookup_trisul(key)
      if m then 
        T.log("ONNEWKEY Found IP in FireHOL Blacklist key="..key.. " ip="..readable_ip(key) )
        engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
            "06A:"..key..":p-0000_"..key..":p-0000","FireHOL",3,"IP "..readable_ip(key).." in FireHOL range "..tostring(m))
      end
    end,

    -- onflush - used to check if data transfer happend , major alert 
    -- near real time 1-minute. Escalate priority if large data Xfer happens
    onflush = function(engine, timestamp, key, arrayofmetrics )
      local m = T.fhole:lookup_trisul(key)
      if m then 
        T.log("ONFLUSH Found IP in FireHOL Blacklist "..readable_ip(key))
        if arrayofmetrics[2] > T.active_config.Vol_Sev1_Alert_Recv  and 
          arrayofmetrics[3] > T.active_config.Vol_Sev1_Alert_Xmit then
            engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
              "06A:"..key..":p-0000_"..key..":p-0000","FireHOL",1,
              "IP "..readable_ip(key).." in FireHOL range "..tostring(m).." exchanged "..tostring(arrayofmetrics[0]).. " bytes Elevated priority")
        else
            engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
              "06A:"..key..":p-0000_"..key..":p-0000","FireHOL",3,"IP "..readable_ip(key).." in FireHOL range "..tostring(m))
        end
      end
    end,

    -- beginflush : reload the list every 30 minutes
    onbeginflush = function(engine,timestamp)
      if os.time() - T.last_load  > T.active_config.Check_Seconds then 
        T.last_load=os.time()
        T.log("Reloading FireHOL list after interval "..T.active_config.Check_Seconds)
        TrisulPlugin.onload()
      end
    end
  },
}

