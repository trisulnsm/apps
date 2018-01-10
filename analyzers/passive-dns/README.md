# Passive DNS Extractor


Passive DNS extractor builds a live database of IP to Domain names. 

## How to run

This app **requires you** to 


> 1. Install the LeveDB database library 


### 1. Installing LevelDB 

On CentOS 7

LevelDB is found in the EPEL repo

````
wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
rpm -ivh epel-release-7-9.noarch.rpm
yum install leveldb
````


On Ubuntu 14.04 and 16.04

LevelDB is found in the libleveldb1 package (14.04) or libleveldb1v5 (16.04)

````
sudo apt-get update 

# for 14.04
sudo apt-get install libleveldb1 

# for 16.04
sudo apt-get install libleveldb1v5 


````

Then restart the Probes. 

>  The level DB database will be built from live network traffic and stored in 
>  the probe  config directory `PassiveDNSDB.level`. The probe config 
>  directory for each context is at `/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/`


UPDATES
=======

````
0.0.3		Jan 08 2018			Now uses `resource_monitor` instead of `fts_monitor` to build the 
                                DNS database. Must faster. 

0.0.1		Oct 10 2017			Initial release 
````


