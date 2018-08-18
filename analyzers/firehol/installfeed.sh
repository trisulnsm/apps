#!/bin/bash
# Script downloads from FireHOL and updates CRON for hourly update 
# for daily updated Level1 and Level3 
#

echo "Using http proxy     : $http_proxy"
echo "Using https proxy    : $https_proxy"

echo "Downloading FireHOL sets into /usr/local/share/trisul-probe/plugins"

curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
curl -o /usr/local/share/trisul-probe/plugins/firehol_level3.netset   https://iplists.firehol.org/files/firehol_level3.netset

OWNERGROUP=$(stat -c '%U.%G' /usr/local/share/trisul-probe/plugins)
echo "  + Changing permission of feed to $OWNERGROUP"
chown $OWNERGROUP  /usr/local/share/trisul-probe/plugins/firehol_level1.netset
chown $OWNERGROUP  /usr/local/share/trisul-probe/plugins/firehol_level3.netset

TMPFILE=$(mktemp)
crontab -l >  $TMPFILE

if  grep -q firehol $TMPFILE ; then 
	cat << ENDCMD  >> $TMPFILE
	0 * * * * curl -o /usr/local/share/trisul-probe/plugins/firehol_level1.netset   https://iplists.firehol.org/files/firehol_level1.netset
	0 * * * * curl -o /usr/local/share/trisul-probe/plugins/firehol_level3.netset   https://iplists.firehol.org/files/firehol_level3.netset
ENDCMD

	crontab $TMPFILE
	echo "  + Added FireHOL sets to crontab for daily refresh"
else
	echo "  - Crontab entry for FireHOL already exists, skipping" 
fi

rm $TMPFILE

echo "  + Successfully installed FireHOL sets. Restart Trisul-Probe "


