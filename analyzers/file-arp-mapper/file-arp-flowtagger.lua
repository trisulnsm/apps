--
-- file-arp-flowtagger.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     session (flow) updates. IP flows are a type of session group
-- DESCRIPTION: Reads ARP/SSM JSON-line records from the latest file in a directory
--              and tags flows with the MAC address whenever the flow LAN IP
--              (ipa/ipz) or WAN/NAT IP (natip/wan_ip) matches a record.
--
local JSON = require("JSON")
require("mkconfig")

TrisulPlugin = {

	id = {
		name = "File ARP Mapper",
		description = "Reads ARP entries from the latest JSON-line file in a directory and maps them to IP addresses",
		author = "Unleash", -- optional
		version_major = 1, -- optional
		version_minor = 0, -- optional
	},

	-- common functions onload, onunload, onmessage()..

	-- WHEN CALLED : your LUA script is loaded into Trisul
	onload = function()
		T.last_poll_secs = 0
		T.arp_entries = {}
		T.last_file = nil

		-- --------------------------------------------
		-- override by trisulnsm_filearp_flowtagger.lua
		-- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config
		--
		T.active_config = make_config(T.env.get_config("App>DBRoot") .. "/config/trisulnsm_filearp_flowtagger.lua", {
			-- Directory containing the ARP record files
			FilePath = "/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/arp",

			-- Only files starting with this prefix are considered. The most
			-- recently modified matching file is used.
			FilePrefix = "arp",

			-- Resolution Seconds - how frequently the directory is re-scanned
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
		onbeginflush = function(engine, ts)
			if ts - T.last_poll_secs < T.active_config.ResolutionSeconds then
				T.logdebug("Skipping rescan, last scan was less than or equal to resolution seconds ago")
				return
			end
			T.logdebug("Rescanning ARP directory for the latest file")
			T.last_poll_secs = ts

			local latest_file = TrisulPlugin.find_latest_file(T.active_config.FilePath, T.active_config.FilePrefix)
			if latest_file == nil then
				T.logdebug("No matching ARP file found in " .. T.active_config.FilePath)
				return
			end

			-- already loaded this file, reuse cached entries (no re-unzip/parse)
			if latest_file == T.last_file then
				if T.active_config.DebugMode then
					print("[file-arp-mapper] latest file unchanged, reusing cached entries = " .. latest_file .. ", old file = " .. tostring(T.last_file))
				end
				return
			end

			local new_arp_entries = TrisulPlugin.load_arp_entries(latest_file)
			if new_arp_entries ~= nil then
				T.arp_entries = new_arp_entries
				-- only mark this file as loaded once it parsed successfully, so a
				-- failed load is retried on the next poll instead of being cached
				T.last_file = latest_file
			end

			if T.active_config.DebugMode then
				for ip_address, mac_address in pairs(T.arp_entries) do
					print("ip_address", ip_address, "mac_address", mac_address)
				end
			end
		end,

		-- WHEN CALLED: before a flow is flushed to the Hub node
		onflush = function(engine, flow)
			local ipa = flow:flow():ipa_readable()
			local ipz = flow:flow():ipz_readable()
			local natip = flow:tags():match("%[natip%](%d+%.%d+%.%d+%.%d+)")

			local lookup_list = { ipa, ipz, natip }
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

	-- find the most recently modified file in dir whose name starts with prefix
	find_latest_file = function(dir, prefix)
		local cmd = "ls -1t " .. dir .. "/" .. prefix .. "* 2>/dev/null | head -1"
		if T.active_config.DebugMode then
			print("[file-arp-mapper] FilePath  = " .. dir)
			print("[file-arp-mapper] FilePrefix= " .. prefix)
			print("[file-arp-mapper] command   = " .. cmd)
		end
		local latest = TrisulPlugin.capture_oscmd(cmd)
		if latest == nil or #latest == 0 then
			return nil
		end
		if T.active_config.DebugMode then
			print("[file-arp-mapper] latest file = " .. latest)
		end
		return latest
	end,

	-- read JSON-line records from file and build an ip_address -> mac_address map
	load_arp_entries = function(filename)
		T.log(T.K.loglevel.INFO, "Loading ARP entries from file " .. filename)

		-- gzipped files (.gz) are read by piping through gunzip, plain files
		-- are opened directly
		local is_gzip = filename:sub(-3) == ".gz"

		if T.active_config.DebugMode then
			print("[file-arp-mapper] loading file = " .. filename .. (is_gzip and " (gzip)" or " (plain)"))
		end

		local h
		if is_gzip then
			h = io.popen("gunzip -c '" .. filename .. "' 2>/dev/null", "r")
		else
			h = io.open(filename, "r")
		end
		if h == nil then
			T.logerror("Could not open ARP file " .. filename)
			return nil
		end

		local ret = {}
		for oneline in h:lines() do
			oneline = oneline:gsub("^%s+", ""):gsub("%s+$", "")
			if #oneline > 0 then
				local ok, rec = pcall(JSON.decode, JSON, oneline)
				if ok and type(rec) == "table" and rec.mac ~= nil and #rec.mac > 0 then
					local mac_address = rec.mac

					-- LAN side IP
					if rec.ipv4_addr ~= nil and #rec.ipv4_addr > 0 and T.active_config.IsIPEnabled(rec.ipv4_addr) then
						ret[rec.ipv4_addr] = mac_address
					end

					-- WAN / NAT side IP
					if rec.wan_ip ~= nil and #rec.wan_ip > 0 and T.active_config.IsIPEnabled(rec.wan_ip) then
						ret[rec.wan_ip] = mac_address
					end
				else
					T.logdebug("Skipping unparseable ARP line=" .. oneline)
				end
			end
		end
		h:close()

		if T.active_config.DebugMode then
			local ip_count = 0
			for _ in pairs(ret) do
				ip_count = ip_count + 1
			end
			print("[file-arp-mapper] loaded " .. ip_count .. " IP -> MAC entries from " .. filename)
		end

		return ret
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

}
