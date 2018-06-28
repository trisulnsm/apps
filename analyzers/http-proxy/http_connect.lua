--
-- http_connect.lua
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Hook into Trisul's TCP reassembly engine 
-- DESCRIPTION: Marks the CONNECT protocol to account for Proxy Destination hosts and protocols 
-- 

function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

-- --------------------------------------------
-- override by trisulnsm_http_connect.lua 
-- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
--
DEFAULT_CONFIG = {

  -- number of dots in hostname to track 
  -- skks.mail.yahoo.com = 3 dots 
  NumDots=3,
  
  -- max hostname len 
  MaxHostnameLen=25,
}
-- --------------------------------------------

TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "HTTP CONNECT",
    description = "Handles HTTP proxies (like Squid) ",
  },

  onload = function()

  	T.re2_http_request = T.re2("(GET|POST|HEAD|OPTIONS|CONNECT)\\s(\\S+)\\sHTTP/\\d\\.\\d")
	T.re2_connect=T.re2("CONNECT\\s(\\S+):(\\d+)")

    -- load custom config if present 
    T.active_config = DEFAULT_CONFIG
    local custom_config_file = T.env.get_config("App>DBRoot").."/config/trisulnsm_http_connect.lua"

    if file_exists(custom_config_file) then 
      local newsettings = dofile(custom_config_file) 
      T.log("Loading custom settings from ".. custom_config_file)
      for k,v in pairs(newsettings) do 
        T.active_config[k]=v
        T.log("Loaded new setting "..k.."="..v)
      end
    else 
      T.log("Loaded default settings")
    end

  end,

  -- reassembly_handler block
  -- 
  reassembly_handler   = {


    -- handle reassembled byte stream here , 
    -- HTTP go straight to proxy
	-- CONNECT for HTTPS 
    onpayload = function(engine, timestamp, flowkey, direction, seekpos, buffer) 
		
		-- bail if not head of flow  
		if  seekpos>0  then  return end 

		local buffstr = buffer:tostring() 

		-- do we see HTTP like request 
		local match,c1,c2 = T.re2_http_request:partial_match_n(buffstr)
		if not match  then 
			return
		end 


		local external_host 
		if c1 == "CONNECT" then 
			local match, host, port = T.re2_connect:partial_match_n(buffstr)
		    external_host=host 
		else
			local _,_,host = buffstr:find("Host%s*:%s*(%S+)")
			external_host=host
		end 

		if external_host == nil then
			T.loginfo("No hostname found in either CONNECT or HTTP Verbs: "..buffstr:sub(1,20));
			return
		end


		-- gotta massage the external host name from HTTP CONNECT 
		-- can be huge like -civaszsc6z7ws-bgljqcbnz6z5e5jx-611747-i1-v6exp3-v4.metric.gstatic.com

		-- restrict hostname to Max dots  for max utility  
		local t = {}                   
		local i = 0
		while true do
		  i = string.find(external_host , '.', i+1, true)    
		  if i == nil then break end
		  table.insert(t, i)
		end

		if #t > T.active_config.NumDots then 
			 external_host= string.sub(external_host,t[#t-T.active_config.NumDots]+1)
		end 

		-- now dont allow huge lengths (again trackers do this) 
		if #external_host > T.active_config.MaxHostnameLen then
			external_host=string.sub(external_host,#external_host-T.active_config.MaxHostnameLen,-1)
		end


		-- Tag flow - so you can search by it 
		engine:tag_flow(flowkey:id(), external_host)

		-- for XMIT 
		engine:add_flow_counter( flowkey:id(), 
								 "{55F98CC1-646E-4DE6-AD79-6B896211F178}",  -- see below new counter group
								 external_host, 0, 1)
		-- for RECV
		engine:add_flow_counter( flowkey:id(), 
								 "{55F98CC1-646E-4DE6-AD79-6B896211F178}",  -- see below new counter group
								 external_host, 1, 2)

		-- EDGE 
		engine:add_flow_edges( flowkey:id(), 
							   "{55F98CC1-646E-4DE6-AD79-6B896211F178}",  
							   external_host);
		
    end,


  },

  -- countergroup block
  -- for PROXY_EXTERNAL_HOSTS 
  countergroup = {

	-- 
    control = {
      guid = "{55F98CC1-646E-4DE6-AD79-6B896211F178}",
      name = "Proxy External",
      description = "Measure external hosts via Proxy",
	  bucketsize=60,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short 
    -- 
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 30, 30, "to traffic", 		"Upload to",        "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 30, 30, "from traffic", 	"Download from",    "Bps" },
    },  

  },
}
