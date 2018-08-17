#!/bin/bash
# Script downloads from IP2Location , compiles them, and loads them into the plugins area
#

if [[ $# -eq 0 ]] ; then
    echo "Error: Need Download Token as first argument"
    echo "Usage: ip2locompile <download-token>"
    exit 1
fi

DOWNLOAD_TOKEN=$1

echo "Using download token : $DOWNLOAD_TOKEN"
echo "Using http proxy     : $http_proxy"

wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=DB3LITE" -O DB3LITE.ZIP 
wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=DBASNLITE" -O DBASNLITE.ZIP 
wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=PX2LITE" -O PX2LITE.ZIP 

unzip -f DB3LITE.ZIP	IP2LOCATION-LITE-DB3.CSV
unzip -f DBASNLITE.ZIP  IP2LOCATION-LITE-ASN.CSV
unzip -f PX2LITE.ZIP  	IP2PROXY-LITE-PX2.CSV

curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/compile_ip2loc.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/tris_leveldb.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/ipprefixdb.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/ip6.lua

luajit compile_ip2loc.lua .  trisul-ip2loc-0.level

cp -r trisul-ip2loc-0.level/ trisul-ip2loc-1.level/
cp -r trisul-ip2loc-0.level/ /usr/local/share/trisul-probe/plugins/
cp -r trisul-ip2loc-1.level/ /usr/local/share/trisul-probe/plugins/

chown -R trisul.trisul /usr/local/share/trisul-probe/plugins/trisul-ip2loc*

echo "Finished"

