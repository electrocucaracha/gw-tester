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
if [[ "${DEBUG:-true}" == "true" ]]; then
    set -o xtrace
fi

multi_cni="${MULTI_CNI:-multus}"

./undeploy_demo.sh

# Get an IP Cluster
kubectl apply -f etcd.yml

# Create a etcd datastore and insert flannel entries
kubectl scale deployment lte-etcd --replicas=1
kubectl rollout status deployment/lte-etcd --timeout=5m

# Deploy SAE-GW helm charts
if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
    helm install saegw "./${multi_cni}/charts/saegw/"
    for chart in pgw sgw; do
        kubectl rollout status "deployment/saegw-$chart"
    done
else
    for pod in pgw sgw; do
        kubectl apply -f "${pod}_${multi_cni}.yml"
        kubectl wait --for=condition=ready pod "$pod" --timeout=120s
    done
fi

# Deploy Http server
if [ "$multi_cni" == "multus" ]; then
    PGW_SGI_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-sgi").ips[0]')
elif [ "$multi_cni" == "danm" ]; then
    PGW_SGI_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' | grep "10.0.1")
fi
export PGW_SGI_IP
envsubst \$PGW_SGI_IP < "http-server_${multi_cni}.yml" | kubectl apply -f -

# Deploy MME service
if [ "$multi_cni" == "multus" ]; then
    SGW_S11_IP=$(kubectl get pods -l=app.kubernetes.io/name=sgw \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-s11").ips[0]')
    PGW_S5C_IP=$(kubectl get pods -l=app.kubernetes.io/name=pgw \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-s5c").ips[0]')
elif [ "$multi_cni" == "danm" ]; then
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
    envsubst \$PGW_S5C_IP,\$SGW_S11_IP < "mme_${multi_cni}.yml" | kubectl apply -f -
    kubectl wait --for=condition=ready pod mme --timeout=120s
fi

# Deploy eNB service
if [ "$multi_cni" == "multus" ]; then
    MME_S1C_IP=$(kubectl get pods -l=app.kubernetes.io/name=mme \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-s1c").ips[0]')
elif [ "$multi_cni" == "danm" ]; then
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
    envsubst \$MME_S1C_IP < "enb_${multi_cni}.yml" | kubectl apply -f -
    kubectl wait --for=condition=ready pod enb --timeout=120s
fi

# Deploy External client
kubectl wait --for=condition=ready pod http-server
if [ "$multi_cni" == "multus" ]; then
    ENB_EUU_IP=$(kubectl get pods -l=app.kubernetes.io/name=enb \
    -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-euu").ips[0]')
    HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server \
    -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks-status}' \
    | jq -r '.[] | select(.name=="lte-sgi").ips[0]')
elif [ "$multi_cni" == "danm" ]; then
    ENB_EUU_IP=$(kubectl get pods -l=app.kubernetes.io/name=enb \
    -o jsonpath='{range .items[0].status.podIPs[*]}{.ip}{"\n"}' | grep "10.0.3")
    HTTP_SERVER_SGI_IP=$(kubectl get pod/http-server \
    -o jsonpath='{.status.podIPs[0].ip}')
elif [ "$multi_cni" == "nsm" ]; then
    HTTP_SERVER_SGI_IP=$(kubectl exec http-server -- ifconfig sgi0 | awk '/inet addr/{print substr($2,6)}')
fi
export ENB_EUU_IP HTTP_SERVER_SGI_IP
envsubst \$ENB_EUU_IP,\$HTTP_SERVER_SGI_IP < "external-client_${multi_cni}.yml" | kubectl apply -f -
kubectl wait --for=condition=ready pod external-client
