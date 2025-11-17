# ARP Table to MAC Mapper

By SNMP Walk of managed switches we can tag flows with MAC addresses of the endpoints.

## How it works

1. Create SNMP Agents using the admin page for all the Terminal Switches which have L2 connectivity to the end workstations see [Configure SNMP Agents](https://docs.trisul.org/docs/ag/context/snmp_agent)

## Customization 

Edit /usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_snmparp_flowtagger.lua

```lua

return {
			-- Resolution Seconds - how frequently SNMP Polling is done
			ResolutionSeconds = 60,

			-- Print debug messages
			DebugMode = false,

			-- Filter these IP - return true if you want IP to be SNMP polled 
			IsIPEnabled = function(ip)
				return true
			end,
		}
}

```

# Version History

````
1.0.0   Nov 15 2025      Initial version 

````
