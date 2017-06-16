# Passive DNS Extractor


Passive DNS extractor builds a live database of IP to Domain names. 

## How to run

This app requires two things on the probe.

1. Install the LeveDB database library 
2. Modify the DNS config file to enable FTS (Full Text) extraction 


### 1. Installing LevelDB 

On CentOS 7

LevelDB is found in the EPEL repo

````
wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
rpm -ivh epel-release-7-9.noarch.rpm
yum install leveldb
````


On Ubuntu 14.04 and 16.04

LevelDB is found in the libleveldb1 package

````
sudo apt-get update 
sudo apt-get install libleveldb1 
````


### 2. Enable DNS FTS

On the probe edit the *DNS configuration file*. This is identified by a GUID PI-CCC..
You can type @/usr/local/share/trisul-probe/cfgedit@  to find and edit the file.

````
sudo -i 
cd /usr/local/etc/trisul-probe/domain0/probe0/context0
nano PI-CCCBBBB3-125E-48D0-8AC9-A7E3AD2F60FD.xml
then change the CreateFTSDocument parameter to 'true'
````

or 


````
/usr/local/share/trisul-probe/cfgedit
#  then locate the DNS Config file and select "edit" 

````


Then restart the Probes. 

