--
-- OTTAPPS
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     OTT Apps for entire network 
-- 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "OTT Apps",
    description = "OTT Apps", -- optional
  },

  -- countergroup block
  -- 
  countergroup = {

    -- control table 
	-- specify details of your new counter group you can use 
	-- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{0D5FFF94-BDA1-4BDB-A13D-A5AED7D6A96C}",
      name = "OTT Apps",
      description = "OTT Apps",
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
