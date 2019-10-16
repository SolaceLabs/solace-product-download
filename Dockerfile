FROM alpine:latest

RUN apk --no-cache add bash curl jq vim
RUN wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v0.0.67/pivnet-linux-amd64-0.0.67 -O /usr/bin/pivnet
run chmod +x /usr/bin/pivnet

ADD assets/ /opt/resource/
ADD bin/ /opt/resource/
RUN chmod a+x /opt/resource/*

WORKDIR /opt/resource
RUN ./test.sh
