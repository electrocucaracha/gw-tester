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

kubectl apply -f https://raw.githubusercontent.com/intel/multus-cni/v3.4.1/images/multus-daemonset.yml
for daemonset in $(kubectl get daemonset -n kube-system | grep kube-multus | awk '{print $1}'); do
    echo "Waiting for $daemonset to successfully rolled out"
    if ! kubectl rollout status "daemonset/$daemonset" -n kube-system --timeout=5m > /dev/null; then
        echo "The $daemonset daemonset has not started properly"
        exit 1
    fi
done
kubectl apply -f k8s/multus/
