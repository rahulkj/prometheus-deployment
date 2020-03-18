#!/usr/bin/env bash

namespace="${1:-"monitoring"}"
release="${2:-prometheus-operator}"

PKS_API_PASSWORD=$(om -e ${OM_ENV} credentials -p pivotal-container-service -c ".properties.uaa_admin_password" -t json | jq -r '.secret')

pks login -a https://${PKS_API_ENDPOINT} -u ${PKS_API_ADMIN_USERNAME} -k -p ${PKS_API_PASSWORD}

echo "${PKS_API_PASSWORD}" | pks get-credentials ${CLUSTER_NAME}

helm uninstall "${release}" -n ${namespace}

kubectl delete secret -n "${namespace}" etcd-client --ignore-not-found
