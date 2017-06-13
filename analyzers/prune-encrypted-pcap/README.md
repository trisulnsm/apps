# Prune PCAP storage 

NSM Practitioners  !! 

Don't waste precious Disk Space and Write IOPs storing encrypted packets from
Netflix/YouTube/Facebook/Twitter.   Save anywhere from 60-80% disk space 
with this Trisul Network Analytics plugin. 

1. Save disk space -- extend your PCAP retention
2. Lower disk throughput -- lower RAID0 requirements 
3. Fast PCAP retrieval for useful queries 
4. Due to PFS you are never going to be able to read the PCAPs
5. Even though the PCAPs arent saved, the flows,SSL certs, and metrics are so you dont lose visibility

## Traffic not saved:  Netflix, Youtube

By default this app skips the following Regex  -- see the skip_youtube.lua file in this package 

````
T.re2x = T.re2("(youtube|googlevideo|twitter|ytimg|twimg|netflix|nflxvideo|nflximg|nflxext)")
````


## Installing

This App requires the "Passive DNS Extractor" app to be installed first.

1. Install the Passive DNS Extractor App
2. Install this App
3. Restart the probes


