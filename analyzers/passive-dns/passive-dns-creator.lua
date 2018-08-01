--
-- passive-dns-creator.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Creates a real time MULTIPURPOSE PASSIVE DNS database 
-- DESCRIPTION: A passive DNS database observes DNS traffic and builds a IP->name
--            and name->IP lookup over time. 
--
-- This script does the following
--        1. leveldb          - uses LUAJIT FFI to build a LEVELDB backend 
--        2. resource_monitor - listens to DNS and updates the leveldb  CNAME/A -> domain
-- 

local leveldb=require'tris_leveldb'

TrisulPlugin = { 

  id =  {
    name = "Passive DNS",
    description = "Listens to DNS traffic and builds a IP->Name DNS database", 
  },

  -- All those interested in plugging into PDNS listen tothis message and
  -- get a handle to the LevelDB database.  The owner of handle skips it  
  onmessage=function(msgid, msg)
    if msgid=='{4349BFA4-536C-4310-C25E-E7C997B92244}' then
      local dbaddr = msg:match("newleveldb=(%S+)")
      if not T.LevelDB then 
        T.LevelDB = leveldb.new() 
        T.LevelDB:fromaddr(dbaddr);
      end
    end
  end,

  -- open the LevelDB database  & create the reader/writer 
  onload = function() 
    T.LevelDB=nil 
  end,

  -- close 
  onunload = function()
    T.loginfo("Closing Leveldb from owner")
    if T.LevelDB then 
      T.LevelDB:close()
    end 
  end, 

  -- resource_monitor  block 
  --
  resource_monitor   = {

    -- watch the DNS RESOURCE STREAM 
    resource_guid = '{D1E27FF0-6D66-4E57-BB91-99F76BB2143E}',

    --  we will each each DNS resource from Trisul into this method
    --  Engine-0 owns the LevelDB , others share the handle through a broadcast
    --  mechanism. Luckily LevelDB supports N reader/writer per process 
    onnewresource  = function(engine, resource )

    -- TODO : explain whats going on here. 
    -- basically openign the sharing the levelDB handle with all other Trisul LUA 
    -- levelDB is multithread 
      if T.LevelDB == nil then
        if engine:instanceid()=="0" then 
          local dbfile = T.env.get_config("App>DBRoot").."/config/PassiveDNSDB.level";
          T.LevelDB = leveldb.new()
          T.LevelDB:open(dbfile); 
          engine:post_message_backend( '{4349BFA4-536C-4310-C25E-E7C997B92244}', "newleveldb="..T.LevelDB:toaddr() ) 
          engine:post_message_frontend('{4349BFA4-536C-4310-C25E-E7C997B92244}', "newleveldb="..T.LevelDB:toaddr() ) 
        else
          -- other backend engines have to wait for LevelDB Handle from post_message_xx 
          return 
        end
      end

      -- the actual storage is straight forward 
      -- push all the A  IPv4 
      local ts = tostring(os.time())
      for ip in  resource:label():gmatch("A%s+([%d%.]+)") do
        T.LevelDB:put(ip,resource:uri())
        -- use a sentinel and push ip/A/name
        T.LevelDB:put(ip.."/A/"..resource:uri(), ts)
        -- use a sentinel and push name/A/ip
        T.LevelDB:put(resource:uri().."/A/"..ip, ts)
      end

      -- push all the AAAA IPv6
      for ip6 in  resource:label():gmatch("AAAA%s+([%x%:]+)") do
        T.LevelDB:put(ip6,resource:uri())
        -- use a sentinel and push ipv6/6A/name
        -- notice trick because /A will match /AAAA as levelDB sentinel 
        T.LevelDB:put(ip6.."/6A/"..resource:uri(), ts)
        -- use a sentinel and push name/6A/ipv6
        T.LevelDB:put(resource:uri().."/6A/"..ip6, ts) 
      end

    end,
  }
}

