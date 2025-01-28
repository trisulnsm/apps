--
--  NAT MAPPER 
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     handles NAT events and tags flows before flushing 
-- 
TrisulPlugin = { 

  id =  {
    name = "NAT Tagger",
    description = "Tag with POST NAT IP and PORT",
    author = "Unleash",                       -- optional
    version_major = 1,                        -- optional
    version_minor = 0,                        -- optional
  },



  -- common functions onload, onunload, onmessage()..

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
  	
	T.flows_match = 0 
	T.flows_notmatch = 0 

	T.MAX_AGE=2  -- TWO+TWO minutes window maintained 
	T.running_age = 0  
	T.current_map_age = 0  
	T.current_map = { } 
	T.prev_map = { } 

  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
  	T.current_map = nil 
	T.prev_map = nil 
  end,

  -- any messages you want to handle for state management 
  message_subscriptions = {"{6ECC7051-616B-4AD8-91C7-40BE8B396A26}" },

  -- WHEN CALLED: when another plugin sends you a message 
  -- CREATE/AC.10.BC.14:p-D5C0/67.DA.70.45:p-E9D4-06
  -- DELETE/AC.10.BC.14:p-D5C0/67.DA.70.45:p-E9D4-11
  onmessage = function(msgid, msg)
	local cmd = msg:sub(1,6)
	local pubip = msg:sub(27,-1)
	local privipkey = msg:sub(8,25) 

	if cmd == "CREATE" then
		T.current_map[pubip]=privipkey 
	elseif cmd == "DELETE" then
		T.current_map[pubip]=nil    
		T.prev_map[pubip]=nil    
	end 
  end,

  
  lookup_private_ipport = function( natmap, pub1, pub2 ) 

		local natm = natmap[pub1] 
		if not natm then
			natm = natmap[pub2]
		end 
		return natm 
  end,

  sg_monitor  = {


    -- WHEN CALLED: a new flow is seen 
    onnewflow  = function(engine, flow ) 

		local k = flow:key()
		local proto = flow:flow():protocol() 
		local ep1 = k:sub(5,22) .. '-' .. proto 
		local ep2 = k:sub(27,44) .. '-' .. proto 

		local natm = TrisulPlugin.lookup_private_ipport( T.current_map, ep1, ep2) 
		if not natm then 
			natm = TrisulPlugin.lookup_private_ipport( T.prev_map, ep1, ep2) 
		end 


		if not natm then
			T.flows_notmatch = T.flows_notmatch + 1
			return
		else 
			T.flows_match = T.flows_match + 1
		end

		-- we got a map, tag 
		local nip_key = natm:sub(1,11)
		local nport_key = natm:sub(13,18) 


		local nip = tonumber(nip_key:sub(1,2),16) .."." ..  tonumber(nip_key:sub(4,5),16) .. "." ..  tonumber(nip_key:sub(7,8),16) .. "." ..  tonumber(nip_key:sub(10,11),16) 
		local nport = tonumber(nport_key:sub(3,6),16)


		flow:add_tag("[natip]".. nip)
		flow:add_tag("[natport]".. nport)

    end,

    -- WHEN CALLED: end of flush
    onendflush = function(engine) 
		T.running_age = T.running_age + 1 

		--
		-- Print stats 
		-- 
		local nitems=0
		for _ in pairs(T.current_map) do
			nitems = nitems + 1
		end 
		T.loginfo("Gen "..T.running_age .." Size of NAT table = " .. nitems .. " Last window flows match="..T.flows_match.." nomatch="..T.flows_notmatch.." "
					.. (100*T.flows_match)/(T.flows_match+T.flows_notmatch) ..'%')

		T.flows_notmatch, T.flows_match = 0 ,0 


		-- Age out tables if old  
		if T.running_age -  T.current_map_age  > T.MAX_AGE then 
			T.loginfo("Aging out old NAT table .. at ".. T.running_age) 

			T.prev_map = T.current_map
			T.current_map = { } 
			T.current_map_age = T.running_age 

			collectgarbage()  
		end 

    end,
  },

}
