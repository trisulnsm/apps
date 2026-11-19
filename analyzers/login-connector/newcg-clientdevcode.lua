-- Client devCode counter group
--  	keyed by the login devCode (e.g. FTC_OAUTH)
--
TrisulPlugin = {

  -- the ID block, you can skip the fields marked 'optional '
  --
  id =  {
    name = "Login Client Devcode",
    description = "Traffic metered per login devCode", -- optional
    author = "trisul", -- optional
  },

  countergroup = {

    control = {
      guid = "{373024C2-6018-43FA-B39B-1AB628E65878}",
      name = "ClientDevcode",
      description = "Count traffic per login devCode",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Total",      "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Recv",       "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Xmit",       "Bps" },
    },

  },
}
