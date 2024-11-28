#!/bin/bash

echo "Pre-flight checks..."
echo "Verifying kubectl installed..."
if ! kubectl &> /dev/null
then
    echo "kubectl could not be found. please install - https://kubernetes.io/docs/tasks/tools/#kubectl"
    exit 1
fi
kubectl version
kubectl cluster-info
kubectl config get-contexts

echo "Verifying helm installed..."
if ! helm version &> /dev/null
then
    echo "helm could not be found. please install - https://helm.sh/docs/intro/install/"
    exit 1
fi
helm version

echo "Verifying you have the image and license information from signup at: https://forms.gle/NMhpVU19SuXRnLhC9"
if ! test ./demo-secrets.yaml
then
  echo "No ./demo-secret.yaml file found to apply. Please go to: <insert url here> to sign up and get the license and pull secrets for the demo images"
  exit 1
fi

namespace="anchore-demo"
echo "Using k8s namespace ${namespace}"

echo "Creating a k8s namespace for the demo: ${namespace}"
kubectl create ns ${namespace}

echo "Installing configuration/secrets for the demo"
kubectl -n ${namespace} apply -f ./demo-secrets.yaml

echo "Adding Anchore chart repository..."
helm repo add anchore https://charts.anchore.io
helm repo update

echo "Installing Anchore Enterprise to namespace ${namespace}"
helm install -n ${namespace} --version "2.7.0" anchore-demo anchore/enterprise -f values.yaml