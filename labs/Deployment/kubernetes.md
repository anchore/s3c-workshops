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
  image: kindest/node:v1.29.4@sha256:3abb816a5b1061fb15c6e9e60856ec40d56b7b52bcea5f5f1350bc6e2320b6f8
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  image: kindest/node:v1.29.4@sha256:3abb816a5b1061fb15c6e9e60856ec40d56b7b52bcea5f5f1350bc6e2320b6f8
EOF
```

Ensure kubectl is installed and pointing to your cluster.
```bash
kubectl cluster-info
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
_Be sure to change <your-docker-username> and <your-docker-password> to those you were supplied._
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

Run Helm install to spin up Anchore Enterprise.
```bash
helm repo add anchore https://charts.anchore.io
helm install -n anchore anchore anchore/enterprise -f values.yaml --version 3.2.0 # 5.12.0
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