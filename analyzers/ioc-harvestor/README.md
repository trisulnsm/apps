# IOC Harvestor

This APP creates a new Trisul Resource Group stream containing INTEL items harvested from various other streams.

Currenly harvested :

1. IPs
2. DNS query Names
3. DNS CNAME
4. DNS IPv4
5. DNS IPv6
6. SSL SNI
7. SSL Certificate CN
8. SSL Certifcate  SAN (Subject Alternative Names)
9. SSL SHA1 Hashes 
10. HTTP URLs
11. HTTP Host names
12. HTTP Referer 
13. JA3 TLS Fingerprints 
14. File Hashes 


All these are now available in a single Resource Stream called *Intel Harvest* with GUID *"{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}"*

## What is the use of this Harvestor ?

> This APP is a building block app, upon which you can build INTEL checking applications which can compare these with Threat databases  in real time. 

## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._

## Using

This IOC-Harvestor APP is just a building block for other higher level apps our users can build on their own. The most obvious application is a Threat Intel database. 

````
..
INDICATOR:DNSIP = 173.194.38.153
INDICATOR:DNSCNAME = pagead46.l.doubleclick.net
INDICATOR:NAME = googleads.g.doubleclick.net
INDICATOR:DNSIP6 = 404:6800:4003:805::1019
INDICATOR:DNSCNAME = pagead46.l.doubleclick.net
INDICATOR:NAME = tacoda.at.atwola.com
INDICATOR:NAME = tacoda.at.atwola.com
INDICATOR:DNSIP = 207.200.81.13
INDICATOR:DNSCNAME = rtx-at.tacoda.akadns.net
INDICATOR:NAME = ums.adtech.de
INDICATOR:NAME = rt.legolas-media.com
INDICATOR:NAME = loadm.exelator.com
INDICATOR:NAME = ums.adtech.de
INDICATOR:DNSIP = 195.93.85.166
INDICATOR:DNSCNAME = ums.glb.adtech.de


````

UPDATES
=======

````
0.0.2		Jul 10 2018			For perf reason now used AC pattern match to get HTTP intel 
0.0.1		Jul 07 2018			Initial release 
````


