---
----
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
  -- Use gsub to find and replace all hex IP patterns with decimal format
  local result = string.gsub(key, "(%x%x)%.(%x%x)%.(%x%x)%.(%x%x)", function(b1, b2, b3, b4)
    return string.format("%d.%d.%d.%d", tonumber(b1,16), tonumber(b2,16), tonumber(b3,16), tonumber(b4,16))
  end)
  
  return result
end

function ip_to_trisul_format(ip)
  -- Use gsub to find and replace all decimal IP patterns with hex Trisul format
  -- Use word boundary pattern to ensure we match complete IP addresses only
  local result = string.gsub(ip, "([^%w])(%d+)%.(%d+)%.(%d+)%.(%d+)", function(prefix, b1, b2, b3, b4)
    return prefix .. string.format("%02X.%02X.%02X.%02X", tonumber(b1), tonumber(b2), tonumber(b3), tonumber(b4))
  end)
  
  -- Also handle IP addresses at the beginning of the string
  result = string.gsub(result, "^(%d+)%.(%d+)%.(%d+)%.(%d+)", function(b1, b2, b3, b4)
    return string.format("%02X.%02X.%02X.%02X", tonumber(b1), tonumber(b2), tonumber(b3), tonumber(b4))
  end)
  
  return result
end

function should_track_key(key)
  -- If no specific IPs configured, track all keys
  if not T.active_config.TrackIPs or #T.active_config.TrackIPs == 0 then
    return true
  end
  
  -- Convert key to readable IP format for comparison
  local readable_ip = ip_readable(key)
  
  -- Check if this IP is in our tracking list
  for _, track_ip in ipairs(T.active_config.TrackIPs) do
    if readable_ip == track_ip then
      return true
    end
  end
  
  return false
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
    ----

    T.active_config = make_config(
      T.env.get_config("App>DBRoot").."/config/trisulnsm_stablekeys.lua",
      {
          -- By default FlowGens 
          CounterGUID  ="{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}",
          --- By default sigid (Alert name)
          SigID="STABLEKEYS",
          -- number of stable intervals 
          NumStableIntervals =1,
          -- mail subject
  	        mailsubject="IPDR Alert-No Netflow received for IP",
          -- debouncing threshold - if more than this many keys are missing, generate single alert
          DebounceThreshold = 5,
          -- list of IP addresses to track (empty means track all)
          TrackIPs = {}

      })

    T.keys_prev_interval = { } 
    T.pending_keys={ }
    T.debounce_pending_keys = { }

    -- Check if this IP is in our tracking list
    for _, track_ip in ipairs(T.active_config.TrackIPs) do
      print("track_ip ".. track_ip .. " readable_ip ".. ip_to_trisul_format(track_ip) )
    end    
  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    -- your code 
    --if we have interval more then 1 we need to maintain the 
  end,

  -- cg_monitor block
  -- 
  cg_monitor  = {

    counter_guid = "{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}",


    -- WHEN CALLED: when a FLUSH operation starts 
    -- by default called every "stream snapshot interval" of 60 seconds
    onbeginflush = function(engine, timestamp) 
      T.keys_this_interval = { } 
      
    end,

  
    -- WHEN CALLED: before an item  is flushed to the Hub node  
    onflush = function(engine, timestamp,key, metrics) 
      if key == "SYS:GROUP_TOTALS"  then return; end 
      
      -- Only track keys that are in our configured IP list (if any)
      if should_track_key(key) then
        T.keys_this_interval[key]=true 
      end

    end,

  
    -- WHEN CALLED: end of flush
    onendflush = function(engine) 
      local countergroup=T.active_config.SigID
      
      -- Track keys that are missing this interval
      local missing_keys_this_interval = {}
      
      for k,v in pairs(T.keys_prev_interval) do 
        if not T.keys_this_interval[k]  then
          --add pending count to match number of interval
          T.pending_keys[k]= (T.pending_keys[k] or 0 )
          missing_keys_this_interval[k] = true
        end
      end

      -- Check if we have too many missing keys for debouncing
      local missing_count = 0
      for k,v in pairs(missing_keys_this_interval) do
        missing_count = missing_count + 1
      end
      
      local should_debounce = missing_count >= T.active_config.DebounceThreshold
      
      for k,v in pairs(T.pending_keys) do
        --if key present this interval remove the key
        --else increase pending key count
        if T.keys_this_interval[k] then
          T.pending_keys[k]=nil
          T.debounce_pending_keys[k]=nil
        else
          T.pending_keys[k] = T.pending_keys[k]+1 
        end
        --once alert generated remove the key
        if (T.pending_keys[k] or 0) >= T.active_config.NumStableIntervals then
          local readable = ip_readable(k) 
          
          if should_debounce then
            -- Add to debounce pending list instead of generating individual alert
            T.debounce_pending_keys[k] = T.pending_keys[k]
            T.pending_keys[k] = nil
          else
            -- Generate individual alert for single missing key
            print("alert"..readable)
            local alert_message="No activity detected on the expected key "..readable.." - potentially inactive."
            engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}",  nil, T.active_config.SigID, 1,  "STABLE_KEYS_ALERT".."|"..T.active_config.mailsubject.."|"..T.active_config.NumStableIntervals.."|"..T.active_config.CounterGUID.."|"..k)
            T.logwarning(alert_message)
            T.pending_keys[k]=nil
          end
        end
      end
      
      -- Generate debounced alert if we have accumulated enough keys
      local debounced_keys_count = 0
      for k,v in pairs(T.debounce_pending_keys) do
        debounced_keys_count = debounced_keys_count + 1
      end
      
      if debounced_keys_count > 0 and should_debounce then
        local alert_message = string.format("Multiple keys (%d) stopped sending metrics - possible network/device outage.", debounced_keys_count)
        
        engine:add_alert( "{B5F1DECB-51D5-4395-B71B-6FA730B772D9}", 
                  nil,
                  T.active_config.SigID .. "_DEBOUNCED",
                  1, 
                  alert_message.."mailsubject:"..T.active_config.mailsubject.." Multiple keys inactive in the last "..T.active_config.NumStableIntervals.." minutes:mailsubject")
        T.logwarning(alert_message)
        
        -- Clear debounced keys after alert
        T.debounce_pending_keys = {}
      end

      T.keys_prev_interval = T.keys_this_interval
    
    end,

  },

}
