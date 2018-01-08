# PINGMON - PING Monitoring

This App continuously  measures latency and packet loss of thousands of endpoints by using ICMP Ping. 

## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._


## Adding IPs to be PINGed

After installing the app, you need to add IP Addresses to be pinged. You can do that using the PING Groups feature from the web interface.

1. Go to Tools > Show All > Bulk Ping Groups 
2. Click on Manage IPs
3. You can Add one by one  or Import from CSV 

## Starting the PING server

After you have added the IPs 

1. Login as Admin 
2. Go to Context:Default > Start Stop Tasks
3. Select the Probe from which you want to PING, then on the far right side Click on "Options"
4. Select "How to start the PING Server" for instructions
5. Then logon to the probe as Root and run the command `sudo trisul_bulkping.. etc` as shown

## Viewing the PING Dashboard

Login as normal user

1. Go to Tools > Show All > Bulk Ping Groups
2. Click on Dashboard


![Ping Group > View Dashboard ](https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/pingmon/screenshot-localhost-3000-2018-01-08-16-29-59-982.png) 


**Note** For security reasons we do not allow to start or stop the PING server from the web interface


HISTORY
=======

````
0.0.1		Jan 7 2018			Initial release 
````


