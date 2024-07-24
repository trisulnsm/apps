--
-- Fortigate DHCP syslog protocol 
-- 


-- in trisul: ipv4 keys look like XX.XX.XX.XX 
function  to_ipkey_format( dotted_ip )
  local b1, b2, b3, b4 =  dotted_ip:match("(%d+).(%d+).(%d+).(%d+)")
  return string.format("%02X.%02X.%02X.%02X", b1, b2, b3, b4 )
end



TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Fortigate DHCP logs packet monitor",
    description = "Listen to SYSLOG DHCP packets", 
  },

  -- COMMON FUNCTIONS:  onload, onunload, onmessage 
  -- 
  onload = function()
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    -- your code 
  end,

  simplecounter = {

    -- to UDP>SYSLOG protocol 
    protocol_guid = "{4323003E-D060-440B-CA26-E146C0C7DB4E}", 

	-- also work in NETFLOW_TAP mode
	flow_counter = true,

    onpacket = function(engine,layer)

		local syslogstr = layer:rawbytes():tostring()

		local t = {}
			  t['srcip']=""
		      t['srcname']=""
			  t['dstip']=""
			  t['hostname']=""
			  t['app']=""
			  t['appcat']=""
			  t['user']=""
			  t['unauthuser']=""
		for k, v in string.gmatch(syslogstr, "(%w+)=([%w.-]+)") do
		  t[k] = v
		end

		for k, v in string.gmatch(syslogstr, '(%w+)="([%w.-]+)"') do
		  t[k] = v
		end


	    if #t['user'] > 0 and #t['srcip'] > 0  then 
			engine:post_message_frontend('{56C435B7-D623-49B7-55F8-5D1210288002}', "USER|"..t['srcip']..'|'..t['user'])
		end


		local user2  = t['user'] .. t['unauthuser'] 
		local srcname  = t['srcname'] 

		if #user2 ==0 and #srcname > 0 then
			 user2 = srcname 
		end 


	    if #user2 > 0 and #t['srcip'] > 0  then 
			local ipk = to_ipkey_format( t['srcip'])
			engine:update_key_info(  '{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}', ipk, user2, t['srcname'])


			engine:add_edge('{A8D34B1F-E0E5-458D-012A-0A31B0746D41}', srcname,
                            '{889900CC-0063-11A5-8380-FEBDBABBDBEA}', ipk)

            engine:add_edge('{889900CC-0063-11A5-8380-FEBDBABBDBEA}', ipk,
						    '{A8D34B1F-E0E5-458D-012A-0A31B0746D41}', srcname) 

			engine:add_edge('{86A8880D-F4B2-4E49-A4FA-718880CAA976}', user2,
                            '{889900CC-0063-11A5-8380-FEBDBABBDBEA}', ipk)

			engine:add_edge('{889900CC-0063-11A5-8380-FEBDBABBDBEA}', ipk,
                            '{86A8880D-F4B2-4E49-A4FA-718880CAA976}', user2)
		end 

	    if #t['hostname']  > 0 and #t['dstip'] > 0 then 
			engine:update_key_info(  '{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}', to_ipkey_format( t['dstip']), t['hostname'])
		end

		if #t['app']  > 0 and #t['dstip'] > 0 then
			engine:post_message_frontend('{56C435B7-D623-49B7-55F8-5D1210288002}', "APP|"..t['dstip']..'|'..t['app'])
		end

		if #t['appcat']  > 0 and #t['dstip'] > 0 then
			engine:post_message_frontend('{56C435B7-D623-49B7-55F8-5D1210288002}', "CAT|"..t['dstip']..'|'..t['appcat'])
		end


		--[[
		print(string.format("%18s", t['srcip']) ..
		      string.format("%15s", t['srcname'])..
			  string.format("%18s", t['dstip'])..
			  string.format("%25s", t['app'])..
			  string.format("%25s", t['appcat'])..
			  string.format("%15s", t['user'])..
			  string.format("%15s", t['unauthuser'])..
			  string.format("%30s", t['hostname']))
		]]-- 

	  return 

    end,
  },
}

