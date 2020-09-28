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

if [ "${DEPLOY_KIND_CLUSTER:-true}" == "true" ]; then
    # Load the ETCD image to local regitstry
    newgrp docker <<EONG
    docker pull nfvpe/multus:v3.4
    kind load docker-image nfvpe/multus:v3.4 --name k8s
EONG
fi

# Deploy Multus CNI daemonset and CRD
kubectl apply -f install

# Create NetworkAttachmentDefinition resources
kubectl apply -f overlay.yml
