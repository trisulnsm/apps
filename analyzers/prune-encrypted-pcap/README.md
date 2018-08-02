# Prune PCAP storage 

> *New*  Metrics to measure how many flows were excluded from PCAP for each category 

### Calling NSM Practitioners  !! 

Don't waste precious Disk Space and Write IOPs storing encrypted packets from
Netflix/YouTube/Facebook/Twitter.   Save anywhere from 60-80% disk space 
with this Trisul Network Analytics plugin. 

1. Save disk space -- extend your PCAP retention
2. Lower disk throughput -- lower RAID0 requirements 
3. Fast PCAP retrieval for useful queries 
4. These packets are almost useless -- YouTube is moving to QUIC (UDP) others uses PFS encryption.
5. Trisul still processes the metrics,flows,SSL certs so you dont lose visibility

> This App requires the [Passive DNS Extractor](https://github.com/trisulnsm/apps/tree/master/analyzers/passive-dns)  app to be installed first.

## Traffic not saved:  Netflix, Youtube

By default this app skips the following Regex  

````lua 
T.re2x = T.re2("(youtube|googlevideo|twitter|ytimg|twimg|netflix|nflxvideo|nflximg|nflxext|acorn.tv|tubitv|atv-ext.amazon.com|atv-ps.amazon.com|hulu)")
````

## How to add your own "Exclude PCAP" sites.

Say you want to exclude `twitch` flows from PCAP, you can override the default regex. 


Save the following snippet and put it in the Probe context config directory in the following file 
`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_skip_youtube.lua`


````lua 
-- --------------------------------------------
-- override by /usr/local/var/lib/trisul-probe/dX/pX/contextX/config/trisulnsm_skip_youtube.lua 
--
DEFAULT_CONFIG = {

  DNS_Regex_To_Skip ="(twitch|youtube|googlevideo|twitter|ytimg|twimg|netflix|nflxvideo|nflximg|nflxext|acorn.tv|tubitv|atv-ext.amazon.com|atv-ps.amazon.com|hulu)"

  }
  -- --------------------------------------------
````

> You need to use the [Google RE2 regex format](https://github.com/google/re2) 

## Installing

This App requires the [Passive DNS Extractor](https://github.com/trisulnsm/apps/tree/master/analyzers/passive-dns)  app to be installed first.

1. Install the Passive DNS Extractor App
2. Install this App
3. Restart the probes

UPDATES
=======

````
0.0.6		Jul  6 2018			New leveldb lib, customization of regex, metrics with new
                                counter group. 
0.0.4		Jan  8 2017			Added acorn.tv,Amazon Prime, Hulu TV packets to be excluded 
0.0.1		Oct 30 2017			Initial release 
````


