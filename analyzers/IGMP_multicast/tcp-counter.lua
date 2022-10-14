--
-- TCP - TCP packet counter 
-- 

local SWP= require'sweepbuf'

TrisulPlugin = { 


  -- the ID block,
  -- 
  id =  {
    name = "MC-TCP",
    description = "TCP counter for custom multicast counting ", -- optional
  },

  -- simple_counter  block
  -- 
  simplecounter = {

    --attach to TCP  protocol
    protocol_guid = "{77E462AB-2E42-42EC-9A58-C1A6821D6B31}" ,

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

		local key=""
		-- create the crosskey sip\dip\dport 
		-- for TCP no multicast group 
		if sport > dport then
			key = sip.."\\"..dip.."\\"..dport 
			engine:update_counter_bytes( "{942AB99F-7A65-4B2E-6F6C-A3050F0F7B35}", key, 0)
		else
			key = dip.."\\"..sip.."\\"..sport 
			engine:update_counter_bytes( "{942AB99F-7A65-4B2E-6F6C-A3050F0F7B35}", key, 1)
		end 



    end,
  }
}
