#!/usr/bin/env bash
set -e

apt-get update && apt-get install -y \
git cmake make gcc g++ clang libmysqlclient-dev libssl-dev libbz2-dev \
libreadline-dev libncurses-dev mysql-server libboost-all-dev ninja-build \
xz-utils curl
mkdir -p /wow && cd /wow
git clone https://github.com/azerothcore/azerothcore-wotlk.git \
--branch master --single-branch --depth 1 azerothcore
dir="_build"
cd azerothcore \
&& cmake -G Ninja -H. -B$dir -DCMAKE_INSTALL_PREFIX=/azeroth-server/ \
-DTOOLS_BUILD=all -DSCRIPTS=static -DMODULES=static \
-DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
&& ninja -C $dir install
mv /azeroth-server/etc/authserver.conf{.dist,} \
&& mv /azeroth-server/etc/worldserver.conf{.dist,} \
&& sed -i -E '/^DataDir/s#=.+$#= "/azeroth-server/data"#' /azeroth-server/etc/worldserver.conf
echo "dataTag=$dataTag"
case $dataTag in
  ac335a_en)
    dataFile="ac-wow3.3.5a_en.tar.xz"
    ;;
  ac335a_zh)
    dataFile="ac-wow3.3.5a_zh.tar.xz"
    ;;
  *)
    echo "Branch unknown, that is weird, use English data as default"
    dataFile="ac-wow3.3.5a_en.tar.xz"
    ;;
esac
echo "dataFile=$dataFile"
dataUrl="https://github.com/novice79/wow/releases/download/v1.0-ac-wow3.3.5a-data/$dataFile"
echo "dataUrl=$dataUrl"
mkdir -p /azeroth-server/data \
&& curl -s -L "$dataUrl" \
| tar Jxf - -C /azeroth-server/data
mkdir -p /wow_deps && cd /wow_deps
find /azeroth-server/bin -type f -perm /a+x -exec ldd {} \; \
| grep "=> /" \
| awk '{print $3}' \
| sort \
| uniq \
| xargs -I '{}' sh -c 'cp --parents -L {} .' \
&& mkdir usr && mv lib usr/

# /etc/init.d/mysql start
/usr/sbin/mysqld &
while : ; do
    # wait for mysql started
    sleep 3
    mysqladmin -uroot processlist 2> /dev/null
    [ $? -eq 0 ] && break
done
mysql -u root < /wow/azerothcore/data/sql/create/create_mysql.sql

cd /azeroth-server/bin
./authserver &
./worldserver &
echo "wait for worldserver started ..."
while ! tail -n 15 ./Server.log | grep -E -q "AzerothCore rev\..+ready\.{3}"; do
    sleep 2
    # show progress
    curLine="$(tail -n 1 ./Server.log)"
    if [[ "$curLine" != "$lastLine" ]];then
        echo "$curLine"
        lastLine="$curLine"
    fi
done
truncate -s 0 ./Server.log
echo "Wow DB initiallizing finished."