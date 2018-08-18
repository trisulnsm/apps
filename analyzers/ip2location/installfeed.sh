#!/bin/bash
# Script downloads from IP2Location , compiles them, and loads them into the plugins area
#

if [[ $# -eq 0 ]] ; then
    echo "Error: Need Download Token as first argument"
    echo "Usage: ./installfeed.sh <download-token>"
    exit 1
fi


if ! [[ -x "$(command -v luajit)" ]]; then
  echo 'Error: luajit is not installed. Use apt install luajit or yum install luajit to install' >&2
  exit 1
fi

DOWNLOAD_TOKEN=$1

echo "  + Using download token : $DOWNLOAD_TOKEN"
echo "  + Using http proxy     : $http_proxy"

wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=DB3LITE" -O DB3LITE.ZIP 
wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=DBASNLITE" -O DBASNLITE.ZIP 
wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=PX2LITE" -O PX2LITE.ZIP 

unzip DB3LITE.ZIP	-f IP2LOCATION-LITE-DB3.CSV
unzip DBASNLITE.ZIP -f IP2LOCATION-LITE-ASN.CSV
unzip PX2LITE.ZIP  	-f IP2PROXY-LITE-PX2.CSV

curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/compile_ip2loc.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/tris_leveldb.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/ipprefixdb.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/ip6.lua

luajit compile_ip2loc.lua .  trisul-ip2loc-0.level

cp -r trisul-ip2loc-0.level/ trisul-ip2loc-1.level/
cp -r trisul-ip2loc-0.level/ /usr/local/share/trisul-probe/plugins/
cp -r trisul-ip2loc-1.level/ /usr/local/share/trisul-probe/plugins/

OWNERGROUP=$(stat -c '%U.%G' /usr/local/share/trisul-probe/plugins)
echo "  + Changing ownership to to Trisul Probe user $OWNERGROUP"
chown -R $OWNERGROUP  /usr/local/share/trisul-probe/plugins/trisul-ip2loc*

echo "  + Finished"
