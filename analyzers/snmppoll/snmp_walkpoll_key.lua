-- .lua     
--       
-- snmp_walkpoll.lua   
-- Update Trisul Counters based on SNMP walk 
--   
--  
-- GUID  of new counter group SNMP-Interface = {9781db2c-f78a-4f7f-a7e8-2b1a9a7be71a} 

local lsqlite3 = require 'lsqlite3'
local JSON=require'JSON'
-- local dbg = require("debugger")
local SNMP_DATABASE="c-2314BB8E-2BCC-4B86-8AA2-677E5554C0FE.SQT"
require'mkconfig'

TrisulPlugin = {

  request_async_workers=2,

  id = {
    name = "SNMP Interface",
    description = "Per Interface Stats : Key Agent:IfIndex ",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  countergroup = {
    control = {
      guid = "{9781db2c-f78a-4f7f-a7e8-2b1a9a7be71a}",
      name = "SNMP-Interface",
      description = "Traffic using SNMP input ",
      bucketsize = 60,
    },
    meters = {
      {  0, T.K.vartype.DELTA_RATE_COUNTER,      100, "bytes", "Total BW",  "Bps" },
      {  1, T.K.vartype.DELTA_RATE_COUNTER,      100, "bytes", "In BW",  	"Bps" },
      {  2, T.K.vartype.DELTA_RATE_COUNTER,      100, "bytes", "Out BW",  	"Bps" },
    },
  },

  -- load polling targets from DB 
  onload = function()
    T.poll_targets =  nil
    T.last_poll_secs=0
    T.snmp_agent_database = T.env.get_config("App>DBRoot").."/config/"..SNMP_DATABASE
    T.async_task = require'async_tasks'

  -- --------------------------------------------
  -- override by trisulnsm_snmpwalkpoll.lua 
  -- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
  --
    T.active_config = make_config(
            T.env.get_config("App>DBRoot").."/config/trisulnsm_snmpwalkpoll.lua",
            {
				-- Resolution Seconds 
				ResolutionSeconds=60,

                -- Print debug messages 
                DebugMode=false,

				-- Filter these IP, default all are allowed 
				IsIPEnabled=function(ip) 
					return true
				end 
            })

   end,

  engine_monitor = {

    -- every interval reload the map -
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
      end

	  if T.active_config.DebugMode then 
		  print("---- ENDFLUSH ASYNC PENDING ITEMS--"..T.async:pending_items())
	  end 

      TrisulPlugin.engine_monitor.schedule_polls(engine,tv)
    end,

    -- schedule polls 
    schedule_polls  = function(engine, tv)
      if T.poll_targets == nil then return end
      for _,agent in ipairs(T.poll_targets) do 
        T.async_task.data =JSON:encode(agent)
        T.async:schedule ( T.async_task) 
		agent.poll_count=agent.poll_count+1
      end
    end,

  },


  -- load polling targets from sqlite3 database 
  -- in this case webtrisul db 
  -- return { agent => [ifindex] } mappings 
  load_poll_targets = function(engine_id, dbfile)


    local dbhash = TrisulPlugin.capture_oscmd("md5sum "..dbfile)
	if T.poll_targets ~= nil and T.dbhash == dbhash then 
        T.logdebug("No change detected in database contents, using existing agent mapping")
		return nil
	end
	T.dbhash=dbhash
	print("DBHash = "..T.dbhash.." file hash "..dbhash) 

    T.log(T.K.loglevel.INFO, "Loading SNMP targets for polling from DB "..dbfile)

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
      if snmp["snmp.ip"] ~=nil and T.util.hash( snmp["snmp.ip"],1) == tonumber(engine_id)  and T.active_config.IsIPEnabled(snmp["snmp.ip"]) then 
        if snmp["snmp.version"] =="2c" then
          if snmp['snmp.community'] ~= nil and #snmp['snmp.community'] > 0  then 
            targets[ #targets + 1] = { agent_ip = snmp["snmp.ip"], 
								       agent_community = snmp["snmp.community"], 
									   agent_version = snmp["snmp.version"]
									 }
            T.log(T.K.loglevel.INFO, "LOADED  ip="..snmp["snmp.ip"].." version"..snmp["snmp.version"].." comm=".. snmp["snmp.community"])
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
        end
      elseif  snmp["snmp.ip"] ~=nil and snmp['snmp.community'] ~= nil then
        T.log(T.K.loglevel.INFO, "SKIPPED ip="..snmp["snmp.ip"].." version"..snmp["snmp.version"].." comm=".. snmp["snmp.community"])
      end 
    end

    stmt:finalize()
    db:close()

	for _,agent in ipairs(targets) do 
		TrisulPlugin.create_commands_for_agent(agent)
	end

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

