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
  	T.natmap = { } 
	T.nitems = 0 
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
  	T.natmap = nil 
  end,

  -- any messages you want to handle for state management 
  message_subscriptions = {"{6ECC7051-616B-4AD8-91C7-40BE8B396A26}" },

  -- WHEN CALLED: when another plugin sends you a message 
  -- CREATE/AC.10.BC.14:p-D5C0/67.DA.70.45:p-E9D4
  -- DELETE/AC.10.BC.14:p-D5C0/67.DA.70.45:p-E9D4
  onmessage = function(msgid, msg)
	local cmd = msg:sub(1,6)
	local pubip = msg:sub(27,-1)
	if cmd == "CREATE" then
		T.natmap[pubip] = msg
		T.nitems = T.nitems + 1
	elseif cmd == "DELETE" then
		T.natmap[pubip] = nil 
		T.nitems = T.nitems - 1
	end 
  end,


  sg_monitor  = {


    -- WHEN CALLED: a new flow is seen 
    onnewflow  = function(engine, flow ) 

		local k = flow:key()
		local ep1 = k:sub(5,22)
		local ep2 = k:sub(27,44)

		local natm = T.natmap[ep1]
		if not natm then
			natm = T.natmap[ep2]
		end 

		if not natm then
			return
		end


		-- we got a map, tag 
		local nip_key = natm:sub(8,18)
		local nport_key = natm:sub(20,25) 

		local nip = tonumber(nip_key:sub(1,2),16) .."." ..  tonumber(nip_key:sub(4,5),16) .. "." ..  tonumber(nip_key:sub(7,8),16) .. "." ..  tonumber(nip_key:sub(10,11),16) 
		local nport = tonumber(nport_key:sub(3,6),16)


		flow:add_tag("[natip]".. nip)
		flow:add_tag("[natport]".. nport)

    end,

    -- WHEN CALLED: end of flush
    onendflush = function(engine) 
		T.loginfo("Size of NAT table = " .. T.nitems ) 
    end,
  },

}
