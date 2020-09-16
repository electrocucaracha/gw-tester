module github.com/electrocucaracha/gw-tester

go 1.15

replace github.com/census-instrumentation/opencensus-proto v0.1.0-0.20181214143942-ba49f56771b8 => github.com/census-instrumentation/opencensus-proto v0.0.3-0.20181214143942-ba49f56771b8

require (
	github.com/networkservicemesh/networkservicemesh/controlplane/api v0.2.0
	github.com/networkservicemesh/networkservicemesh/pkg v0.2.0
	github.com/networkservicemesh/networkservicemesh/sdk v0.2.0
	github.com/networkservicemesh/networkservicemesh/utils v0.2.0
	github.com/sirupsen/logrus v1.6.0
)
