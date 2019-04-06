#!/bin/bash
# Script downloads from IP2Location , compiles them, and loads them into the plugins area
# if you only want 1 database use the --only flag 
# --only DB1 DB3  DB3 ASN PX2 


if [[ $# -eq 0 ]] ; then
    echo "Error: Need Download Token as first argument"
    echo "Usage: ./installfeed.sh <download-token> [--only databasename]"
    exit 1
fi

DOWNLOAD_TOKEN=$1
shift 


while true; do
  case "$1" in
    --only)          DATABASE_NAME="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) if [ ! -z "$1" ]; then
            echo "Unknown option [$1]";
        fi
        break ;;
  esac
done

echo $DATABASE_NAME

if ! [[ -x "$(command -v luajit)" ]]; then
  echo 'Error: luajit is not installed. Use apt install luajit or yum install luajit to install' >&2
  exit 1
fi

if ! [[ -x "$(command -v wget)" ]]; then
  echo 'Error: wget is not installed. Use apt install wget or yum install wget to install' >&2
  exit 1
fi

if ! [[ -x "$(command -v unzip)" ]]; then
  echo 'Error: unzip is not installed. Use apt install unzip or yum install unzip to install' >&2
  exit 1
fi

HASLEVEL=$(/sbin/ldconfig -p | grep libleveldb)
if ! [[ -z  "$HASLEVEL" ]]; then
  echo Found level db library : $HASLEVEL
else
  echo Error: leveldb not found
  echo    Ubuntu:  apt install libleveldb1v5
  echo    CentOS:  yum install leveldb
  exit 1
fi



echo "  + Using download token : $DOWNLOAD_TOKEN"
echo "  + Using http proxy     : $http_proxy"

if ! [[ -z  "$DATABASE_NAME" ]]; then
	wget  "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=${DATABASE_NAME}LITE" -O ${DATABASE_NAME}LITE.ZIP 
	unzip ${DATABASE_NAME}LITE.ZIP	-f IP2LOCATION-LITE-$DATABASE_NAME.CSV

else
	wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=DB3LITE" -O DB3LITE.ZIP 
	wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=DBASNLITE" -O DBASNLITE.ZIP 
	wget    "http://www.ip2location.com/download/?token=$DOWNLOAD_TOKEN&file=PX2LITE" -O PX2LITE.ZIP 

	unzip DB3LITE.ZIP	-f IP2LOCATION-LITE-DB3.CSV
	unzip DBASNLITE.ZIP     -f IP2LOCATION-LITE-ASN.CSV
	unzip PX2LITE.ZIP  	-f IP2PROXY-LITE-PX2.CSV

fi 

curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/compile_ip2loc.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/tris_leveldb.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/ipprefixdb.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/ip6.lua
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/ip2location/checkip.lua

luajit compile_ip2loc.lua .  trisul-ip2loc-0.level

cp -r trisul-ip2loc-0.level/ trisul-ip2loc-1.level/
cp -r trisul-ip2loc-0.level/ /usr/local/share/trisul-probe/plugins/
cp -r trisul-ip2loc-1.level/ /usr/local/share/trisul-probe/plugins/

OWNERGROUP=$(stat -c '%U.%G' /usr/local/share/trisul-probe/plugins)
echo "  + Changing ownership to to Trisul Probe user $OWNERGROUP"
chown -R $OWNERGROUP  /usr/local/share/trisul-probe/plugins/trisul-ip2loc*

echo +++ Running test for IP 138.68.45.27 
luajit checkip.lua 138.68.45.27

echo 
echo
echo "  + Finished"
