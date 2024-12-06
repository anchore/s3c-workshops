# Deployment Lab

In this lab you will learn how to deploy Anchore Enterprise into an environment of your choice. 
A stand-alone deployment requires at least 8GB of RAM and 40GB of storage. For a smoother experience, we recommended 16 GB of RAM and 100 GB of storage.

_**The deployment in this tutorial is not production ready, and will receive limited support from Anchore, but don't let that stop you from learning!**_

1. Download this repo and move to the `Deployment` directory.
2. Retrieve your Anchore license file and DockerHub login credentials.
   1. To obtain these, fill out a [form](https://forms.gle/NMhpVU19SuXRnLhC9) for instant access.
3. Pick a deployment target and deploy Anchore Enterprise.
   1. Deploy using [Docker Compose](./docker-compose.md)
   2. Deploy using [Kubernetes](./kubernetes.md)
   3. Deploy using [AWS Anchore Free Trial](./aws-free-trial.md)
4. Install AnchoreCTL the Anchore Enterprise Command Line Interface.
   1. Download & Install [AnchoreCTL](./anchorectl.md)
5. Lab wrap up
   1. Follow instructions for [cleanup](./cleanup.md)