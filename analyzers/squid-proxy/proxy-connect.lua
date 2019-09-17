--
-- proxy-connect.lya
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Hook into Trisul's TCP reassembly engine 
-- DESCRIPTION: Metrics based on CONNECT used by explicit proxies 
-- 
TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Tag flows with Proxy CONNECT",
    description = "Tag flows with Proxy Connect and update HTTP Hosts hits",
  },

  -- reassembly_handler block
  -- 
  reassembly_handler   = {

    -- WHEN CALLED: when a chunk of reassembled payload is available 
    -- 
    -- handle reassembled byte stream here , 
    -- 
    onpayload = function(engine, timestamp, flowkey, direction, seekpos, buffer) 

		if seekpos==0 and direction==1 then
			local s = buffer:tostring()
			local connectstr  = s:match("CONNECT (%S+)")

			if connectstr then 

				if #connectstr > 60 then
					connectstr = connectstr:sub(-60)
				end 

				--print(connectstr)
				engine:tag_flow(flowkey:key(), "[pxy]"..connectstr)
				engine:add_flow_counter(flowkey:key(), '{B7571E87-F794-4BF6-A57A-EEA8A90F0324}',  connectstr, 0, 0)
				engine:add_flow_counter(flowkey:key(), '{B7571E87-F794-4BF6-A57A-EEA8A90F0324}',  connectstr, 1, 1)
				engine:update_counter('{B7571E87-F794-4BF6-A57A-EEA8A90F0324}',  connectstr, 2, 1)
				engine:add_edge('{B7571E87-F794-4BF6-A57A-EEA8A90F0324}', connectstr, 
							    '{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}', flowkey:ipa()) 
				engine:add_edge('{B7571E87-F794-4BF6-A57A-EEA8A90F0324}', connectstr, 
							    '{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}', flowkey:ipz())
			end 
	    else 
			engine:disable_reassembly(flowkey:key())
		end
		
    end,

  },

}
