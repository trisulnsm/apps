--
-- counter_monitor.lua skeleton
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Process metrics as they are streamed and snapshotted 
-- DESCRIPTION: If you are working off metrics streams, this is the script for you
-- 
-- 
-- 
function ipstr_tokey(ipstr)
  local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
end



TrisulPlugin = { 

  -- id block 
  id =  {
    name = "Multicast Host",
    description = "Listen and process events in 'Hosts' counter group",   -- optional
    author = "Unleash",                       -- optional
    version_major = 1,                        -- optional
    version_minor = 0,                        -- optional
  },

  -- 
  -- common functions onload, onunload, onmessage()..

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
 		T.multicast_mapping = { }  
  end,


  -- any messages you want to handle for state management 
  message_subscriptions =  { "{18D4B77A-AA86-4924-2201-6ABE892F2937}" } ,

  -- WHEN CALLED: when another plugin sends you a message 
  onmessage = function(msgid, msg)

	local mips, sips = msg:match("(%S+)=(%S+)")

	local mip = ipstr_tokey(mips)
	local sip = ipstr_tokey(sips)


	if T.multicast_mapping[mip] == nil then 
		T.multicast_mapping[mip] = {}
	end
	
	T.multicast_mapping[mip][sip] = true 
    
  end,


  -- cg_monitor block
  -- 
  cg_monitor  = {

    -- which counter group do you want to monitor
    -- need a separate lua file for each type of countergroup! 
    -- the GUID {4CD..} below represents the Hosts counter group
    -- 
    counter_guid = "{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}",


    -- WHEN CALLED: before an item  is flushed to the Hub node  
    onflush = function(engine, timestamp,key, metrics) 

		local mmap = T.multicast_mapping[key]
    if mmap then

        engine:update_counter("{2792D434-496E-40C9-5E2D-73B60623A631}", key, 0, tonumber(metrics[1])*60 )
        engine:update_counter("{2792D434-496E-40C9-5E2D-73B60623A631}", key, 1, tonumber(metrics[2])*60 )
        engine:update_counter("{2792D434-496E-40C9-5E2D-73B60623A631}", key, 2, tonumber(metrics[3])*60 )

       for k,v in pairs(mmap) do

         engine:update_counter("{51177E0A-7535-46B7-1477-9F0E0E0F9808}", k, 0, tonumber(metrics[1])*60 )
         engine:update_counter("{51177E0A-7535-46B7-1477-9F0E0E0F9808}", k, 1, tonumber(metrics[2])*60 )
         engine:update_counter("{51177E0A-7535-46B7-1477-9F0E0E0F9808}", k, 2, tonumber(metrics[3])*60 )


         engine:update_counter("{074E78B6-E032-4B22-B085-12A2E72E1BB7}", k.."\\\\"..key, 0, tonumber(metrics[1])*60 )
         engine:update_counter("{074E78B6-E032-4B22-B085-12A2E72E1BB7}", k.."\\\\"..key, 1, tonumber(metrics[2])*60 )
         engine:update_counter("{074E78B6-E032-4B22-B085-12A2E72E1BB7}", k.."\\\\"..key, 2, tonumber(metrics[3])*60 )
       end

    end

    end,

  },

}
