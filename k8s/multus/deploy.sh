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

pushd k8s/multus/
kubectl apply -f multus-daemonset.yml
eval "./${CNI:-flannel}/deploy.sh"
for daemonset in $(kubectl get daemonset -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}'); do
    kubectl rollout status "daemonset/$daemonset" -n kube-system
done
for pod in pgw sgw; do
    kubectl apply -f "${pod}.yml"
    kubectl wait --for=condition=ready pod "$pod"
done
SGW_S11_IP=$(kubectl logs sgw | grep -oP 'S11 on \K.*?(?=:)')
PGW_S5C_IP=$(kubectl logs pgw | grep -oP 'S5-C on \K.*?(?=:)')
export SGW_S11_IP PGW_S5C_IP
envsubst \$PGW_S5C_IP,\$SGW_S11_IP < mme.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod mme
MME_S11_ADDR="$(kubectl logs mme | grep -oP 'S1-MME on: \K.*?(?=:)'):36412"
export MME_S11_ADDR
envsubst \$MME_S11_ADDR < enb.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod enb
PGW_SGI_IP=$(kubectl get pod/pgw -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' | jq '.[] | select(.name=="lte-sgi").ips[0]' | sed -e 's/^"//' -e 's/"$//' )
export PGW_SGI_IP
envsubst \$PGW_SGI_IP < http-server.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod http-server
ENB_EUU_IP=$(kubectl get pod/enb -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' | jq '.[] | select(.name=="lte-euu").ips[0]' | sed -e 's/^"//' -e 's/"$//' )
HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' | jq '.[] | select(.name=="lte-sgi").ips[0]' | sed -e 's/^"//' -e 's/"$//' )
export ENB_EUU_IP HTTP_SERVER_SGI_IP
envsubst \$ENB_EUU_IP,\$HTTP_SERVER_SGI_IP < external-client.yml | kubectl apply -f -
popd
