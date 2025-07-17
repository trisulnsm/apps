# StableKeys

Checks if a counter group reports the same set of keys across time.



## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._




Config Parameters
==============

The config settings you can customize on a per Probe basis

````lua

DEFAULT_CONFIG = {
	-- Counter Group GUID to monitor
	CounterGUID  ="{7FAB8F84-C580-424B-2BA4-B2546D2DB15A}",

	-- number of stable intervals 
	NumStableIntervals =1,
	
	-- debouncing threshold - if more than this many keys are missing, generate single alert
	DebounceThreshold = 5,
	
	-- list of IP addresses to track (empty means track all keys)
	TrackIPs = {},
}
````

To supply your own custom settings, 

1. create a new config file named `trisulnsm_stablekeys.lua` in the probe config directory
`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config` directory with the following
2. You only supply new values for parameters you want to replace 


````lua 

# in file /usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_stablekeys.lua 

return  {
	CounterGUID  ="{7FAB8F84-C580-424B-2BA4-B2546D2DB15A}",
	DebounceThreshold = 10,  -- Increase threshold for less sensitive environments
	
	-- Track only specific IP addresses (empty list tracks all)
	TrackIPs = {
		"192.168.1.1",    -- Router
		"192.168.1.10",   -- Server 1
		"192.168.1.20",   -- Server 2
		"10.0.0.1",       -- Gateway
	},
}


````

If using CrossKeys ensure that you specify the keys with \\ double backslash to prevent escaped strings.
For example

````lua

    -- use double backslash .. 
    TrackIPs = {
		"244.0.0.152\\10.68.78.33",
    },
}

````

## Viewing alerts

The Alerts shows up in Trisul as User-Alerts 

1. View alerts real time. Select Alerts > Show All > User Alerts > Click on "View Real Time" 
2. View older alerts. Select Alerts > Show All > click on User Alerts



## IP Filtering Feature

The script can be configured to track only specific IP addresses, reducing noise and focusing on critical infrastructure.

- **TrackIPs**: List of IP addresses in dotted decimal format to monitor
- **Default**: Empty list (tracks all keys)
- **Format**: `{"192.168.1.1", "10.0.0.1", ...}`
- **Behavior**: Only keys matching these IPs will be tracked and alerted upon

## Debouncing Feature

The script now includes debouncing logic to prevent alert spam when many keys stop simultaneously (e.g., end of office hours, network outages). 

- **DebounceThreshold**: If more than this many keys are missing in a single interval, a single consolidated alert is generated instead of individual alerts
- **Default**: 5 keys
- **Alert Message**: "Multiple keys (X) stopped sending metrics - possible network/device outage."
- **Alert Signature**: Uses `STABLEKEYS_DEBOUNCED` to distinguish from individual key alerts

UPDATES
=======

````
1.0.8   Jul 17 2025     Logic to support alternate key forms like crosskeys IPs 
1.0.7   Jul 10 2025     Added IP filtering to track only specific addresses
1.0.6   Jul 7 2025      Debounce logic to prevent mass alert spam 
1.0.3   Jan 2025        Added debouncing logic to prevent alert spam
1.0.2   Jun 21 2023     Changed default guid to flowgen 
1.0.1   Jun 14 2023     Initial release 
````


