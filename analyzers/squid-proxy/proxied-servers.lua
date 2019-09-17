--
-- proxied-servers : a new counter group
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Create a new counter group
-- DESCRIPTION: Holds metrics for proxied servers 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Proxied Servers",
    description = "Proxied servers seen in CONNECT tunnel proxies like squid", 
  },

  -- countergroup block
  -- 
  countergroup = {

    -- control table 
	-- specify details of your new counter group you can use 
	-- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{B7571E87-F794-4BF6-A57A-EEA8A90F0324}",
      name = "Proxied Servers",
      description = "In/Out/Conns for proxy servers",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 10, 0, "Bytes", "Download bytes",    "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 10, 0, "Bytes", "Upload bytes",    "Bps" },
        {  2, T.K.vartype.COUNTER,      10, 0, "Hits",  "hits",  "Hits" },
    },  

  },
}
