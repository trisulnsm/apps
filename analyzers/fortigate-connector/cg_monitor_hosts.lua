--
-- counter_monitor.lua skeleton
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Process metrics and update new counter group USERID with the hostname 
--              instead of IP Address 
-- 
function ipstr_tokey(ipstr)
  local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
end



TrisulPlugin = { 

  -- id block 
  id =  {
    name = "DHCP DB",
    description = "DHCP counter group in database",   -- optional
  },

  -- 
  -- common functions onload, onunload, onmessage()..

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
 		T.dhcp_map  = { }  
  end,


  -- any messages you want to handle for state management 
  message_subscriptions =  { "{DE53D193-9A98-4443-2289-84E537A5820A}" },

  -- WHEN CALLED: when another plugin sends you a message 
  onmessage = function(msgid, msg)


	local t= {} 
	for str in string.gmatch(msg, "([^%s]+)") do
		table.insert(t, str)
	end


	T.dhcp_map[ipstr_tokey(t[1])] = t 

  end,


  -- cg_monitor block
  -- 
  cg_monitor  = {

    -- attach to internal hosts counter group
    -- 
    counter_guid = "{889900CC-0063-11A5-8380-FEBDBABBDBEA}",


    -- WHEN CALLED: before an item  is flushed to the Hub node  
    onflush = function(engine, timestamp,key, metrics) 

		local mp= T.dhcp_map[key]

		if mp then

			if timestamp > tonumber(mp[4])  then
				print("Lease expired for key.."..key)
				T.dhcp_map[key]=nil
				return
			end
			-- print(""..timestamp.." "..engine:id().." Got map..".. table.concat(mp,' '))

			local newkey=mp[2]
			engine:update_counter( "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", newkey, 0, 60*metrics[1])
			engine:update_counter( "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", newkey, 1, 60*metrics[2])
			engine:update_counter( "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", newkey, 2, 60*metrics[3])
		else
			engine:update_counter( "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", key, 0, 60*metrics[1])
			engine:update_counter( "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", key, 1, 60*metrics[2])
			engine:update_counter( "{A8D34B1F-E0E5-458D-012A-0A31B0746D41}", key, 2, 60*metrics[3])
		end

    end,

  },

}
