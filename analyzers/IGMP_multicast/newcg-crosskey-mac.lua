--
-- Exchange Multicast MAC 
--    counts UDP  for Fin cloud 
-- 
--    actual-destination-ip/actual-source-ip/mac 
-- 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Multicast MAC ",
    description = "Meter multicast traffic flow IP/IP flow ", -- optional
  },

  -- countergroup block
  -- 
  countergroup = {

    control = {
      guid = "{095E0C56-D17F-4634-A0B8-E000B4E85140}", 
      name = "Exchange MAC",
      description = "Crosskey flow IP/IP/MAC-multicast",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes/sec",  "Multicast ",    "Bps" },
    },  

  },
}
