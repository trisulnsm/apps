# OTT Analytics

Maps external flow destinations to OTT app labels (via Passive DNS + pattern map) and updates OTT counters, including interface/app cross-keys.

## Config

- Passive DNS DB path used by scripts: `//App/DBRoot/config/PassiveDNSDB.level.<instanceid>`
- App matching dictionary: `appmap.lua`
- Counter groups:
  - OTT Apps: `ottcg.lua`
  - OTT XKey: `ott_xkey.lua`


UPDATES
=======

````
1.0.3   Apr 17 2026      Released as an APP
```` 
