--
-- igmp - IGMP counter  
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Protocol Handler, 
-- 

local SWP= require'sweepbuf'

TrisulPlugin = { 


  -- the ID block,
  -- 
  id =  {
    name = "IGMPCG",
    description = "IGMP countergroup to track Multicast group numbers ", -- optional
  },

  -- simple_counter  block
  -- 
  simplecounter = {

    --attach to IGMP  protocol
    protocol_guid = "{D3E8D72E-48ED-43F9-1E8C-DD5FED84E830}",

    -- WHEN CALLED: when the Trisul platform detects a packet at the protocol_guid layer
    --              above. In this case, every DNS packet
    -- 
    onpacket = function(engine,layer)

		local swb=SWP.new(layer:rawbytes():tostring())

		local code  = swb:next_u8();
		if code == 0x16  then

			local iplayer = layer:packet():get_layer(1)
			local ipbuf = iplayer:rawbytes():tostring() 
			local ipswb = SWP.new(ipbuf)
			ipswb:skip(12) 
			local source_ip = ipswb:next_ipv4()


			swb:skip(1)
			swb:skip(2)
			local mip = swb:next_ipv4()
			print("Mapping ".. source_ip.. " member of multicast group " .. mip ) 

			engine:post_message_backend("{18D4B77A-AA86-4924-2201-6ABE892F2937}", mip.."="..source_ip)
			engine:post_message_frontend("{18D4B77A-AA86-4924-2201-6ABE892F2937}", mip.."="..source_ip)

		end 


    end,
  }
}
