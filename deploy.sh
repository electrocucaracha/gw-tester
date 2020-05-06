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
set -o xtrace
set -o errexit
set -o nounset

function install_deps {
    pkgs=""
    for pkg in "$@"; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi
}

case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        install_deps docker-compose
        sudo docker swarm init --advertise-addr "${HOST_IP:-10.10.17.4}"
        sudo docker-compose --file docker/skydive/docker-compose.yml up --detach
        make pull
        make deploy
    ;;
    k8s)
        install_deps kind kubectl
        pushd k8s
        newgrp docker <<EONG
        kind create cluster --name k8s --config=./kind-config.yml
EONG
        kubectl apply -f kube-flannel.yml
        popd
        pushd "$(mktemp -d)"
        curl -Lo cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz
        tar xvf cni-plugins.tgz
        for id in $(sudo docker ps -q --filter "ancestor=$(sudo docker images --filter=reference='kindest/node*' -q)"); do
            for plugin in flannel bridge macvlan; do
                sudo docker cp $plugin "$id:/opt/cni/bin/$plugin"
            done
        done
        popd
        ./k8s/"${MULTI_CNI:-multus}"/deploy.sh
    ;;
esac
