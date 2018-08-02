# Passive DNS Creator

Builds a real time passive DNS database.  

> ### What is a Passive DNS Database? 
> A passive DNS DB is a historical record of which domains resolved to which IPs and its inverse - 
> IPs to domains.  A Real-Time Passive DNS database is designed to be used in 
> streaming analytics platforms like Trisul where you need this intelligence in the Fast
> path to make decisions.  An alternative to a Real Time database would be a Log or SQL 
> database. 


## Purpose of this App

Installing this app gives you a high speed, embedded, real time capability to :   

1. lookup an IP or IPv6  to a domain name.  
2. lookup a domain to a IP or IPv6
3. lookup a subdomain using the reverse format , eg com.facebook will give you all sub domains, see the examples below
3. detect "first seen" IP and "first seen" domain
4. detect "not seen in 1 month" and other variants thereof 
5. iterate over all IPs used by a domain historically with timestamp
6. iterate over all domains used by an IP historically 
7. just a solid record of all DNS mappings in a proven and fast LevelDB database 

You can use this to build more advanced APPs like the [Prune Encrypted PCAP](https://github.com/trisulnsm/apps/tree/master/analyzers/prune-encrypted-pcap)  APP that cuts high volume youtube/netflix/etc from PCAP storage.

## Dependency on LevelDB  

This app requires the `libleveldb` library. See below for install instructions  


### 1. Installing LevelDB On CentOS 7 probe 

LevelDB is found in the EPEL repo

````
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install leveldb
````

### 2. Installing LevelDB on Ubuntu 14.04 and 16.04 probes

LevelDB is found in the libleveldb1 package (14.04) or libleveldb1v5 (16.04)

````
sudo apt-get update 

# for 14.04
sudo apt-get install libleveldb1 

# for 16.04
sudo apt-get install libleveldb1v5 
````
## Then restart the Trisul Probes. 

The level DB database will be built from live network traffic and stored in the probe  config directory as `PassiveDNSDB.level`. The probe config directory for each context is at `/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/`


## API  to access it

The catch here is you cannot read the LevelDB database `PassiveDNSDB.level` from outside while it is in LIVE use by Trisul. However, the file api.lua provides a simple interface for the outside world to query the database.  The interface is available on the Unix Socket `$run/leveldbapi.sock.0` , the run directory is located at `/usr/local/var/lib/trisul-probe/domain0/probe0/context0/run` can be switched by the [trisbashrc](https://www.trisul.org/docs/ref/trisbashrc.html)  helper macro `cd.run` 

There are two API commands
1. `dump` : dumps the entire database 
1. `listprefix<space>prefix` : dump all the matching prefixes

The PassiveDNS database is nothing but a LevelDB database with the key-value format as `key=timestamp-when-it-was-seen`

Some examples should make it clear 

### Example 1: all IPs used by weather.yahoo.com

````
root@unpl:echo "listprefix weather.yahoo.com" | nc  -U leveldbapi.sock.0 
weather.yahoo.com/6A/406:2000:f016:1fe::3000=1533210156
weather.yahoo.com/6A/406:2000:f016:1fe::3001=1533210156
weather.yahoo.com/6A/a00:1288:12c:2::100b=1533206029
weather.yahoo.com/6A/a00:1288:12c:2::100c=1533206029
weather.yahoo.com/A/203.84.197.25=1533210156
weather.yahoo.com/A/203.84.197.26=1533210156
weather.yahoo.com/A/203.84.197.27=1533210156
weather.yahoo.com/A/203.84.197.9=1533210156
weather.yahoo.com/A/206.190.61.106=1533210130
weather.yahoo.com/A/206.190.61.107=1533210130
weather.yahoo.com/A/208.71.44.30=1533210152
````

only show IPv4 address

```
root@unpl:echo "listprefix weather.yahoo.com/A/" | nc  -U leveldbapi.sock.0 
```



### Example 2: show all IPv4 and IPv6 for *.facebook.com (use the reverse format com.facebook to list the prefix matches) 

````
root@unpl:echo "listprefix com.facebook" | nc  -U leveldbapi.sock.0 
com.facebook.0-edge-chat/6A/a03:2880:f01c:2:face:b00c:0:1=1533206029
com.facebook.0-edge-chat/A/31.13.93.3=1533206029
com.facebook.1-edge-chat/6A/a03:2880:f01c:2:face:b00c:0:1=1533206036
com.facebook.1-edge-chat/A/31.13.93.3=1533206036
com.facebook.2-edge-chat/6A/a03:2880:f01c:2:face:b00c:0:1=1533206098
com.facebook.6-edge-chat/6A/a03:2880:f01c:2:face:b00c:0:1=1533206098
com.facebook.6-edge-chat/A/31.13.93.3=1533206098
com.facebook.ak.api/A/63.80.4.11=1533209959
com.facebook.ak.api/A/63.80.4.27=1533209959
com.facebook.ak.s-static/6A/600:1409:0:193::236=1533210118
com.facebook.ak.s-static/6A/600:1409:0:194::236=1533210118
..

````

### Example 3 : show all domains used by a particular IP `107.21.237.25` 

````
root@unpl:echo "listprefix 107.21.237.25" | nc  -U leveldbapi.sock.0 
107.21.237.25=bl.ocks.org
107.21.237.25/A/bl.ocks.org=1533210158
107.21.237.25/A/jobs.jsfiddle.net=1533210131
107.21.237.25/A/pix.btrll.com=1533210044
107.21.237.25/A/rubycentral.org=1533210104
107.21.237.25/A/www.d3-generator.com=1533210070
````

### Example 4 : dump the entire database to a file `allpassivedns.txt` 

````
root@unpl:echo "dump" | nc  -U leveldbapi.sock.0  > allpassivedns.txt 
````


UPDATES
=======

````
0.0.9       Aug 02 2018         API.lua allows you to query the online (live) database from outside
0.0.8       Aug 01 2018         Lookup domain to IP history , IP to domain history 
0.0.7       Jul 08 2018         Upgraded to the new tris_levelDB library helper
0.0.3       Jan 08 2018         Now uses `resource_monitor` instead of `fts_monitor` to build the 
                                DNS database. Must faster. 

0.0.1       Oct 10 2017         Initial release 
````


