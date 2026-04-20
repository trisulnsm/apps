--
-- OTT crosskey explicit 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     OTT explicit crosskey 
-- 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "OTT XKey",
    description = "OTT XKey", -- optional
  },

  -- countergroup block
  -- 
  countergroup = {

    -- control table 
	-- specify details of your new counter group you can use 
	-- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{113091EA-CF82-46E0-DE38-9A8C42DD0279}",
      name = "OTT XKey",
      description = "OTT XKey",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "Bytes Receive", "bytes recv",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "Bytes Transmit", "bytes xmit",    "Bps" },
    },  

  },
}
