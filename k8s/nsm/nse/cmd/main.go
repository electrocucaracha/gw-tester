// Copyright 2020
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"os"

	"github.com/networkservicemesh/networkservicemesh/controlplane/api/networkservice"
	"github.com/networkservicemesh/networkservicemesh/utils"

	"github.com/networkservicemesh/networkservicemesh/pkg/tools"
	"github.com/networkservicemesh/networkservicemesh/sdk/common"
	"github.com/networkservicemesh/networkservicemesh/sdk/endpoint"
	"github.com/sirupsen/logrus"
)

const (
	routeEnv = "ROUTE"
)

func main() {
	logrus.Info("Starting nse...")
	utils.PrintAllEnv(logrus.StandardLogger())
	// Capture signals to cleanup before exiting
	c := tools.NewOSSignalChannel()

	configuration := common.FromEnv()

	endpoints := []networkservice.NetworkServiceServer{
		endpoint.NewMonitorEndpoint(configuration),
		endpoint.NewConnectionEndpoint(configuration),
		endpoint.NewIpamEndpoint(configuration),
		endpoint.NewCustomFuncEndpoint("podName", endpoint.CreatePodNameMutator()),
	}

	route := os.Getenv(routeEnv)
	if route != "" {
		routeAddr := endpoint.CreateRouteMutator([]string{route})
		endpoints = append(endpoints, endpoint.NewCustomFuncEndpoint("route", routeAddr))
	}
	composite := endpoint.NewCompositeEndpoint(endpoints...)
	nsEndpoint, err := endpoint.NewNSMEndpoint(context.Background(), configuration, composite)
	if err != nil {
		logrus.Fatalf("%v", err)
	}
	if err := nsEndpoint.Start(); err != nil {
		logrus.Fatalf("Unable to start the endpoint: %v", err)
	}

	defer func() { _ = nsEndpoint.Delete() }()

	// Capture signals to cleanup before exiting
	<-c
}
