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
local FIREHOL_FILENAME = "firehol_level1.netset"

TrisulPlugin = { 

  id =  {
    name = "FireHOL tracker",
    description = "Scans host traffic vs this excellent list ", 
  },

  -- load the list 
  onload = function()
  T.fhole = FH.new()
    local firehol_intel_file  = T.env.get_config("App>DataDirectory") .. "/" ..  FIREHOL_FILENAME
    local status,errormsg = T.fhole:load(firehol_intel_file)
    if status == false then 
      T.logerror("Error loading filehol list msg="..errormsg)
      return false
    end
  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    -- monitor all hosts 
    counter_guid = "{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}",

    -- As soon as a new key is seen , new keys repeat every X hours 
    onnewkey = function(engine, timestamp, key)
      local m = T.fhole:lookup(key)
      if m then 
        T.log("Found IP in FireHOL Blacklist"..key)
        engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}" ,             
            nil,"FireHOL",2,"Found alert in FireHOL range "..tostring(m))
      end
    end,

  },
}

