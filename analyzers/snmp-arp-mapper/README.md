# ARP Table to MAC Mapper

By SNMP Walk of managed switches we can tag flows with MAC addresses of the endpoints.

## How it works

1. Create SNMP Agents using the admin page for all the Terminal Switches which have L2 connectivity to the end workstations see [Configure SNMP Agents](https://docs.trisul.org/docs/ag/context/snmp_agent)
2. Every poll walks two OIDs on each agent
   - `.1.3.6.1.2.1.4.20.1.3` ipAdEntNetMask - the interface IP and its subnet mask
   - `.1.3.6.1.2.1.4.22.1.2` ipNetToMediaPhysAddress - the ARP cache
3. Each subnet is expanded into every host IP, all pointing at the MAC of the interface owning that subnet. An IP present in the ARP cache keeps its own MAC.
4. Flows are tagged with `[mac]` by a single hash lookup on ipa, ipz, and the natip tag.

## Customization 

Edit /usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_snmparp_flowtagger.lua

```lua

return {
			-- Resolution Seconds - how frequently SNMP Polling is done
			ResolutionSeconds = 60,

			-- Print debug messages
			DebugMode = false,

			-- Subnets with more addresses than this are not expanded
			MaxSubnetHosts = 4096,

			-- Filter these IP - return true if you want IP to be SNMP polled 
			IsIPEnabled = function(ip)
				return true
			end,
		}
}

```

# Version History

````
1.0.5   Sep 18 2026      ipNetToMediaPhysAddress to ipAdEntNetMask
1.0.4   Jan 27 2026      Changed config to XPATH
1.0.1   Nov 15 2025      Initial version 

````
