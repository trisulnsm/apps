# TCP Analyzer 

Install this Trisul App to add TCP Analysis to Trisul 

This APP uses the Trisul LUA API to calculate latency from connection setup time, retransmissions, and timedout flows.  

A new counter group called **TCP Analyzer** is added with the following metrics 

1. Per Host Latency for internal and external hosts. Setup time in microseconds.
2. Per Host Retransmission count for internal and external hosts. Number of retransmitted packets. 
3. Per Host Retransmission Percent for internal and external hosts.  % retransmitted vs total packets
4. Per Host Poor Quality Flows : Number of flows with high retransmissions
5. Per Host Mark Flow with bad BADQUALITY if timeout 
6. Per Host Timeouts : Number of established connections that timed out
7. Per Host Unidirectional : Number of flows seen in one direction only

Adds a new Flow Tracker 
1. **POOR QUALITY** - Mark flows with high retransmission rate (set to 5%) or those timed out.

Adds the Flow Tagger
1. **BADQUALITY**  - flows with high retranmissions or timeouts 


## Minimum flow size

A retransmission rate is a proportion, and over a handful of packets it measures
the flow's size rather than the network - one ordinary retransmission in a 16
packet flow is 6.25%, over the 5% threshold. So the **rate**, the **Poor Quality
Flows** counter, the **BADQUALITY** tag and the **POOR QUALITY** tracker all
require the flow to carry at least `MIN_PACKETS_FOR_RATE` (50) packets.

Latency, timeouts, unidirectional flows and the raw count of retransmitted
packets are *not* gated - they are single events or volumes, valid at any flow
size, and most flows are small.

Change the constant at the top of `tcp_analyzer.lua`, `appcg.lua` and
`poorquality.lua` to retune; keep all three on the same value.

## How to use 

Install this app and restart Trisul-Probe 



HISTORY
=======

````
0.0.6		Sep 23 2026			Retrans rate and the BADQUALITY verdict now need a
                                minimum flow size (MIN_PACKETS_FOR_RATE, 50 pkts).
                                A single retransmission in a 16 packet flow is 6.25%
                                and was tagging healthy flows. Latency, timeouts,
                                unidirectional and the raw retrans count are ungated.
0.0.5		Sep 23 2026			Other fixes, dont update with 0 RTT, dont repeat RTT measurements for long
                                running flows, use correct server ports rather than the lowerport Rule.
0.0.4		Sep 21 2026			Error in ishomenet fr IPv6
0.0.3		Oct 4  2020			Added APPS and Unidirectional detection 
0.0.1		Feb 7  2018			Initial release 
````


