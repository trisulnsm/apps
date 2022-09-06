local AsyncTasks= {}

AsyncTasks.data = ""

-- execute ASYNC - dont worry about when and where this is called. Trisul will take care of it 
AsyncTasks.onexecute = function(in_data) 

  local ipstr_tokey=function(ipstr)
    local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
  end
	local JSON=require'JSON'
	local BW=require'bulkwalk_cmd'

	local agent=JSON:decode(in_data);
	local async_results   =  { 
	  update_counters = {},
	  update_key_info = {},
    add_alerts ={},
	} 
  print(os.date("%c"))
  local s=os.date("%S")
  local diff = 5-s
  if(diff <=5 and diff >=0) then
    print("wait"..diff)
    os.execute("sleep " .. tonumber(diff))
  end
  print(os.date("%c"))
	-- update IN 
	local oid = ".1.3.6.1.2.1.31.1.1.1.6"
	if agent.agent_version == "1"  then oid = "1.3.6.1.2.1.2.2.1.10" end
	-- print("Async bulk walk start for "..agent.agent_ip)
	local bw_in =  do_bulk_walk( agent, oid)
	local has_varbinds = false
	for k,v in pairs( bw_in) do 
	  v = tonumber(v) or 0
	  table.insert(async_results.update_counters, {  "{9781db2c-f78a-4f7f-a7e8-2b1a9a7be71a}", k, 1, tonumber(v)}   );
	  has_varbinds=true
	end

	if not has_varbinds then
    
    local logmsg = "SNMP Poll Failed for "..agent.agent_ip.." with v"..agent.agent_version
	  T.logerror(logmsg)
    local dest_ip = ipstr_tokey(agent.agent_ip)
    local flow_key = "11A:00.00.00.00:p-804D_"..dest_ip..":p-00A1"
    table.insert(async_results.add_alerts,{ "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",flow_key,"SNMP Poll Failed",1,logmsg} );
	end 
	  -- update OUT 
	local oid = ".1.3.6.1.2.1.31.1.1.1.10"
	if agent.agent_version == "1"  then oid = "1.3.6.1.2.1.2.2.1.16" end
	if has_varbinds then 
	  local bw_in =  do_bulk_walk( agent, oid)
	  for k,v in pairs( bw_in) do 
	  v = tonumber(v) or 0
		table.insert(async_results.update_counters, {  "{9781db2c-f78a-4f7f-a7e8-2b1a9a7be71a}", k, 2, tonumber(v)}   );
	  end

	  -- update keys - ALIAS iii
	  local oid = ".1.3.6.1.2.1.31.1.1.1.18"
	  if agent.agent_version == "1"  then oid = "1.3.6.1.2.1.2.2.1.2" end
	  local up_key =  do_bulk_walk( agent, oid)
	  for k,v in pairs( up_key) do 
      if(v~="") then
        table.insert(async_results.update_key_info, {  "{9781db2c-f78a-4f7f-a7e8-2b1a9a7be71a}", k, v}   );
      end
	  end
	end

	return  JSON:encode(async_results)
end

-- update the counters after unpacking the JSON response 
AsyncTasks.onresult = function(engine,req,response)
	local JSON=require'JSON'
	local async_results=JSON:decode(response)
	for _,v in ipairs(async_results.update_counters) do
	  engine:update_counter(v[1],v[2],v[3],v[4])
		--print("iupdate counter "..table.concat(v,' '))
	end

	for _,v in ipairs(async_results.update_key_info)  do
	  engine:update_key_info(v[1],v[2],v[3])
		--print("iupdate key "..table.concat(v,' '))
	end
	for _,v in ipairs(async_results.add_alerts)  do
	  engine:add_alert(v[1],v[2],v[3],v[4],v[5])
		--print("iupdate key "..table.concat(v,' '))
	end
end

return AsyncTasks;

