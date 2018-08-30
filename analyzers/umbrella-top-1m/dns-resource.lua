--
-- dns-resource.lua skeleton
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Check all DNS requests w/ Umbrella Top-1M
-- DESCRIPTION: If any dont match count them up 
-- 
local LDB=require'tris_leveldb'

TrisulPlugin = { 

  -- id block
  --
  id =  {
    name = "DNS Monitor for Umbrella-Top1M",
    description = "Meter out of 1M", 
  },

  onload=function()
  end, 

  -- resource_monitor block 
  --
  resource_monitor  = {

    -- DNS guid 
    resource_guid = '{D1E27FF0-6D66-4E57-BB91-99F76BB2143E}',

    -- by default called every "stream snapshot interval" 
    -- of 60 seconds
    onbeginflush = function(engine) 

      T.ldb=LDB:new()
      local umbrella1m_db = T.env.get_config("App>DataDirectory") .. "/plugins/umbrella.level." ..  engine:id()
      local stat,errmsg=T.ldb:open(umbrella1m_db)
      if not stat then
        T.logerror("Error opening Umbrella-Top-1M levelDB file msg="..errmsg)
        print("Error opening Umbrella-Top-1M levelDB file msg="..errmsg)

        T.ldb=nil
      end 

    end,


    -- check each DNS uri
    onflush = function(engine, resource) 
      if T.ldb==nil then return end 
      local v=T.ldb:getval(resource:uri())
      if v  then
        engine:update_counter("{3317EEB3-CE83-4C8F-E321-79E7194BD974}",
                    resource:uri(),
                    0,
                    1)
      end
    end,

    -- close the umbrella compiled 
    onendflush = function(engine) 
      if T.ldb then
        T.ldb:close()
        T.ldb=nil
      end
    end,

  },


  -- countergroup block
  -- 
  countergroup = {

    -- control table 
    -- specify details of your new counter group you can use 
    -- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
        guid="{3317EEB3-CE83-4C8F-E321-79E7194BD974}",
        name = "Outside Umbrella Top-1M",
        description = "Meter domains outside the Cisco Top-1M",
        bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.COUNTER,      10, 0, "Hits",  "hits",  "hits" },
    },  
  },
}
