-- .lua
--
-- snmp_qos_walkpoll.lua
-- Update Trisul Counters based on SNMP CBQOS walk
--
-- GUID QOS-Traffic       = {1AB9F248-1E49-4245-571A-55BCDA658843}
-- GUID QoS-Class           = {116888A7-23B4-4873-5691-E6E0806CCB11}
-- GUID FlowIntf_bx_QOS     = {D3F7A892-4E1B-4C6D-8A5F-2E1C9B7D4A63}

local lsqlite3 = require 'lsqlite3'
local JSON=require'JSON'
local SNMP_DATABASE="c-2314BB8E-2BCC-4B86-8AA2-677E5554C0FE.SQT"
require'mkconfig'

local function is_qos_enabled(snmp)
  local qosenabled = snmp["snmp.qosenabled"]
  return qosenabled == "true" or qosenabled == "1"
end

TrisulPlugin = {

  request_async_workers=2,

  id = {
    name = "SNMP QoS",
    description = "Per Class and Interface QoS Stats from Cisco CBQOS MIB",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  -- load polling targets from DB
  onload = function()
    T.poll_targets =  nil
    T.dbhash = nil
    T.last_poll_secs=0
    T.snmp_agent_database = T.env.get_config("//App/DBRoot").."/config/"..SNMP_DATABASE
    T.async_task = require'async_tasks'

    T.active_config = make_config(
            T.env.get_config("//App/DBRoot").."/config/trisulnsm_snmpqospoll.lua",
            {
				ResolutionSeconds=60,
				MapRefreshPolls=30,
                DebugMode=false,
				IsIPEnabled=function(ip)
					return true
				end
            })

   end,

  engine_monitor = {

    onendflush = function(engine,tv)
      if tv - T.last_poll_secs < T.active_config.ResolutionSeconds then
        return
      else
        T.last_poll_secs = tv
      end

	  if T.active_config.DebugMode then
		  print("---- ENDFLUSH FROM PAST CYCLE    --"..T.async:pending_items())
	  end

      local new_targets =  TrisulPlugin.load_poll_targets(engine:instanceid(), T.snmp_agent_database)
      if new_targets ~= nil then
        T.poll_targets = new_targets
      elseif T.poll_targets == nil or #T.poll_targets == 0 then
        T.log(T.K.loglevel.INFO, "SNMP QoS: no poll targets loaded yet")
      end

	  if T.active_config.DebugMode then
		  print("---- ENDFLUSH ASYNC PENDING ITEMS--"..T.async:pending_items())
	  end

      TrisulPlugin.engine_monitor.schedule_polls(engine,tv)
    end,

    schedule_polls  = function(engine, tv)
      if T.poll_targets == nil then return end
      for _,agent in ipairs(T.poll_targets) do
        agent.map_refresh_polls = T.active_config.MapRefreshPolls
        T.async_task.data =JSON:encode(agent)
        T.async:schedule ( T.async_task)
		agent.poll_count=agent.poll_count+1
      end
    end,

  },


  load_poll_targets = function(engine_id, dbfile)

    local dbhash = TrisulPlugin.capture_oscmd("md5sum "..dbfile)
	if T.poll_targets ~= nil and #T.poll_targets > 0 and T.dbhash == dbhash then
        T.logdebug("No change detected in database contents, using existing agent mapping")
		return T.poll_targets
	end
	print("DBHash = "..dbhash)

    T.log(T.K.loglevel.INFO, "Loading SNMP QoS targets for polling from DB "..dbfile)

    local status,db=pcall(lsqlite3.open,dbfile);
    if not status then
      T.logerror("Error open lsqlite3 err="..db)
      return nil
    end

    local status, stmt=pcall(db.prepare, db,  "SELECT * from KEY_ATTRIBUTES where ATTR_NAME like 'snmp.%'");
    if not status then
      db:close()
      T.logerror("Error prepare lsqlite3 err="..stmt)
      return nil
    end

    local targets = {}
    local snmp_attributes={}
    local ok, stepret = pcall(stmt.step, stmt)
    while stepret  do
      local v = stmt:get_values()
      if snmp_attributes[v[1]] == nil then
        snmp_attributes[v[1]]={}
      end
      snmp_attributes[v[1]][v[2]]=v[3]
      ok, stepret = pcall(stmt.step, stmt)
    end

    for ipkey,snmp in pairs(snmp_attributes) do
      if snmp["snmp.ip"] ~=nil
         and T.util.hash( snmp["snmp.ip"],1) == tonumber(engine_id)
         and T.active_config.IsIPEnabled(snmp["snmp.ip"])
         and is_qos_enabled(snmp) then
        if snmp["snmp.version"] =="2c" then
          if snmp['snmp.community'] ~= nil and #snmp['snmp.community'] > 0  then
            targets[ #targets + 1] = { agent_ip = snmp["snmp.ip"],
								       agent_community = snmp["snmp.community"],
									   agent_version = snmp["snmp.version"]
									 }
            T.log(T.K.loglevel.INFO, "LOADED QoS ip="..snmp["snmp.ip"].." version"..snmp["snmp.version"].." comm=".. snmp["snmp.community"])
          else
            T.log(T.K.loglevel.INFO, "NULL community , skipping deleted SNMP agent  ip="..snmp["snmp.ip"].." version="..snmp["snmp.version"])
          end
        elseif snmp["snmp.version"] == "3" then
          targets[ #targets + 1] = { agent_ip = snmp["snmp.ip"], agent_version = snmp["snmp.version"],
                                    agent_auth_password = snmp["snmp.auth_password"],
                                    agent_auth_protocol = snmp["snmp.auth_protocol"],
                                    agent_priv_password = snmp["snmp.priv_password"],
                                    agent_priv_protocol = snmp["snmp.priv_protocol"],
                                    agent_username = snmp["snmp.username"],
                                    agent_contextname = snmp["snmp.contextname"]
                                  }
          T.log(T.K.loglevel.INFO, "LOADED QoS ip="..snmp["snmp.ip"].." version"..snmp["snmp.version"])
        end
      elseif snmp["snmp.ip"] ~=nil and snmp['snmp.community'] ~= nil and is_qos_enabled(snmp) then
        T.log(T.K.loglevel.INFO, "SKIPPED QoS ip="..snmp["snmp.ip"].." version"..snmp["snmp.version"].." comm=".. snmp["snmp.community"])
      end
    end

    stmt:finalize()
    db:close()

	for _,agent in ipairs(targets) do
		TrisulPlugin.create_commands_for_agent(agent)
	end

	T.dbhash = dbhash
    return targets
  end,


  capture_oscmd=function(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	if raw then return s end
	s = string.gsub(s, '^%s+', '')
	s = string.gsub(s, '%s+$', '')
	s = string.gsub(s, '[\n\r]+', ' ')
	return s
  end,

  create_commands_for_agent=function(agent)

	  local command = "snmpbulkwalk"
	  local cmdargs=""
	  if agent.agent_version == "1" then command="snmpwalk" end
	  local level='noAuthNoPriv'

	  if agent.agent_version=="2c" then
			cmdargs =" -r 1 -O q -t 3  -v"..agent.agent_version.." -c '"..agent.agent_community.."' "..agent.agent_ip
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
		   cmdargs = cmdargs.." "..agent.agent_ip
	  end

	  agent.cmdargs=cmdargs
	  agent.walk_command=command
	  agent.poll_count=0

  end,


}
