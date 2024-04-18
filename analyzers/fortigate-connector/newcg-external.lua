-- External IP but from Forti syslog 
--  	a new counter group 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Syslog External IP",
    description = "External IP from syslog", -- optional
    author = "Unleash", -- optional
  },

  countergroup = {

    control = {
      guid = "{459BACD7-8F16-428F-2882-9DED4801C46D}", 
      name = "External Syslog IP",
      description = "Count IP outside from syslog",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Total",      "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Recv",       "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Xmit",       "Bps" },
    },  

  },
}
