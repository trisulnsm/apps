--
-- Flow watcher - alert when forbidden flows are seen 
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Detect when host isolation is broken 
-- 
TrisulPlugin = { 

  id =  {
    name = "Flow Isolator",
    description = "Monitor endpoints for banned convos  ",
    author = "Unleash",                       -- optional
    version_major = 1,                        -- optional
    version_minor = 0,                        -- optional
  },


  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    -- your code 
  end,



  -- sg_monitor block
  -- sg = session group
  sg_monitor  = {

    -- that guid refers to IPv4/IPv6 flows (you can skip the session_guid field if you want its the default )
    session_guid = '{99A78737-4B41-4387-8F31-8077DB917336}', -- optional

    -- WHEN CALLED: a new flow is seen 
    onnewflow  = function(engine, flow ) 

		print(flow:key()) 
		if  flow:key():match("C0.A8.01.??")  then
		  if not  flow:key():match("C0.A8.01.4D")  then 

         -- alert
          engine:add_alert( "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",
                    flow:key(),
                    "BANNED-CONN",
                    1,
                    "End point tried to connect with another end point.  Potentially stopped")
          T.logwarning("BANNED-CONN End point tried to connect with another End point")

		  end
		end
    end,

    -- WHEN CALLED: before a flow is flushed to the Hub node  
    onflush = function(engine, flow) 
      -- your lua code goes here 
    end,

  },

}
