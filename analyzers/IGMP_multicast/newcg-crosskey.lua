--
-- crosskey multicast 
--
-- 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Exchange XFlow",
    description = "Meter packet lengths ", -- optional
  },

  -- countergroup block
  -- 
  countergroup = {

    -- control table 
	-- specify details of your new counter group you can use 
	-- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{942AB99F-7A65-4B2E-6F6C-A3050F0F7B35}", 
      name = "Exchange XFlow",
      description = "Crosskey flow IP/IP/Port",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "TCP Recv",  "bytes",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "TCP Xmit",  "bytes",    "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "Multicast",  "bytes",    "Bps" },
    },  

  },
}
