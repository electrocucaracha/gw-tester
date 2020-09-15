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
            sudo docker logs "$(sudo docker ps --filter "name=docker_external_client_1*" --format "{{.Names}}")"
        fi
    ;;
    k8s)
        if [ -n "${PKG_MGR:-}" ] && [ "${PKG_MGR:-}" == "helm" ]; then
            make helm-deploy
            if [[ "${DEBUG:-true}" == "true" ]]; then
                kubectl get all -o wide
                make helm-logs
            fi
            make helm-deploy-demo
            if [[ "${DEBUG:-true}" == "true" ]]; then
                kubectl logs external-client -c external-client
            fi
        else
            make k8s-deploy
            if [[ "${DEBUG:-true}" == "true" ]]; then
                kubectl get all -o wide
                make k8s-logs
            fi
            make k8s-deploy-demo
            if [[ "${DEBUG:-true}" == "true" ]]; then
                kubectl logs external-client -c external-client
            fi
        fi
    ;;
esac
