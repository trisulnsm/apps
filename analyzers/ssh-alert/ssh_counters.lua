--
-- ssh_counters
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     For SSH monitor
-- DESCRIPTION: Counts 
--        1. server and client types. Stringsl like Putty / openssh etc
--		  2. server and client successful logins - IP Addresses 
-- 
-- 
TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "ssh endpoints cg",
  },

  countergroup = {

    control = {
      guid = "{E6A387F4-5B51-4C8B-86FD-DE6258D3F214}",
      name = "SSH Endpoints",
      description = "SSH Client and Servers",
	  bucketsize = 60,
    },

    -- meters table
    -- id, type of meter, toppers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.COUNTER,      20, "SSH Server Types",  "Hits",  "hits" },
        {  1, T.K.vartype.COUNTER,      20, "SSH Client Types",  "Hits",  "hits" },
        {  2, T.K.vartype.COUNTER,      20, "SSH Server Logins", "Hits",  "hits" },
        {  3, T.K.vartype.COUNTER,      20, "SSH Client Logins", "Hits",  "hits" },
    },  

  }

}
