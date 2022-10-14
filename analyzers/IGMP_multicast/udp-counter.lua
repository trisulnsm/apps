--
-- UDP - UDP packet counter 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Protocol Handler, 
-- 

local SWP= require'sweepbuf'

function ipstr_tokey(ipstr)
  local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
end

TrisulPlugin = { 


  -- the ID block,
  -- 
  id =  {
    name = "MC-UDP",
    description = "UDP counter for custom multicast counting ", -- optional
  },

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
 		T.multicast_mapping = { }  
  end,


  -- any messages you want to handle for state management 
  message_subscriptions =  { "{18D4B77A-AA86-4924-2201-6ABE892F2937}" } ,

  -- WHEN CALLED: when another plugin sends you a message 
  onmessage = function(msgid, msg)

	local mips, sips = msg:match("(%S+)=(%S+)")

	local mip = mips
	local sip = sips


	if T.multicast_mapping[mip] == nil then 
		T.multicast_mapping[mip] = {}
	end
	
	T.multicast_mapping[mip][sip] = true 
    
  end,


  -- simple_counter  block
  -- 
  simplecounter = {

    --attach to IGMP  protocol
    protocol_guid = "{14D7AB53-CC51-47E9-8814-9C06AAE60189}" ,

    -- WHEN CALLED: when the Trisul platform detects a packet at the protocol_guid layer
    --              above. In this case, every DNS packet
    -- 
    onpacket = function(engine,layer)

		local swb=SWP.new(layer:rawbytes():tostring())

		local sport = swb:next_u16()
		local dport = swb:next_u16()


		local iplayer = layer:packet():get_layer(1)
		local ipbuf = iplayer:rawbytes():tostring() 
		local ipswb = SWP.new(ipbuf)
		ipswb:skip(12) 
		local sip = ipswb:next_ipv4()
		local dip = ipswb:next_ipv4()

		-- check if DIP has a mapping 
		-- if no mapping dont do anything.. this is only for multicast mapping
		-- a 4 tuple multicast mapping 
		local mmap = T.multicast_mapping[dip]
		if mmap then

			for k,v in pairs(mmap) do
				local key = k.."\\"..sip.."\\"..dport.."\\"..dip
				engine:update_counter_bytes( "{942AB99F-7A65-4B2E-6F6C-A3050F0F7B35}", key, 2)
			end 

		end 

    end,
  }
}
