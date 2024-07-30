#!/usr/bin/env bash

log () {
    printf "[%(%Y-%m-%d %T)T] %s\n" -1 "$*"
}

if [ ! -d "/var/lib/mysql/acore_world" ]; then
    log "Copy wow server database ..."
    rm -rf /var/lib/mysql/*
    cp -r /usr/local/skyfire-server/mysql/* /var/lib/mysql/
fi
chown -R mysql:mysql /var/lib/mysql
log "Starting mysql server, please wait ..."
/usr/sbin/mysqld &
while : ; do
    # wait for mysql started
    sleep 3
    mysqladmin -uroot processlist 2> /dev/null
    [ $? -eq 0 ] && break
done
log "mysql service is started"
if [ -n "$realmid" ]; then
    sed -i -E '/^RealmID/s/=.+$/= '"$realmid"'/' /usr/local/skyfire-server/etc/worldserver.conf
fi
if [ -n "$logindb" ]; then
    sed -i -E '/^LoginDatabaseInfo/s/".+"/"'"$logindb"'"/' /usr/local/skyfire-server/etc/worldserver.conf
fi
if [ -n "$name" ]; then
    mysql -u root -D acore_auth -e "update realmlist set name='$name' where id=1;"
fi
if [ -n "$address" ]; then
    mysql -u root -D acore_auth -e "update realmlist set address='$address' where id=1;"
fi
if [ -n "$port" ]; then
    mysql -u root -D acore_auth -e "update realmlist set port='$port' where id=1;"
fi
cd /usr/local/skyfire-server/bin
screen -AmdS as /bin/bash -c 'while :; do ./authserver; sleep 5; done'
log "start authserver"
screen -AmdS ws /bin/bash -c 'while :; do ./worldserver; sleep 5; done'
log "wait for worldserver initializing ..."
while ! tail -n 15 ./Server.log | grep -E -q "SkyFire 5.x.x rev\..+ready\.{3}"; do
    sleep 2
    # show progress
    tail -n 1 ./Server.log
done
log "wow services started !!!"

log "set user=${user:="wow"}"
log "set pass=${pass:="wow"}"
# todo: if user exist, no need to set
screen -S ws -p 0 -X stuff "account create $user $pass \\r"

count=0
while [ 1 ]; do
    mysql -uroot -D acore_auth -e "select id,username from account ;" | grep -i "$user"
    if [ $? -eq 0 ]; then
        screen -S ws -p 0 -X stuff "account set gmlevel $user 3 -1 \\r"
        #set this account to highest gm level 
        # mysql -uroot -D acore_auth -e "select * from account_access;"
        # mysql -uroot -D acore_auth -e "UPDATE account_access AS access
        # INNER JOIN account AS account ON access.id = account.id
        # SET gmlevel = 4 WHERE username = '$user';"
        log "Account: [$user] has flushed, can be used to login in game now!"
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
