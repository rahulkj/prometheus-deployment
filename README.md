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
```

  Sample `env.yml`

  ```
  target: opsmgr.example.io
  username: admin
  password: admin
  skip-ssl-validation: true
  ```
* Have internet access to pull down the helm charts

### Deploying Prometheus Operator

To setup prometheus operator, first execute `direnv allow .`

Once the variables are sources, then execute `./setup-prometheus.sh`

You should see the output similar to the one below:
```
❯❯❯ ./setup-prometheus.sh

"stable" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈ Happy Helming!⎈

API Endpoint: https://api.pks.example.io
User: admin
Login successful.


Fetching credentials for cluster cluster-01.
Password: ********************************Context set for cluster cluster-01.

You can now switch between clusters by using:
$kubectl config use-context <cluster-name>
secret/etcd-client created
Release "prometheus-operator" does not exist. Installing it now.
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
NAME: prometheus-operator
LAST DEPLOYED: Wed Mar 18 15:03:25 2020
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

### Uninstall Prometheus Operator

To uninstall, execute `direnv allow .` and then `./uninstall.sh`
