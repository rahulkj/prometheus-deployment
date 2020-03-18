#!/bin/bash -e

helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update

OM_TARGET=$(om interpolate --config ${OM_ENV} --path /target)

export BOSH_ALL_PROXY=ssh+socks5://ubuntu@${OM_TARGET}:22?private-key=${OM_KEY}
export CREDHUB_PROXY=${BOSH_ALL_PROXY}

eval "$(om -e ${OM_ENV} bosh-env)"

PKS_API_PASSWORD=$(om -e ${OM_ENV} credentials -p pivotal-container-service -c ".properties.uaa_admin_password" -t json | jq -r '.secret')

pks login -a https://${PKS_API_ENDPOINT} -u ${PKS_API_ADMIN_USERNAME} -k -p ${PKS_API_PASSWORD}

CLUSTER_UUID=$(pks cluster ${CLUSTER_NAME} --json | jq -r '.uuid')

DEPLOYMENT_NAME=service-instance_${CLUSTER_UUID}

credhub get -n "/p-bosh/${DEPLOYMENT_NAME}/tls-etcdctl-2018-2" -k ca > etcd-client-ca.crt
credhub get -n "/p-bosh/${DEPLOYMENT_NAME}/tls-etcdctl-2018-2" -k certificate > etcd-client.crt
credhub get -n "/p-bosh/${DEPLOYMENT_NAME}/tls-etcdctl-2018-2" -k private_key > etcd-client.key

echo "${PKS_API_PASSWORD}" | pks get-credentials ${CLUSTER_NAME}

# Create secrets for etcd client cert
kubectl delete secret -n "${NAMESPACE}" etcd-client --ignore-not-found
kubectl create secret -n "${NAMESPACE}" generic etcd-client \
  --from-file=etcd-client-ca.crt \
  --from-file=etcd-client.crt \
  --from-file=etcd-client.key

master_ips=$(bosh -d "${DEPLOYMENT_NAME}" vms --column=Instance --column=IPs | grep master | awk '{print $2}' | sort)
master_node_ips="$(echo ${master_ips[*]})"
export VARS_endpoints="[${master_node_ips// /, }]"

# Replace config variables in config.yaml
om interpolate \
    --config "values.yaml" \
    --vars-env VARS \
    > vars.yml

helm upgrade -i prometheus-operator \
  --namespace "${NAMESPACE}" \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.adminPassword=admin \
  --set global.rbac.pspEnabled=false \
  --set grafana.testFramework.enabled=false \
  --set alertmanager.enabled=false \
  --set kubeTargetVersionOverride="$(kubectl version --short | grep -i server | awk '{print $3}' |  cut -c2-1000)" \
  --values vars.yml \
  stable/prometheus-operator

rm -rf etcd-client-ca.crt etcd-client.crt etcd-client.key vars.yml
