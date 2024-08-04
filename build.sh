#!/usr/bin/env bash
set -e

apt-get update && apt-get install -y \
gcc g++ clang cmake git libssl-dev libreadline-dev libbz2-dev \
mysql-server libmysqlclient-dev libmysql++-dev libace-dev \
ninja-build xz-utils curl unzip
mkdir -p /wow && cd /wow
git clone https://codeberg.org/ProjectSkyfire/SkyFire_548.git \
-b main --single-branch --depth 1 
# -DCMAKE_INSTALL_PREFIX= not effect
cd SkyFire_548 \
&& dir="_build" \
&& cmake -G Ninja -H. -B$dir -DTOOLS=1 \
&& ninja -C $dir install
mv /usr/local/skyfire-server/etc/authserver.conf{.dist,} \
&& mv /usr/local/skyfire-server/etc/worldserver.conf{.dist,} \
&& sed -i -E '/^DataDir/s#=.+$#= "/usr/local/skyfire-server/data"#' /usr/local/skyfire-server/etc/worldserver.conf
echo "dataTag=$dataTag"
case $dataTag in
  sf548_en)
    dataFile="sf-wow5.4.8_en.tar.xz"
    ;;
  sf548_zh)
    dataFile="sf-wow5.4.8_zh.tar.xz"
    ;;
  *)
    echo "Branch unknown, that is weird, use English data as default"
    dataFile="sf-wow5.4.8_en.tar.xz"
    ;;
esac
echo "dataFile=$dataFile"
dataUrl="https://github.com/novice79/wow/releases/download/v1.0-sf-wow5.4.8-data/$dataFile"
echo "dataUrl=$dataUrl"
mkdir -p /usr/local/skyfire-server/data \
&& curl -s -L "$dataUrl" \
| tar Jxf - -C /usr/local/skyfire-server/data
mkdir -p /wow_deps && cd /wow_deps
find /usr/local/skyfire-server/bin -type f -perm /a+x -exec ldd {} \; \
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
# This "create_mysql.sql" not match to config file connection string
# mysql -u root < /wow/SkyFire_548/sql/create/create_mysql.sql
mysql -u root <<EOF
DROP USER IF EXISTS 'skyfire'@'localhost';
CREATE USER 'skyfire'@'localhost' IDENTIFIED BY 'skyfire' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0;
GRANT ALL PRIVILEGES ON * . * TO 'skyfire'@'localhost' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS world DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS characters DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS auth DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON world . * TO 'skyfire'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON characters . * TO 'skyfire'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON auth . * TO 'skyfire'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON world . * TO 'root'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON characters . * TO 'root'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON auth . * TO 'root'@'localhost' WITH GRANT OPTION;
EOF
mysql -u root auth < /wow/SkyFire_548/sql/base/auth_database.sql 
mysql -u root characters < /wow/SkyFire_548/sql/base/characters_database.sql
cd /tmp && curl -s -OL \
"https://codeberg.org/ProjectSkyfire/database/releases/download/R24.000/SFDB_full_548_24.000_2024_03_17_Release.zip" \
&& unzip *.zip
start=`date +%s`
find SFDB_full_548*/main_db/procs SFDB_full_548*/main_db/world \
-type f -iname "*.sql" -print0 | while read -d $'\0' i
do
    echo "import $i ..."
    mysql -u root world < "$i"
    # mv "$i" /usr/local/skyfire-server/bin/
done
end=`date +%s`
echo "Importing sql to world DB takes $((end-start)) seconds"
find SFDB_full_548*/world_updates \
-type f -iname "*.sql" -print0 | while read -d $'\0' i
do
    echo "copy update file $i ..."
    mv "$i" /usr/local/skyfire-server/bin/
done
# import update sql now?
set +e
find /wow/SkyFire_548/sql/updates/characters \
-type f -iname "*.sql" -print0 | while read -d $'\0' i
do
    echo "import $i ..."
    mysql -u root characters < "$i"
done

find /wow/SkyFire_548/sql/updates/world \
-type f -iname "*.sql" -print0 | while read -d $'\0' i
do
    echo "import $i ..."
    mysql -u root world < "$i"
done
set -e
cd /usr/local/skyfire-server/bin
./authserver &
./worldserver &
echo "wait for worldserver started ..."
while ! tail -n 15 ./Server.log | grep -E -q "SkyFire 5.x.x rev\..+ready\.{3}"; do
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