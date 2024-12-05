## Overview
In this lab you will learn how to deploy Anchore Enterprise into an environment of your choice. 
A stand-alone deployment requires at least 8GB of RAM and 40GB of Storage. For a smoother experience, we recommended 16 GB of RAM and 100 GB of storage.
It may take a few minutes for Anchore Enterprise to spin up and for all services to be operational.

_**The deployment in this tutorial is not production ready, and will receive limited support from Anchore, but don't let that stop you from learning!**_

## Deploy Anchore Enterprise

1. Download all the files in the labs `Deployment` directory.
2. Retrieve a license file and set of Anchore Dockerhub login credentials.
   1. To obtain these, please fill out this [form](https://forms.gle/NMhpVU19SuXRnLhC9).
3. Choose your deployment target from a choice of three:
   1. [Docker Compose](#docker-compose)
   2. [Kubernetes](#kubernetes)
   3. [AWS Anchore Free Trial](#aws-anchore-free-trial)

### Docker Compose

#### Requirements
- Docker v1.12 or higher
  - Tested to work on Windows WSL 2
- Docker Compose that supports at least v2 of the docker-compose configuration format.

#### Setup

Login to DockerHub with access credentials for the Anchore Enterprise images.
```bash
docker login --username <your-docker-username> # followed by <your-docker-password>
```
Run docker compose and spin up Anchore Enterprise
```bash
docker compose -f anchore-compose.yaml up -d
```
Now point your browser at the Anchore Enterprise UI by directing it to http://localhost:3000/ and use admin credentials:
- username: `admin`
- password: `anchore12345`

### Kubernetes

#### Requirements
- [Helm](https://helm.sh/) >=3.8
- [Kubernetes](https://kubernetes.io/) >=1.23
- [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed and configured to a cluster

#### Setup

Store your License, DockerHub and Anchore Credentials as Kubernetes Secrets which is then, used by your Anchore Deployment.
```bash
kubectl create namespace anchore
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

Run Helm and spin up Anchore Enterprise
```bash
helm repo add anchore https://charts.anchore.io
helm install -n anchore anchore anchore/enterprise -f values.yaml --version 3.2.0 # 5.12.0
```

The Anchore UI can be accessed via http://localhost:8080 with kubernetes port-forwarding:
```bash
kubectl port-forward svc/anchore-enterprise-ui -n anchore 8080:80
```
The Anchore API can be accessed via localhost:8228 with kubernetes port-forwarding:
```bash
kubectl port-forward svc/anchore-enterprise-api -n anchore 8228:8228
```

Now point your browser at the Anchore Enterprise UI by directing it to http://localhost:8080/ and use admin credentials:
- username: `admin`
- password: `anchore12345`

### AWS Anchore Free Trial

#### Requirements
- An AWS account with the ability to launch an AMI/CF instance in us-west-1, us-east-1, or us-east-2.
  - Running the Anchore trail will incur AWS Compute and other infrastructure costs.
- Fill out this form [Anchore Free Trial](https://get.anchore.com/free-trial/)

#### Setup

1. Follow the [installation instructions](https://sites.google.com/anchore.com/anchore-enterprise-trial) included in the free trial email.
2. Review [launching the trial](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.ddctetfymxlt) and [accessing the trial](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.ddctetfymxlt) on how to access the Anchore Enterprise UI and login.

## Install AnchoreCTL

AnchoreCTL is used tool that can be used to interact with Anchore Enterprise for all types of use cases and will be used throughout the labs.
If you have chosen the AWS Anchore Free Trial route, the AnchoreCTL has [already been installed and configured](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.g74u7lejv5m1) for you. Otherwise, please continue with the following steps:

Download and install the AnchoreCTL
```bash
curl -sSfL  https://anchorectl-releases.anchore.io/anchorectl/install.sh  | sh -s -- -b /usr/local/bin v5.12.0
```

Create the AnchoreCTL environment variables
```bash
export ANCHORECTL_URL="http://localhost:8228"
export ANCHORECTL_USERNAME="admin"
export ANCHORECTL_PASSWORD="anchore12345" 
```
_You can permanently install and configure `anchorectl` removing the need for setting environment variables, see [Installing AnchoreCTL](https://docs.anchore.com/current/docs/deployment/anchorectl/)._

Test your AnchoreCTL and Anchore Enterprise deployment
```bash
anchorectl system status
```
```bash
# Your output should look something like the following with 'PASS' for all rows:
 ✔ Status system                                                                                                                                                                                                                                  
┌────────────────┬───────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────┬──────┬────────────────┬────────────┬──────────────┐
│ SERVICE        │ HOST ID                                           │ URL                                                                    │ UP   │ STATUS MESSAGE │ DB VERSION │ CODE VERSION │
├────────────────┼───────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────┼──────┼────────────────┼────────────┼──────────────┤
│ analyzer       │ anchore-enterprise-analyzer-5577b69bb7-bpvnw      │ http://anchore-enterprise-analyzer.anchore.svc.cluster.local:8084      │ true │ available      │ 5120       │ 5.12.0       │
│ notifications  │ anchore-enterprise-notifications-55c66f7c88-82k4t │ http://anchore-enterprise-notifications.anchore.svc.cluster.local:8668 │ true │ available      │ 5120       │ 5.12.0       │
│ simplequeue    │ anchore-enterprise-simplequeue-5c5b46466c-xq6kq   │ http://anchore-enterprise-simplequeue.anchore.svc.cluster.local:8083   │ true │ available      │ 5120       │ 5.12.0       │
│ reports_worker │ anchore-enterprise-reportsworker-6fb4f55455-gggtf │ http://anchore-enterprise-reportsworker.anchore.svc.cluster.local:8559 │ true │ available      │ 5120       │ 5.12.0       │
│ apiext         │ anchore-enterprise-api-5ccff5fdd-gcwkh            │ http://anchore-enterprise-api.anchore.svc.cluster.local:8228           │ true │ available      │ 5120       │ 5.12.0       │
│ policy_engine  │ anchore-enterprise-policy-8d4bb4c45-7lc9r         │ http://anchore-enterprise-policy.anchore.svc.cluster.local:8087        │ true │ available      │ 5120       │ 5.12.0       │
│ catalog        │ anchore-enterprise-catalog-86c6978bbf-89hg7       │ http://anchore-enterprise-catalog.anchore.svc.cluster.local:8082       │ true │ available      │ 5120       │ 5.12.0       │
│ data_syncer    │ anchore-enterprise-datasyncer-64f7f7fcb9-m5tkf    │ http://anchore-enterprise-datasyncer.anchore.svc.cluster.local:8778    │ true │ available      │ 5120       │ 5.12.0       │
│ reports        │ anchore-enterprise-reports-7b6497fffc-msd7x       │ http://anchore-enterprise-reports.anchore.svc.cluster.local:8558       │ true │ available      │ 5120       │ 5.12.0       │
└────────────────┴───────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────┴──────┴────────────────┴────────────┴──────────────┘
```

## Cleanup

Please continue testing Anchore Enterprise, you can easily add your own source, images and test other integrations (such as CI/CD, SSO and more).
More information and examples can be found in the docs pages - https://docs.anchore.com/current/docs/.

If you need to spin down resources, please review the relevant steps below.

**AnchoreCTL**
```bash
sudo rm /usr/local/bin/anchorectl
```
**Compose**
```bash
docker compose -f anchore-compose.yaml down
```
**Kubernetes**
```bash
helm uninstall anchore
```
**AWS Free Trial**
```bash
Please follow the instructions you have received via email.
```