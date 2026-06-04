
local AsyncTasks= {}

AsyncTasks.data = ""

-- execute ASYNC - dont worry about when and where this is called. Trisul will take care of it
AsyncTasks.onexecute = function(in_data)

	-- Counter group GUIDs and Cisco CBQOS MIB OIDs (inside onexecute: async workers do not see module locals)
	local GUID_QOS_TRAFFIC     = "{1AB9F248-1E49-4245-571A-55BCDA658843}"
	local GUID_QOS_CLASS       = "{116888A7-23B4-4873-5691-E6E0806CCB11}"
	local GUID_FLOWINTF_BX_QOS = "{D3F7A892-4E1B-4C6D-8A5F-2E1C9B7D4A63}"
	local OID_QOS_CLASS_NAME   = "1.3.6.1.4.1.9.9.166.1.7.1.1.1"
	local OID_QOS_OBJECT_INDEX = "1.3.6.1.4.1.9.9.166.1.5.1.1.2"
	local OID_QOS_CONFIG_INDEX = "1.3.6.1.4.1.9.9.166.1.5.1.1.4"
	local OID_QOS_IFINDEX      = "1.3.6.1.4.1.9.9.166.1.1.1.1.4"
	local OID_QOS_POST_POLICY     = "1.3.6.1.4.1.9.9.166.1.15.1.1.10"
	local OID_QOS_PRE_POLICY      = "1.3.6.1.4.1.9.9.166.1.15.1.1.6"
	local OID_QOS_DROP_BYTES      = "1.3.6.1.4.1.9.9.166.1.15.1.1.16"
	local OID_QOS_QUEUE_BUFFER    = "1.3.6.1.4.1.9.9.166.1.18.1.1.1"
	local OID_QOS_QUEUE_DROP_PKTS = "1.3.6.1.4.1.9.9.166.1.18.1.1.8"
	local OID_QOS_QUEUE_DROP_BYTES= "1.3.6.1.4.1.9.9.166.1.18.1.1.4"

	local ipstr_tokey=function(ipstr)
		local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
		return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
	end

	local ipstr_tonetflowkey=function(ipstr,ifindex)
		local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
		return  string.format("%02X.%02X.%02X.%02X_%08X", b1,b2,b3,b4,ifindex)
	end

	local parse_snmp_value=function(raw)
		local v = raw:gsub('^%S+:%s*',''):gsub('"',''):gsub('^%s+',''):gsub('%s+$','')
		return v
	end

	-- 1.3.6.1.4.1.9.9.166... -> enterprises.9.9.166... (snmpwalk -O q output)
	local oid_enterprise_tail=function(base_oid)
		local rest = base_oid:match("^1%.3%.6%.1%.4%.1%.(.+)$")
		if rest then
			return "enterprises." .. rest
		end
		return base_oid
	end

	local parse_qos_line=function(oneline, base_oid)
		local escaped_num = base_oid:gsub("%.", "%%.")
		local ent_tail = oid_enterprise_tail(base_oid):gsub("%.", "%%.")
		local patterns = {
			"%." .. escaped_num .. "%.([^%s]+)%s+(.+)$",
			"::" .. ent_tail .. "%.([^%s]+)%s+(.+)$",
			ent_tail .. "%.([^%s]+)%s+(.+)$",
		}
		for _, pat in ipairs(patterns) do
			local idx, rawval = oneline:match(pat)
			if idx then
				return idx, rawval
			end
		end
		return nil, nil
	end

	local do_qos_walk=function(agent,base_oid)
		if base_oid == nil or base_oid == "" then
			T.logerror("SNMP QoS: missing OID for "..tostring(agent.agent_ip))
			return {}
		end
		local ofile = os.tmpname()
		os.execute(agent.walk_command.." "..agent.cmdargs.." ."..base_oid.." > "..ofile)

		local ret = {}
		local h=io.open(ofile)
		if not h then
			return ret
		end

		for oneline in h:lines()
		do
			if oneline ~= "" and not oneline:match("^#") then
				local idx, rawval = parse_qos_line(oneline, base_oid)
				if idx then
					ret[idx] = parse_snmp_value(rawval)
				else
					T.logdebug("SNMP QoS: unparseable line="..oneline)
				end
			end
		end
		h:close()
		os.remove(ofile)
		return ret
	end

	local JSON=require'JSON'
	local agent=JSON:decode(in_data);
	local async_results   =  {
	  update_counters = {},
	  update_key_info = {},
	  add_alerts ={},
	}

	local map_refresh_polls = tonumber(agent.map_refresh_polls) or 30
	if map_refresh_polls < 1 then
		map_refresh_polls = 30
	end
	-- nil cache: first poll loads mapping immediately; thereafter refresh every MapRefreshPolls
	local refresh_map = agent.qos_map_cache == nil
		or agent.poll_count % map_refresh_polls == 0

	local class_names, object_index, config_index, ifindex_map
	if refresh_map then
		class_names = do_qos_walk(agent, OID_QOS_CLASS_NAME)
		if next(class_names) == nil then
			local logmsg = "SNMP QoS Poll Failed for "..agent.agent_ip.." with v"..agent.agent_version
			T.logerror(logmsg)
			local dest_ip = ipstr_tokey(agent.agent_ip)
			local flow_key = "11A:00.00.00.00:p-804D_"..dest_ip..":p-00A1"
			table.insert(async_results.add_alerts,{ "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",flow_key,"SNMP QoS Poll Failed",1,logmsg} )
			return JSON:encode(async_results)
		end
		-- 1.5.1.1.2: ifIndex.configIndex -> class id
		object_index = do_qos_walk(agent, OID_QOS_OBJECT_INDEX)
		-- 1.5.1.1.4: policyIndex.queueIndex (or ifIndex.queueIndex) -> configIndex
		config_index = do_qos_walk(agent, OID_QOS_CONFIG_INDEX)
		-- 1.1.1.1.4: policyIndex -> ifIndex
		ifindex_map = do_qos_walk(agent, OID_QOS_IFINDEX)
		async_results.qos_map_cache = {
			agent_ip = agent.agent_ip,
			class_names = class_names,
			object_index = object_index,
			config_index = config_index,
			ifindex_map = ifindex_map,
		}
		for class_id, class_name in pairs(class_names) do
			if class_name ~= "" then
				table.insert(async_results.update_key_info, { GUID_QOS_CLASS, class_id, class_name })
			end
		end
	else
		class_names = agent.qos_map_cache.class_names
		object_index = agent.qos_map_cache.object_index
		config_index = agent.qos_map_cache.config_index or {}
		ifindex_map = agent.qos_map_cache.ifindex_map
	end

	local function add_counter(qos_by_class, flowintf_by_key, class_id, ifindex, rawval)
		local val = tonumber(rawval) or 0
		if val == 0 then
			return
		end
		qos_by_class[class_id] = (qos_by_class[class_id] or 0) + val
		local ifkey = ipstr_tonetflowkey(agent.agent_ip, tonumber(ifindex))
		local crosskey = ifkey.."\\"..class_id
		flowintf_by_key[crosskey] = (flowintf_by_key[crosskey] or 0) + val
	end

	-- Policy (1.15): 2-level lookup
	--   counter policyIndex.configIndex -> 1.5.1.1.2 -> class id -> 1.7.1.1.1 name
	--   e.g. 18.65536 -> object_index[18.65536]=1593
	local function resolve_policy_class_and_ifindex(idx)
		local policy_idx, config_idx = idx:match("^(%d+)%.(%d+)$")
		if not policy_idx or not config_idx then
			return nil, nil
		end
		-- level 1: counter index -> class id via 1.5.1.1.2
		local class_id = object_index[idx]
		if not class_id then
			local ifindex = ifindex_map[policy_idx]
			if ifindex then
				class_id = object_index[ifindex.."."..config_idx]
			end
		end
		if not class_id then
			return nil, nil
		end
		local ifindex = ifindex_map[policy_idx] or policy_idx
		return class_id, ifindex
	end

	-- Queue (1.18): 3-level lookup
	--   counter policyIndex.queueIndex -> 1.5.1.1.4 -> configIndex
	--     -> ifIndex via policy map -> 1.5.1.1.2 -> class id -> 1.7.1.1.1 name
	--   e.g. 18.196611 -> config_index[18.196611]=196608 -> object_index[114.196608]=288431494
	local function resolve_queue_class_and_ifindex(idx)
		local policy_idx, queue_idx = idx:match("^(%d+)%.(%d+)$")
		if not policy_idx or not queue_idx then
			return nil, nil
		end
		local ifindex = ifindex_map[policy_idx]
		if not ifindex then
			return nil, nil
		end
		-- level 1: counter index -> configIndex via 1.5.1.1.4
		local config_idx = config_index[idx]
			or config_index[policy_idx.."."..queue_idx]
			or config_index[ifindex.."."..queue_idx]
		if not config_idx then
			return nil, nil
		end
		-- level 2: ifIndex.configIndex -> class id via 1.5.1.1.2
		local class_id = object_index[ifindex.."."..config_idx]
		return class_id, ifindex
	end

	local function process_qos_counters(oid, qos_by_class, flowintf_by_key, is_queue)
		local counters = do_qos_walk(agent, oid)
		for idx, rawval in pairs(counters) do
			local class_id, ifindex
			if is_queue then
				class_id, ifindex = resolve_queue_class_and_ifindex(idx)
			else
				class_id, ifindex = resolve_policy_class_and_ifindex(idx)
			end
			if class_id and ifindex then
				add_counter(qos_by_class, flowintf_by_key, class_id, ifindex, rawval)
			end
		end
	end

	local function emit_counters(guid, agg, meter_id)
		for key, val in pairs(agg) do
			if val ~= 0 then
				table.insert(async_results.update_counters, { guid, key, meter_id, val })
			end
		end
	end

	-- policy meters polled every cycle; queue meters use cached ifIndex.configIndex map
	local qos_aggs = {}
	local flowintf_aggs = {}
	local policy_meter_oids = {
		{ OID_QOS_POST_POLICY, 0 },
		{ OID_QOS_PRE_POLICY,  1 },
		{ OID_QOS_DROP_BYTES,  2 },
	}
	local queue_meter_oids = {
		{ OID_QOS_QUEUE_BUFFER,     3 },
		{ OID_QOS_QUEUE_DROP_PKTS,  4 },
		{ OID_QOS_QUEUE_DROP_BYTES, 5 },
	}
	for _, spec in ipairs(policy_meter_oids) do
		local qos_agg = {}
		local flowintf_agg = {}
		process_qos_counters(spec[1], qos_agg, flowintf_agg, false)
		qos_aggs[spec[2]] = qos_agg
		flowintf_aggs[spec[2]] = flowintf_agg
	end
	for _, spec in ipairs(queue_meter_oids) do
		local qos_agg = {}
		local flowintf_agg = {}
		process_qos_counters(spec[1], qos_agg, flowintf_agg, true)
		qos_aggs[spec[2]] = qos_agg
		flowintf_aggs[spec[2]] = flowintf_agg
	end

	for meter_id, qos_agg in pairs(qos_aggs) do
		emit_counters(GUID_QOS_TRAFFIC, qos_agg, meter_id)
	end
	for meter_id, flowintf_agg in pairs(flowintf_aggs) do
		emit_counters(GUID_FLOWINTF_BX_QOS, flowintf_agg, meter_id)
	end

	return  JSON:encode(async_results)
end

-- update the counters after unpacking the JSON response
AsyncTasks.onresult = function(engine,req,response)
	local JSON=require'JSON'
	local async_results=JSON:decode(response)
	for _,v in ipairs(async_results.update_counters) do
	  if v[4] ~= 0 then
		  engine:update_counter(v[1],v[2],v[3],v[4])
	  end
	end

	for _,v in ipairs(async_results.update_key_info)  do
	  engine:update_key_info(v[1],v[2],v[3])
	end
	for _,v in ipairs(async_results.add_alerts)  do
	  engine:add_alert(v[1],v[2],v[3],v[4],v[5])
	end
	if async_results.qos_map_cache and async_results.qos_map_cache.agent_ip and T.poll_targets then
		for _, agent in ipairs(T.poll_targets) do
			if agent.agent_ip == async_results.qos_map_cache.agent_ip then
				agent.qos_map_cache = async_results.qos_map_cache
				break
			end
		end
	end
end

return AsyncTasks;
