--
-- ping alert group. For DOWN and UP 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     CUstom alert for PING reachability events 
--
--
-- {20100949-751A-43D1-685F-F860E4D4091B}
-- 
TrisulPlugin = { 


  id =  {
    name = "PING Alerts",
    description = "Alerts on PING reachability lost", -- optional
  },

  -- alertgroup  block
  -- 
  alertgroup  = {

    control = {
      guid = "{20100949-751A-43D1-685F-F860E4D4091B}",
      name = "PING Alerts",
      description = "Reachability events from PING test",
    },

  },
}
