--
-- message_monitor.lua  (login-connector)
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     message monitor
-- DESCRIPTION: MMON listens to TMS frontend messages and meters flow bytes
--              per ClientId and per client source.
--
function mysplit(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

TrisulPlugin = {

  -- the ID block, you can skip the fields marked 'optional '
  --
  id =  {
    name = "LoginMessageMonitor",
    description = "mmonitor listens to login messages ",
  },

  -- message subscriptions
  message_subscriptions = {
	  '{A563693D-A2EC-41BB-8481-C4EB0316AFF8}'
  },

  -- this method is only called when some other script does a post_message_frontend
  onmessage = function(msgid, message)

  	local t = mysplit( message,"|")

	if t[1] == "CLIENTID" then
		T.clientids[ t[2] ] = t[3]
	elseif t[1] == "SOURCE" then
		T.clientsources[ t[2] ] = t[3]
	end

  end,

  onload = function()

	T.clientids     = { }
	T.clientsources = { }

  end,

  -- messagemonitor  block
  --
  messagemonitor   = {

  onnewflowrecord = function(engine, flowid, bytes_az, bytes_za, packets_az, packets_za)

	local ipa = flowid:ipa_readable()
	local ipz = flowid:ipz_readable()

	-- client IP can be on either side of the flow
	local clientid     = T.clientids[ ipa ]     or T.clientids[ ipz ]
	local clientsource = T.clientsources[ ipa ] or T.clientsources[ ipz ]

	local t, x, r = bytes_az + bytes_za , bytes_az, bytes_za

	if clientid then
          -- update ClientId counter group
          engine:update_counter("{C9212EE1-A8EC-4A9F-9062-D1E87E5DF616}", clientid, 0, t)
          engine:update_counter("{C9212EE1-A8EC-4A9F-9062-D1E87E5DF616}", clientid, 1, r)
          engine:update_counter("{C9212EE1-A8EC-4A9F-9062-D1E87E5DF616}", clientid, 2, x)
	end

	if clientsource then
          -- update client source counter group
          engine:update_counter("{009EBF17-72A7-49E7-81B0-3979497509D5}", clientsource, 0, t)
          engine:update_counter("{009EBF17-72A7-49E7-81B0-3979497509D5}", clientsource, 1, r)
          engine:update_counter("{009EBF17-72A7-49E7-81B0-3979497509D5}", clientsource, 2, x)
	end

  end,

  },
}
