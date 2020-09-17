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
    export PKG_DEBUG=true
fi

function get_cpu_arch {
    if [ -z "${PKG_CPU_ARCH:-}" ]; then
        case "$(uname -m)" in
            x86_64)
                PKG_CPU_ARCH=amd64
            ;;
            armv8*)
                PKG_CPU_ARCH=arm64
            ;;
            aarch64*)
                PKG_CPU_ARCH=arm64
            ;;
            armv*)
                PKG_CPU_ARCH=armv7
            ;;
        esac
    fi
    echo "$PKG_CPU_ARCH"
}

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
        sudo docker swarm init --advertise-addr "${HOST_IP:-$(ip route get 8.8.8.8 | grep "^8." | awk '{ print $7 }')}"
        if [ "${ENABLE_SKYDIVE:-false}" == "true" ]; then
            sudo docker-compose --file docker/skydive/docker-compose.yml up --detach
        fi
        if [ "${ENABLE_PORTAINER:-false}" == "true" ]; then
            curl -L https://downloads.portainer.io/portainer-agent-stack.yml -o portainer-agent-stack.yml
            sudo docker stack deploy --compose-file=portainer-agent-stack.yml portainer
        fi
        make docker-pull
    ;;
    k8s)
        install_deps kind kubectl jq helm

        # Download CNI plugins
        if [ ! -d /opt/containernetworking/plugins ]; then
            pushd "$(mktemp -d)"
            cni_plugin_version=$(curl -s https://api.github.com/repos/containernetworking/plugins/releases/latest | grep -Po '"tag_name":.*?[^\\]",' | awk -F  "\"" 'NR==1{print $4}')
            curl -Lo cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${cni_plugin_version}/cni-plugins-$(uname | awk '{print tolower($0)}')-$(get_cpu_arch)-${cni_plugin_version}.tgz" > /dev/null
            sudo mkdir -p /opt/containernetworking/plugins
            sudo chown "$USER" -R /opt/containernetworking/plugins
            tar xf cni-plugins.tgz -C /opt/containernetworking/plugins
            popd
        fi

        # Deploy Kubernetes Cluster
        if ! sudo "$(command -v kind)" get clusters | grep -e k8s; then
            newgrp docker <<EONG
            kind create cluster --name k8s --config=./k8s/kind-config.yml --wait=300s
            docker pull quay.io/coreos/flannel:v0.12.0-amd64
            kind load docker-image quay.io/coreos/flannel:v0.12.0-amd64 --name k8s
EONG
            # Create K8s Pod network
            kubectl apply -f ./k8s/overlay/pod_subnet.yml
        fi
        for node in $(kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}'); do
            kubectl wait --for=condition=ready "node/$node" --timeout=3m
        done
        if [ "${ENABLE_SKYDIVE:-false}" == "true" ]; then
            kubectl apply -f k8s/skydive.yml
        fi

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
        make k8s-pull
    ;;
esac
