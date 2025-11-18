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
		T.snmp_agent_database = T.env.get_config("App>DBRoot") .. "/config/" .. SNMP_DATABASE
        T.arp_entries = {}

		-- --------------------------------------------
		-- override by trisulnsm_snmparp_flowtagger.lua
		-- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config
		--
		T.active_config = make_config(T.env.get_config("App>DBRoot") .. "/config/trisulnsm_snmparp_flowtagger.lua", {
			-- Resolution Seconds
			ResolutionSeconds = 60,

			-- Print debug messages
			DebugMode = false,

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

            if ts - T.last_poll_secs <= T.active_config.ResolutionSeconds then
                T.logdebug("Skipping poll for new targets, last poll was less than or equal to resolution seconds ago")
                return
            end
            T.logdebug("Polling for new targets, last poll was more than resolution seconds ago")
            T.last_poll_secs = ts

			T.snmp_agent_database = T.env.get_config("App>DBRoot") .. "/config/" .. SNMP_DATABASE
			local new_targets = TrisulPlugin.load_poll_targets(engine:instanceid(), T.snmp_agent_database)
			if new_targets ~= nil then
				T.poll_targets = new_targets
			end
            
            for _,agent in ipairs(T.poll_targets) do
                local new_arp_entries = TrisulPlugin.do_bulk_walk(agent, ".1.3.6.1.2.1.4.22.1.2")
                for ip_address, mac_address in pairs(new_arp_entries) do
                    T.arp_entries[ip_address] = mac_address
                end
            end

            -- print the arp_entries
            for ip_address, mac_address in pairs(T.arp_entries) do
                print("ip_address", ip_address, "mac_address", mac_address)
            end
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
				and T.util.hash(snmp["snmp.ip"], 1) == tonumber(engine_id)
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

	do_bulk_walk=function(agent,oid)
        local tstart = os.time()
        local ofile = os.tmpname() 
  
        os.execute(agent.walk_command.." "..agent.cmdargs.. " " .. oid .. " > "..ofile)
  
        local ret = { } 
        local h=io.open(ofile)
        for oneline in h:lines()
        do
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
        end 
        h:close()
        os.remove(ofile)
        return ret
      end

}
