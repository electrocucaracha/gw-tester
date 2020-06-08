#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
set -o xtrace

./undeploy_demo.sh

# Deploy Http server
PGW_SGI_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' | grep "10.0.1")
export PGW_SGI_IP
envsubst \$PGW_SGI_IP < http-server.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod http-server --timeout=120s

# Deploy External client
ENB_EUU_IP=$(kubectl get pods -l=app.kubernetes.io/name=enb -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' | grep "10.0.3")
HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server -o jsonpath='{.status.podIPs[0].ip}')
export ENB_EUU_IP HTTP_SERVER_SGI_IP
envsubst \$ENB_EUU_IP,\$HTTP_SERVER_SGI_IP < external-client.yml | kubectl apply -f -
