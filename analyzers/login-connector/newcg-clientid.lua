-- ClientId counter group
--  	keyed by the login ClientId (e.g. FT045507)
--
TrisulPlugin = {

  -- the ID block, you can skip the fields marked 'optional '
  --
  id =  {
    name = "Login ClientId",
    description = "Traffic metered per login ClientId", -- optional
    author = "trisul", -- optional
  },

  countergroup = {

    control = {
      guid = "{C9212EE1-A8EC-4A9F-9062-D1E87E5DF616}",
      name = "ClientId",
      description = "Count traffic per login ClientId",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 5000, 0, "bytes", 		"Total",      "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 5000, 0, "bytes", 		"Recv",       "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 5000, 0, "bytes", 		"Xmit",       "Bps" },
    },

  },
}
