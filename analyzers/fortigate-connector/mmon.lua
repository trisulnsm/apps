--
-- message_monitor.lua skeleton
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     message monitor 
-- DESCRIPTION: MMON listens to TMS frontend messages 
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
    name = "MessageMonitor",
    description = "mmonitor listens to messages ", 
  },

  -- message subscriptions -- mapping/ip/name 
  message_subscriptions = {
	  '{56C435B7-D623-49B7-55F8-5D1210288002}'
  },

  -- this method is only called when some other script does a postmessage_
  onmessage = function(msgid, message)

  	local t = mysplit( message,"|")


	if t[1] == "USER" then
		T.users[ t[2] ] = t[3]
	elseif t[1] == "MACHINE" then
		T.machinenames[ t[2] ] = t[3]
	elseif t[1] == "HOST" then
		T.hostnames[ t[2] ] = t[3]
	elseif t[1] == "APP" then 
		T.apps[ t[2] ] = t[3]
	elseif t[1] == "APPCAT" then
		T.appcats[ t[2] ] = t[3]
	end 

  end, 


  onload = function()

  	T.users = { } 
	T.machinenames = { } 

	T.apps = { } 
	T.appcats = { } 
	T.hostnames = { } 

  end, 

  -- messagemonitor  block
  -- 
  messagemonitor   = {

  onflowmetric  = function(engine,flowid,meter,value)

	print("onflowmetric ="..flowid:key())

  end,

  onnewflowrecord = function(engine, flowid, bytes_az, bytes_za, packets_az, packets_za)

	-- print("onnewflowrecord ="..flowid:key().. ' az=' .. bytes_az.. " za="..bytes_za)

	local ipa = flowid:ipa_readable()
	local ipz = flowid:ipz_readable()


	local userid  = T.users[ ipa ]
	local mcid    = T.machinenames[ ipa ]
	local website = T.hostnames[ ipz ]
	local appid   = T.apps[ ipz ]
	local appcat  = T.appcats[ ipz ]

	local t, x, r = bytes_az + bytes_za , bytes_az, bytes_za 

	if userid  then 
          -- update user
          engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 0, t)
          engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 1, r)
          engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 2, x)
	  engine:update_key_info("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, userid)

	end

	if mcid then 
          engine:tag_flow(flowid:key(), "[sysname]"..mcid)
	end 

	if appid then 
          -- update app
          engine:update_counter("{9021F5D3-FEFB-401B-99EC-EF2ACD088578}", appid, 0, t)
          engine:update_counter("{9021F5D3-FEFB-401B-99EC-EF2ACD088578}", appid, 1, r)
          engine:update_counter("{9021F5D3-FEFB-401B-99EC-EF2ACD088578}", appid, 2, x)
	end 


	if appcat then 
          -- update app cat 
          engine:update_counter("{2DE5A613-BC31-4C73-1EAA-B527FDD40E7D}", appcat, 0, t)
          engine:update_counter("{2DE5A613-BC31-4C73-1EAA-B527FDD40E7D}", appcat, 1, r)
          engine:update_counter("{2DE5A613-BC31-4C73-1EAA-B527FDD40E7D}", appcat, 2, x)
	end 

  end,

  },
}
