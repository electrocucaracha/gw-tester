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

multi_cni="${MULTI_CNI:-multus}"

./undeploy_demo.sh

# Deploy Http server
if [ "$multi_cni" == "multus" ]; then
    PGW_SGI_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-sgi").ips[0]')
else
    PGW_SGI_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' | grep "10.0.1")
fi
export PGW_SGI_IP
envsubst \$PGW_SGI_IP < http-server.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod http-server

# Deploy External client
if [ "$multi_cni" == "multus" ]; then
    ENB_EUU_IP=$(kubectl get pods -l=app.kubernetes.io/name=enb \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-euu").ips[0]')
    HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server \
    -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-sgi").ips[0]')
else
    ENB_EUU_IP=$(kubectl get pods -l=app.kubernetes.io/name=enb \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' | grep "10.0.3")
    HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server \
    -o jsonpath='{.status.podIPs[0].ip}')
fi
export ENB_EUU_IP HTTP_SERVER_SGI_IP
envsubst \$ENB_EUU_IP,\$HTTP_SERVER_SGI_IP < external-client.yml | kubectl apply -f -
