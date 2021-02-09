FROM golang:1.15-alpine3.13 as builder

RUN apk --no-cache add git=2.30.1-r0
RUN go get -v github.com/wmnsk/go-gtp/examples/gw-tester/enb

FROM alpine:3.13

ENV APP_ROOT=/opt/gw-tester
COPY --from=builder /go/bin/enb ${APP_ROOT}/bin/
COPY ./enb_default.yml /etc/gw-tester/enb.yml

RUN apk --no-cache add coreutils=8.32-r2 curl=7.74.0-r0 jq=1.6-r1
RUN chmod -R u+x ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/gw-tester && \
    chgrp -R 0 ${APP_ROOT}

#USER 10001
WORKDIR ${APP_ROOT}

EXPOSE 2152/udp

ENTRYPOINT ["/opt/gw-tester/bin/enb", "-config", "/etc/gw-tester/enb.yml"]
