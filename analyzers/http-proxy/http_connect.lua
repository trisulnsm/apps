--
-- http_connect.lua
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Hook into Trisul's TCP reassembly engine 
-- DESCRIPTION: Marks the CONNECT protocol to account for Proxy Destination hosts and protocols 
-- 
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
