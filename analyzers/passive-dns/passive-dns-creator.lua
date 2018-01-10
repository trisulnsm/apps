--
-- passive-dns-creator.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Creates a real time MULTIPURPOSE PASSIVE DNS database 
-- DESCRIPTION: A passive DNS database observes DNS traffic and builds a IP->name
--        and name->IP lookup over time. For NSM purposes an IP->Name mapping is 
--        a crucial capability for real time streaming analytics. 
--
--        This script does the following
--        1. leveldb          - uses LUAJIT FFI to build a LEVELDB backend 
--        2. resource_monitor - listens to DNS and updates the leveldb  CNAME/A -> domain
-- 
local leveldb=require'tris_leveldb'

TrisulPlugin = { 

  id =  {
    name = "Passive DNS",
    description = "Listens to DNS traffic and builds a IP->Name DNS database", 
  },

  onmessage=function(msgid, msg)
    if msgid=='{4349BFA4-536C-4310-C25E-E7C997B92244}' then
      local dbaddr = msg:match("newleveldb=(%S+)")
      T.LevelWriter,_,T.LevelCloser = leveldb.from_addr(dbaddr);
    end
  end,


  -- open the LevelDB database  & create the reader/writer 
  onload = function() 
    T.pending,T.owner=false,false
  end,


  -- close 
  onunload = function()
    if T.owner then 
      T.log("Closing Leveldb from owner")
      T.LevelCloser()
    end 
  end, 


  -- resource_monitor  block 
  --
  resource_monitor   = {

    -- DNS RESOURCE 
    resource_guid = '{D1E27FF0-6D66-4E57-BB91-99F76BB2143E}',

    --  we will each each DNS resource from Trisul into this method
    --  since levelDB is 1:writer-N:reader - we lazily open the DB and
    --  transmit the handle to other instances. Once that is setup 
    --  we just store the mapping into the DB 
    onnewresource  = function(engine, resource )


      if T.LevelWriter == nil then 
        if engine:instanceid() == "0" and not T.pending then
          local dbfile = T.env.get_config("App>DBRoot").."/config/PassiveDNSDB.level";
          T.dbaddr = leveldb.open(dbfile); -- dont use local to prevent GC 
          T.pending = true
          T.owner=true
          engine:post_message_backend('{4349BFA4-536C-4310-C25E-E7C997B92244}', "newleveldb="..T.dbaddr) 
          engine:post_message_frontend('{4349BFA4-536C-4310-C25E-E7C997B92244}', "newleveldb="..T.dbaddr) 
        end
        return
      end

      for ip in  resource:label():gmatch("A%s+([%d%.]+)") do
        print(resource:uri().."="..ip)
        T.LevelWriter(ip,resource:uri())
      end


    end,

  }

}
