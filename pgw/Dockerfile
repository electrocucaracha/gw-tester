FROM golang:1.15-alpine3.13 as builder

RUN apk --no-cache add git=2.30.1-r0
RUN go get -v github.com/wmnsk/go-gtp/examples/gw-tester/pgw

FROM alpine:3.13

ENV APP_ROOT=/opt/gw-tester
COPY --from=builder /go/bin/pgw ${APP_ROOT}/bin/
COPY ./pgw_default.yml /etc/gw-tester/pgw.yml

RUN apk --no-cache add curl=7.74.0-r0
RUN chmod -R u+x ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/gw-tester && \
    chgrp -R 0 ${APP_ROOT}

#USER 10001
WORKDIR ${APP_ROOT}

EXPOSE 2123/udp
EXPOSE 2152/udp

ENTRYPOINT ["/opt/gw-tester/bin/pgw", "-config", "/etc/gw-tester/pgw.yml"]
