--
-- new_counter_group.lua skeleton
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Create a new counter group
-- DESCRIPTION: Use this to create your own Metrics counter group with associated
--              meters and key mappings 
--
-- 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "IP x Multicast",
    description = "Mapping ip to multicast", -- optional
    author = "Unleash", -- optional
    version_major = 1, -- optional
    version_minor = 0, -- optional
  },

  -- countergroup block
  -- 
  countergroup = {

    -- control table 
	-- specify details of your new counter group you can use 
	-- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{2792D434-496E-40C9-5E2D-73B60623A631}", 
      name = "Multicast Hosts",
      description = "Count multicast traffic for members ",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 1000, 0, "Total", "bytes",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 1000, 0, "Recv", "bytes",    "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 1000, 0, "Transmit", "bytes",    "Bps" },
    },  

  },
}
