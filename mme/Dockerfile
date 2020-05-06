FROM golang:1.14-alpine3.11 as builder

RUN apk --no-cache add git
RUN go get -v github.com/wmnsk/go-gtp/examples/gw-tester/mme

FROM alpine:3.11

ENV APP_ROOT=/opt/gw-tester
COPY --from=builder /go/bin/mme ${APP_ROOT}/bin/
COPY ./mme_default.yml /etc/gw-tester/mme.yml

RUN chmod -R u+x ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/gw-tester && \
    chgrp -R 0 ${APP_ROOT}

USER 10001
WORKDIR ${APP_ROOT}

EXPOSE 36412/udp
EXPOSE 2123/udp

ENTRYPOINT ["/opt/gw-tester/bin/mme", "-config", "/etc/gw-tester/mme.yml"]
