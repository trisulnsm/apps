-- hostnames from DHCP ACK messages 
--  	a new counter group 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "DHCP Host ",
    description = "DHCP host", -- optional
    author = "Unleash", -- optional
  },

  countergroup = {

    control = {
      guid = "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", 
      name = "DHCP Hostnames",
      description = "Count DHCP hostname from IP",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Total",      "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Recv",       "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Xmit",       "Bps" },
    },  

  },
}
