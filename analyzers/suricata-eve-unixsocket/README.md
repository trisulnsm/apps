# Suricata EVE Unix Socket Interface

Connect up to Suricata alerts in EVE format on a Unix Socket.

## Installation

1. Enable EVE alerts on Suricata.  

````
 # Extensible Event Format (nicknamed EVE) event log in JSON format
  - eve-log:
      enabled: yes
      filetype: unix_dgram  #regular|syslog|unix_dgram|unix_stream|redis
      filename: eve.socket 
````

This would make Suricata output EVE to `/var/log/suricata/eve.socket` 

2. This App listens on `{Run-State-Directory}/suricata_eve.socket` 

Run-State-Directory for a particular context is the location where transient files and sockets are stored for the context. To find out the directory name, open `/usr/local/etc/trisul-probe/domain0/probe0/context0/trisulProbeConfig.xml` and look for the `RunStateDirectory` option. 



