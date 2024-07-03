FROM ubuntu:24.04 as wow_build

# This for local test in mainland China
# COPY tsinghua.sources /etc/apt/sources.list.d/ubuntu.sources

RUN apt-get update && apt-get install -y \
git cmake make gcc g++ clang libmysqlclient-dev libssl-dev libbz2-dev \
libreadline-dev libncurses-dev mysql-server libboost-all-dev ninja-build \
xz-utils curl
WORKDIR /wow
RUN git clone https://github.com/azerothcore/azerothcore-wotlk.git \
--branch master --single-branch --depth 1 azerothcore
# # for local test
# COPY azerothcore /wow/azerothcore
ENV dir="_build"
RUN cd azerothcore \
&& cmake -G Ninja -H. -B$dir -DCMAKE_INSTALL_PREFIX=/azeroth-server/ \
-DTOOLS_BUILD=all -DSCRIPTS=static -DMODULES=static \
-DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
&& ninja -C $dir install
SHELL ["/bin/bash", "-c"]
RUN mv /azeroth-server/etc/authserver.conf{.dist,} \
&& mv /azeroth-server/etc/worldserver.conf{.dist,} \
&& sed -i -E '/^DataDir/s#=.+$#= "/azeroth-server/data"#' /azeroth-server/etc/worldserver.conf
# for local test
# ln -sf /wow/client/data/az-wow3.3.5a_en /azeroth-server/data
# COPY client/data/ac-wow3.3.5a_en /azeroth-server/data
RUN mkdir -p /azeroth-server/data \
&& curl -s -L https://github.com/novice79/wow/releases/download/v1.0-ac-wow3.3.5a-data/ac-wow3.3.5a_en.tar.xz \
| tar Jxvf - -C /azeroth-server/data
WORKDIR /wow_deps
# copy .so symlink & target files together
RUN find /azeroth-server/bin -type f -perm /a+x -exec ldd {} \; \
| grep "=> /" \
| awk '{print $3}' \
| sort \
| uniq \
| xargs -I '{}' sh -c 'cp --parents -L {} .' \
&& mkdir usr && mv lib usr/

FROM ubuntu:24.04
LABEL maintainer="novice <novice79@126.com>"
# this needed to install tzdate noninteractivelly
ENV DEBIAN_FRONTEND noninteractive

# COPY sources.list /etc/apt/sources.list
RUN apt-get update && apt-get install -y \
	screen mysql-server tzdata

ENV TZ=Asia/Chongqing
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
&& mkdir -p /wow/azerothcore
COPY --from=wow_build /wow/azerothcore/data /wow/azerothcore/data
COPY --from=wow_build /wow_deps /
COPY --from=wow_build /azeroth-server /azeroth-server

RUN mkdir -p /var/run/mysqld ; chown mysql:mysql /var/run/mysqld
WORKDIR /azeroth-server/bin

VOLUME ["/var/lib/mysql"]

EXPOSE 3724 8085

COPY init.sh /

ENTRYPOINT ["/init.sh"]
