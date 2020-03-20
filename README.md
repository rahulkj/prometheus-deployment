Prometheus Operator to Monitor PKS k8s cluster
---

### Pre-requisties:

* Copy the `.envrc.example` and create a `.envrc` file.
* Fill in the values for:
  ```
  OM_KEY=/Users/user/Documents/secrets/om.key  # Path to the ops manager ssh key
  OM_ENV=/Users/user/Documents/secrets/env.yml # Path to the ops manager env.yml, that has the target,
                                                 username, password and skip-ssl-validation params.
  NAMESPACE=monitoring # Namespace to add/upgrade the prometheus-operator
  CLUSTER_NAME=cluster-01 # kubernetes cluster name to deploy prometheus operator on
  PKS_API_ENDPOINT=api.TLD # PKS API endpoint
  PKS_API_ADMIN_USERNAME=admin # PKS admin username
  USE_ISTIO=true # Use istio ingress gateway or not (true|false)
  ```

  Sample `env.yml`

  ```
  target: opsmgr.example.io
  username: admin
  password: admin
  skip-ssl-validation: true
  ```

**NOTE: If using istio, then install the [istiocli](https://istio.io/docs/setup/getting-started/#download), and set the `PATH` variable in your shell profile.**

* Have internet access to pull down the helm charts

### Deploying Prometheus Operator

To setup prometheus operator, first execute `direnv allow .`

Once the variables are sources, then execute `./setup-prometheus.sh`

You should see the output similar to the one below:
```
❯❯❯ ./setup-prometheus.sh                                                    master ✱ ◼
"stable" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "istio.io" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈ Happy Helming!⎈

API Endpoint: https://api.pks.example.io
User: admin
Login successful.


Fetching credentials for cluster cluster-01.
Password: ********************************Context set for cluster cluster-01.

You can now switch between clusters by using:
$kubectl config use-context <cluster-name>
monitoring exists
secret "etcd-client" deleted
secret/etcd-client created
Detected that your cluster does not support third party JWT authentication. Falling back to less secure first party JWT. See https://istio.io/docs/ops/best-practices/security/#configure-third-party-service-account-tokens for details.
- Applying manifest for component Base...
✔ Finished applying manifest for component Base.
- Applying manifest for component Pilot...
✔ Finished applying manifest for component Pilot.
- Applying manifest for component AddonComponents...
- Applying manifest for component IngressGateways...
✔ Finished applying manifest for component IngressGateways.
✔ Finished applying manifest for component AddonComponents.


✔ Installation complete

gateway.networking.istio.io/monitoring-grafana-gateway unchanged
gateway.networking.istio.io/monitoring-prometheus-gateway unchanged
virtualservice.networking.istio.io/monitoring unchanged
virtualservice.networking.istio.io/monitoring-prometheus unchanged
Release "prometheus-operator" does not exist. Installing it now.
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
NAME: prometheus-operator
LAST DEPLOYED: Thu Mar 19 21:14:56 2020
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Prometheus Operator has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=prometheus-operator"

Visit https://github.com/coreos/prometheus-operator for instructions on how
to create & configure Alertmanager and Prometheus instances using the Operator.
```

* Once deployed, you can connect to the prometheus and grafana endpoints

  - Without Istio:

    ```
    GRAFANA_URL=http://$(kubectl --namespace $NAMESPACE get svc \
      | grep prometheus-operator-grafana \
      | grep LoadBalancer \
      | awk '{print $4}'):80

    echo ${GRAFANA_URL}

    PROMETHEUS_URL=http://$(kubectl --namespace $NAMESPACE get svc \
      | grep prometheus-operator-prometheus \
      | grep LoadBalancer \
      | awk '{print $4}'):9090

    echo ${PROMETHEUS_URL}
    ```

  - With istio:

    ```
    GRAFANA_URL=http://$(kubectl get svc istio-ingressgateway -n istio-system \
      | grep LoadBalancer \
      | awk '{print $4}'):80

    echo ${GRAFANA_URL}

    PROMETHEUS_URL=http://$(kubectl get svc istio-ingressgateway -n istio-system \
      | grep LoadBalancer \
      | awk '{print $4}'):9090

    echo ${PROMETHEUS_URL}
    ```

### Uninstall Prometheus Operator

To uninstall, execute `direnv allow .` and then `./uninstall.sh`
