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

./undeploy_main.sh

# Deploy P-GW and S-GW services
for pod in pgw sgw; do
    kubectl apply -f "${pod}.yml"
    kubectl wait --for=condition=ready pod "$pod" --timeout=120s
done

# Deploy MME service
SGW_S11_IP=$(kubectl logs sgw | grep -oP 'S11 on \K.*?(?=:)')
PGW_S5C_IP=$(kubectl logs pgw | grep -oP 'S5-C on \K.*?(?=:)')
export SGW_S11_IP PGW_S5C_IP
envsubst \$PGW_S5C_IP,\$SGW_S11_IP < mme.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod mme --timeout=120s

# Deploy eNB service
MME_S11_ADDR="$(kubectl logs mme | grep -oP 'S1-MME on: \K.*?(?=:)'):36412"
export MME_S11_ADDR
envsubst \$MME_S11_ADDR < enb.yml | kubectl apply -f -
kubectl wait --for=condition=ready pod enb --timeout=120s
