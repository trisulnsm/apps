# StableKeys

Checks if a counter group reports the same set of keys across time.



## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._




Config Parameters
==============

The config settings you can customize on a per Probe basis

````lua

DEFAULT_CONFIG = {
	-- filename of FireHOL level1 Feed  - will trigger Sev-1 alert 
	CounterGUID  ="{7FAB8F84-C580-424B-2BA4-B2546D2DB15A}",

	-- number of stable intervals 
	NumStableIntervals =1,
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
}

````

## Viewing alerts

The Alerts shows up in Trisul as User-Alerts 

1. View alerts real time. Select Alerts > Show All > User Alerts > Click on "View Real Time" 
2. View older alerts. Select Alerts > Show All > click on User Alerts



UPDATES
=======

````
1.0.2   Jun 21 2023     Changed default guid to flowgen 
1.0.1   Jun 14 2023     Initial release 
````


