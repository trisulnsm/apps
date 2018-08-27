#!/bin/bash
# Script downloads from Cisco Umbrella Top-1M 
# and compiles them into a LevelDB database 
#

echo "Using http proxy     : $http_proxy"
echo "Using https proxy    : $https_proxy"

pushd  /tmp

programs=(luajit wget unzip)
for p in ${programs[@]}; do
	if ! [[ -x "$(command -v $p)" ]]; then
	  echo 'Error: $p is not installed. Try apt install $p or yum install $p' >&2
	  exit 1
	fi
done 

libs=(libleveldb)
for p in ${libs[@]}; do
	if ! ldconfig -p | grep -q $p ;  then
	  echo 'Error: $p is not installed. ' >&2
	  exit 1
	fi 
done

echo "  + Downloading Top-1M list from umbrella-static"
curl -O  http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip

echo "  + Unzipping" 
unzip http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip

echo "  + Downloading compiler script"
curl -O  https://raw.githubusercontent.com/trisulnsm/apps/master/analyzers/cisco-umbrella-top1m/compile-top1m.lua

echo "  + Compiling the list into a LevelDB database for use by Trisul"
luajit compile-top1m.lua  top-1m.csv  


OWNERGROUP=$(stat -c '%U.%G' /usr/local/share/trisul-probe/plugins)
echo "  + Changing permission of feed to $OWNERGROUP"
cp -r umbrella.level /usr/local/share/trisul-probe/plugins/umbrella.level.0
cp -r umbrella.level /usr/local/share/trisul-probe/plugins/umbrella.level.1
chown -R $OWNERGROUP  /usr/local/share/trisul-probe/plugins/umbrella.level.*

echo "  + Success" 

popd 
