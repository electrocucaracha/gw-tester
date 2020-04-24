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

case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        sudo docker swarm init --advertise-addr "${HOST_IP:-10.10.17.4}"
        make build
        make deploy
    ;;
    k8s)
        curl -fsSL http://bit.ly/install_pkg | PKG="kind kubectl" bash
        make build
        newgrp docker <<EONG
        kind create cluster --name k8s --config=./k8s/kind-config.yaml
EONG
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.12.0/Documentation/kube-flannel.yml
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
