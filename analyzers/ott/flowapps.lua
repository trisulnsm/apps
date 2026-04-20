--
-- ispapps
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Uses a ldb lookup DB to assign names .. then do a crosskey: ifkey\app 
local leveldb = require 'tris_leveldb'
local lmap = require 'appmap'

TrisulPlugin = { 

  id =  {
    name = "ISP Apps",
    description = "ISP apps metering based on signature database ",
  },


  -- common functions onload, onunload, onmessage()..

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
    T.LevelDB = nil
    local tbl = {}
    for k in pairs(lmap) do
      table.insert(tbl, k)
    end
    T.ahoCora = T.ac(tbl)
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    if T.LevelDB then
      T.LevelDB:close()
      T.LevelDB = nil
    end
    T.ahoCora = nil
  end,

  -- any messages you want to handle for state management 
  message_subscriptions = {},

  -- WHEN CALLED: when another plugin sends you a message 
  onmessage = function(msgid, msg)
    -- your code 
  end,


  -- sg_monitor block
  -- sg = session group
  sg_monitor  = {

    -- that guid refers to IPv4/IPv6 flows (you can skip the session_guid field if you want its the default )
    session_guid = '{99A78737-4B41-4387-8F31-8077DB917336}', -- optional

    -- WHEN CALLED: when a flow FLUSH operation starts 
    -- by default called every "stream snapshot interval" of 60 seconds
    onbeginflush = function(engine) 
      if T.LevelDB==nil then 
        local dbfile = T.env.get_config("//App/DBRoot").."/config/PassiveDNSDB.level."..engine:instanceid();
        T.LevelDB = leveldb.new()

        local ret,errmsg = T.LevelDB:open(dbfile); 
        if ret==false then
          print("Unable to open the level DB file ".. errmsg)
          T.LevelDB=nil
          return
        end
      end
    end,

    -- WHEN CALLED: before a flow is flushed to the Hub node  
    onflush = function(engine, flow) 
      
      if T.LevelDB == nil or T.ahoCora == nil then return end

      local ip_a = flow:flow():ipa_readable()
      local ip_z = flow:flow():ipz_readable()
      local dns_a = T.LevelDB:getval(ip_a)
      local dns_z = T.LevelDB:getval(ip_z)

      if dns_a == nil and dns_z == nil then return  end

      
       -- mostly ott matches server side Z 
      if dns_z then
        local m = T.ahoCora:match_one(dns_z)
        if next(m)  then
          for k,v in pairs(m) do 
            local app = lmap[k] or k or dns_z or "INTERNET"

            local XKCG = "{32A268B9-27BD-4661-9C9D-0A0D633C041D}"

            -- cross key
            local ifapp1 = flow:flow():netflow_router() .. "_".. flow:flow():netflow_ifindex_in() .. "\\" .. app
            local ifapp2 = flow:flow():netflow_router() .. "_".. flow:flow():netflow_ifindex_out() .. "\\" .. app
            engine:update_counter(XKCG, ifapp1, 0, flow:az_bytes() ) 
            engine:update_counter(XKCG, ifapp1, 1, flow:za_bytes() ) 
            engine:update_counter(XKCG, ifapp2, 0, flow:az_bytes() ) 
            engine:update_counter(XKCG, ifapp2, 1, flow:za_bytes() ) 
          end
        end
      end
    end,

    -- WHEN CALLED: end of flush
    onendflush = function(engine) 
      if T.LevelDB then
        T.LevelDB:close()
        T.LevelDB=nil
      end
    end,

  },

}
