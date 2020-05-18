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
PGW_SGI_IP=$(kubectl get pod/pgw -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' | jq '.[] | select(.name=="lte-sgi").ips[0]' | sed -e 's/^"//' -e 's/"$//' )
export PGW_SGI_IP
envsubst \$PGW_SGI_IP < http-server.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod http-server

# Deploy External client
ENB_EUU_IP=$(kubectl get pod/enb -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' | jq '.[] | select(.name=="lte-euu").ips[0]' | sed -e 's/^"//' -e 's/"$//' )
HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' | jq '.[] | select(.name=="lte-sgi").ips[0]' | sed -e 's/^"//' -e 's/"$//' )
export ENB_EUU_IP HTTP_SERVER_SGI_IP
envsubst \$ENB_EUU_IP,\$HTTP_SERVER_SGI_IP < external-client.yml | kubectl apply -f -
