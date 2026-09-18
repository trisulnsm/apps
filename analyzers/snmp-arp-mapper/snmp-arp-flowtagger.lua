--
-- session_group_monitor.lua skeleton
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     session (flow) updates. IP flows are a type of sesssion group
-- DESCRIPTION: Handle flow related streaming metrics and listen to flows as they
--              are flushed to the database (hub) node.
--
local lsqlite3 = require("lsqlite3")
local JSON = require("JSON")
require("mkconfig")
local SNMP_DATABASE = "c-2314BB8E-2BCC-4B86-8AA2-677E5554C0FE.SQT"

TrisulPlugin = {

	id = {
		name = "SNMP ARP Mapper",
		description = "Gets ARP entries from SNMP and maps them to IP addresses",
		author = "Unleash", -- optional
		version_major = 1, -- optional
		version_minor = 0, -- optional
	},

	-- common functions onload, onunload, onmessage()..

	-- WHEN CALLED : your LUA script is loaded into Trisul
	onload = function()
		T.poll_targets = nil
		T.last_poll_secs = 0
		T.snmp_agent_database = T.env.get_config("//App/DBRoot") .. "/config/" .. SNMP_DATABASE
        T.arp_entries = {}

		-- --------------------------------------------
		-- override by trisulnsm_snmparp_flowtagger.lua
		-- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config
		--
		T.active_config = make_config(T.env.get_config("//App/DBRoot") .. "/config/trisulnsm_snmparp_flowtagger.lua", {
			-- Resolution Seconds
			ResolutionSeconds = 60,

			-- Print debug messages
			DebugMode = false,

			-- Subnets larger than this many addresses are not expanded into T.arp_entries
			MaxSubnetHosts = 4096,

			-- Filter these IP, default all are allowed
			IsIPEnabled = function(ip)
				return true
			end,
		})
	end,

	-- WHEN CALLED : your LUA script is unloaded  / detached from Trisul
	onunload = function()
		-- your code
	end,

	-- sg_monitor block
	-- sg = session group
	sg_monitor = {

		-- that guid refers to IPv4/IPv6 flows (you can skip the session_guid field if you want its the default )
		session_guid = "{99A78737-4B41-4387-8F31-8077DB917336}", -- optional

		-- WHEN CALLED: when a flow FLUSH operation starts
		-- by default called every "stream snapshot interval" of 60 seconds
		onbeginflush = function(engine,ts)
            if ts - T.last_poll_secs < T.active_config.ResolutionSeconds then
                T.logdebug("Skipping poll for new targets, last poll was less than or equal to resolution seconds ago")
                return
            end
            T.logdebug("Polling for new targets, last poll was more than resolution seconds ago")
            T.last_poll_secs = ts

			T.snmp_agent_database = T.env.get_config("//App/DBRoot") .. "/config/" .. SNMP_DATABASE
			local new_targets = TrisulPlugin.load_poll_targets(engine:instanceid(), T.snmp_agent_database)
			if new_targets ~= nil then
				T.poll_targets = new_targets
			end
            
            if T.poll_targets == nil then
                T.logdebug("No SNMP poll targets loaded, nothing to walk")
                return
            end

            -- rebuilt from scratch on every poll so stale IPs age out
            local new_entries = {}
            local exact_entries = {}
            local total = 0

            for _,agent in ipairs(T.poll_targets) do
                local arp = TrisulPlugin.do_bulk_walk(agent, ".1.3.6.1.2.1.4.22.1.2")
                local netmasks = TrisulPlugin.do_netmask_walk(agent, ".1.3.6.1.2.1.4.20.1.3")

                -- every IP of a local subnet gets the MAC of the interface owning that subnet
                for interface_ip, netmask in pairs(netmasks) do
                    local mac_address = arp[interface_ip]
                    if mac_address then
                        total = total + TrisulPlugin.expand_subnet(interface_ip, netmask, mac_address, new_entries)
                    else
                        T.logdebug("No ARP MAC for interface " .. interface_ip .. ", subnet not expanded")
                    end
                end

                for ip_address, mac_address in pairs(arp) do
                    exact_entries[ip_address] = mac_address
                end
            end

            -- a real ARP entry always wins over the subnet wide interface MAC
            for ip_address, mac_address in pairs(exact_entries) do
                new_entries[ip_address] = mac_address
            end

            T.arp_entries = new_entries
			for key, value in pairs(T.arp_entries) do
				print(key .. ": " .. tostring(value))
			end
            T.logdebug("arp_entries rebuilt, subnet addresses=" .. total)
		end,

		-- WHEN CALLED: before a flow is flushed to the Hub node
		onflush = function(engine, flow)

            local ipa = flow:flow():ipa_readable()
            local ipz = flow:flow():ipz_readable()
            local natip = flow:tags():match("%[natip%](%d+%.%d+%.%d+%.%d+)")

            local lookup_list = {ipa, ipz, natip}
            for _, ip in ipairs(lookup_list) do
                if ip then
                    local mac_address = T.arp_entries[ip]
                    if mac_address then
                        flow:add_tag("[mac]" .. mac_address)
                    end
                end
            end
		end,
	},

	-- load polling targets from sqlite3 database
	load_poll_targets = function(engine_id, dbfile)
		local dbhash = TrisulPlugin.capture_oscmd("md5sum " .. dbfile)
		if T.poll_targets ~= nil and T.dbhash == dbhash then
			T.logdebug("No change detected in database contents, using existing agent mapping")
			return nil
		end
		T.dbhash = dbhash
		print("DBHash = " .. T.dbhash .. " file hash " .. dbhash)

		T.log(T.K.loglevel.INFO, "Loading SNMP targets for polling from DB " .. dbfile)

		local status, db = pcall(lsqlite3.open, dbfile)
		if not status then
			T.logerror("Error open lsqlite3 err=" .. db)
			return nil
		end

		local status, stmt = pcall(db.prepare, db, "SELECT * from KEY_ATTRIBUTES where ATTR_NAME like 'snmp.%'")
		if not status then
			db:close()
			T.logerror("Error prepare lsqlite3 err=" .. stmt)
			return nil
		end

		local targets = {}
		local snmp_attributes = {}
		local ok, stepret = pcall(stmt.step, stmt)
		while stepret do
			local v = stmt:get_values()
			if snmp_attributes[v[1]] == nil then
				snmp_attributes[v[1]] = {}
			end
			snmp_attributes[v[1]][v[2]] = v[3]
			ok, stepret = pcall(stmt.step, stmt)
		end

		for ipkey, snmp in pairs(snmp_attributes) do
			if
				snmp["snmp.ip"] ~= nil
				and T.active_config.IsIPEnabled(snmp["snmp.ip"])
			then
				if snmp["snmp.version"] == "2c" then
					if snmp["snmp.community"] ~= nil and #snmp["snmp.community"] > 0 then
						targets[#targets + 1] = {
							agent_ip = snmp["snmp.ip"],
							agent_community = snmp["snmp.community"],
							agent_version = snmp["snmp.version"],
						}
						T.log(
							T.K.loglevel.INFO,
							"LOADED  ip="
								.. snmp["snmp.ip"]
								.. " version"
								.. snmp["snmp.version"]
								.. " comm="
								.. snmp["snmp.community"]
						)
					else
						T.log(
							T.K.loglevel.INFO,
							"NULL community , skipping deleted SNMP agent  ip="
								.. snmp["snmp.ip"]
								.. " version="
								.. snmp["snmp.version"]
						)
					end
				elseif snmp["snmp.version"] == "3" then
					targets[#targets + 1] = {
						agent_ip = snmp["snmp.ip"],
						agent_version = snmp["snmp.version"],
						agent_auth_password = snmp["snmp.auth_password"],
						agent_auth_protocol = snmp["snmp.auth_protocol"],
						agent_priv_password = snmp["snmp.priv_password"],
						agent_priv_protocol = snmp["snmp.priv_protocol"],
						agent_username = snmp["snmp.username"],
						agent_contextname = snmp["snmp.contextname"],
					}
				end
			elseif snmp["snmp.ip"] ~= nil and snmp["snmp.community"] ~= nil then
				T.log(
					T.K.loglevel.INFO,
					"SKIPPED ip="
						.. snmp["snmp.ip"]
						.. " version"
						.. snmp["snmp.version"]
						.. " comm="
						.. snmp["snmp.community"]
				)
			end
		end

		stmt:finalize()
		db:close()

		for _, agent in ipairs(targets) do
			TrisulPlugin.create_commands_for_agent(agent)
		end

		return targets
	end,

	capture_oscmd = function(cmd, raw)
		local f = assert(io.popen(cmd, "r"))
		local s = assert(f:read("*a"))
		f:close()
		if raw then
			return s
		end
		s = string.gsub(s, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		s = string.gsub(s, "[\n\r]+", " ")
		return s
	end,

	create_commands_for_agent = function(agent)
		local command = "snmpbulkwalk"
		local cmdargs = ""
		if agent.agent_version == "1" then
			command = "snmpwalk"
		end
		local level = "noAuthNoPriv"

		if agent.agent_version == "2c" then
			cmdargs = " -r 1 -O q -t 3  -v"
				.. agent.agent_version
				.. " -c '"
				.. agent.agent_community
				.. "' "
				.. agent.agent_ip
		elseif agent.agent_version == "3" then
			cmdargs = " -r 1 -O q -t 3  -v" .. agent.agent_version .. " -u " .. agent.agent_username
			if agent.agent_auth_password ~= nil and #agent.agent_auth_password > 0 then
				level = "authNoPriv"
				cmdargs = cmdargs .. " -a " .. agent.agent_auth_protocol .. " -A " .. agent.agent_auth_password
			end
			if agent.agent_priv_password ~= nil and #agent.agent_priv_password > 0 then
				level = "authPriv"
				cmdargs = cmdargs .. " -x " .. agent.agent_priv_protocol .. " -X " .. agent.agent_priv_password
			end
			cmdargs = cmdargs .. " -l " .. level
			if agent.agent_contextname ~= nil and #agent.agent_contextname > 0 then
				level = "authPriv"
				cmdargs = cmdargs .. " -n " .. agent.agent_contextname
			end
			cmdargs = cmdargs .. " " .. agent.agent_ip
		end

		agent.cmdargs = cmdargs
		agent.walk_command = command
		agent.poll_count = 0
	end,

	run_walk=function(agent,oid,parse_line)
        local ofile = os.tmpname()

        os.execute(agent.walk_command.." "..agent.cmdargs.. " " .. oid .. " > "..ofile)

        local ret = { }
        local h=io.open(ofile)
        if h then
            for oneline in h:lines()
            do
                parse_line(oneline, ret)
            end
            h:close()
        else
            T.logerror("Cannot read snmp walk output for oid="..oid)
        end
        os.remove(ofile)
        return ret
      end,

	-- walk ipNetToMediaPhysAddress .1.3.6.1.2.1.4.22.1.2 -> { ip = mac }
	do_bulk_walk=function(agent,oid)
        return TrisulPlugin.run_walk(agent, oid, function(oneline, ret)
            -- Parse line like: iso.3.6.1.2.1.4.22.1.2.9.192.168.2.1 "44 95 3B B2 DB C0 "
            -- Extract IP address from OID (the IP appears as part of the OID before the quoted MAC)
            -- Match pattern: .192.168.2.1 "MAC" or 192.168.2.1 "MAC"
            local ip_address = oneline:match("(%d+%.%d+%.%d+%.%d+)%s+\"")
            -- Extract MAC address from quoted string
            local mac_address = oneline:match('"([^"]+)"')

            if ip_address and mac_address then
                -- Convert MAC address from space-separated to colon-separated format
                -- Remove leading/trailing spaces and convert spaces to colons
                mac_address = mac_address:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", ":")
                -- Convert to uppercase for consistency
                mac_address = mac_address:upper()
                ret[ip_address] = mac_address
            else
                print("ERROR in snmp output line="..oneline)
            end
        end)
      end,

	-- walk ipAdEntNetMask .1.3.6.1.2.1.4.20.1.3 -> { interface_ip = netmask }
	do_netmask_walk=function(agent,oid)
        return TrisulPlugin.run_walk(agent, oid, function(oneline, ret)
            -- Parse line like: iso.3.6.1.2.1.4.20.1.3.192.168.2.1 255.255.255.0
            -- the IP is the tail of the OID, the value is the netmask
            local interface_ip, netmask = oneline:match("4%.20%.1%.3%.(%d+%.%d+%.%d+%.%d+)%s+(%d+%.%d+%.%d+%.%d+)")

            if interface_ip and netmask then
                if interface_ip:match("^127%.") or interface_ip == "0.0.0.0" or netmask == "0.0.0.0" then
                    return
                end
                ret[interface_ip] = netmask
            else
                print("ERROR in snmp netmask output line="..oneline)
            end
        end)
      end,

	ip_to_u32 = function(ip)
		local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
		if a == nil then
			return nil
		end
		a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
		if a > 255 or b > 255 or c > 255 or d > 255 then
			return nil
		end
		return a * 16777216 + b * 65536 + c * 256 + d
	end,

	u32_to_ip = function(n)
		return math.floor(n / 16777216) % 256
			.. "."
			.. math.floor(n / 65536) % 256
			.. "."
			.. math.floor(n / 256) % 256
			.. "."
			.. n % 256
	end,

	-- addresses in the block described by this mask, nil if the mask is not contiguous
	mask_to_blocksize = function(mask_u32)
		local remaining = mask_u32
		local ones = 0
		for i = 31, 0, -1 do
			local bitval = 2 ^ i
			if remaining >= bitval then
				remaining = remaining - bitval
				ones = ones + 1
			else
				break
			end
		end
		if remaining ~= 0 then
			return nil
		end
		return 2 ^ (32 - ones)
	end,

	-- write every host IP of interface_ip/netmask into out, all pointing at mac_address
	expand_subnet = function(interface_ip, netmask, mac_address, out)
		local ip_u32 = TrisulPlugin.ip_to_u32(interface_ip)
		local mask_u32 = TrisulPlugin.ip_to_u32(netmask)
		if ip_u32 == nil or mask_u32 == nil then
			T.logdebug("Bad subnet " .. interface_ip .. "/" .. netmask)
			return 0
		end

		local blocksize = TrisulPlugin.mask_to_blocksize(mask_u32)
		if blocksize == nil then
			T.logdebug("Non contiguous netmask " .. netmask .. " on " .. interface_ip)
			return 0
		end

		if blocksize > T.active_config.MaxSubnetHosts then
			T.logdebug("Skipping oversized subnet " .. interface_ip .. "/" .. netmask)
			return 0
		end

		local network = ip_u32 - (ip_u32 % blocksize)
		local first, last = network, network + blocksize - 1
		if blocksize > 2 then
			-- skip network and broadcast addresses
			first, last = network + 1, network + blocksize - 2
		end

		for h = first, last do
			out[TrisulPlugin.u32_to_ip(h)] = mac_address
		end
		return last - first + 1
	end,

}
