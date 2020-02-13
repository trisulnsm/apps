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
|Alienvault OTX|Scans your traffic against AlienVault OTX Intel, needs IOC-Harvestor APP|
|FireHOL checker  |Alerts if activity seen from FireHOL blacklist  |
|Geo based on IP2Location db|Geo based metering to Trisul using the IP2Location LITE databases|
|HTTP Proxy|Extracts metrics in HTTP Proxy|
|IOC Harvestor|Harvests intel items into a single resource stream from different places in Trisul pipeline|
|Passive DNS Extractor|Extracts IP to Domain map|
|PingMON | Large scale PING reachability and latency monitor| 
|Protocol Tree Metrics|Generates metrics in a protocol tree |
|Prune Encrypted PCAP|Prunes high volume encrypted Netflix/YouTube from PCAP storage|
|Prune TLS from PCAP storage|Dont store TLS traffic|
|SNI TLS Metrics|Traffic metrics from TLS Server Name Indication|
|SNMP Poller|SNMP Poller for Interface Usage|
|SSH Events|SSH Login and Tunnel|
|Squid Proxy Metrics|Extracts metrics from proxy servers traffic|
|Save Binaries|Extract binary files, PDF, Flash from traffic|
|Suricata via EVE UnixSocket|Suricata alerts via EVE Unix Socket|
|TCP Analyzer|Identify hosts experiencing TCP performance|
|TLS Fingerprinter|Generates and tracks TLS Fingerprint indicators|
|TLS Metrics Pack|Generates extra metrics and relationships in TLS traffic|
|CIDR Tagger |Tags flows with CIDR subnets|
|Umbrella Top-1M|Tracks DNS queries outside the Top-1-Million |


## JS Dashboards
|APP Name | Description
|---------|----------|
|Country Analytics Drilldown|View country mappings for routers and interfaces|
|Daily Key Report| Shows daily usage report for key|
|Edge vertex Monitor|Show usage report for selected guid,meters and keys|
|Geo IP Lookup| Shows the ip look up|
|ISP Country Analytics|View country mappings for routers and interfaces|
|ISP Home Prefixes Analytics|View home prefixes mappings for routers and interfaces|
|ISP External Prefixes Analytics|View external prefixes mappings for routers and interfaces|
|ISP Overview|Top level dashboard for ISP |
|ISP Router Geo Map|View country locations for your router|
|IXP Analytics|L2 IXP Traffic Analytics|
|Key Space Explorer| Search all active key space and get total usage|
|Multi Probe Charts|Draw a multi-probe chart |
|Path  Analytics|Shows the top used AS PATHS|
|Peering Analytics|View ASN mappings for routers and interfaces|
|Peering Analytics Drilldown|View ASN mappings for routers and interfaces|
|PCAP Totals|Shows total summary of pcap file |
|Prefix Analytics Drilldown|View Prefix mappings for routers and interfaces|
|Protocol Tree Viewer |View metrics in a Protocol Tree |
|Sankey Crossdrill|Show sankey chart for crosskey filter counter group|
|Search Keys|Search keys to check any usage activity in your network|
|Security Overview - Internal Hosts| Shows IDS and Badfellas alerts count for internal hosts|
|Super search host|earch all hosts by domain name and print total usage of each.|
|Usage Activity Heatmap|Shows key activity usage in d3 heatmap visualization Day/Hour|

## Package Dashboard

|APP Name | Description
|---------|----------|
|DNS monitoring|DNS Custom Metrics and dashboards|
|ISP Dashboard Pack|Some useful dashboards for ISP Analytics|
|Probe Performance|System performance of Trisul Probes|
|Save Binaries Monitoring|Dashboards for the Save Binaries App|
|Simple executive|Top Inbound , Outbound Apps and risky traffics|
|TCP Analysis|TCP analyzer dashboards|
