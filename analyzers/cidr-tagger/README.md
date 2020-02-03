# Flexible CIDR Flow tagger

Automatically tags flows with CIDR network tags. This allows you to search blazingly fast for
all network traffic in a CIDR.

## Without this APP

You can still search for individual hosts by IP by sweeping a CIDR range. But with the 
CIDR flow tagger your search speed is orders of magnitude faster because the tags are 
integrated into the backend indices. 


## Installing 

1. Logon as admin, then select _Flexible CIDR Flow Tagger_ from  _Web Admin > Manage > Apps._ to install
2. Restart the Trisul Probes 

### 2. Custom options : Specify networks to tag 


 1. specify which networks you want to tag, by default /25, /26, /27, /28 are tagged 
 1. specify if you only want to tag internal IPs or all IPs 

````
# create a file named /usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_cidr-tagger.lua"
# put the lines below in that file 


return    {
		  	-- only tag these subnet networks
            tag_masks={26,27,28},

			-- only tag internalhosts 
		    tag_internal_hosts_only = true
          } 
} 

````

## Using 

After you install this app you can search for specific subnetwork flows by using the following format. The flow tags are 
added in the _tag group_ called _[cidr]_

```
tag=[cidr]192.17.20.32/27 
```


UPDATES
=======

````
0.0.1   Feb 2 2020     Initial release 
````


