#!/bin/bash -e

helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update

om_target=$(om interpolate --config ${OM_ENV} --path /target)

export BOSH_ALL_PROXY=ssh+socks5://ubuntu@${om_target}:22?private-key=${OM_KEY}
export CREDHUB_PROXY=${BOSH_ALL_PROXY}

eval "$(om -e ${OM_ENV} bosh-env)"

pks_api_password=$(om -e ${OM_ENV} credentials -p pivotal-container-service -c ".properties.uaa_admin_password" -t json | jq -r '.secret')

pks login -a https://${PKS_API_ENDPOINT} -u ${PKS_API_ADMIN_USERNAME} -k -p ${pks_api_password}

cluster_uuid=$(pks cluster ${CLUSTER_NAME} --json | jq -r '.uuid')

deployment_name=service-instance_${cluster_uuid}

credhub get -n "/p-bosh/${deployment_name}/tls-etcdctl-2018-2" -k ca > etcd-client-ca.crt
credhub get -n "/p-bosh/${deployment_name}/tls-etcdctl-2018-2" -k certificate > etcd-client.crt
credhub get -n "/p-bosh/${deployment_name}/tls-etcdctl-2018-2" -k private_key > etcd-client.key

echo "${pks_api_password}" | pks get-credentials ${CLUSTER_NAME}

set +e
ns=$(kubectl get ns | grep "${NAMESPACE}")
if [ -z "$ns" ]; then
  echo "Create ${NAMESPACE}"
  kubectl create ns "${NAMESPACE}"
else
  echo "${NAMESPACE} exists"
fi
set -e

# Create secrets for etcd client cert
kubectl delete secret -n "${NAMESPACE}" etcd-client --ignore-not-found
kubectl create secret -n "${NAMESPACE}" generic etcd-client \
  --from-file=etcd-client-ca.crt \
  --from-file=etcd-client.crt \
  --from-file=etcd-client.key

master_ips=$(bosh -d "${deployment_name}" vms --column=Instance --column=IPs | grep master | awk '{print $2}' | sort)
master_node_ips="$(echo ${master_ips[*]})"
export VARS_endpoints="[${master_node_ips// /, }]"

# Replace config variables in config.yaml
om interpolate \
    --config "values.yaml" \
    --vars-env VARS \
    > vars.yml

service_type="LoadBalancer"
if [[ "$USE_ISTIO" == "true" ]]; then
  SERVICE_TYPE="ClusterIP"
  istioctl manifest apply --set profile=default --skip-confirmation
  kubectl apply -f istio.yaml --overwrite=true

  set +e
  prometheus_port_exists=$(kubectl get svc istio-ingressgateway -n istio-system -o yaml | grep 9090)
  if [ -z "$prometheus_port_exists" ]; then
    kubectl patch svc istio-ingressgateway -n istio-system --patch "$(cat ingress-gateway-patch.yaml)"
  fi
  set -e
fi

helm upgrade -i "${RELEASE}" \
  --namespace "${NAMESPACE}" \
  --set grafana.service.type=${service_type} \
  --set prometheus.service.type=${service_type} \
  --set grafana.adminPassword=admin \
  --set global.rbac.pspEnabled=false \
  --set grafana.testFramework.enabled=false \
  --set alertmanager.enabled=false \
  --set kubeTargetVersionOverride="$(kubectl version --short | grep -i server | awk '{print $3}' |  cut -c2-1000)" \
  --values vars.yml \
  stable/prometheus-operator

rm -rf etcd-client-ca.crt etcd-client.crt etcd-client.key vars.yml
