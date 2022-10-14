-- Multicast Hosts
--  	Tracks all the 224.0.0.0 hosts 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "MCast Host ",
    description = "Mcast host", -- optional
    author = "Unleash", -- optional
  },

  countergroup = {

    control = {
      guid = "{2792D434-496E-40C9-5E2D-73B60623A631}", 
      name = "Multicast Hosts",
      description = "Count multicast traffic for members ",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 1000, 0, "bytes", 		"Total",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 1000, 0, "bytes", 		"Recv",    "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 1000, 0, "bytes", 	"Transmit",    "Bps" },
    },  

  },
}
