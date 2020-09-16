FROM golang:1.15.1-alpine3.12 as builder

WORKDIR /go/src/github.com/electrocucaracha/gw-tester
COPY . .

ENV GO111MODULE "on"
ENV CGO_ENABLED "0"
ENV GOOS "linux"
ENV GOARCH "amd64"

RUN go build -v -ldflags '-extldflags "-static"' -o /go/bin/sidecar-nse ./cmd/main.go

FROM alpine:3.12

COPY --from=builder /go/bin/sidecar-nse /bin/sidecar-nse
ENTRYPOINT ["/bin/sidecar-nse"]
