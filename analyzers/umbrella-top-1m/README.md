Cisco Umbrella Top 1M Domains List 
============


The Top-1-Million domains list can be used in NSM to train the spotlight on least common domains seen in your network traffic.
Some of the uses can be to 

1. Visibility - what are the usage patterns outside the Top-1M in your enterprise 
2. Detect Outliers - rare domains, those created by DGA, typically used by malware stand out
3. Iterative - you can add whitelisted based on your enterprise and fine tune this list 


> Added Quantcast-Top-1M to this as well. So any domain that is not in either of the lists
> can be truly said to be outside Top-1M 

## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._

Post install ,  run the `installfeed.sh` script to keep the FireHOL list updated as shown below 

### Prerequisites

This app needs the following packages installed.

> Ubuntu 18.04 note : add the `universe` repository using `sudo add-apt-repository universe`

* luajit  - `apt install luajit`
* unzip - `apt install unzip`
* libleveldb  - `apt install libleveldb1v5` for CentOS see [leveldb for CentOS](https://github.com/trisulnsm/apps/tree/master/analyzers/passive-dns#dependency-on-leveldb)


### 1. Installing the feed 

Run the `installfeed.sh` script in this folder  to download the Umbrella-Top-1M list and keep it updated 

Cut paste the below

````
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/umbrella-top-1m/installfeed.sh
bash ./installfeed.sh 
````


### 2. Restart probe

Login as admin , go to Context : default > Admin Tasks > Start/Stop Tasks. Restart the probe

## Viewing the results

This APP adds a new counter group called "Outside Umbrella Top-1M".  

To view the metrics :

1. Use Retro > Retro Tools 
2. Select a time frame and the "Outside Umbrella Top-1M" counter group.


UPDATES
=======

````
0.0.2   Aug 27 2018      Initial release 
````

