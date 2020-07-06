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

echo "Running deployment process..."
case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        make docker-deploy-demo
        sudo docker ps
        make docker-logs
    ;;
    k8s)
        if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
            make helm-deploy
            make helm-logs
            kubectl get pods -o wide
            make helm-deploy-demo
        else
            make k8s-deploy
            make k8s-logs
            kubectl get pods -o wide
            make k8s-deploy-demo
        fi
    ;;
esac
