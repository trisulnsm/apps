# Login Connector

Meters IP based network usage per `ClientId` and per login `source`,
using login syslog messages pushed by the login platform.

## Purpose of this App

The platform sends login syslog messages like:

````
LOCAL7.INFO: 2026-11-01T17:55:00+05:30 ftc-mum-kvm3-inhouse1 logins[2270828]: ClientId="FT045507" Ip="2405:201:680e:11d4:75c0:289d:935b:6297" source="FTC_OAUTH" ts=1793535679
````

From this the app builds an in-memory map of:

1. `Ip -> ClientId`
2. `Ip -> source`

The syslog only carries these label mappings. Actual traffic byte counts come
from flow records: on every flow record the client IP is looked up and the
bytes are metered into the counter groups below.

## Counter groups

1. **ClientId**     `{C9212EE1-A8EC-4A9F-9062-D1E87E5DF616}`  traffic per ClientId
2. **ClientSource** `{009EBF17-72A7-49E7-81B0-3979497509D5}`  traffic per login source

## Crosskeys

1. **HostsXClientId**         Hosts x ClientId
2. **HostsXClientSource**     Hosts x client source
3. **FlowIntfsXClientId**     Flow Interface x ClientId
4. **FlowIntfsXClientSource** Flow Interface x client source
5. **ClientXClientSource**    ClientId x client source

The two `Flowtagger*.json` policies tag flows with `AUTO:clientid` and
`AUTO:clientsource` so the crosskeys that reference the custom counter groups
get populated.

## Notes

- The login `Ip` may be IPv4 or IPv6; both are keyed by their readable form.
- This app registers its own `LOGIN_SYSLOG` protocol on UDP 514. If another
  syslog connector (e.g. fortigate-connector) is also listening on 514, run
  only one of them to avoid a protocol/port conflict.


UPDATES
=======

````
0.1.0       Nov 01 2026         Initial release
````
