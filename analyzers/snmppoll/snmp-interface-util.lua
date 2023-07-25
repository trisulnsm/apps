-- .lua
--
-- SNMP-interface-util
-- Update the Recv-Util and Xmit-Util meters based on traffic and ifspeed 
-- Based on snmp.ifspeed available in the NETFLOW feature 
--
local lsqlite3 = require 'lsqlite3'
-- local dbg = require("debugger")

-- ONLY Flow_interface contains the ifSpeed, we dont want to duplicate 
-- this 
local PERSIST_DB_FILENAME="c-C0B04CA7-95FA-44EF-8475-3835F3314761.SQT"

TrisulPlugin = {

  id = {
    name = "SNMP-Intf Util",
    description = "Computes Recv and Xmit pure SNMP based on ifSpeed",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  -- load polling targets from DB 
  onload = function()
    T.ifspeeds  =  {} 
  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    --  FlowIntf  
    counter_guid = "{9781DB2C-F78A-4F7F-A7E8-2B1A9A7BE71A}",


    -- reload if hash changed of persist mapping 
    onbeginflush = function(engine, timestamp) 
		local persist_file = T.env.get_config("App>DBRoot").."/config/"..PERSIST_DB_FILENAME
		local f = io.open(persist_file,"r")
		if not f then
			T.ifspeeds = nil
			return
		else
			f:close()
		end

		local pipeout = io.popen("md5sum   "..persist_file)
		local md5hash = pipeout:read("*a")
		pipeout:close()
		if T.persist_hash == md5hash then
			return
		end 

		-- reload
		T.ifspeeds = {} 

		T.log(T.K.loglevel.INFO, "Loading ifspeeds from "..persist_file)
		local status,db=pcall(lsqlite3.open,persist_file);
		if not status then
		  T.logerror("Error open lsqlite3 err="..db)
		  return nil
		end 

		local status, stmt=pcall(db.prepare, db,  
									"SELECT KEY, ATTR_NAME, ATTR_VALUE from KEY_ATTRIBUTES where ATTR_NAME = 'snmp.ifspeed'");
		if not status then
		  db:close() 
		  T.logerror("Error prepare lsqlite3 err="..stmt)
		  return nil
		end 
		local ok, stepret = pcall(stmt.step, stmt) 
		while stepret  do
		  local v = stmt:get_values()
		  T.ifspeeds[ v[1] ] = v[3]
		  ok, stepret = pcall(stmt.step, stmt) 
		end
		stmt:finalize()
		db:close()

		T.persist_hash = md5hash
    end,

    -- WHEN CALLED: before an item  is flushed to the Hub node  
    onflushfilter = function(engine, timestamp,key, metrics) 

		if T.ifspeeds == nil then return true; end

		local ifi = T.ifspeeds[key]
		if ifi then
			local nspeed = tonumber(ifi) 
			if nspeed > 0 then 
				local recvutil  = (metrics[2] * 8 * 100 )  / nspeed
				local xmitutil  = (metrics[3] * 8 * 100 )  / nspeed
				engine:update_counter("{9781DB2C-F78A-4F7F-A7E8-2B1A9A7BE71A}", key, 3,  recvutil)
				engine:update_counter("{9781DB2C-F78A-4F7F-A7E8-2B1A9A7BE71A}", key, 4,  xmitutil)
				return true, { -1, -1, -1, recvutil, xmitutil }  -- -1 will not touch the metric 
			end 
		end 
		
		return true 
    end,
  },
}
