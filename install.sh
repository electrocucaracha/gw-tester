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

cni_plugin_version="v0.8.6"

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

echo "Running installation process..."
case ${DEPLOYMENT_TYPE:-docker} in
    docker)
        install_deps docker-compose
        sudo docker network create --subnet 10.244.0.0/16 --opt com.docker.network.bridge.name=docker_gwbridge docker_gwbridge
        sudo docker swarm init --advertise-addr "${HOST_IP:-10.10.17.4}"
        if [ "${ENABLE_SKYDIVE:-false}" == "true" ]; then
            sudo docker-compose --file docker/skydive/docker-compose.yml up --detach
        fi
        make pull
    ;;
    k8s)
        install_deps kind kubectl jq helm

        # Download CNI plugins
        if [ ! -d /tmp/cni_plugins ]; then
            pushd "$(mktemp -d)"
            curl -Lo cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${cni_plugin_version}/cni-plugins-linux-amd64-${cni_plugin_version}.tgz"
            mkdir -p /tmp/cni_plugins
            tar xvf cni-plugins.tgz -C /tmp/cni_plugins
            popd
        fi

        # Deploy Kubernetes Cluster
        if ! sudo kind get clusters | grep -e k8s; then
            newgrp docker <<EONG
            kind create cluster --name k8s --config=./k8s/kind-config.yml
EONG
            kind_img="$(grep image /vagrant/k8s/kind-config.yml | uniq | awk -F 'image: ' '{print $2}')"
            for id in $(sudo docker ps -q --filter "ancestor=$(sudo docker images --filter=reference="$kind_img" -q)"); do
                for plugin in flannel bridge; do
                    sudo docker cp "/tmp/cni_plugins/$plugin" "$id:/opt/cni/bin/$plugin"
                done
            done
        fi
        for node in $(kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}'); do
            kubectl wait --for=condition=ready "node/$node"
        done

        # Create Multiple Networks
        kubectl label nodes k8s-worker flannel-etcd=true --overwrite
        pushd k8s/overlay
        ./install.sh
        popd

        # Deploy Multiplexer CNI services
        pushd ./k8s/"${MULTI_CNI:-multus}"/
        ./install.sh
        popd

        for daemonset in $(kubectl get daemonset -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}'); do
            kubectl rollout status "daemonset/$daemonset" -n kube-system
        done
    ;;
esac
