--
-- skip_youtube.lua
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Fine grained control of PCAP storage
-- DESCRIPTION: Dont store packets from youtube,googlevideo,twitter,netflix 
--
-- 1. plug into a passiveDNS DB 
-- 2. when new flow is setup; check if IP maps to youtube/googlevideo/twitter use a pre compiledregex
-- 3. block matches, allow others 
-- 
-- Requires the PassiveDNS Lua plugin that extracts IP->Domain and broadcasts to all filters
-- 
local leveldb=require'tris_leveldb' 

function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

-- --------------------------------------------
-- override by /usr/local/var/lib/trisul-probe/dX/pX/contextX/config/trisulnsm_skip_youtube.lua 
--
DEFAULT_CONFIG = {

  DNS_Regex_To_Skip ="(youtube|googlevideo|twitter|ytimg|twimg|netflix|nflxvideo|nflximg|nflxext|acorn.tv|tubitv|atv-ext.amazon.com|atv-ps.amazon.com|hulu)"

}
-- --------------------------------------------

TrisulPlugin = { 

  id =  {
    name = "SKIP PCAP(YT)",
    description = "Skip youtube,twitter,netflix ", 
  },

  -- pre-Compile the regex 
  onload = function()

    -- load custom config if present 
    T.active_config = DEFAULT_CONFIG
    local custom_config_file = T.env.get_config("App>DBRoot").."/config/trisulnsm_skip_youtube.lua"
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

    T.re2x = T.re2( T.active_config.DNS_Regex_To_Skip) 
    T.LevelDB = nil 
  end,

  -- we listen to onmessage for a pDNS attach event (from the PassiveDNS app )
  message_subscriptions = { '{4349BFA4-536C-4310-C25E-E7C997B92244}' },

  -- get a levelDB handle 
  onmessage=function(msgid, msg)
    if msgid=='{4349BFA4-536C-4310-C25E-E7C997B92244}' then
      if not T.LevelDB then 
    local dbaddr = msg:match("newleveldb=(%S+)")
        T.LevelDB = leveldb.new() 
        T.LevelDB:fromaddr(dbaddr);
      end
    end
  end,

  -- packet_storage block
  -- lookup IPZ (usually the outside IP) -> domain name
  -- use the Regex to filter the domain name 
  packet_storage   = {

    filter = function( engine, timestamp, flow ) 
      if T.LevelDB then 
        local name =  T.LevelDB( flow:ipz_readable());
        if name then 
          local ok, category = T.re2x:partial_match_c1( name)
          if ok then 
            print( T.contextid .. " skip flow=" .. flow:to_s() .. "   map=" .. category) 
            return 0
          end 
        end
      end
      return -1 
    end

  },
}
