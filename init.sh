#!/usr/bin/env bash

log () {
    printf "[%(%Y-%m-%d %T)T] %s\n" -1 "$*"
}

chown -R mysql:mysql /var/lib/mysql
if [ ! -e "/var/lib/mysql/mysql" ]; then
    log "initializing database ..."
    rm -rf /var/lib/mysql/*
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi
/usr/sbin/mysqld &
while : ; do
    # wait for mysql started
    sleep 3
    mysqladmin -uroot processlist 2> /dev/null
    [ $? -eq 0 ] && break
done
log "mysql service is started"
if [ ! -d "/var/lib/mysql/acore_world" ]; then
    log "Wow database not exist, first run will need to import 636+ MB sql data, \
    that will take 4-5 minutes, please be patient(subsequent run will be significant faster)"
    mysql -u root < /wow/azerothcore/data/sql/create/create_mysql.sql
fi
cd /azeroth-server/bin

if [ -n "$realmid" ]; then
    sed -i -E '/^RealmID/s/=.+$/= '"$realmid"'/' /azeroth-server/etc/worldserver.conf
fi
if [ -n "$logindb" ]; then
    sed -i -E '/^LoginDatabaseInfo/s/".+"/"'"$logindb"'"/' /azeroth-server/etc/worldserver.conf
fi
screen -AmdS ws /bin/bash -c 'while :; do ./worldserver; sleep 5; done'
log "start worldserver"

# update realmlist set name='艾泽拉斯' where id=1;
while [ -z "$logindb" ] ; do
    sleep 3
    log "wait for worldserver initializing ..."
    if [ -f /var/lib/mysql/acore_auth/realmlist.ibd ]; then
        sleep 1
        if [ -n "$name" ]; then
            mysql -u root -D acore_auth -e "update realmlist set name='$name' where id=1;"
        fi
        if [ -n "$address" ]; then
            mysql -u root -D acore_auth -e "update realmlist set address='$address' where id=1;"
        fi
        if [ -n "$port" ]; then
            mysql -u root -D acore_auth -e "update realmlist set port='$port' where id=1;"
        fi
        log "set worldserver name & address"
        break
    fi
done

while [ -z "$logindb" ] ; do
    sleep 3
    if [ -f /var/lib/mysql/acore_auth/account.ibd ]; then
        sleep 1
        log "set user=${user:="wow"}"
        log "set pass=${pass:="wow"}"
        # todo: if user exist, no need to set
        screen -S ws -p 0 -X stuff "account create $user $pass 0\\r"
        screen -S ws -p 0 -X stuff "account set gmlevel $user 3 -1 0\\r"

        screen -AmdS as /bin/bash -c 'while :; do ./authserver; sleep 5; done'
        log "start authserver"
        break
    fi
done
# mysql -uroot -D acore_auth -e "select * from realmlist;"
# mysql -uroot -D acore_auth -e "select * from account;"
log "wow services started !!!"
count=0
while [ 1 ]; do
    mysql -uroot -D acore_auth -e "select id,username from account ;" | grep -i "$user"
    if [ $? -eq 0 ]; then
        log "account: [$user] flushed. can use it to login game!"
        break
    else
        sleep 2
        log "wait for account: [$user] to take effect ...$((++count*2)) seconds"
    fi
done
SERVICE="mysqld"
while [ 1 ]; do
    sleep 2
    if ! pidof "$SERVICE" >/dev/null; then
        log "$SERVICE stopped. restart it"
        /usr/sbin/mysqld &
    fi
done

# docker run -it --name ac --entrypoint bash ac 
# 