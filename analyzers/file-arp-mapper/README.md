# File ARP Table to MAC Mapper

Reads ARP/SSM records written as JSON lines into a directory and tags flows with the
MAC address of the endpoint. Both the LAN IP (`ipv4_addr`) and the WAN/NAT IP
(`wan_ip`) of each record are mapped to its MAC, so flows are tagged when Trisul's
`ipa`, `ipz`, or `natip` matches.

## How it works

1. An external process drops ARP records into a directory as JSON lines, e.g.

```
{"src": "SSM", "if": "eth0", "ipv4_addr": "192.168.100.126", "ipv4_alloc": "dhcp", "ts": "2026-06-16T21:06:18+05:30", "status": "disconnected", "mac": "02:01:01:7b:5d:cb", "host": "unknown", "wan_ip": "192.168.192.40", "imei": "355866000254842"}
{"src": "ARP", "if": "eth0", "ipv4_addr": "192.168.104.66", "ipv4_alloc": "dhcp", "ts": "2026-06-16T21:06:31.455895+05:30", "status": "connected", "mac": "aa:bb:cc:dd:ee:ff", "host": "laptop-8", "wan_ip": "100.68.0.1", "imei": "351554119992476"}
```

2. Every `ResolutionSeconds` the app finds the most recently modified file in
   `FilePath` whose name starts with `FilePrefix`, parses it, and rebuilds the
   `ip -> mac` map.

3. On flush, each flow's `ipa`, `ipz`, and `natip` are looked up and a `[mac]<addr>`
   tag is added on a match.

## Customization 

Edit /usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_filearp_flowtagger.lua

```lua

return {
			-- Directory containing the ARP record files
			FilePath = "/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/arp",

			-- Only files starting with this prefix are considered (latest wins)
			FilePrefix = "arp",

			-- Resolution Seconds - how frequently the directory is re-scanned
			ResolutionSeconds = 60,

			-- Print debug messages
			DebugMode = false,

			-- Filter these IP - return true if you want the IP to be mapped
			IsIPEnabled = function(ip)
				return true
			end,
}

```

# Version History

````
1.0.0   Jun 17 2026      Initial version 

````
