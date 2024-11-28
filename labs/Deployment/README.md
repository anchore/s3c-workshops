## Overview
In this lab you will learn how to deploy Anchore Enterprise into an environment of your choice.

## Prerequisites

Working installations of Anchorectl and Anchore Enterprise are required to complete the remaining labs in this workshop. 
The following steps, will get both set up and configured Anchore Enterprise deployment

> _The deployment in this tutorial is not production ready, and will receive limited support from Anchore, but don't let that stop you from learning!_

## Clone this Repo

Download the contents of this repository, you will require the files in this README and the `assets` directories. 

If it works better for you, you can follow the labs via docs on GitHub.

## Get Access

You will require an Anchore Enterprise license and set of credentials to pull the images for this demo.

To obtain the required licence and credentials instantly, please fill out this [form](https://forms.gle/NMhpVU19SuXRnLhC9).
 - Download the relevant files for your deployment into the `./assets` folder.

## Deploy Anchore Enterprise

You can spin up an Anchore Enterprise Demo environment in three ways:
  - Docker Compose
  - Kubernetes
  - AWS Anchore Free Trial

Resources
  - A stand-alone deployment to run through the labs requires at least 8GB of RAM and 40GB of Storage. 
  - For smoother experience we recommended 16 GB of RAM and 100 GB of storage to support storage for 100’s of images. 

> [!NOTE]
> It may take a few minutes for Anchore to spin up and for all services to be operational.

### Docker Compose

#### Requirements
- Docker v1.12 or higher
  - Tested to work on Windows WSL 2
- Docker Compose that supports at least v2 of the docker-compose configuration format.

#### Setup

Login to DockerHub with access credentials for the Anchore Enterprise images.
```bash
docker login --username 'username-in-docker-config.json' # password-in-docker-config.json
```
Pull the images from the Registry
```bash
docker pull docker.io/anchore/demo:enterprise-s3c-demo-5.6
```
```bash
docker pull docker.io/anchore/demo:enterprise-ui-s3c-demo-5.6
```
Run docker compose and spin up Anchore Enterprise
```bash
docker compose -f assets/anchore-compose.yaml up -d
```

Point your browser at the Anchore Enterprise UI by directing it to http://localhost:3000/ and use credentials:
- username: `admin`
- password: `foobar`

### Kubernetes

#### Requirements
- [Helm](https://helm.sh/) >=3.8
- [Kubernetes](https://kubernetes.io/) >=1.23
- [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed and configured to a cluster

#### Setup

Ensure the setup script is executable, then run the setup script. Please note this will utilize the current active cluster context.
```bash
cd ./assets
chmod +x setup.sh
./setup.sh
```

The Anchore UI can be accessed via localhost:8080 with kubernetes port-forwarding:
```bash
kubectl port-forward svc/anchore-demo-enterprise-ui -n anchore-demo 8080:80
```
The Anchore API can be accessed via localhost:8228 with kubernetes port-forwarding:
```bash
kubectl port-forward svc/anchore-demo-enterprise-api -n anchore-demo 8228:8228
```
Retrieve the admin password using the following command:
MacOS
```bash
kubectl get secret anchore-demo-enterprise -n anchore-demo -o jsonpath='{.data.ANCHORE_ADMIN_PASSWORD}' | base64 -D
```
Linux
```bash
kubectl get secret anchore-demo-enterprise -n anchore-demo -o jsonpath='{.data.ANCHORE_ADMIN_PASSWORD}' | base64 -d
```

Setup UI port forwarding and point your browser at the Anchore Enterprise UI by directing it to http://localhost:8080/ and use credentials:
- username: `admin`
- password: `kubectl secret output above`

### AWS Anchore Free Trial

#### Requirements
- An AWS account with the ability to launch an AMI/CF instance in us-west-1, us-east-1, or us-east-2.
- Fill out this form [Anchore Free Trial](https://get.anchore.com/free-trial/)

> [!WARNING]
> There will be AWS Compute and other costs for running the Anchore Free trial.

#### Setup

Follow the [installation instructions](https://sites.google.com/anchore.com/anchore-enterprise-trial) included in the free trial email.

Review [launching the trial](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.ddctetfymxlt) and [accessing the trial](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.ddctetfymxlt) on how to access the Anchore Enterprise UI and login.

## Install AnchoreCTL

Next, we'll install the Anchore Enterprise ctl tool, quickly test using the `version` operation, and set up a few environment variables to allow it to interact with your quickstart deployment using the following process:

> [!NOTE]
> If you have chosen the AWS Anchore Free Trial route, the AnchoreCTL has already been installed and configured for you.
> Please follow the [installation instructions](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.g74u7lejv5m1) for usage.

Download and install the AnchoreCTL
```bash
curl -sSfL  https://anchorectl-releases.anchore.io/anchorectl/install.sh  | sh -s -- -b /usr/local/bin v5.6.2
```
> [!TIP]
> For more specific help, please consult our [installation docs](https://docs.anchore.com/current/docs/deployment/anchorectl/).

Create the anchorectl url and username env variables for all environments
```bash
export ANCHORECTL_URL="http://localhost:8228"
export ANCHORECTL_USERNAME="admin"
```
**For Compose only** - create the anchorectl password environment variable
```bash
export ANCHORECTL_PASSWORD="foobar" 
```
**For Kubernetes only** - create the anchorectl password environment variable
```bash
export ANCHORECTL_PASSWORD=$(kubectl get secret anchore-enterprise -o jsonpath='{.data.ANCHORE_ADMIN_PASSWORD}' | base64 -D)
```

Quickly test using the `version` operation that anchorectl has been set up correctly. Your output should look like the following:
```bash
./anchorectl version
```
> output
```
Application:        anchorectl
Version:            5.6.2
SyftVersion:        v1.5.0
BuildDate:          2024-05-30T02:22:55Z
GitCommit:          1c7b0cdc25834656cefc4adc3794500a0b6bb807
GitDescription:     v5.6.2
Platform:           darwin/arm64
GoVersion:          go1.21.10
Compiler:           gc
```

> [!NOTE]
> For this tutorial, we're installing the tool in your local directory `./` which requires the environment variables throughout the labs.

> You can permanently install and configure `anchorectl` removing the need for setting environment variables, see [Installing AnchoreCTL](https://docs.anchore.com/current/docs/deployment/anchorectl/).

## Cleanup

If you would like, please continue testing Anchore Enterprise, you can easily add your own source, images and other integrations (such as CI/CD, SSO and more).
It's a great way to kick the tyres a little further and examine what the results and workflows could look like for you.

- See some examples of CI/CD integrations - https://docs.anchore.com/current/docs/integration/ci_cd/
- Learn about SSO support - https://docs.anchore.com/current/docs/configuration/sso/ and context switching https://docs.anchore.com/current/docs/configuration/accounts/

If you do however, need to spin down resources, please check out the steps below.

### Spin down your Anchore deployment

**Compose**
```bash
docker compose -f assets/anchore-compose.yaml down
```
**Kubernetes**
```bash
helm uninstall anchore
```
**AWS Free Trial**
Please follow the instructions you have received via email.
