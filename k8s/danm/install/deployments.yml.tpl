---
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  name: danm-webhook-config
  namespace: kube-system
webhooks:
  - name: danm-netvalidation.nokia.k8s.io
    clientConfig:
      service:
        name: danm-webhook-svc
        namespace: kube-system
        path: "/netvalidation"
      # Configure your pre-generated certificate matching the details of your environment
      caBundle: ${CA_BUNDLE}
    rules:
      # UPDATE IS TEMPORARILY REMOVED DUE TO:https://github.com/nokia/danm/issues/144
      - operations: ["CREATE"]
        apiGroups: ["danm.k8s.io"]
        apiVersions: ["v1"]
        resources: ["danmnets", "clusternetworks", "tenantnetworks"]
    failurePolicy: Fail
  - name: danm-configvalidation.nokia.k8s.io
    clientConfig:
      service:
        name: danm-webhook-svc
        namespace: kube-system
        path: "/confvalidation"
      # Configure your pre-generated certificate matching the details of your environment
      caBundle: ${CA_BUNDLE}
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["danm.k8s.io"]
        apiVersions: ["v1"]
        resources: ["tenantconfigs"]
    failurePolicy: Fail
  - name: danm-netdeletion.nokia.k8s.io
    clientConfig:
      service:
        name: danm-webhook-svc
        namespace: kube-system
        path: "/netdeletion"
      # Configure your pre-generated certificate matching the details of your environment
      caBundle: ${CA_BUNDLE}
    rules:
      - operations: ["DELETE"]
        apiGroups: ["danm.k8s.io"]
        apiVersions: ["v1"]
        resources: ["danmnets", "clusternetworks", "tenantnetworks"]
    failurePolicy: Fail
---
apiVersion: v1
kind: Service
metadata:
  name: danm-webhook-svc
  namespace: kube-system
  labels:
    danm: webhook
spec:
  ports:
    - name: webhook
      port: 443
      targetPort: 8443
  selector:
    danm: webhook
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: danm-webhook-deployment
  namespace: kube-system
  labels:
    danm: webhook
spec:
  selector:
    matchLabels:
      danm: webhook
  template:
    metadata:
      annotations:
        # Adapt to your own network environment!
        danm.k8s.io/interfaces: |
          [
            {
              "network":"mgmt-net"
            }
          ]
      name: danm-webhook
      labels:
        danm: webhook
    spec:
      serviceAccountName: danm-webhook
      containers:
        - name: danm-webhook
          image: webhook
          command: ["/usr/local/bin/webhook", "-tls-cert-bundle=/etc/webhook/certs/cert.pem", "-tls-private-key-file=/etc/webhook/certs/key.pem", "bind-port=8443"]
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - name: webhook-certs
              mountPath: /etc/webhook/certs
              readOnly: true
      # Configure the directory holding the Webhook's server certificates
      volumes:
        - name: webhook-certs
          secret:
            secretName: danm-webhook-certs
