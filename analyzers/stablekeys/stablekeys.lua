--
-- StableKeys.lua
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Monitor is keys are completely stable every interval
-- DESCRIPTION: All keys in a group must be present from one interval to the next
-- 
-- 
-- 

require 'mkconfig' 

function ip_readable(key)

	local ret,_, b1, b2, b3, b4 = string.find( key, "(%x+).(%x+).(%x+).(%x+)")
	if ret then 
	 	return string.format( "%d.%d.%d.%d", tonumber(b1,16), tonumber(b2,16),tonumber(b3,16), tonumber(b4,16)) 
	else 
		return key 
	end 
end

TrisulPlugin = { 

  -- id block 
  id =  {
    name = "Stable Keys",
    description = "All keys must show activity every interval",   -- optional
    author = "Unleash",                       -- optional
    version_major = 1,                        -- optional
    version_minor = 0,                        -- optional
  },

  -- 

  -- WHEN CALLED : your LUA script is loaded into Trisul 
  onload = function()
	-- override by trisulnsm_stablekeys.lua 
    -- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
	--

    T.active_config = make_config(
            T.env.get_config("App>DBRoot").."/config/trisulnsm_stablekeys.lua",
            {
                -- By default FlowGens 
                CounterGUID  ="{7FAB8F84-C580-424B-2BA4-B2546D2DB15A}",

                -- number of stable intervals 
                NumStableIntervals =1,
            })

	T.keys_prev_interval = { } 
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    -- your code 
  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

	counter_guid = function() 
		if not T.active_config then 
			TrisulPlugin.onload()
		end 
		return T.active_config.CounterGUID 
	end, 


    -- WHEN CALLED: when a FLUSH operation starts 
    -- by default called every "stream snapshot interval" of 60 seconds
    onbeginflush = function(engine, timestamp) 
		T.keys_this_interval = { } 
    end,

    -- WHEN CALLED: before an item  is flushed to the Hub node  
    onflush = function(engine, timestamp,key, metrics) 

		if key == "SYS:GROUP_TOTALS"  then return; end 

		T.keys_this_interval[key]=true 

    end,

    -- WHEN CALLED: end of flush
    onendflush = function(engine) 

		for k,v in pairs(T.keys_this_interval) do 
			if not T.keys_prev_interval[k]  then

				local readable = ip_readable(k) 

				-- alert 
				engine:add_alert( "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}", 
								  nil,
								  "STABLEKEYS" ,
								  1, 
								  "No activity on expected key "..readable.."Potentially stopped")
				print("STABLEKEYS ALERT: No activity on expected key "..readable.." Potentially stopped")

			end 
		end 

		T.keys_prev_interval = T.keys_this_interval
		
    end,

  },

}
