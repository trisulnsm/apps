--
-- prune_counters.lua skeleton
--
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Prune-PCAP",
    description = "Performance of PCAPs", -- optional
  },

  -- countergroup block
  -- 
  countergroup = {

    -- control table 
	-- specify details of your new counter group you can use 
	-- 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{1E92FD61-5129-499D-0A12-883E9FC1C00C}",
      name = "Prune-PCAP",
      description = "Which domain matches PCAPs were pruned",
      bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.COUNTER,      20, 20, "Flows",  "flows",  "Flws" },
    },  

  },
}
