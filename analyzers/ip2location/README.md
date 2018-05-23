# IP2Location LITE Geo Metrics  


This app adds Geo based metering to Trisul using the IP2Location LITE databases. 

The following CSV databases are processed. The databases can be found at https://lite.ip2location.com/

1. ASN-LITE - for Autonomous System Number metrics 
2. DB3-LITE - for Country and City 
3. P2-LITE  - for Proxies 


## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._

Post install run the following 3 steps to keep the FireHOL list updated. 


### 1. Download the latest IP2 Location Databases

From https://lite.ip2location.com/ download the following databases into  `/usr/local/share/trisul-probe/plugins`
Then `unzip` them.



````bash
$ ls -l /usr/local/share/trisul-probe/plugins 
-rw-rw-r-- 1 guru guru  9082502 May 17 15:14 IP2LOCATION-LITE-ASN.CSV
-rw-rw-r-- 1 guru guru 37129729 May 17 15:14 IP2LOCATION-LITE-DB3.CSV
-rw-rw-r-- 1 guru guru  1000038 May 17 15:15 IP2PROXY-LITE-PX2.CSV

````



### 2. Compile the CSV lists  



Make sure you have `luajit` on your probe. If not run `apt install luajit`.  Then run the following command to compile the databases. 

1. Download the two lua files (`compile_ip2loc.lua and tris_leveldb.lua`) used to compile this  into a LevelDB database
2. Run the compiler and generate the two databases 

The commands would look like this 

````bash

cd /usr/local/share/trisul-probe/plugins 

wget https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/compile_ip2loc.lua
wget https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/tris_leveldb.lua

luajit compile_ip2loc.lua /usr/local/share/trisul-probe/plugins /usr/local/share/trisul-probe/plugins/trisul-ip2loc-0.level
luajit compile_ip2loc.lua /usr/local/share/trisul-probe/plugins /usr/local/share/trisul-probe/plugins/trisul-ip2loc-1.level

````


### 3.  How updates are picked up

Everytime you download and recompile, Trisul automatically picks up the changes. So you can setup a CRON for this.


### 4. Restart probe

Login as admin , go to Context : default > Admin Tasks > Start/Stop Tasks. Restart the probe


## Viewing data 

This app creates four new counter groups. Go to Retro > Counter to start your analysis.

## Cron updates


Use the script `ip2locupdate-cron.sh` to update the list every week.  You have to supply the URL and the registration code 


````sh

crontab -e -u trisul

# then add this line 
0 0 * * * /usr/local/share/trisul-probe/plugins/ip2locupdate-cron.sh 

````

The updates are automatically picked up.  

## Notices

All sites, advertising materials and documentation mentioning features or use of this database must display the following acknowledgment:

"This site or product includes IP2Proxy LITE data available from https://www.ip2location.com/proxy-database."
"This site or product includes IP2Proxy LITE data available from https://www.ip2location.com/asn-database."


UPDATES
=======

````
0.0.3		May 23 2018			Added cron script to DL and compile 
0.0.2		May 22 2018			Initial release 
````



