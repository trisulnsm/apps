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

-- local dbg=require'debugger'

local FH = require'iprangemap'
require'mkconfig'

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

  -- --------------------------------------------
  -- override by trisulnsm_firehol.lua 
  -- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
  --
    T.active_config = make_config(
            T.env.get_config("App>DBRoot").."/config/trisulnsm_firehol.lua",
            {
                -- filename of FireHOL level1 Feed  - will trigger Sev-1 alert 
                Firehol_Filename_Level1 ="firehol_level1.netset",

                -- optional level3 - will create Sev-3 alert 
                Firehol_Filename_Level3 ="firehol_level3.netset",

                -- How much should blacklisted IP Recv for Priority elevation to MAJOR (1)
                Vol_Sev1_Alert_Recv=10000,

                -- How much should blacklisted IP Transmit for Priority elevation to MAJOR (1)
                Vol_Sev1_Alert_Xmit=20000,
            })

    T.intel_file_hashes = {} 
  
    -- Firehol 1: required - load into iprangemap struct 
    T.fhole_1 = TrisulPlugin.check_reload( T.env.get_config("App>DataDirectory") .. "/plugins/" ..  T.active_config.Firehol_Filename_Level1) 
    if T.fhole_1 == nil then 
      T.logerror("Sorry cant find firehol_level1 intel file. Follow instructions in README to download the file")
      return false
    end 

    -- Firehol 3 : optional 
    T.fhole_3 = TrisulPlugin.check_reload( T.env.get_config("App>DataDirectory") .. "/plugins/" ..  T.active_config.Firehol_Filename_Level3) 
    if T.fhole_3 == nil then 
      T.loginfo("firehol_level3 intel file not found, wont generate those alerts")
    end 

  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    -- monitor all external hosts 
    counter_guid = "{00AA77BB-0063-11A5-8380-FEBDBABBDBEA}", 

    -- As soon as a new key is seen , new keys repeat every X hours 
    -- real time
    onnewkey = function(engine, timestamp, key)
      local m = T.fhole_1:lookup_trisul(key)
      if m then 
        T.log("ONNEWKEY Found IP in FireHOL LEVEL1 Blacklist key="..key.. " ip="..readable_ip(key) )
        engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
            "06A:"..key..":p-0000_"..key..":p-0000","FireHOL-Level1",1,"IP "..readable_ip(key).." in FireHOL Level1 range "..tostring(m))
      end

      if T.fhole_3 then 
       local m2 = T.fhole_3:lookup_trisul(key)
       if m2 then 
          T.log("ONNEWKEY Found IP in FireHOL LEVEL3 Blacklist key="..key.. " ip="..readable_ip(key) )
          engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
                "06A:"..key..":p-0000_"..key..":p-0000","FireHOL-Level3",2,"IP "..readable_ip(key).." in FireHOL Level3 range "..tostring(m2))
        end
      end 
    end,

    -- onflush - used to check if data transfer happend , major alert 
    -- near real time 1-minute. Escalate priority if large data Xfer happens
    -- arrayofmetrics is an array containing counters , see LUA Docs for cg_monitor 
    onflush = function(engine, timestamp, key, arrayofmetrics )
      if T.fhole_3 then 
        local m = T.fhole_3:lookup_trisul(key)
        if m then 
          T.log("ONFLUSH Found IP in FireHOL Level3 Blacklist "..readable_ip(key))
          if arrayofmetrics[2] > T.active_config.Vol_Sev1_Alert_Recv  and 
            arrayofmetrics[3] > T.active_config.Vol_Sev1_Alert_Xmit then
              engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
                "06A:"..key..":p-0000_"..key..":p-0000","FireHOL-Xfer",1,
                "IP "..readable_ip(key).." in FireHOL range "..tostring(m).." exchanged "..tostring(arrayofmetrics[1]).. " bytes Elevated priority")
          end
        end
      end 
    end,

    -- beginflush : reload the list if ondisk hash changes 
    onbeginflush = function(engine,timestamp)

      -- Firehol 1: required - load into iprangemap struct 
      local new_map = TrisulPlugin.check_reload( T.env.get_config("App>DataDirectory") .. "/plugins/" ..  T.active_config.Firehol_Filename_Level1) 
      if new_map then
        T.fhole_1 = new_map
      end 

      -- Firehol 3: optional 
      local new_map = TrisulPlugin.check_reload( T.env.get_config("App>DataDirectory") .. "/plugins/" ..  T.active_config.Firehol_Filename_Level3) 
      if new_map then
        T.fhole_3 = new_map
      end 
    end,
  },

  -- Uses T.intel_file_hashes to reload intel file if hash changes on disk 
  check_reload = function(firehol_intel_file )
    if not file_exists(firehol_intel_file) then return nil end 
    local h = io.popen("md5sum   "..firehol_intel_file)
    local md5=  h:read("*a"):match('%w+') 
	h:close() 
    if T.intel_file_hashes[ firehol_intel_file ]  ~= md5 then
      T.log("Reloading FireHOL list , change detected")
      T.intel_file_hashes[ firehol_intel_file ] = md5
      local fholemap = FH.new()
      local status,errormsg = fholemap:load(firehol_intel_file)
      if status == false then 
        T.logerror("Error loading FireHOL list msg="..errormsg)
        return nil 
      else
        T.loginfo("Loaded FireHOL list Level-3 from "..firehol_intel_file)
      end 
      return fholemap
    end
  end 

}

