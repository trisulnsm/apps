-- return { key, value } 


function do_bulk_walk( agent, oid  )
  command = "snmpbulkwalk"
  cmdargs=""
  if agent.agent_version == "1" then command="snmpwalk" end
  local tstart = os.time()
  local ofile = os.tmpname() 
  level='noAuthNoPriv'
  if agent.agent_version=="2c" then
    cmdargs =" -r 1 -O q -t 3  -v"..agent.agent_version.." -c '"..agent.agent_community.."' "..agent.agent_ip.."  "..oid
  elseif agent.agent_version=="3" then
    cmdargs =" -r 1 -O q -t 3  -v"..agent.agent_version.." -u "..agent.agent_username
    if agent.agent_auth_password ~= nil and #agent.agent_auth_password > 0  then
      level = 'authNoPriv'
      cmdargs = cmdargs.." -a "..agent.agent_auth_protocol.." -A "..agent.agent_auth_password
    end
    if agent.agent_priv_password ~= nil and #agent.agent_priv_password > 0  then
      level = 'authPriv'
      cmdargs = cmdargs.." -x "..agent.agent_priv_protocol.." -X "..agent.agent_priv_password

    end
    cmdargs = cmdargs.." -l "..level

    if agent.agent_contextname ~= nil and #agent.agent_contextname > 0  then
      level = 'authPriv'
      cmdargs = cmdargs.." -n "..agent.agent_contextname
    end

   cmdargs = cmdargs.." "..agent.agent_ip.." "..oid
  end
  os.execute(command..""..cmdargs.. " > "..ofile)
  --print(command.." -r 1 -O q -t 3  -v"..version.." -c '"..community.."' "..agent.."  "..oid)

  local ret = { } 
  local h=io.open(ofile)
  for oneline in h:lines()
  do
    local  k,v = oneline:match("%.(%d+)%s+(.+)") 
	if k then 
		ret[agent.agent_ip.."_"..k] = v:gsub('"','')
	else
		print("ERROR in snmp output line="..oneline)
	end 
  end 
  h:close()
  os.remove(ofile)

  print("Done with agent "..agent.agent_ip.." elapsed secs="..os.time()-tstart)
  return ret
end

