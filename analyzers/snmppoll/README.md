# SNMP Poller

Install this Trisul APP to add SNMP Polling functionality to Trisul.

>> UPDATE NOTICE: This app has been updated completely in version 0.2. Updating from the older version
>> should be seamless. If some users experience issues please reach out to Trisul Network Analytics Support

>> DISTRIBUTED TRISUL COMPATIBILITY: This app does not work with distributed license of Trisul. 
>> Please contact Trisul Network Analytics support. 

This APP uses the Trisul LUA API to poll SNMP interface usage along with their names and aliases. These metrics are fed back into the Trisul pipelines.

1. Interface In/Out octets  from ifXTable or ifTable
2. Automatically loads the agents 
3. A new counter group is created to store the metrics, Total/In/Out 


## How to use 

1. You need to add the ROUTERS/SWITCHES you want to pull interface metrics from
2. Login as Admin to WebTrisul
3. Goto Web Admin : Manage > App Settings 
4. Scroll to the end and find "Manage Extended Settings"
5. Fill in the SNMP Type details and press create
6. Repeat this for all routers you want to track
7. Install this app and restart Trisul-Probe

**All interfaces from all the specified routers** will be tracked and all in/out/total utilizations will be stored at 1-min interval. All Trisul features like Top-K Bottom-K will be available. 


UPDATES
=======

````
1.0.2		Nov 10 2022 		Completely revamped for distributed probe support, refactored code, config, 
                                optimized reloading of agents only if changed, key format matching netflow,
								optimized no retrieval of Alias info on every cycle.
0.0.11		Feb 26 2021			Updated to properly require async command file bulkwalk.cmd 
0.0.3		Nov 03 2020			Updated completely to use ASYNC polling 
0.0.1		Feb 03 2018			Initial release as an App. This was in 
                                production earlier as standalone script 
````


