FROM alpine:latest

RUN apk --no-cache add bash curl jq vim

ADD assets/ /opt/resource/
ADD bin/ /opt/resource/
RUN chmod a+x /opt/resource/*

WORKDIR /opt/resource
RUN ./test.sh
