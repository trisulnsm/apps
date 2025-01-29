

local lsqlite3 = require 'lsqlite3'
local JSON=require'JSON'
require'mkconfig'


TrisulPlugin = {

  id = {
    name = "Hello World",
    description = "Nothing much ",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  onload = function()
    T.last_loded_time= 0
    T.terminal_ip_mappings={}
    T.regex=T.re2(".*\\[natip\\]([\\d.]+)")
    T.host:log(T.K.loglevel.INFO, "TEST LUA loaded");
    T.active_config = make_config(
      T.env.get_config("App>DBRoot").."/config/trisulnsm_ipdr_tag_userid.lua",
      {
        DebugMode=false,
        RefreshInterval=3600, --in seconds/every one hour
        DBFile=T.env.get_config("App>DBRoot").."/config/".."IPDRCONTROL.SQDB",
      }
    )
    local new_terminal_ip_mappings = TrisulPlugin.load_terminal_mappings(T.active_config.DBFile)
    if(new_terminal_ip_mappings~=nil) then
      T.terminal_ip_mappings=new_terminal_ip_mappings
    end
  end,

  onunload = function ()
    print("OnUnload PKT - TEST")

  end,


  sg_monitor  = {

    session_guid = '{99A78737-4B41-4387-8F31-8077DB917336}',

    onflush = function(engine, flow)
      local src_ip_num = TrisulPlugin.key_toipnum(flow:flow():ipa())
      local dst_ip_num = TrisulPlugin.key_toipnum(flow:flow():ipz())
      
     

      if(T.terminal_ip_mappings[src_ip_num]) then
        flow:add_tag("[username]" .. T.terminal_ip_mappings[src_ip_num])
      end
      if(T.terminal_ip_mappings[dst_ip_num]) then
        flow:add_tag("[username]" .. T.terminal_ip_mappings[dst_ip_num])
      end
      --matching nat ip from the tag
      local bret,natip = T.regex:partial_match_n(flow:tags())
      if(bret==true) then
        local natipkey=TrisulPlugin.ipstr_tokey(natip)
        local natipnum =  TrisulPlugin.key_toipnum(natipkey)
         if(T.terminal_ip_mappings[natipnum]) then
          flow:add_tag("[username]" .. T.terminal_ip_mappings[natipnum])
        end
      end
    end,

    onendflush = function(engine, flow)
      local new_terminal_ip_mappings = TrisulPlugin.load_terminal_mappings(T.active_config.DBFile)
      if(new_terminal_ip_mappings~=nil) then
        T.terminal_ip_mappings=new_terminal_ip_mappings
      end
    end,


  },


  load_terminal_mappings=function(dbfile)
    local current_time = tonumber(os.time())


    if(current_time-T.last_loded_time < T.active_config.RefreshInterval or T.last_loded_time ~=0 ) then
      T.logdebug("No change detected in database contents, using existing agent mapping")
      return nil
    end
    T.last_loded_time=current_time
  

    local mappings = {}
    local db, err = lsqlite3.open(dbfile) 

    if not db then
      T.logerror("Error opening SQLite database: " .. err)
      return nil
    end

    
	T.loginfo("IPDR-CUSTMAP   Loading customer mappings from " .. dbfile) 
    local query = string.format("SELECT IPDR_CUSTOMER_MAPPINGS.ipsubnet, IPDR_CUSTOMERS.UserID FROM IPDR_CUSTOMER_MAPPINGS INNER JOIN IPDR_CUSTOMERS ON IPDR_CUSTOMERS.id = IPDR_CUSTOMER_MAPPINGS.ipdr_customer_id WHERE IPDR_CUSTOMER_MAPPINGS.starttime <= %s AND (IPDR_CUSTOMER_MAPPINGS.endtime IS NULL OR IPDR_CUSTOMER_MAPPINGS.endtime >= %s);",current_time,current_time)
    local status, stmt = pcall(db.prepare, db, query)
    --print(query)
    if not status then
      db:close()
      T.logerror("Error prepare lsqlite3 err="..stmt)
      return nil
    end
    local ok, stepret = pcall(stmt.step, stmt)
    while stepret  do
      local row = stmt:get_values()
      if(row[2]~=nil) then
        local ipcidr = row[1]
        if not string.find(ipcidr, "/") then
          ipcidr = ipcidr .. "/32"
        end
        local ns, ne = TrisulPlugin.cidr_range(ipcidr) 
        for ipnum =ns,ne,1 do
          mappings[ipnum]=row[2]
        end
      end
      ok, stepret = pcall(stmt.step, stmt) 
    end
    stmt:finalize()
    db:close()


    return mappings
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

  key_toipnum=function (key)
    local pmatch,_, b1,b2,b3,b4= key:find("(%x+)%.(%x+)%.(%x+)%.(%x+)")
    return  tonumber(b1,16)*16777216+tonumber(b2,16)*65536+tonumber(b3,16)*256+tonumber(b4,16) 
  end,

  ipstr_tokey=function (ipstr)
    local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
  end,

  cidr_range=function(ip_range)
    local _,_, b1,b2,b3,b4,cidr = ip_range:find("(%d+)%.(%d+)%.(%d+)%.(%d+)/*(%d*)")
    if b1 == nil then return; end  
      local num_start = b1*math.pow(2,24) + b2*math.pow(2,16) + b3*math.pow(2,8) + b4*math.pow(2,0) 
      local num_end = num_start
      if #cidr > 0  then 
        num_end = num_start + math.pow(2, 32-tonumber(cidr)) -1 
      end

    return num_start, num_end 
  end

}

