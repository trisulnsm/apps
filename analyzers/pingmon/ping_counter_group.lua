--
-- ping_counter_group.lua skeleton
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Counts LATENCY ms  to be used for PING MONITOR Service of Trisul 
--
-- {4DF11F00-B726-4260-5F83-0D9891197B45}
-- 
-- 
TrisulPlugin = { 

  id =  {
    name = "PING Latency ",
    description = "Latency of host tested with PING "
  },

  -- countergroup block
  -- 
  countergroup = {

    control = {
      guid = "{4DF11F00-B726-4260-5F83-0D9891197B45}", 
      name = "PING Latency",
      description = "Monitors latency of PINGs",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.GAUGE,      100, "Latency",  "latency",  "ms" },
    },  


  },
}
