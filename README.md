# Trisul Apps 

Installable dashboards, custom analytics, and other extensions to the Trisul Network Analytics Platform


1. Dashboards : New visualization and dashboards 
2. Analytics : Real Time packet analysis tools, metrics, and other extensions
3. Hunting : Tools to analyze saved data 


# Installing

To install these tools

1. Login as admin
2. Go to Webadmin > Manage > Apps 
3. Click on the App you want to install
4. For each App click on the README link for additional instructions


## LUA analyzer

| APP Name  | Description |
| ------------- | ------------- |
|FireHOL checker  |Alerts if activity seen from FireHOL blacklist  |
|Geo based on IP2Location db|Geo based metering to Trisul using the IP2Location LITE databases|
|HTTP Proxy|Extracts metrics in HTTP Proxy|
|IOC Harvestor|Harvests intel items into a single resource stream from different places in Trisul pipeline|
|Passive DNS Extractor|Extracts IP to Domain map|
|PingMON | Large scale PING reachability and latency monitor| 
|Prune Encrypted PCAP|Prunes high volume encrypted Netflix/YouTube from PCAP storage|
|Prune TLS from PCAP storage|Dont store TLS traffic|
|SNI TLS Metrics|Traffic metrics from TLS Server Name Indication|
|SNMP Poller|SNMP Poller for Interface Usage|
|SSH Events|SSH Login and Tunnel|
|Save Binaries|Extract binary files, PDF, Flash from traffic|
|Suricata via EVE UnixSocket|Suricata alerts via EVE Unix Socket|
|TCP Analyzer|Identify hosts experiencing TCP performance|
|TLS Fingerprinter|Generates and tracks TLS Fingerprint indicators|
|CIDR Tagger |Tags flows with CIDR subnets|


## JS Dashboards
|APP Name | Description
|---------|----------|
|Daily Key Report| Shows daily usage report for key|
|Edge vertex Monitor|Show usage report for selected guid,meters and keys|
|Key Space Explorer| Search all active key space and get total usage|
|PCAP Totals|Shows total summary of pcap file |
|Security Overview - Internal Hosts| Shows IDS and Badfellas alerts count for internal hosts| 
|Super search host|earch all hosts by domain name and print total usage of each.|
|Usage Activity Heatmap|Shows key activity usage in d3 heatmap visualization Day/Hour|

## Package Dashboard

|APP Name | Description
|---------|----------|
|DNS monitoring|DNS Custom Metrics and dashboards|
|Probe Performance|System performance of Trisul Probes|
|Save Binaries Monitoring|Dashboards for the Save Binaries App|
|TCP Analysis|TCP analyzer dashboards|
