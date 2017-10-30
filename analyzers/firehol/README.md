# FireHOL Checker

Check all your traffic against the excellent FireHOL blacklist.
The FireHOL list has a reputation for a  very low false positive rate. 


**If you see a FireHOL alert in Trisul, you MUST investigate further.** 


## Download latest list 

After installing this app. Do the following to keep it updated


Download the latest file 
````
curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
````


Or if  your probe uses a proxy  to get outside 
````
curl -x https://192.168.2.11:3128 -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
````


## Keep the list updated every hour

````

crontab -e 

# add this line
0 * * * * curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset

````

## Automatically picked up

This app automatically refereshes the list every hour. 


## Viewing alerts








UPDATES
=======

0.0.1		Oct 30 2017			Initial release 



