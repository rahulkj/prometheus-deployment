#!/bin/bash -ex

OM_KEY=/Users/rjain/Documents/github/rahulkj/secrets/om.key
OM_ENV=/Users/rjain/Documents/github/rahulkj/secrets/env.yml
NAMESPACE=monitoring

CLUSTER_NAME=cluster-01

PKS_API_ENDPOINT=api.pks.homelab.io
PKS_API_ADMIN_USERNAME=admin

export BOSH_ALL_PROXY=ssh+socks5://ubuntu@opsmgr.homelab.io:22?private-key=$OM_KEY
export CREDHUB_PROXY=$BOSH_ALL_PROXY

eval "$(om -e $OM_ENV bosh-env)"

PKS_API_PASSWORD=$(om -e $OM_ENV credentials -p pivotal-container-service -c ".properties.uaa_admin_password" -t json | jq -r '.secret')

pks login -a https://${PKS_API_ENDPOINT} -u ${PKS_API_ADMIN_USERNAME} -k -p ${PKS_API_PASSWORD}

CLUSTER_UUID=$(pks cluster ${CLUSTER_NAME} --json | jq -r '.uuid')
DEPLOYMENT_NAME=service-instance_$CLUSTER_UUID

credhub get -n "/p-bosh/${DEPLOYMENT_NAME}/tls-etcdctl-2018-2" -k ca > etcd-client-ca.crt
credhub get -n "/p-bosh/${DEPLOYMENT_NAME}/tls-etcdctl-2018-2" -k certificate > etcd-client.crt
credhub get -n "/p-bosh/${DEPLOYMENT_NAME}/tls-etcdctl-2018-2" -k private_key > etcd-client.key

# Create secrets for etcd client cert
kubectl delete secret -n "${NAMESPACE}" etcd-client --ignore-not-found
kubectl create secret -n "${NAMESPACE}" generic etcd-client \
  --from-file=etcd-client-ca.crt \
  --from-file=etcd-client.crt \
  --from-file=etcd-client.key

rm -rf etcd-client-ca.crt etcd-client.crt etcd-client.key

helm upgrade -i --version 8.8.0 prometheus-operator \
  --namespace "${NAMESPACE}" \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.adminPassword=admin \
  --set global.rbac.pspEnabled=false \
  --set grafana.testFramework.enabled=false \
  --set alertmanager.enabled=false \
  --set kubeTargetVersionOverride="$(kubectl version --short | grep -i server | awk '{print $3}' |  cut -c2-1000)" \
  --values values.yaml \
  stable/prometheus-operator

# helm upgrade -i --version 8.8.0 prometheus-operator \
#   --namespace "${NAMESPACE}" \
#   --set grafana.enabled=false \
#   --set prometheus.service.type=LoadBalancer \
#   --set global.rbac.pspEnabled=false \
#   --set alertmanager.enabled=false \
#   --set kubeTargetVersionOverride="$(kubectl version --short | grep -i server | awk '{print $3}' |  cut -c2-1000)" \
#   --values values.yaml \
#   stable/prometheus-operator
