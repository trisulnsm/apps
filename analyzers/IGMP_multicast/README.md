# IGMP Multicast monitor 

This Trisul APP provides the following features.


Adds three new counter groups
1.  Multicast Hosts - tracks all 224.0.0.0 through 239.255.255.255 multicast space IPs
2.  Multicast Members - tracks individual unicast members of the multicast group 
3.  Exchange XFlow - tracks flows UnicastDestIP/DestPort/UnicastSourceIP/MulticastDestIP


## Use case

When you want to disaggregate multicast group traffic and account for individual IPs. 


## How to use 

Go to Retro > Retro Counters
Then Select "Multicast Hosts" and "Multicast Members" to see traffic.

Select "Exchange XFlow" to view individual multicast flows 


Example 

``` 
10.22.100.10\172.19.1.2\18001\239.50.50.50   250MB 
```

This should be interpreted as 

IP 172.19.1.2 is sending 250MB to the multicast address 239.50.50.50 port 18001 and received by member 10.22.100.10 


UPDATES
=======

````
0.0.4   Oct 13 2022     Added README.md 
````


