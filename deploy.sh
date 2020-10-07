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

echo "Running deployment process..."
case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        make docker-deploy-demo
        if [[ "${DEBUG:-true}" == "true" ]]; then
            sudo docker ps
            make docker-logs
        fi
        sudo docker logs "$(sudo docker ps --filter "name=docker_external_client_1*" --format "{{.Names}}")"
    ;;
    k8s)
        if [ "${PKG_MGR:-k8s}" == "helm" ]; then
            make helm-deploy-demo
            if [[ "${DEBUG:-true}" == "true" ]]; then
                kubectl get all -o wide
                make helm-logs
            fi
        else
            make k8s-deploy-demo
            if [[ "${DEBUG:-true}" == "true" ]]; then
                kubectl get all -o wide
                make k8s-logs
            fi
        fi
        kubectl logs external-client -c external-client
    ;;
esac
