#!/usr/bin/env bash

namespace="${1:-"monitoring"}"
release="${2:-prometheus-operator}"

helm uninstall "${release}" -n ${namespace}

kubectl delete secret -n "${namespace}" etcd-client --ignore-not-found
