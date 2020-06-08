FROM golang:1.14-alpine3.11 as builder

RUN apk --no-cache add git
RUN go get -v github.com/wmnsk/go-gtp/examples/gw-tester/enb

FROM alpine:3.11

RUN apk --no-cache add coreutils
ENV APP_ROOT=/opt/gw-tester
COPY --from=builder /go/bin/enb ${APP_ROOT}/bin/
COPY ./enb_default.yml /etc/gw-tester/enb.yml

RUN chmod -R u+x ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/gw-tester && \
    chgrp -R 0 ${APP_ROOT}

#USER 10001
WORKDIR ${APP_ROOT}

EXPOSE 2152/udp

ENTRYPOINT ["/opt/gw-tester/bin/enb", "-config", "/etc/gw-tester/enb.yml"]
