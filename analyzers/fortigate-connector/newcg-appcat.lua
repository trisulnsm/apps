-- App Cat 
--  	app category 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "App Category ",
    description = "Application Category ", -- optional
    author = "Unleash", -- optional
  },

  countergroup = {

    control = {
      guid = "{2DE5A613-BC31-4C73-1EAA-B527FDD40E7D}", 
      name = "App Category",
      description = "Count per app category",
      bucketsize = 60,
    },

    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Total",      "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Recv",       "Bps" },
        {  2, T.K.vartype.RATE_COUNTER, 100, 0, "bytes", 		"Xmit",       "Bps" },
    },  

  },
}
