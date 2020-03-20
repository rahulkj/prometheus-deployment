#!/usr/bin/env bash

pks_api_password=$(om -e ${OM_ENV} credentials -p pivotal-container-service -c ".properties.uaa_admin_password" -t json | jq -r '.secret')

pks login -a https://${PKS_API_ENDPOINT} -u ${PKS_API_ADMIN_USERNAME} -k -p ${pks_api_password}

echo "${pks_api_password}" | pks get-credentials ${CLUSTER_NAME}

kubectl delete -f istio/istio-gateway-virtual-service.yaml

helm uninstall "${RELEASE}" -n ${NAMESPACE}

kubectl delete secret -n "${NAMESPACE}" etcd-client --ignore-not-found

if [[ "$USE_ISTIO" == "true" ]]; then
  istioctl manifest generate | kubectl delete -f -
fi

kubectl delete ns "${NAMESPACE}"
