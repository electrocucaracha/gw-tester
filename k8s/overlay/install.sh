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

# Wait for CoreDNS service
kubectl rollout status deployment/coredns -n kube-system

# Load the ETCD image to local regitstry
newgrp docker <<EONG
docker pull quay.io/coreos/etcd:v3.3.20
kind load docker-image quay.io/coreos/etcd:v3.3.20 --name k8s
EONG

# Get an IP Cluster
kubectl apply -f etcd.yml

# Create a etcd datastore and insert flannel entries
kubectl scale deployment flannel-etcd -n kube-system --replicas=1
kubectl rollout status deployment/flannel-etcd -n kube-system --timeout=3m
flannel_etdc_pod=$(kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep flannel-etcd )
until kubectl logs "$flannel_etdc_pod" -n kube-system | grep "ready to serve client requests"; do
    sleep 2
done

# Create Flannel separate services for every network
kubectl apply -f "configmaps_${PLUGIN_CNI:-flannel}.yml"
kubectl apply -f ./lte-networks/
