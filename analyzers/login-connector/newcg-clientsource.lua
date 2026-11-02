-- Client source counter group
--  	keyed by the login source (e.g. FTC_OAUTH)
--
TrisulPlugin = {

  -- the ID block, you can skip the fields marked 'optional '
  --
  id =  {
    name = "Login Client Source",
    description = "Traffic metered per login source", -- optional
    author = "trisul", -- optional
  },

  countergroup = {

    control = {
      guid = "{009EBF17-72A7-49E7-81B0-3979497509D5}",
      name = "ClientSource",
      description = "Count traffic per login source",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Total",      "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Recv",       "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Xmit",       "Bps" },
    },

  },
}
