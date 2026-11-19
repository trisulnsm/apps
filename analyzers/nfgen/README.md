# NetFlow Generator 

Exports Trisul flow flush events to a NetFlow collector as either NetFlow v9 or IPFIX (v10).

## Features

- IPv4 and IPv6 are exported using different templates.
- Uses standard field IDs for source/destination IP, ports, and protocol.
- Exports `ifIndexIn` and `ifIndexOut` as `0`.
- Each Trisul flow is exported as two unidirectional records, A->Z and Z->A (endpoints
  swapped), each with its own bytes/packets in `octetDeltaCount` / `packetDeltaCount` (IE 1/2).
  Collectors that merge directions (Trisul `MatchBiDirectionalFlows`) rebuild the flow.
- Long flows that Trisul flushes more than once are exported as increments: each export
  carries only the bytes/packets since the previous one, and starts where it ended.
  A direction with nothing new is not exported. A new flow that reuses a 5-tuple (different
  start time) is exported in full.
- To do that, the exported totals of each flow are remembered: finished flows for
  `done_ttl_seconds`, unfinished ones for `exported_ttl_seconds` after their last flush, at most
  `max_tracked_flows` per engine (least recently flushed dropped first). If a dropped unfinished
  flow is flushed again, its totals so far are not re-sent (they may already have been exported);
  only later increments are. The flush log line shows `tracked=` and `skipped=` counts.
- ICMP flows are exported with ports `0`.

## Config

Create override file:

`//App/DBRoot/config/trisulnsm_nfgen.lua`

Example:

```lua
return {
  enabled = true,
  netflow_version = "v10", -- "v5", "v9" or "v10" to export IPFIX records as defined in IETF RFC 7011
  collector_ip = "127.0.0.1",
  collector_port = 2055,
  template_id_base = 256,
  template_refresh_seconds = 30,
  template_refresh_packets = 20,
  export_only_terminated = false, -- true: export a flow only once it has terminated
  source_id_base = 5000,
  max_records_per_packet = 24,
  tag_template_ids = { "COUNTRY", "TLS-SNI", "HOSTNAME", "ASN", "ALERT" },
  tag_field_max_len = 64,
  -- IPFIX (v10) only: IANA Private Enterprise Number for custom tag string fields.
  -- Required for correct Wireshark/collector decoding (RFC 7011 enterprise IEs).
  ipfix_enterprise_number = 39499,
  -- NetFlow v9 only: first field type number used for tag strings (next tags use base+1, ...).
  tag_v9_field_type_base = 200,
  exported_ttl_seconds = 3600,   -- remember an unfinished flow's exported totals this long
  done_ttl_seconds = 300,        -- ... and a finished flow's, in case it is flushed again
  max_tracked_flows = 1000000,   -- per engine; 0 = no limit
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
1.0.8  Nov 18 2026    v9 FlowSet length includes padding; v9 sequence counts template packets;
                      reused 5-tuple no longer undercounted; dropped flows not exported twice;
                      compact flow table with max_tracked_flows; v5 First/Last filled in
1.0.6  Nov 18 2026    Fix crash in onendflush (no timestamp from Trisul) that dropped records;
                      one record per direction instead of Z->A in IE 23/24; export increments
                      for long flows instead of running totals; ICMP ports 0 instead of 12;
                      export_only_terminated implemented
1.0.2  Apr 30 2026    Customizable PEN number for IPFIX 
1.0.1  Apr 29 2026    Revised to do bidirectional netflow 
1.0.0  Oct 10 2024    First version 

````


