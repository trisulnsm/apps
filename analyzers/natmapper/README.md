# NAT Tagger 

Tags flows with NAT information 


> Requires leveldb 
> apt install leveldb 

## Application

Primary used in flow logging applications. NAT mapping information is sent by 
Netflow from devices like Cisco Nexus , this information is mixed with Flow Records
to add Private IP / Private Port tags.


Tags added `[natip]10.0.23.11` and `[natport]55372` 



UPDATES
=======

````
1.0.1   Jan 17 2025     Changed backing map to LEVELDB to handle ISP scale 
1.0.0   Jul 10 2024     Initial release 
````


