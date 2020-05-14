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

for pod in pgw sgw mme enb; do
    kubectl delete -f "${pod}.yml" --wait=false --ignore-not-found=true
done
for pod in pgw sgw mme enb; do
    kubectl wait --for=delete "pod/$pod" --timeout=120s || true
done
