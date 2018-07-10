# Passive DNS Extractor

Passive DNS extractor builds a live database of IP to latest seen domain name. 

## Purpose of this App

To construct a live IP -> Domain database that can be used by other Trisul Apps that need a real time
lookup of IP to Domain.  This is more of a building block app for other richer applications. 

## How to run

> **Note** This app requires the `libleveldb` library. See below for install instructions  


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


UPDATES
=======

````
0.0.7		Jul 08 2018			Upgraded to the new tris_levelDB library helper
0.0.3		Jan 08 2018			Now uses `resource_monitor` instead of `fts_monitor` to build the 
                                DNS database. Must faster. 

0.0.1		Oct 10 2017			Initial release 
````


