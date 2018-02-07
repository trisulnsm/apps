# TCP Analyzer 

Install this Trisul App to add TCP Analysis to Trisul 

This APP uses the Trisul LUA API to calculate latency from connection setup time, retransmissions, and timedout flows.  

A new counter group called **TCP Analyzer** is added with the following metrics 

1. Per Host Latency for internal and external hosts. Setup time in microseconds.
2. Per Host Retransmission count for internal and external hosts. Number of retransmitted packets. 
3. Per Host Retransmission Percent for internal and external hosts.  % retransmitted vs total packets
4. Per Host Poor Quality Flows : Number of flows with high retransmissions
5. Per Host Mark Flow with bad BADQUALITY if timeout 

Adds a new Flow Tracker 
1. **POOR QUALITY** - Mark flows with high retransmission rate (set to 5%) or those timed out.

Adds the Flow Tagger
1. **BADQUALITY**  - flows with high retranmissions or timeouts 


## How to use 

Install this app and restart Trisul-Probe 



HISTORY
=======

````
0.0.1		Feb 7 2018			Initial release 
````


