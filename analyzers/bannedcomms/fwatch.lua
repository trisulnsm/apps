--
-- Flow watcher - alert when forbidden flows are seen 
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Detect when host isolation is broken 
-- 
require 'mkconfig' 

-- in trisul: ipv4 keys look like XX.XX.XX.XX
function  readable_ip( ipk)
  local b1, b2, b3, b4 =  ipk:match("(%x+).(%x+).(%x+).(%x+)")
    return string.format("%d.%d.%d.%d", tonumber(b1,16), tonumber(b2,16), tonumber(b3,16), tonumber(b4,16) )
end


TrisulPlugin = { 

  id =  {
    name = "Flow Isolator",
    description = "Monitor endpoints for banned convos  ",
    author = "Unleash",                       -- optional
    version_major = 1,                        -- optional
    version_minor = 0,                        -- optional
  },


  -- any messages you want to handle for state management 
  message_subscriptions = {"{06FD5221-5615-4C4B-945F-8D457ECB5E11}" },

  -- WHEN CALLED: when another plugin sends you a message 
  onmessage = function(msgid, msg)
		local mac = msg:sub(1,17)
		local ip = msg:sub(22,-1)

		local eip = T.macip[mac] 
		if eip == nil then 
			T.macip[mac]=ip
		elseif eip ~= ip then
			local alertmsg = "ALERT .. found new IP assigned to MAC "..mac.." oldip="..readable_ip(eip).." newip="..readable_ip(ip)
			T.dupips[mac] = alertmsg 
		end

  end,

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()


   T.active_config = make_config(
            T.env.get_config("//App/DBRoot").."/config/trisulnsm_bannedcomms.lua",
            {
				WhiteList  =  {
						{ ["0A.02.02.%x%x"] = "0A.02.00.F[BC]" },
						{ ["0A.02.02.%x%x"] = "[EF]%x.%x%x.%x%x.%x%x" },
				} ;
            })

   T.macip = { } 
   T.dupips = { } 
   T.fired = { } 

  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    -- your code 
  end,



  -- sg_monitor block
  -- sg = session group
  sg_monitor  = {

    -- that guid refers to IPv4/IPv6 flows (you can skip the session_guid field if you want its the default )
    session_guid = '{99A78737-4B41-4387-8F31-8077DB917336}', -- optional


	onbeginflush  = function(engine, timestamp)

		for k,amsg in pairs(T.dupips) do 

			if not T.fired[amsg] then 

				engine:add_alert( "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",
						nil,
						"MULTIPLE-IP-ASSIGNED",
						1,
						amsg) 

				T.fired[amsg] = true 

				-- print("alerted ".. amsg) 
			end 
		end 

	end, 

    -- WHEN CALLED: a new flow is seen 
    onupdate  = function(engine, flow ) 


		local cltmatch,svrmatch=0,0
		for _,rule in  ipairs(T.active_config.WhiteList) do
			for clt,svr in pairs(rule) do 
				if  flow:key():match(clt)  then 
					if  flow:key():match(svr)  then 
						svrmatch=svrmatch+1 
					else 
						cltmatch=cltmatch+1 
					end
				end
			end 
		end 

		if cltmatch>0 and svrmatch ==0 then 

			-- print(flow:key()) 

			local fo=flow:flow()
			local amsg = "Prohibited traffic detected between "..fo:ipa_readable().." and "..fo:ipz_readable()
						   .. " device "..fo:netflow_router_readable()
						   .. " in-port ".. fo:netflow_ifindex_in_readable() 
						   .. " out-port ".. fo:netflow_ifindex_out_readable() 

			-- print(amsg)

			-- alert
			engine:add_alert( "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",
					flow:key(),
					"BANNED-CONN",
					1,
					amsg) 
			T.logwarning("BANNED-CONN "..amsg) 


		end 
		
    end,

  },

}
