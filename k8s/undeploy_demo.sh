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

kubectl delete -f etcd.yml --ignore-not-found
for pod in http-server external-client; do
    kubectl delete -f "${pod}_${multi_cni}.yml" --wait=false --ignore-not-found=true
done
for pod in http-server external-client; do
    kubectl wait --for=delete "pod/$pod" --timeout=3m || true
done

if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
    for chart in saegw mme enb; do
        if helm ls | grep "$chart"; then
            helm uninstall "$chart"
        fi
    done
else
    for pod in pgw sgw mme enb; do
        kubectl delete -f "${pod}_${multi_cni}.yml" --wait=false --ignore-not-found=true
    done
    for pod in pgw sgw mme enb; do
        kubectl wait --for=delete "pod/$pod" --timeout=3m || true
    done
fi

