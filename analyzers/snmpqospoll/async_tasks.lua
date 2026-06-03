
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
	local OID_QOS_IFINDEX      = "1.3.6.1.4.1.9.9.166.1.1.1.1.4"
	local OID_QOS_PRE_POLICY      = "1.3.6.1.4.1.9.9.166.1.15.1.1.10"
	local OID_QOS_POST_POLICY     = "1.3.6.1.4.1.9.9.166.1.15.1.1.6"
	local OID_QOS_DROP_BYTES      = "1.3.6.1.4.1.9.9.166.1.15.1.1.17"
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

	-- class id -> name  (cbQosPolicyMapName)
	local class_names = do_qos_walk(agent, OID_QOS_CLASS_NAME)
	local has_varbinds = next(class_names) ~= nil

	if not has_varbinds then
		local logmsg = "SNMP QoS Poll Failed for "..agent.agent_ip.." with v"..agent.agent_version
		T.logerror(logmsg)
		local dest_ip = ipstr_tokey(agent.agent_ip)
		local flow_key = "11A:00.00.00.00:p-804D_"..dest_ip..":p-00A1"
		table.insert(async_results.add_alerts,{ "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",flow_key,"SNMP QoS Poll Failed",1,logmsg} )
		return JSON:encode(async_results)
	end

	-- policyIndex.objectsIndex -> class map index
	local object_index = do_qos_walk(agent, OID_QOS_OBJECT_INDEX)

	-- cbQos policy interface index -> ifIndex
	local ifindex_map = do_qos_walk(agent, OID_QOS_IFINDEX)

	local ipkey = ipstr_tokey(agent.agent_ip)

	-- update class names periodically
	if agent.poll_count % 60 == 0 then
		for class_id, class_name in pairs(class_names) do
			if class_name ~= "" then
				table.insert(async_results.update_key_info, { GUID_QOS_CLASS, class_id, class_name })
			end
		end
	end

	local function process_policy_counters(oid, qos_by_class, flowintf_by_key)
		local counters = do_qos_walk(agent, oid)
		for idx, rawval in pairs(counters) do
			local policy_idx = idx:match("^(%d+)%.")
			local class_id = object_index[idx]
			local ifindex = policy_idx and ifindex_map[policy_idx]
			if class_id and ifindex then
				local val = tonumber(rawval) or 0
				if val ~= 0 then
					-- QOS-Traffic: resolver is QoS-Class; key is class id only (e.g. 288431494)
					qos_by_class[class_id] = (qos_by_class[class_id] or 0) + val
					-- FlowIntf_bx_QOS: flow interface key + class (e.g. 64.62.0B.1D_0000000A\288431494)
					local ifkey = ipstr_tonetflowkey(agent.agent_ip, tonumber(ifindex))
					local crosskey = ifkey.."\\"..class_id
					flowintf_by_key[crosskey] = (flowintf_by_key[crosskey] or 0) + val
				end
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

	-- meter id -> { qos aggregate, flowintf aggregate }
	local qos_aggs = {}
	local flowintf_aggs = {}
	local meter_oids = {
		{ OID_QOS_PRE_POLICY,       0 },
		{ OID_QOS_POST_POLICY,      1 },
		{ OID_QOS_DROP_BYTES,       2 },
		{ OID_QOS_QUEUE_BUFFER,     3 },
		{ OID_QOS_QUEUE_DROP_PKTS,  4 },
		{ OID_QOS_QUEUE_DROP_BYTES, 5 },
	}
	for _, spec in ipairs(meter_oids) do
		local qos_agg = {}
		local flowintf_agg = {}
		process_policy_counters(spec[1], qos_agg, flowintf_agg)
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
end

return AsyncTasks;
