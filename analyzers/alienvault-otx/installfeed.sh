#!/bin/bash
# Script downloads from FireHOL and updates CRON for hourly update 
# for daily updated Level1 and Level3 
#

echo "Using http proxy     : $http_proxy"
echo "Using https proxy    : $https_proxy"

if [[ $# -eq 0 ]] ; then
    echo "Error: Need Alien Vault Key as first argument"
    echo "Usage: ./installfeed.sh <download-token>"
    exit 1
fi

if ! [[ -x "$(command -v ruby)" ]]; then
  echo 'Error: ruby is not installed. Use apt install ruby or yum install ruby and retry' >&2
  exit 1
fi

API_KEY=$1
echo "Using OTX API KEY    : $API_KEY"

curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/alienvault-otx/otx2leveldb.rb
ruby ./otx2leveldb.rb $API_KEY   trisul-otx-intel.level

cp -r trisul-otx-intel.level /usr/local/share/trisul-probe/plugins/trisul-intel.level.0
cp -r trisul-otx-intel.level /usr/local/share/trisul-probe/plugins/trisul-intel.level.1

OWNERGROUP=$(stat -c '%U.%G' /usr/local/share/trisul-probe/plugins)
echo "  + Changing permission of feed to $OWNERGROUP"
cp -r trisul-otx-intel.level /usr/local/share/trisul-probe/plugins/trisul-otx-intel.level.0
cp -r trisul-otx-intel.level /usr/local/share/trisul-probe/plugins/trisul-otx-intel.level.1
chown -R $OWNERGROUP  /usr/local/share/trisul-probe/plugins/trisul-otx-intel.level.*


