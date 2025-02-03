--
-- Microsoft-AD Auth syslog 
--
function to_ipkey_format(dotted_ip)
    local b1, b2, b3, b4 = dotted_ip:match("(%d+).(%d+).(%d+).(%d+)")
    return string.format("%02X.%02X.%02X.%02X", b1, b2, b3, b4)
end

local dbg=require'debugger'


TrisulPlugin = {

    -- the ID block, you can skip the fields marked 'optional '
    --
    id = {
        name = "Microsoft-AD DHCP logs packet monitor",
        description = "Listen to SYSLOG DHCP packets",
    },

    -- COMMON FUNCTIONS:  onload, onunload, onmessage
    --
    onload = function() 
		local kRexLogon = '^<\\d+>([A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}).+\\s4624\\s.+An account was successfully logged on.+?Account Name:\\s+(\\w[\\w-]+).+?Account Domain:\\s+(\\w+).+?Workstation Name:\\s+([\\w-]+).+?Source Network Address: (\\d{1,3}(?:\\.\\d{1,3}){3})';

		T.regex_kerb_logon  = T.re2(kRexLogon)

		print(kRexLogon);

		T.regex_kerb_logoff  = T.re2('^<\\d+>([A-Za-z]{3}\\s+[0-9]{2}\\s+[0-9]{2}:[0-9]{2}:[0-9]{2}).+An account was logged off.+?Account Name:\\s+(\\w+).+?Account Domain:\\s+(\\w+)')


	end,

    -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul
    onunload = function() end,

    simplecounter = {

        -- to UDP>SYSLOG protocol
        protocol_guid = "{4323003E-D060-440B-CA26-E146C0C7DB4E}",

        -- also work in NETFLOW_TAP mode
        flow_counter = true,

        -- each SYSLOG packet
        onpacket = function(engine, layer)
            local syslogstr = layer:rawbytes():tostring()

			local match, ts,username, adomain,  wsname, ipaddress = T.regex_kerb_logon:partial_match_n( syslogstr) 
			if match then 

				-- print( "++" .. ts.." " .. adomain .. "/".. username .. " " .. wsname .. " "  .. ipaddress) 


				local aduser = adomain.."/"..username 

                engine:post_message_frontend(
                    "{1A41BB0C-A872-46E2-DF19-85B658643B58}",
                    "USERLOGON|"..ipaddress .."|"..aduser 
                )

				if wsname ~= "-" then 

					engine:post_message_frontend(
						"{1A41BB0C-A872-46E2-DF19-85B658643B58}",
						"MACHINENAME|"..ipaddress.."|"..wsname
					)

					engine:update_key_info("{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}", to_ipkey_format(ipaddress), wsname)

				end 

				engine:add_resource( "{E3EF6B1A-6553-4474-69B6-D015CEF3D41F}", 
									 layer:packet():flowid():id(), "AD AUTH SYSLOG", syslogstr)


			end 

			local match, ts, username, adomain = T.regex_kerb_logoff:partial_match_n( syslogstr)
			if match then 
				-- print( "    >>" .. ts.." " .. adomain .. "/".. username )

				local aduser = adomain.."/"..username 

                engine:post_message_frontend(
                    "{1A41BB0C-A872-46E2-DF19-85B658643B58}",
                    "USERLOGOFF|"..aduser
                )

				engine:add_resource( "{E3EF6B1A-6553-4474-69B6-D015CEF3D41F}", 
									 layer:packet():flowid():id(), "AD AUTH SYSLOG", syslogstr)
			end 

        end,
    },
}
