# Banned Comms

This app watches for flows and detects if these rules are broken 

- Some clt IP are only supposed to talk to specific servers IPs and not to each other 
- Broadcast traffic is allowed 
- IP clients not on the whitelist are allowed 




Config Parameters
==============

To supply your own custom whitelists , 

1. create a new config file named `trisulnsm_bannedcomms.lua` in the probe config directory
`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config` directory with the following

````lua 

# in file /usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_bannedcomms.lua 

# the IP Addresses are hexadecimal representations of the client and server IP
# LUA regex are used to specify ranges of IPs 

return  {
			WhiteList  =  {
					{ ["0A.02.02.%x%x"] = "0A.02.00.F[BC]" },
					{ ["0A.02.02.%x%x"] = "[EF]%x.%x%x.%x%x.%x%x" },
			} ;
}

````

UPDATES
=======

````
1.0.2   Oct 7 2024     Rules based to exclude broadcast traffic and other opts
1.0.2   Oct 1 2024     Initial release 
````
