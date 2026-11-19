# Login Connector

Meters IP based network usage per `ClientId`, per login `source`, and per
`devCode`, using login syslog messages pushed by the login platform.

## Purpose of this App

The platform sends login syslog messages like:

````
<190>2026-11-19T11:30:00+05:30 ftc-mum-kvm3-inhouse1 logins[2898354]: ClientId="FZ56358" Ip="187.127.149.145" source="API" devCode="FTC_OAUTH" ts=1795067670
````

From this the app builds an in-memory map of:

1. `Ip -> ClientId`
2. `Ip -> source`
3. `Ip -> devCode`

The syslog only carries these label mappings. Actual traffic byte counts come
from flow records: on every flow record the client IP is looked up and the
bytes are metered into the counter groups below.

## Counter groups

1. **ClientId**      `{C9212EE1-A8EC-4A9F-9062-D1E87E5DF616}`  traffic per ClientId
2. **ClientSource**  `{009EBF17-72A7-49E7-81B0-3979497509D5}`  traffic per login source
3. **ClientDevcode** `{373024C2-6018-43FA-B39B-1AB628E65878}`  traffic per login devCode

## Crosskeys

1. **Hosts_X_ClientId**                      Hosts x ClientId
2. **Hosts_X_ClientSource**                  Hosts x client source
3. **Hosts_X_ClientDevcode**                 Hosts x ClientDevcode
4. **FlowIntf_X_ClientId**                   Flow Interface x ClientId
5. **FlowIntf_X_ClientSource**               Flow Interface x client source
6. **FlowIntf_X_ClientDevcode**              Flow Interface x ClientDevcode
7. **ClientId_X_ClientSource**               ClientId x client source
8. **ClientId_X_ClientDevcode**              ClientId x ClientDevcode
9. **ClientSource_X_ClientDevcode**          ClientSource x ClientDevcode
10. **ClientId_X_ClientSource_X_ClientDevcode** ClientId x ClientSource x ClientDevcode

The `Flowtagger*.json` policies tag flows with `AUTO:clientid`,
`AUTO:clientsource`, and `AUTO:clientdevcode` so the crosskeys that reference
the custom counter groups get populated.

## Notes

- The login `Ip` may be IPv4 or IPv6; both are keyed by their readable form.
- This app registers its own `LOGIN_SYSLOG` protocol on UDP 514. If another
  syslog connector (e.g. fortigate-connector) is also listening on 514, run
  only one of them to avoid a protocol/port conflict.


UPDATES
=======

````
0.1.0       Nov 01 2026         Initial release
0.2.0       Nov 19 2026         ClientDevcode counter group, crosskeys, and flowtagger
````
