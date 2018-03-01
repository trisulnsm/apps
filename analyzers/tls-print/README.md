# TLS Fingerprinter

This Trisul APP adds TLS Fingerprinting capability to TrisulNSM. 

TLS fingerprinting is a network analytics technique to intelligently guess a SSL/TLS client.  Use this to detect rogue clients, build a profile of known clients.  It is just a very good extra piece of info  when more than 70% of enterprise traffic these days are using SSL/TLS. 


Links:
1. Trisul [IOC Based on TLS Fingerprinting](https://github.com/trisulnsm/trisul-scripts/tree/master/lua/frontend_scripts/reassembly/ja3)
2. The work by [Lee Brotherston](https://github.com/synackpse/tls-fingerprinting)
3. The JA3 Hash described by [John Althouse](https://github.com/salesforce/ja3) 


## Installing 

1. To install the "TLS Print" APP. Logon as admin, then select APP from _Web Admin > Manage > Apps._
2. Then restart the Trisul Probes to turn the app live.

### 1. The TLS Fingerprint database 

The App uses a stock TLS Fingerprint JSON database located at  the following location

````
# stock database 
/usr/local/var/lib/trisul-config/domain0/context0/profile0/lua/github.com_trisulnsm_apps
````

If you have a different JSON database you can put it in the share directory at the following location. 

````
# custom database, this is loaded if present first 
/usr/local/share/trisul-probe/plugins/tls-fingerprints.json 
````

## Screenshots 

![Retro Counters > JA3 ](https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/tls-print/ja3_topk.png?raw=true) 

![Retro Counters > JA3 > Click on Print > View Edge ](https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/tls-print/ja3_graph.png?raw=true) 



## Using 

The APP adds a new Counter Group called "JA3 Hash"

1. Use Retro > Retro Counters, then select _JA3 Hash_  to show time distribution of each fingerprint seen.
2. Click and select _View Edges_ to explore deeper using Trisul's streaming graph analytics 
3. If you want to discover and tag new prints, consult Trisul LUA Wiki for examples 

UPDATES
=======

````
0.0.4		Mar 01 2018			* Updated with 50+new prints
                                * Adds Flow Tags with first 6 chars of JA3 Hash
								* Handle very long descriptions 
0.0.3		Jan 08 2018			Updated with 150+ newprints 
                                Adds a new Edge to Graph Analytics when no SNI hostname is present.
								Adds  Bottom-K JA3 prints in addition to Top-K to the streaming analytics 
0.0.1		Nov 10 2017			Initial release 
````


