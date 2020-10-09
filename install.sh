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

function exit_trap {
    if [[ "${DEBUG:-true}" == "true" ]]; then
        set +o xtrace
    fi
    printf "CPU usage: "
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    printf "Memory free(Kb): "
    awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    if [ "${DEPLOYMENT_TYPE:-docker}" == "docker" ]; then
        sudo docker ps
    else
        echo "Environment variables:"
        echo "MULTI_CNI: $MULTI_CNI"
        echo "PKG_MGR: $PKG_MGR"
        echo "Kubernetes Resources:"
        kubectl get all -A -o wide
    fi
}

trap exit_trap ERR

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
        install_deps kubectl jq helm

        if [ "${DEPLOY_KIND_CLUSTER:-true}" == "true" ]; then
            install_deps kind cni-plugins

            # Deploy Kubernetes Cluster
            if ! sudo "$(command -v kind)" get clusters | grep -e k8s; then
                newgrp docker <<EONG
                kind create cluster --name k8s --config=./k8s/kind-config.yml --wait=300s
                docker pull quay.io/coreos/flannel:v0.12.0-amd64
                kind load docker-image quay.io/coreos/flannel:v0.12.0-amd64 --name k8s
EONG
            fi
            for node in $(kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
                kubectl wait --for=condition=ready "node/$node" --timeout=3m
            done

            # NOTE: DANM does not support chaining together multiple CNI plugin
            if [ "${MULTI_CNI:-multus}" == "danm" ]; then
                newgrp docker << "EONG"
                for container in $(docker ps -q --filter ancestor=kindest/node:v1.18.2); do
                docker cp $container:/etc/cni/net.d/10-kindnet.conflist /tmp/10-kindnet.conflist
                jq '. | { name: .name, cniVersion: .cniVersion, type: .plugins[0].type, ipMasq: .plugins[0].ipMasq, ipam: .plugins[0].ipam }' /tmp/10-kindnet.conflist > /tmp/kindnet.conf
                docker cp /tmp/kindnet.conf $container:/etc/cni/net.d/kindnet.conf
                docker exec $container rm /etc/cni/net.d/10-kindnet.conflist
                done
EONG
            fi

            # Wait for CoreDNS service
            kubectl rollout status deployment/coredns -n kube-system
        fi

        if [ "${ENABLE_SKYDIVE:-false}" == "true" ]; then
            kubectl apply -f k8s/skydive.yml
        fi

        # Create Multiple Networks
        if [ "${MULTI_CNI:-multus}" != "nsm" ]; then
            pushd k8s/overlay
            kubectl apply -f flannel_rbac.yml
            ./install.sh
            popd
        fi

        # Deploy Multiplexer CNI services
        pushd ./k8s/"${MULTI_CNI:-multus}"/
        ./install.sh
        popd

        if [ "${DEPLOY_KIND_CLUSTER:-true}" == "true" ]; then
            make k8s-pull
        fi
        # Wait for CNI services
        for daemonset in $(kubectl get daemonset -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
            kubectl rollout status "daemonset/$daemonset" -n kube-system
        done
    ;;
esac
