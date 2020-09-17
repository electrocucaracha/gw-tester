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

exit_trap() {
    if [[ "${DEBUG:-true}" == "true" ]]; then
        set +o xtrace
    fi
    printf "CPU usage: "
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    printf "Memory free(Kb):"
    awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    echo "Environment variables:"
    printenv
    echo "Kubernetes Resources:"
    kubectl get all -A -o wide
}

trap exit_trap ERR

./undeploy_demo.sh

# Get an IP Cluster
kubectl apply -f etcd.yml

# Create a etcd datastore and insert flannel entries
kubectl scale deployment lte-etcd --replicas=1
kubectl rollout status deployment/lte-etcd --timeout=3m

if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
    for chart in saegw mme enb; do
        helm install "$chart" "./${multi_cni}/charts/$chart/"
    done
    kubectl rollout status deployment/saegw-pgw --timeout=3m
else
    for pod in pgw sgw mme enb; do
        kubectl apply -f "${pod}_${multi_cni}.yml"
    done
    kubectl wait --for=condition=ready pods pgw --timeout=3m
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

# Deploy External client
kubectl wait --for=condition=ready pods --all --timeout=3m
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
kubectl wait --for=condition=ready pod external-client --timeout=3m

trap ERR
