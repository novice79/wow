FROM ubuntu:24.04 AS wow_data
RUN apt-get update && apt-get install -y xz-utils curl
RUN mkdir -p /azeroth-server/data \
&& curl -s -L https://github.com/novice79/wow/releases/download/v1.0-ac-wow3.3.5a-data/ac-wow3.3.5a_zh.tar.xz \
| tar Jxf - -C /azeroth-server/data


FROM novice/wow:ac335a_en
LABEL maintainer="novice <novice79@126.com>"

ENV DEBIAN_FRONTEND=noninteractive

RUN rm -rf /azeroth-server/data
COPY --from=wow_data /azeroth-server/data /azeroth-server/data

WORKDIR /azeroth-server/bin

VOLUME ["/var/lib/mysql"]

EXPOSE 3724 8085

ENTRYPOINT ["/init.sh"]
