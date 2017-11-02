# FireHOL Checker

Check all your traffic against the excellent FireHOL blacklist. The FireHOL list has a reputation for a very low false positive rate.  **If you see a FireHOL alert in Trisul, you MUST investigate further.**  To help the analyst further, this app elevates the alert priority to 1 when bi-directional data transfer above a threshold occurs with a blacklisted host. 


## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._

Post install run the following 3 steps to keep the FireHOL list updated. 


### 1. Download the latest file 

````
curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
````


Or if  your probe uses a proxy to get outside.  In the following example the proxy is at 192.168.2.11  port 3128
````
curl -x https://192.168.2.11:3128 -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
````


### 2.  Keep the list updated every hour


````

crontab -e 

# add this line
0 * * * * curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset

````

This app automatically refereshes the list every hour. 

### 3. Restart probe

Login as admin , go to Context : default > Admin Tasks > Start/Stop Tasks. Restart the probe


Config Parameters
==============

Some of the knobs you can adjust on a per-probe basis.


From the filehol.lua script these are the settings you can customize. 


````lua

DEFAULT_CONFIG = { 

	-- filename of FireHOL Feed 
	Firehol_Filename ="firehol_level1.netset", 

	-- How frequently to check for new files, sync with your cron update 
	Check_Seconds=1800,			

	-- How much should blacklisted IP Recv for Priority elevation to MAJOR (1)
	Vol_Sev1_Alert_Recv=10000,

	-- How much should blacklisted IP Transmit for Priority elevation to MAJOR (1)
	Vol_Sev1_Alert_Xmit=20000,
}
````

To supply your own custom settings, 

1. create a new config file named `trisulnsm_filehol.lua` in the probe config directory
`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config` directory with the following
2. You only supply new values for parameters you want to replace 
3. An example here , we want to increase the `Check_Seconds` to 3600 seconds (check for new feeds every hour) 


````lua 

return  {

	Check_Seconds=1800			 -- our new value 
}

````

## Viewing alerts

The FireHOL alerts show up in Trisul as User-Alerts.

1. View alerts real time. Select Alerts > Show All > User Alerts > Click on "View Real Time" 
2. View older alerts. Select Alerts > Show All > click on User Alerts


![Alerts > View All> Real Time Alerts](https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/firehol/screenshot-demo.trisul.org-3000-2017-11-02-13-43-01-686.png?raw=true) 


UPDATES
=======

````
0.0.2		Nov 2 2017			Custom options 
0.0.1		Oct 30 2017			Initial release 
````


