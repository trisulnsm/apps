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
    name = "Multicast Members",
    description = "Meter packet lengths ", -- optional
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
      guid = "{51177E0A-7535-46B7-1477-9F0E0E0F9808}", 
      name = "Multicast Members",
      description = "Count multicast traffic for members ",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "Total", "bytes",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "Recv", "bytes",    "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "Transmit", "bytes",    "Bps" },
    },  

  },
}
