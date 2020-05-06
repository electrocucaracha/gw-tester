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

pushd flannel/
kubectl apply -f etcd.yml
kubectl scale deployment flannel-etcd -n kube-system --replicas=1
kubectl rollout status deployment/flannel-etcd -n kube-system --timeout=5m
kubectl apply -f ./overlay/
popd
