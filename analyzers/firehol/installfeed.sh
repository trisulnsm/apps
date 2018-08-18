#!/bin/bash
# Script downloads from FireHOL and updates CRON for hourly update 
# for daily updated Level1 and Level3 
#

echo "Using http proxy     : $http_proxy"

echo "Downloading FireHOL sets into /usr/local/share/trisul-probe/plugins"

curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
curl -o /usr/local/share/trisul-probe/plugins/firehol_level3.netset   https://iplists.firehol.org/files/firehol_level3.netset

OWNERGROUP=$(stat -c '%U.%G' /usr/local/share/trisul-probe/plugins)
chown $OWNERGROUP  /usr/local/share/trisul-probe/plugins/firehol_level1.netset
chown $OWNERGROUP  /usr/local/share/trisul-probe/plugins/firehol_level2.netset

TMPFILE=$(mktemp)
crontab -l >  $TMPFILE

cat << ENDCMD  >> $TMPFILE
0 * * * * curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
0 * * * * curl -o /usr/local/share/trisul-probe/plugins/firehol_level3.netset   https://iplists.firehol.org/files/firehol_level3.netset
ENDCMD

crontab $TMPFILE
rm $TMPFILE

echo "Successfully installed FireHOL sets and added to CRONTAB for daily refresh"






