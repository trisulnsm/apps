# IOC Harvestor

This APP creates a single new Trisul Resource Group stream containing INTEL items harvested from various other streams.

Currently harvesting 14 items 

1. IPv4
2. IPv6
2. DNS query Names
3. DNS CNAME
4. DNS A IPv4
5. DNS AAAA IPv6
6. SSL SNI
7. SSL Certificate CN (Common name)
8. SSL Certifcate  SAN (Subject Alternative Names)
9. SSL SHA1 Hashes 
10. HTTP URLs
11. HTTP Host 
12. HTTP Referer 
13. JA3 TLS Fingerprints 
14. File Hashes 


This apps creates a new Resource Stream called *Intel Harvest* with GUID *"{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}"*. You can just listen to the resorces on this stream and write code to do something with them. See `intel_print.lua` which just prints them to the terminal. 

## What is the use of this Harvestor ?

> This is a building block APP. This gives you all Intel items in a single stream, you can plug this into any Intel checking code. 

## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._

## Saving to backend database

By default , this APP stores the harvested candidate IOC to the backend Hub database. This can take up significant disk space on busy networks. To prevent saving this stream, create a config file at `/usr/local/var/lib/trisul-probe0/domain0/probe0/contextX/config/trisulnsm_ioc-harvestor.lua` and put the following

````lua
return {
	SaveHarvestedItems=false,
} 
````

## Sample output 


````
..
INDICATOR:DNSIP = 173.194.38.153
INDICATOR:DNSCNAME = pagead46.l.doubleclick.net
INDICATOR:NAME = googleads.g.doubleclick.net
INDICATOR:DNSIP6 = 404:6800:4003:805::1019
INDICATOR:DNSCNAME = pagead46.l.doubleclick.net
INDICATOR:NAME = tacoda.at.atwola.com
INDICATOR:DNSIP = 207.200.81.13
INDICATOR:DNSCNAME = rtx-at.tacoda.akadns.net
INDICATOR:NAME = ums.adtech.de
INDICATOR:NAME = rt.legolas-media.com
INDICATOR:NAME = ums.adtech.de
INDICATOR:DNSIP = 195.93.85.166

````

UPDATES
=======

````
0.0.3		Jul 11 2018			IPv6 and also a config option to prevent saving to DB 
0.0.2		Jul 10 2018			For perf reason now used AC pattern match to get HTTP intel 
0.0.1		Jul 07 2018			Initial release 
````


