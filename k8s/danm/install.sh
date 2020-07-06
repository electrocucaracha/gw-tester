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

danm_version="v4.2.0"

if [ ! -d /opt/danm ]; then
    sudo git clone --depth 1 https://github.com/nokia/danm -b "$danm_version" /opt/danm
    sudo chown -R "$USER" /opt/danm
fi

pushd /opt/danm
if [ "$(sudo docker images | grep -c "$danm_version")" != "5" ]; then
    newgrp docker <<EONG
    ./build_danm.sh
    docker image prune --force
    for img in danm-cni-plugins webhook svcwatcher netwatcher damn-installer; do
        docker tag "\$img:latest" "\$img:$danm_version"
    done
EONG
fi
echo "Create Webhook certificate"
./integration/manifests/webhook/webhook-create-signed-cert.sh
popd

for img in danm-cni-plugins webhook svcwatcher netwatcher damn-installer; do
    newgrp docker <<EONG
    kind load docker-image "$img:$danm_version" --name k8s
EONG
done

cp ~/.kube/config /tmp/kubeconfig
sed -i "s|server: .*|server: https://$(kubectl get all -o jsonpath='{.items[0].spec.clusterIP}'):443|g" /tmp/kubeconfig
for id in $(sudo docker ps -q --filter "ancestor=$(sudo docker images --filter=reference='kindest/node*' -q)"); do
    sudo docker cp 00-danm.conf "${id}:/etc/cni/net.d/"
    sudo docker exec "${id}" mkdir -p /etc/cni/net.d/danm.d/
    sudo docker cp /tmp/kubeconfig "${id}:/etc/cni/net.d/danm.d/kubeconfig"
done

rm -f ./install/deployments.yml 2> /dev/null
CA_BUNDLE=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
export CA_BUNDLE
envsubst <./install/deployments.yml.tpl > ./install/deployments.yml

# Deploy DANM CNI daemonsets and CRDs
for file in rbac crds mgmt_net; do
    kubectl apply -f "install/$file.yml"
    sleep 1
done

echo "Deploy DANM daemonsets"
cat <<EOF >./kustomization.yml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
images:
  - name: danm-cni-plugins
    newTag: $danm_version
  - name: webhook
    newTag: $danm_version
  - name: svcwatcher
    newTag: $danm_version
  - name: netwatcher
    newTag: $danm_version
resources:
  - install/daemonsets.yml
  - install/deployments.yml
EOF
kubectl apply -k ./

kubectl rollout status deployment/danm-webhook-deployment -n kube-system
# Create ClusterNetwork resources
kubectl apply -f "overlay_${PLUGIN_CNI:-flannel}.yml"
