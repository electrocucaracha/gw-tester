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

./undeploy_main.sh

# Deploy SAE-GW helm charts
if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
    helm install saegw "./${multi_cni}/charts/saegw/"
    for chart in pgw sgw; do
        kubectl rollout status "deployment/saegw-$chart"
    done
else
    for pod in pgw sgw; do
        kubectl apply -f "${pod}.yml"
        kubectl wait --for=condition=ready pod "$pod" --timeout=120s
    done
fi

# Deploy MME service
if [ "$multi_cni" == "multus" ]; then
    SGW_S11_IP=$(kubectl get pods -l=app.kubernetes.io/name=sgw \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-s11").ips[0]')
    PGW_S5C_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-s5c").ips[0]')
else
    SGW_S11_IP=$(kubectl get pods -l=app.kubernetes.io/name=sgw \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' \
    | grep "172.22.0")
    PGW_S5C_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' \
    | grep "172.25.1")
fi
if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
    helm install mme "./${multi_cni}/charts/mme" \
    --set sgw.s11.ip="$SGW_S11_IP" \
    --set pgw.s5c.ip="$PGW_S5C_IP"
    kubectl rollout status deployment/mme
else
    export SGW_S11_IP PGW_S5C_IP
    envsubst \$PGW_S5C_IP,\$SGW_S11_IP < mme.yml | kubectl apply -f -
    kubectl wait --for=condition=ready pod mme --timeout=120s
fi

# Deploy eNB service
if [ "$multi_cni" == "multus" ]; then
    MME_S1C_IP=$(kubectl get pods -l=app.kubernetes.io/name=mme \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-s1c").ips[0]')
else
    MME_S1C_IP=$(kubectl get pods -l=app.kubernetes.io/name=mme \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' \
    | grep "172.21.1")
fi
if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
    helm install enb "./${multi_cni}/charts/enb" \
    --set mme.s1c.ip="$MME_S1C_IP"
    kubectl rollout status deployment/enb
else
    export MME_S1C_IP
    envsubst \$MME_S1C_IP < enb.yml | kubectl apply -f -
    kubectl wait --for=condition=ready pod enb --timeout=120s
fi
