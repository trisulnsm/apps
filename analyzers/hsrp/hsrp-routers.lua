TrisulPlugin = { 


  -- the ID block,
  -- 
  id =  {
    name = "HSRPRouterCG",
    description = "HSRP to track IP of router ", -- optional
  },
  -- countergroup info block
  countergroup = {

    control = {
      guid = "{47FB78D7-76F6-4AF0-D45A-7D9BA6E83762}",
      name = "HSRP Routers",
      description = "Track HSRP router",
      bucketsize = 30,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short
    --60
    meters = {
        {  0, T.K.vartype.GAUGE, 10, 0, "Status", "hits",    "hits" },
    },

  },
}