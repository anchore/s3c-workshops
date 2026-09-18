# Kubernetes

## Requirements
- [Helm](https://helm.sh/) >=3.8
- [Docker](https://docs.docker.com/engine/install/) >=29.0
- [Kubernetes](https://kubernetes.io/) 1.23 - 1.37 
- [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) >=1.35
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager) (recommended)

## Setup

Create a Kubernetes Cluster to deploy Anchore Enterprise. This example uses [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager), but feel free to use your own.

```bash
cd ./labs/Deployment/k8s
kind create cluster --config kind-config.yaml
```

Ensure kubectl is installed and pointing to your cluster.
```bash
kubectl cluster-info --context kind-anchore
```

Your cluster info should look something like this. Port number will likely differ. 
```
Kubernetes control plane is running at https://127.0.0.1:46087
CoreDNS is running at https://127.0.0.1:46087/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Create a namespace where Anchore Enterprise will be deployed.
```bash
kubectl create namespace anchore
kubectl config set-context --current --namespace=anchore
```

Place your *license.yaml* file into this directory (`./labs/Deployment/k8s`).

Store your License, DockerHub and Anchore Credentials as Kubernetes Secrets. These will be used by your Anchore Deployment.  

> [!IMPORTANT]
> Be sure to change _your-docker-username_ and _your-docker-password_ to your supplied credentials.
> The PostgreSQL image used here is private, so these credentials must exist before the database is created.
```bash
kubectl create secret generic anchore-enterprise-license \
--from-file=license.yaml=./license.yaml -n anchore

kubectl create secret docker-registry anchore-enterprise-pullcreds \
--docker-server=docker.io \
--docker-username=your-docker-username \
--docker-password=your-docker-password -n anchore

kubectl create secret generic anchore-enterprise-env \
--from-literal=ANCHORE_DB_HOST=anchore-db-rw --from-literal=ANCHORE_DB_NAME=anchore \
--from-literal=ANCHORE_DB_USER=anchore --from-literal=ANCHORE_DB_PORT=5432 \
--from-literal=ANCHORE_DB_PASSWORD=anchore-postgres,123 --from-literal=ANCHORE_ADMIN_PASSWORD=anchore12345 -n anchore

kubectl create secret generic anchore-enterprise-ui-env \
--from-literal=ANCHORE_APPDB_URI=postgres://anchore:anchore-postgres,123@anchore-db-rw:5432/anchore \
--from-literal=ANCHORE_REDIS_URI=redis://:anchore-redis,123@anchore-ui-redis-master:6379 -n anchore
```

Anchore Enterprise 6 requires PostgreSQL 17 or above with the `pg_cron` extension.
The Helm chart no longer bundles a database, so deploy one with the [CloudNativePG](https://cloudnative-pg.io/) operator.

Install the CNPG operator.
```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace --wait
```

Create the PostgreSQL cluster and wait for it to come up.
```bash
kubectl apply -f cnpg-cluster.yaml
kubectl wait --for=condition=Ready cluster/anchore-db -n anchore --timeout=600s
```

Run Helm install to spin up Anchore Enterprise (6.2.0)
```bash
helm repo add anchore https://charts.anchore.io
helm upgrade --install --namespace anchore anchore anchore/enterprise --version 4.3.1 -f anchore-values.yaml
```

Wait for the deployment to become ready.
```bash
kubectl wait --for=condition=available --timeout=600s deployment --all -n anchore
```

The kind cluster publishes the API and UI on your host, so no port-forwarding is
required and nothing needs to be left running. The API is available at
http://localhost:8228/v2/.

Access the Anchore Enterprise Web UI by visiting http://localhost:3000/ and use the following credentials to login:
- username: `admin`
- password: `anchore12345`

## Pausing the cluster

If you want to stop for the day and pick this up later, you don't need to tear the cluster down and redeploy.  
Stop the Kind node containers — your deployment, database contents and published ports are all preserved.
```bash
docker stop $(kind get nodes --name anchore | tr '\n' ' ')
```

Start them again when you want to carry on, and allow about a minute for every
service to report ready.
```bash
docker start $(kind get nodes --name anchore | tr '\n' ' ')
```

When you are finished with the lab entirely, [cleanup](../cleanup.md) covers tearing everything down.

## Next Step

Now that you have Anchore Enterprise operational, [proceed to the next step](../README.md) of the lab.
