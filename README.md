# S3C Workshops - Software Security in the Real World

This repo offers step-by-step guidance for deploying Anchore Enterprise (version 6.x) and working through a set of specific labs that showcase how you can utilize Anchore Enterprise to improve security across your software supply chain.

## Target audience

Anyone who wants to understand how they can improve security across their SDLC using Anchore Enterprise.  
This repository will help you establish a running Anchore Enterprise deployment via Docker Compose or Kubernetes. 
After you have a successful deployment, just pick an interesting lab, and we guide you through it step-by-step.

## Use cases

Anchore Enterprise is a flexible platform that can be utilized in many ways, here are some common use cases:

**SBOM (Software Bill of Materials)** - Get comprehensive visibility of your software components to bolster security and ensure vulnerability accuracy with the most complete SBOM available.

**Container Vulnerability Scanning** - Reduce false positives and false negatives with best-in-class signal-to-noise ratio.

**Container Security** - Identify and remediate container security risks, and monitor deployments for new vulnerabilities.

**Container Registry Scanning** - Get continuous security and compliance checks integrated directly into your container image registry.

**CI/CD Pipeline Security** - Embed security and compliance into your CI/CD / DevSecOps pipeline to uncover vulnerabilities, secrets, and malware in your automated build processes and keep development moving.

**Cluster Integrations** - Allow or prevent deployment of images based on flexible policies and continuously monitor the inventory of insecure images running in your clusters.

**FedRAMP Vulnerability Scanning** - Meet the new FedRAMP Vulnerability Scanning Requirements for Containers and achieve compliance faster.

**Cybersecurity & Federal Compliance** - Automate compliance checks using out-of-the-box and/or custom policies.

## Labs

Each lab below steps you through tried and tested examples across many use cases.  
    
* [Deployment](labs/Deployment/README.md) - Get Anchore Enterprise & AnchoreCTL Running (REQUIRED)
* [VIPERR](labs/VIPERR/README.md) - **V**isibility, **I**nspection, **P**olicy **E**nforcement, **R**emediation, **R**eporting

## Learn more

Anchore supports many use cases, configurations and environments, please check out the Anchore Docs, wider resources, or get in touch directly to learn more.

- [Anchore Enterprise Docs](https://docs.anchore.com/current/docs/)
- [Anchore Resources](https://anchore.com/resources/)
- [Get in touch](https://get.anchore.com/contact/)
