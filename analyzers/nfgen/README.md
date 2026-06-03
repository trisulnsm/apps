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
  netflow_version = "v10", -- "v5", "v9" or "v10"
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
  -- IPFIX (v10) only: IANA Private Enterprise Number for custom tag string fields.
  -- Required for correct Wireshark/collector decoding (RFC 7011 enterprise IEs).
  ipfix_enterprise_number = 39499,
  -- NetFlow v9 only: first field type number used for tag strings (next tags use base+1, ...).
  tag_v9_field_type_base = 200,
}
```

## IPFIX tag fields and Wireshark

For `netflow_version = "v10"` (IPFIX), each entry in `tag_template_ids` is exported as an
**enterprise-specific** information element: local IE id `1..N` under your
`ipfix_enterprise_number` (PEN). The template includes the PEN after each tag field
specifier, per RFC 7011. Set `ipfix_enterprise_number` to your real IANA-assigned PEN
so tools decode the last string column correctly.

For `netflow_version = "v9"`, tags use plain field types starting at `tag_v9_field_type_base`
(no PEN). Ensure `tag_v9_field_type_base + #tag_template_ids - 1` stays below `32768`.

## Tag Mapping

The app parses flow tags from Trisul in `TAGID:value` form, for example:

- `COUNTRY:US`
- `TLS-SNI:monl.pb.com`




UPDATES
=======

````
1.0.2  Apr 30 2026    Customizable PEN number for IPFIX 
1.0.1  Apr 29 2026    Revised to do bidirectional netflow 
1.0.0  Oct 10 2024    First version 

````


