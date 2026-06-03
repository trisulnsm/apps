# SNMP QoS Poller

Install this Trisul APP to add SNMP QoS polling for Cisco routers using the CBQOS MIB.

This APP polls Cisco CBQOS SNMP OIDs and feeds pre-policy and post-policy traffic into two counter groups:

1. **QOS-Traffic** — aggregated per router and QoS class (interface ignored)
2. **FlowIntf_bx_QOS** — per interface and QoS class crosskey

## Prerequisites

1. SNMP agents configured in WebTrisul (same database as the SNMP Interface poller)
2. Set `snmp.qosenabled=true` (or `1`) on each router that has QoS enabled
3. SNMP tools (`snmpbulkwalk` / `snmpwalk`) installed on the probe
4. Install the SNMP Interface poller first if you want interface resolution

## SNMP OIDs polled

| Purpose | OID |
|---------|-----|
| QoS class names | 1.3.6.1.4.1.9.9.166.1.7.1.1.1 |
| Object/config index → class ID | 1.3.6.1.4.1.9.9.166.1.5.1.1.2 |
| CBQOS ifIndex → ifIndex | 1.3.6.1.4.1.9.9.166.1.1.1.1.4 |
| Pre-policy bytes | 1.3.6.1.4.1.9.9.166.1.15.1.1.10 |
| Post-policy bytes | 1.3.6.1.4.1.9.9.166.1.15.1.1.6 |
| Policy drop bytes | 1.3.6.1.4.1.9.9.166.1.15.1.1.17 |
| Queue buffer | 1.3.6.1.4.1.9.9.166.1.18.1.1.1 |
| Queue drop packets | 1.3.6.1.4.1.9.9.166.1.18.1.1.8 |
| Queue drop bytes | 1.3.6.1.4.1.9.9.166.1.18.1.1.4 |

## Counter groups

| Name | GUID | Key format |
|------|------|------------|
| QoS-Class | `{116888A7-23B4-4873-5691-E6E0806CCB11}` | class ID (e.g. `1593`) |
| QOS-Traffic | `{1AB9F248-1E49-4245-571A-55BCDA658843}` | `{class_id}` (resolves via QoS-Class) |
| FlowIntf_bx_QOS | `{D3F7A892-4E1B-4C6D-8A5F-2E1C9B7D4A63}` | `{router_ip}_{ifindex}\\{class_id}` (ifindex is 8-digit hex, e.g. `_0000000A` for 10) |

Each counter group has six meters (scale factor 1000):

- Meter 0: Pre Policy BW (Bps)
- Meter 1: Post Policy (Bps)
- Meter 2: Policy Drop BW (Bps)
- Meter 3: Queue Buffer (Packets, gauge)
- Meter 4: Queue Drops (packets)
- Meter 5: Queue Drop Bytes (Bps)

## How to use

1. Configure SNMP on routers in WebTrisul Admin (Manage > App Settings > Manage Extended Settings)
2. Add attribute `snmp.qosenabled` = `true` for routers with QoS
3. Install this app and restart Trisul-Probe

## Customizing

Place config at `/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_snmpqospoll.lua`:

```
return
{
    ResolutionSeconds=60,
    DebugMode=false,
    IsIPEnabled=function(ip)
        return true
    end
}
```

## UPDATES

````
1.0.0   Jun 02 2026   Initial release - Cisco CBQOS SNMP polling
````
