# Passive DNS Creator

Builds a real time passive DNS database. 

> ### What is a Passive DNS Database? ** 
> A passive DNS DB is a historical record of which domains resolved to which IPs and its inverse - 
> IPs to domains.  A Real-Time Passive DNS database is designed to be used in 
> streaming analytics platforms like Trisul where you need this intelligence in the Fast
> path to make decisions.  An alternative to a Real Time database would be a Log or SQL 
> database. 


## Purpose of this App

Installing this app gives you several capabilities :

1. the ability in real time to lookup an IP to a domain name.  
2. the ability to lookup a domain name to IP. 
3. detect "first seen" IP and "first seen" domain
4. detect "not seen in 1 month" and other variants thereof 
5. iterate over all IPs used by a domain historically with timestamp
6. iterate over all domains used by an IP historically 
7. just a solid record of all DNS mappings in a proven and fast LevelDB database 

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

The level DB database will be built from live network traffic and stored in 
the probe  config directory `PassiveDNSDB.level`. The probe config 
directory for each context is at `/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/`


## Working with the LevelDB

You can use the [tris_leveldb.lua library](https://github.com/trisulnsm/trisul-scripts/tree/master/lua/libs/leveldb)  to work with the database. 

For example if you want to dump the database - put this file in the passiveDNS app directory and run `luajit dump.lua` 

````lua

local LevelDB=require'tris_leveldb' 
db1=LevelDB.new()

db1:open("/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/PassiveDNSDB.level")
db1:dump()
db1:close() 


````


UPDATES
=======

````
0.0.8       Aug 01 2018         Lookup domain to IP history , IP to domain history 
0.0.7       Jul 08 2018         Upgraded to the new tris_levelDB library helper
0.0.3       Jan 08 2018         Now uses `resource_monitor` instead of `fts_monitor` to build the 
                                DNS database. Must faster. 

0.0.1       Oct 10 2017         Initial release 
````


