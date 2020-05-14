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

echo "Running deployment process..."
case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        make docker-deploy-demo
        make docker-logs
    ;;
    k8s)
        make k8s-deploy
        make k8s-logs
        make k8s-deploy-demo
    ;;
esac
