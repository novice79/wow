# wow private server 

ac335a_en -- stand for azerothcore wow3.3.5a English version

# Usage:
```
docker run \
--restart=always \
-d --name ac \
-p 4000:3724 -p 5000:8085 \
-v wow-db1:/var/lib/mysql \
-e logindb="172.17.0.1;3306;acore;acore;acore_auth" \
-e realmid=3 \
-e name="wlk" \
-e address="192.168.1.221" \
-e port=5000 \
-e user=admin \
-e pass=admin \
novice/wow:ac335a_en
```

P.S. :  
if only need one auth+world server(or as a main server), then 
**logindb & realmid** _no need to supply_

# run gm command on the server backend

    docker exec -it ac bash
    screen -r ws
    server info

# add login address to wow client(3.3.5a), like this

    in dir: azerothcore-wow-3.3.5a/Data/enUS/realmlist.wtf
    set realmlist 192.168.1.221:4000

# then use gm account(user&pass env var specified above) enter into game

# if want to add another worldserver(aka realm)

    in the first container, add second worldserver's ip, port, and proper name 

    mysql -uroot -D acore_auth -e \
    "insert into realmlist (name, address, port, timezone,flag) 
    values('wlk','192.168.1.221','5000',16,0);"

    then start second container, 
    use the command above(with logindb & realmid env specify first container's auth db info)