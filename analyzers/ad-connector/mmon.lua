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
	  '{1A41BB0C-A872-46E2-DF19-85B658643B58}'
  },

  -- this method is only called when some other script does a postmessage_
  onmessage = function(msgid, message)

  	local t = mysplit( message,"|")


	if t[1] == "USERLOGON" then
		T.users2ip[ t[3] ] = t[2] 
		T.ip2users[ t[2] ] = t[3]
	elseif t[1] == "USERLOGOFF" then 
		local ip = T.users2ip[ t[2] ]
		if ip  then 
			T.ip2users[ip] = nil 
			T.users2ip[ t[2] ] = nil 
			T.ip2machinenames[ ip ] = nil 
		end
	elseif t[1] == "MACHINENAME" then
		T.ip2machinenames[ t[2] ] = t[3]
	end 

  end, 


  onload = function()

  	T.ip2users = { } 
  	T.users2ip = { } 
	T.ip2machinenames = { } 

  end, 

  onunload = function() 


	print("IP Table")
  	for k,v in pairs(T.ip2users) do 
		print(k..' => ' .. v) 
	end 


  end, 

  -- messagemonitor  block
  -- 
  messagemonitor   = {

  onnewflowrecord = function(engine, flowid, bytes_az, bytes_za, packets_az, packets_za)

	-- print("onnewflowrecord ="..flowid:key().. ' az=' .. bytes_az.. " za="..bytes_za)

	local ipa = flowid:ipa_readable()
	local ipz = flowid:ipz_readable()


	local userid  = T.ip2users[ ipa ] or  T.ip2users[ipz] 
	local mcid    = T.ip2machinenames[ ipa ] or  T.ip2machinenames[ ipz ] 

	local t, x, r = bytes_az + bytes_za , bytes_az, bytes_za 

	if userid  then 
          -- update user
          engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 0, t)
          engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 1, r)
          engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 2, x)
	end

	if mcid then 
          engine:tag_flow(flowid:key(), "[sysname]"..mcid)
	end 

  end,

  },
}
