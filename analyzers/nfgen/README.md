# NetFlow Generator 

Exports Trisul flow flush events to a NetFlow collector as either NetFlow v9 or IPFIX (v10).

## Features

- IPv4 and IPv6 are exported using different templates.
- Uses standard field IDs for source/destination IP, ports, and protocol.
- Exports `ifIndexIn` and `ifIndexOut` as `0`.

## Config

Create override file:

`//App/DBRoot/config/trisulnsm_nfgen.lua`

Example:

```lua
return {
  enabled = true,
  netflow_version = "v10", -- "v9" or "v10"
  collector_ip = "127.0.0.1",
  collector_port = 2055,
  template_id_base = 256,
  template_refresh_seconds = 30,
  template_refresh_packets = 20,
  export_only_terminated = false,
  source_id_base = 5000,
  max_records_per_packet = 24,
  tag_template_ids = { "COUNTRY", "TLS-SNI", "HOSTNAME", "ASN", "ALERT" },
  tag_field_max_len = 64,
}
```

## Tag Mapping

The app parses flow tags from Trisul in `TAGID:value` form, for example:

- `COUNTRY:US`
- `TLS-SNI:monl.pb.com`




UPDATES
=======

````
1.0.1  Apr 29 2026    Revised to do bidirectional netflow 
1.0.0  Oct 10 2024    First version 

````


