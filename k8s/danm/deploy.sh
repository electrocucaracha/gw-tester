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

danm_version="v4.2.0-rc3"

pkgs=""
for pkg in jq openssl; do
    if ! command -v "$pkg"; then
        pkgs+=" $pkg"
    fi
done
if [ -n "$pkgs" ]; then
    curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
fi

cp k8s/danm/00-danm.conf /tmp
cp k8s/danm/cni_plugins_ds.patch /tmp
if [ ! -d /opt/danm ]; then
    sudo git clone --depth 1 https://github.com/nokia/danm -b "$danm_version" /opt/danm
    sudo chown -R "$USER" /opt/danm
    pushd /opt/danm
    git apply /tmp/cni_plugins_ds.patch
    popd
fi

pushd /opt/danm
newgrp docker <<EONG
./build_danm.sh
docker image prune --force
EONG
for img in danm-cni-plugins webhook svcwatcher netwatcher; do
    sudo docker tag "$img:latest" "$img:$danm_version"
    newgrp docker <<EONG
    kind load docker-image "$img:$danm_version" --name k8s
EONG
done
echo "Create DANM CRDs"
kubectl apply -f integration/crds/production
kubectl apply -f integration/crds/lightweight
kubectl apply -f integration/bootstrap_networks/lightweight/flannel.yaml
kubectl apply -f example/4_0_examples/7_default_cnet.yaml

echo "Create Webhook certificate"
./integration/manifests/webhook/webhook-create-signed-cert.sh
CA_BUNDLE=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster."certificate-authority-data"' | tr -d '"')
export CA_BUNDLE
envsubst <./integration/manifests/webhook/webhook.yaml > integration/manifests/webhook/webhook_deploy.yaml

echo "Deploy DANM daemonsets"
cat <<EOF >kustomization.yaml
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
- integration/manifests/cni_plugins/cni_plugins_ds.yml
- integration/manifests/netwatcher/netwatcher_ds.yaml
- integration/manifests/svcwatcher/svcwatcher_ds.yaml
- integration/manifests/webhook/webhook_deploy.yaml
EOF
kubectl apply -k .

cp ~/.kube/config /tmp/kubeconfig
sed -i "s|server: .*|server: https://$(kubectl get all -o json | jq -r .items[0].spec.clusterIP):443|g" /tmp/kubeconfig
for id in $(sudo docker ps -q --filter "ancestor=$(sudo docker images --filter=reference='kindest/node*' -q)"); do
    sudo docker cp /tmp/00-danm.conf "${id}:/etc/cni/net.d/"
    sudo docker exec "${id}" mkdir -p /etc/cni/net.d/danm.d/
    sudo docker exec "${id}" cp /etc/cni/net.d/10-flannel.conflist /etc/cni/net.d/flannel.conf
    sudo docker cp /tmp/kubeconfig "${id}:/etc/cni/net.d/danm.d/kubeconfig"
done
echo "Create Service accounts"
kubectl create --namespace kube-system serviceaccount danm
kubectl apply -f integration/cni_config/danm_rbac.yaml
kubectl apply -f integration/manifests/netwatcher/0netwatcher_rbac.yaml
kubectl apply -f integration/manifests/svcwatcher/0svcwatcher_rbac.yaml
popd

kubectl apply -f k8s/danm/

# TODO: Investigate the proper way to get User token
exit
SECRET_NAME=$(kubectl get --namespace kube-system -o jsonpath='{.secrets[0].name}' serviceaccounts danm)
cat <<EOF >/tmp/kubeconfig.yml
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://$(kubectl get all -o json | jq -r .items[0].spec.clusterIP):443
    certificate-authority-data: $(kubectl config view --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
users:
- name: danm
  user:
    token: $(kubectl get --namespace kube-system secrets "${SECRET_NAME}" -o jsonpath='{.data.token}')
contexts:
- name: danm-context
  context:
    cluster: local
    user: danm
current-context: danm-context
EOF
