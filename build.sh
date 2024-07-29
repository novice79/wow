#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y \
git clang cmake make gcc g++ libmysqlclient-dev libssl-dev \
libbz2-dev libreadline-dev libncurses-dev libboost-all-dev mysql-server \
ninja-build xz-utils curl p7zip

update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100
update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang 100


mkdir -p /wow && cd /wow
git clone https://github.com/TrinityCore/TrinityCore.git \
-b 3.3.5 --single-branch --depth 1 
dir="_build"
cd TrinityCore \
&& cmake -G Ninja -H. -B$dir -DCMAKE_INSTALL_PREFIX=/tc-server/ \
&& ninja -C $dir install
mv /tc-server/etc/authserver.conf{.dist,} \
&& mv /tc-server/etc/worldserver.conf{.dist,} \
&& sed -i -E '/^DataDir/s#=.+$#= "/tc-server/data"#' /tc-server/etc/worldserver.conf
echo "dataTag=$dataTag"
case $dataTag in
  tc335a_en)
    dataFile="tc-wow3.3.5a_en.tar.xz"
    ;;
  tc335a_zh)
    dataFile="tc-wow3.3.5a_zh.tar.xz"
    ;;
  *)
    echo "Branch unknown, that is weird, use English data as default"
    dataFile="tc-wow3.3.5a_en.tar.xz"
    ;;
esac
echo "dataFile=$dataFile"
dataUrl="https://github.com/novice79/wow/releases/download/v1.0-tc-wow3.3.5a-data/$dataFile"
echo "dataUrl=$dataUrl"
mkdir -p /tc-server/data \
&& curl -s -L "$dataUrl" \
| tar Jxf - -C /tc-server/data
mkdir -p /wow_deps && cd /wow_deps
find /tc-server/bin -type f -perm /a+x -exec ldd {} \; \
| grep "=> /" \
| awk '{print $3}' \
| sort \
| uniq \
| xargs -I '{}' sh -c 'cp --parents -L {} .' \
&& mkdir usr && mv lib usr/

# # /etc/init.d/mysql start
/usr/sbin/mysqld &
while : ; do
    # wait for mysql started
    sleep 3
    mysqladmin -uroot processlist 2> /dev/null
    [ $? -eq 0 ] && break
done
mysql -u root < /wow/TrinityCore/sql/create/create_mysql.sql

cd /tc-server/bin
curl -s -OL https://github.com/TrinityCore/TrinityCore/releases/download/TDB335.24041/TDB_full_world_335.24041_2024_04_10.7z
7z x *.7z && rm -f *.7z 
./worldserver &
echo "wait for worldserver started ..."
while ! tail -n 15 ./Server.log | grep -E -q "TrinityCore rev\..+ready\.{3}"; do
    sleep 2
    # show progress
    curLine="$(tail -n 1 ./Server.log)"
    if [[ "$curLine" != "$lastLine" ]];then
        echo "$curLine"
        lastLine="$curLine"
    fi
done
./authserver &
sleep 2
rm -f *.log
echo "Wow DB initiallizing finished."