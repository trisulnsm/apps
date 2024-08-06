--
-- RADIUS SYSLOG - creates files every 1 hour 
--
local SB = require("sweepbuf")

RADIUS_ACCT_OFF = 0
RADIUS_ACCT_LIVE = 1

TrisulPlugin = {

	-- the ID block, you can skip the fields marked 'optional '
	--
	id = {
		name = "SYGLOG  RADIUS Monitor",
		description = "Listen to SYSLOG packets",
	},

	-- WHEN CALLED : your LUA script is loaded into Trisul
	onload = function()
		T.state = {}
		T.logdir="/tmp"
		T.aaadir="/opt/aaa"
	end,

	-- WHEN CALLED : your LUA script is unloaded  / detached from Trisul
	onunload = function() end,

	simplecounter = {

		-- to UDP>SYSLOG protocol
		protocol_guid = "{4323003E-D060-440B-CA26-E146C0C7DB4E}",

		-- also work in NETFLOW_TAP mode
		flow_counter = true,

		onpacket = function(engine, layer)
			local syslogstr = layer:rawbytes():tostring()

			if not syslogstr:find("radius,debug,", 1, true) then
				-- not a radius log syslog
				return
			end

			--ip_layer protocol
			local iplayer = layer:packet():find_layer("{0A2C724B-5B9F-4BA6-9C97-B05080558574}")
			local ip_sb = SB.new(iplayer:rawbytes():tostring())
			--skip to get ip
			ip_sb:skip(12)
			local iplayer_deviceip = ip_sb:next_ipv4()

			local nas_state = T.state[iplayer_deviceip]
			if not nas_state then
				T.state[iplayer_deviceip] = {
					radius_state = RADIUS_ACCT_OFF,
					live_messages = {},
					logfile = io.open(T.logdir .. "/radiuslog.".. iplayer_deviceip,"a") ,
					snapfile = io.open(T.logdir .. "/radiussnap.".. iplayer_deviceip,"a") 
				}
				nas_state = T.state[iplayer_deviceip]
			end

			nas_state.logfile:write(syslogstr.."\n")

			if nas_state.radius_state == RADIUS_ACCT_OFF then
				-- STATE OFF
				if syslogstr:find("Accounting-Request with id", 1, true) then
					nas_state.radius_state = RADIUS_ACCT_LIVE
				else
					return
				end
			elseif nas_state.radius_state == RADIUS_ACCT_LIVE then
				-- STATE ON

				if syslogstr:find("received", 1, true) or syslogstr:find("sending", 1, true) then
					nas_state.radius_state = RADIUS_ACCT_OFF

					-- flush
					print(
						"Record "
							.. nas_state.live_messages["User-Name"]
							.. "=> "
							.. nas_state.live_messages["Framed-IP-Address"]
							.. "=> "
							.. nas_state.live_messages["Acct-Session-Time"]
							.. "=> "
							.. nas_state.live_messages["Acct-Status-Type"]
					)

					-- #eventts,username,framedip,startm,endtime,duration,sessionid
					local lm = nas_state.live_messages
					local snf  = nas_state.snapfile
					snf:write(lm["Event-Timestamp"]) snf:write(',')
					snf:write(lm["Acct-Session-Id"]) snf:write(',')

					-- time computation block 
					local dur=tonumber(lm["Acct-Session-Time"])
					local evts=tonumber(lm["Event-Timestamp"])
					local starttm=evts-dur
					local endts=''
					if lm["Acct-Status-Type"]=="2" then
						print("EEEEEENDDDDD")
						endts=evts
					end

					snf:write(starttm) 
					snf:write(',')
					snf:write(evts) 
					snf:write(',')
					snf:write(endts) 
					snf:write(',')
					snf:write(dur) 
					snf:write(',')
					snf:write(lm["User-Name"]) snf:write(',')
					snf:write(lm["Framed-IP-Address"]) snf:write(',')
					snf:write(lm["NAS-IP-Address"]) snf:write(',')
					snf:write("\n") 

				else
					local fields = {
						"User-Name",
						"Service-Type",
						"Acct-Status-Type",
						"Acct-Session-Id",
						"Framed-IP-Address",
						"Event-Timestamp",
						"Acct-Session-Time",
						"NAS-IP-Address",
					}
					for _, v in ipairs(fields) do
						if syslogstr:find(v, 1, true) then
							local k, v = syslogstr:match('([%w%-]+)%s*=%s*(%S+)')
							nas_state.live_messages[k] = v
						end
					end
				end
			end
		end,
	},
}
