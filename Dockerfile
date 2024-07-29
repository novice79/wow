FROM ubuntu:24.04 AS wow_build
ARG branchTag
ENV dataTag=$branchTag

COPY build.sh /
RUN /build.sh

FROM ubuntu:24.04
LABEL maintainer="novice <novice79@126.com>"
# this needed to install tzdate noninteractivelly
ENV DEBIAN_FRONTEND=noninteractive

# COPY sources.list /etc/apt/sources.list
RUN apt-get update && apt-get install -y \
	screen mysql-server tzdata

ENV TZ=Asia/Chongqing
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone 

COPY --from=wow_build /wow_deps /
COPY --from=wow_build /tc-server /tc-server
# todo: no need to copy whole folder?
COPY --from=wow_build /wow/TrinityCore/sql /wow/TrinityCore/sql
SHELL ["/bin/bash", "-c"]
RUN rm -rf /wow/TrinityCore/sql/{old,base/dev}
COPY --from=wow_build /var/lib/mysql /tc-server/mysql

RUN mkdir -p /var/run/mysqld ; chown mysql:mysql /var/run/mysqld
WORKDIR /tc-server/bin

VOLUME ["/var/lib/mysql"]

EXPOSE 3724 8085

COPY init.sh /

ENTRYPOINT ["/init.sh"]
