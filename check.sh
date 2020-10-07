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

function info {
    _print_msg "INFO" "$1"
}

function error {
    _print_msg "ERROR" "$1"
    exit 1
}

function _print_msg {
    echo "$(date +%H:%M:%S) - $1: $2"
}

function assert_non_empty {
    local input=$1

    if [ -z "$input" ]; then
        error "Empty input value"
    fi
}

function assert_equals {
    local input=$1
    local expected=$2

    if [ "$input" != "$expected" ]; then
        error "Go $input expeted $expected"
    fi
}

case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        info "Running Docker assertions"
        assert_non_empty "$(sudo docker logs "$(sudo docker ps --filter "name=docker_external_client_1*" --format "{{.Names}}")")"
        assert_equals "$(sudo docker logs "$(sudo docker ps --filter "name=docker_external_client_1*" --format "{{.Names}}")" | awk 'END{print}')" "It works!"
    ;;
    k8s)
        info "Running Kubernetes assertions"
        assert_non_empty "$(kubectl logs external-client -c external-client)"
        assert_equals "$(kubectl logs external-client -c external-client | awk 'END{print}')" "It works!"
    ;;
esac
