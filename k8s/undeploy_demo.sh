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

kubectl delete -f etcd.yml --ignore-not-found --wait=false
if [ "${PKG_MGR:-k8s}" == "helm" ]; then
    for chart in saegw mme enb; do
        if helm ls | grep "$chart"; then
            helm uninstall "$chart"
        fi
    done
fi
kubectl delete pod --all --timeout=3m
