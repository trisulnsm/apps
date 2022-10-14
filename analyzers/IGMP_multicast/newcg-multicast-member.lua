-- Multicast Members 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Multicast Members",
    description = "Unicast IP that are members of multicast group hosts", -- optional
    author = "Unleash", -- optional
  },

  countergroup = {

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
        {  0, T.K.vartype.RATE_COUNTER, 1000, 0, "bytes", 		"Total",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 1000, 0, "bytes", 		"Recv",    "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 1000, 0, "bytes", 	"Transmit",    "Bps" },
    },  

  },
}
