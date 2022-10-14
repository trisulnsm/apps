--
-- Exchange X Flow 
--    counts TCP Recv/Xmit/UDP multicast 
-- 
--    actual-destination-ip/actual-source-ip/port/destination-multicast-ip 
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
      description = "Crosskey flow IP/IP/Port/MCastIP",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes/sec",  "TCP Recv",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "bytes/sec",  "TCP Xmit",    "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "bytes/sec",  "Multicast",    "Bps" },
    },  

  },
}
