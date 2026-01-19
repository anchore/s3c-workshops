# Kubernetes

## Requirements
- [Helm](https://helm.sh/) >=3.8
- [Kubernetes](https://kubernetes.io/) >=1.23
- [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed and configured to your Anchore Enterprise cluster
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager) (recommended)

## Setup

Create a Kubernetes Cluster to deploy Anchore Enterprise. In this example I use [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager), but feel free to use your own.

```bash
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: anchore
nodes:
- role: control-plane
  image: kindest/node:v1.31.6@sha256:28b7cbb993dfe093c76641a0c95807637213c9109b761f1d422c2400e22b8e87
- role: worker
  image: kindest/node:v1.31.6@sha256:28b7cbb993dfe093c76641a0c95807637213c9109b761f1d422c2400e22b8e87
  extraPortMappings:
    - containerPort: 443
      hostPort: 443
      listenAddress: 127.0.0.1 
      protocol: TCP
EOF
```

Ensure kubectl is installed and pointing to your cluster.
```bash
kubectl cluster-info --context kind-anchore
```
```
Kubernetes control plane is running at https://127.0.0.1:51735
CoreDNS is running at https://127.0.0.1:51735/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Create a K8s namespace, which will be used to deploy Anchore Enterprise.
```bash
kubectl create namespace anchore
```
Store your License, DockerHub and Anchore Credentials as Kubernetes Secrets. These will be used by your Anchore Deployment.
_Be sure to change <your-docker-username> and <your-docker-password> to those you were supplied by the google form._
```bash
cd ./labs/Deployment

kubectl create secret generic anchore-enterprise-license \
--from-file=license.yaml=./license.yaml -n anchore

kubectl create secret docker-registry anchore-enterprise-pullcreds \
--docker-server=docker.io --docker-username=<your-docker-username> --docker-password=<your-docker-password> -n anchore

kubectl create secret generic anchore-enterprise-env \
--from-literal=ANCHORE_DB_HOST=anchore-postgresql --from-literal=ANCHORE_DB_NAME=anchore \
--from-literal=ANCHORE_DB_USER=anchore --from-literal=ANCHORE_DB_PORT=5432 \
--from-literal=ANCHORE_DB_PASSWORD=anchore-postgres,123 --from-literal=ANCHORE_ADMIN_PASSWORD=anchore12345 -n anchore

kubectl create secret generic anchore-enterprise-ui-env \
--from-literal=ANCHORE_APPDB_URI=postgres://anchore:anchore-postgres,123@anchore-postgresql:5432/anchore \
--from-literal=ANCHORE_REDIS_URI=redis://:anchore-redis,123@anchore-ui-redis-master:6379 -n anchore
```

Run Helm install to spin up Anchore Enterprise (5.24.1)
```bash
helm repo add anchore https://charts.anchore.io
helm upgrade --install --namespace anchore anchore anchore/enterprise --version 3.20.3 -f - <<EOF
  useExistingSecrets: true
  existingSecretName: anchore-enterprise-env

  postgresql:
    chartEnabled: true
    externalEndpoint: "anchore-postgresql"
  anchoreConfig:
    policy_engine:
      vulnerabilities:
        matching:
          exclude:
            providers: []
            package_types: []
    analyzer:
      layer_cache_max_gigabytes: 5
      enable_hints: true
      configFile:
        malware:
          clamav:
            enabled: true
            db_update_enabled: true
EOF
```

Run port forwarding to get access to the Anchore Enterprise Web UI.
```bash
kubectl port-forward svc/anchore-enterprise-ui -n anchore 3000:80
```
Run port forwarding to get access to the Anchore Enterprise API.
```bash
kubectl port-forward svc/anchore-enterprise-api -n anchore 8228:8228
```

_Keep these port-forward commands running as you use Anchore Enterprise and AnchoreCTL/APIs_

Access the Anchore Enterprise Web UI by visiting http://localhost:3000/ and use the following credentials to login:
- username: `admin`
- password: `anchore12345`

## Next Step

Now that you have Anchore Enterprise operational, [proceed to the next step](./README.md) of the lab.
