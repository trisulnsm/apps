# TLS Fingerprinter

This Trisul APP adds TLS Fingerprinting capability to Trisul NSM. 

TLS fingerprinting is a network analysis technique to intelligently guess the client being used for a given SSL/TLS connection.  You can use this method to detect rogue clients, build a profile of known clients, apply any intel you may come across for known Malware fingerprints. It is just a very good extra insight you can get into your network , particularly when more than 70% of typical enterprise traffic  these days are using SSL/TLS. 


Links:
1. Trisul [IOC Based on TLS Fingerprinting](https://github.com/trisulnsm/trisul-scripts/tree/master/lua/frontend_scripts/reassembly/ja3)
2. The work by [Lee Brotherston](https://github.com/synackpse/tls-fingerprinting)
3. The JA3 Hash described by [John Althouse](https://github.com/salesforce/ja3) 


## Installing 

1. To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._
2. Then restart the Trisul Probes to turn the app live.



### 1. The TLS Fingerprint database 

The App uses a stock TLS Fingerprint JSON database located at 

````
/usr/local/var/lib/trisul-probe/domain0/probe0/context0/lua/repo/tls-fingerprints.json 
````

If you have a different database you can put it in the share directory at. If a fingerprint file is found at this location it is loaded instead. 

````
/usr/local/share/trisul-probe/plugins/tls-fingerprints.json 
````

## Using 

The APP adds a new Counter Group called "JA3 Hash"

1. Use Retro > Retro Counters, then select _JA3 Hash_  to show time distribution of each fingerprint seen.
2. Click and select _View Edges_ to explore deeper using Trisul's streaming graph analytics 
3. If you want to discover and tag new prints, consult Trisul LUA Wiki for examples 

UPDATES
=======

````
0.0.1		Nov 10 2017			Initial release 
````


