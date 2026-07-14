# NAT Syslog 

This script attaches to UDP 514 Syslog and only stores flow records based on NAT syslog events 


UPDATES
=======

````
1.0.16  Jul 14 2026    Rewrote regexes for performance , minimize .* usage and
                       strengthen the gate check 
1.0.13  Oct 10 2025    Mikrotik NAT logs 
1.0.11  Sep 1  2025    Checkpoint NAT Syslog support 
1.0.10  Feb 11 2025    NAT SYSLOG ensure private IP is sent to NAT field and tags are set correctly 
1.0.9   Jan 28 2025    Removed store_tagged_flows.lua -- now all flows are stored, this 
                       can accidentally prevent IPDR flows from being stored. 
1.0.2   Aug 6  2024    RADIUS syslog - may move to a new APP 
1.0.2   Sep 10 2023    is_flow_counter lua added to enable NETFLOW_TAP mode 
1.0.0   Sep 1  2023    Meter 2 changed for XKEY from transmit to heartbeat 
````


