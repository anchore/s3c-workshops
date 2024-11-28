# Policy Enforcement

Enforce compliance with external and/or internal standards.

Facilitating everything from policy creation to policy enforcement can help meet compliance goals and importantly prioritize your efforts without crippling developer velocity.

Anchore Enterprise enables users to define automated rules that indicate which vulnerabilities violate their organizations’ policies or work against compliance goals.
For example, an organization may raise policy violations for vulnerabilities scored as Critical or High that have a fix available.
These policy violations can generate alerts and notifications or be used to stop builds in the CI/CD pipeline or prevent code from moving to production.
Policy enforcement can be applied at any stage in the development process, from the selection and usage of open source components through the build, staging, and deployment process, here are our top 10 uses:

1. Policy alerts and enforces for malware findings
2. Create a policy that doesn't cripple velocity
3. Enforce control of license abuse/misuse via Policy
4. Enforce secret + password monitoring in Policy
5. Policy checks for known exploited vulnerabilities across SDLC
6. Enforce building from approved images
7. Detect & Block misconfigurations in images
8. Policy blocks unauthorized software reaching kubernetes
9. Policy blocks unauthorized images reaching registry
10. Don’t pass builds that violate CVE thresholds

> [!TIP]
> For a visual walkthrough checkout the [Policy enforcement workshop materials](https://viperr.anchore.com/policy/).

## Lab Exercises

Once an image has been analyzed and its content has been discovered, categorized, and processed, the results can be evaluated against a user-defined set of checks to give a final pass/fail recommendation for an image. Anchore Enterprise policies are how users describe which checks to perform on what images and how the results should be interpreted.

A policy is made up from a set of rules that are used to perform an evaluation of a container image. The rules can define checks against an image for things such as:

- Security vulnerabilities
- Package allowlists and denylists
- Configuration file contents
- Presence of credentials in image
- Image manifest changes
- Exposed ports

### Policy Enforcement - creation & management of policies

Anchore comes with some policies out of the box and you can create a flexible policy yourself to build a policy enforcement strategy that works for you.
These are stored as json files and can be moved / shared between Anchore deployments too.

Anchore also has prebuilt policy bundles to offer, that meet a [wide range](https://docs.anchore.com/current/docs/overview/capabilities/#anchore-enterprise-policy-packs) of compliance measures such as NIST, FedRAMP, SSDF and many more.

To understand Anchore policies, rules (triggers and gates), mappings, allow lists and more, please review our detailed [UI policies guide](https://docs.anchore.com/current/docs/compliance_management/policy_overview_ui/).

We can switch to inspecting the current policies in place with the following anchorectl commands.
```bash
anchorectl policy list
```
Output
```
┌─────────────────────────┬──────────────────────────────────────┬────────┬──────────────────────┐
│ NAME                    │ POLICY ID                            │ ACTIVE │ UPDATED              │
├─────────────────────────┼──────────────────────────────────────┼────────┼──────────────────────┤
│ anchore_security_only   │ anchore_security_only                │ false  │ 2024-03-08T09:38:50Z │
│ Default policy          │ 2c53a13c-1765-11e8-82ef-23527761d060 │ false  │ 2024-03-12T19:55:05Z │
│ anchore_cis_1.13.0_base │ anchore_cis_1.13.0_base              │ true   │ 2024-03-14T12:25:11Z │
└─────────────────────────┴──────────────────────────────────────┴────────┴──────────────────────┘
```
As you can see only the CIS one is active.

Let's activate the default policy as this has checks for source code.
```bash
anchorectl policy activate 2c53a13c-1765-11e8-82ef-23527761d060
```
Output
```
Name: Default policy
Policy Id: 2c53a13c-1765-11e8-82ef-23527761d060
Active: true
Updated: 2024-03-17T15:18:33Z
```
Now go review the policy compliance page for your images in the Web UI.

### Policy Enforcement and use cases 

Anchore Enterprise provides a mechanism to compare the policy checks and security vulnerabilities of an image with those of a base image. This allows you to 
- filter out results that are inherited from a base image and focus on the results relevant to the application image
- reverse the focus and examine the base image for policy check violations and vulnerabilities which could be a deciding factor in choosing the base image for the application

Additionally, another way to view policy enforcement, is to accept a risk, and allow either a CVE or Image to pass through policy checks.
This is only suitable for some use cases, however it does allow you to continue shipping your code AND have that exception logged.

Here are some guides on how both of these work
- https://docs.anchore.com/current/docs/compliance_management/policy_overview_ui/allowlists/
- https://docs.anchore.com/current/docs/compliance_management/policy_overview_ui/allowed_denied_images/

### Policy Enforcement and integration with CI/CD

Anchore Enterprise provides the building blocks for you to integrate with your chosen pipeline tooling.
In many cases, you will want to retrieve vulnerabilities or policy compliance data in order to make decisions and 'shift-left' and flag the outcomes to the Engineer.

We now turn to some examples to illustrate some of the features required.

When adding an image for example after building it in a pipeline, the iamage will be queued to be analyzed.
Let's add a new image as an example BUT wait for the analysis to complete using `--wait` 
```bash
anchorectl image add docker.io/nginx:latest --wait
```
You can fetch and store all results to a local directory. Useful if you want to store the results in your CI/CD tooling.
```bash
anchorectl image add docker.io/library/nginx:latest --get all=./tmp/app
```
To apply the active policy bundle and SEE all the policy violations:
```bash
anchorectl image check docker.io/centos:latest --detail
```
To apply the active policy bundle and get a simple pass/fail check result:
```bash
anchorectl image check -f docker.io/app:v2.0.0
```
Output
```
Tag: docker.io/app:v2.0.0
Digest: sha256:f691c18fc3a6ee3884f68d8d65930585b3456b5d64483829bebc6b619e182a5a
Policy ID: 1f6ff4dc-da3c-4299-b2bf-56d2344f6f2d
Last Evaluation: 2024-03-17T16:05:20Z
Evaluation: fail
Final Action: stop
Reason: policy_evaluation
error: 1 error occurred:
	* failed policies:
```
> [!IMPORTANT]
> This sets the exit code to 1 if the policy evaluation result is "fail" (useful for breaking pipelines as a gating mechanism)

Below is what a pass with warn looks like (I used a loose policy to let the checks only flag a warn). 
No need to replicate. If you want to replicate, create a new policy, add a ruleset that will trigger a warn.
Then either make the policy active or supply the -p argument along with your chosen policy.
```bash
anchorectl image check -f docker.io/app:v2.0.0 -p <my-policy-id>
```
Output
```
Tag: docker.io/app:v2.0.0
Digest: sha256:f691c18fc3a6ee3884f68d8d65930585b3456b5d64483829bebc6b619e182a5a
Policy ID: 1f6ff4dc-da3c-4299-b2bf-56d2344f6f2d
Last Evaluation: 2024-03-26T10:24:11Z
Evaluation: pass
Final Action: warn
Reason: policy_evaluation
```
Incidentally, its worth mentioning that currently you can only have one policy active in an Anchore account. 
However, by using the -p flag you can point to use another policy. Useful for checking a new policy.
Bear in mind that whilst the right policy checks are made on this call. The default is still set to another policy.

> [!TIP]
> It is recommended to use the specific image digest rather than image tag when performing an 'anchorectl image check'

Finally, here is an outline of what needs to happen in essentially in all the CI/CD tools:
```bash
# Setup the anchorectl in the pipeline environment
mkdir -p ${HOME}/.local/bin
curl -sSfL  https://anchorectl-releases.anchore.io/anchorectl/install.sh  | sh -s -- -b $HOME/.local/bin  
export PATH="${HOME}/.local/bin/:${PATH}"

# Foreach commit map your source code to an application version (used later to track sboms)
anchorectl syft --source-name app --source-version HEAD -o json . | anchorectl source add github.com/anchore/webinar-demo@73522db08db1758c251ad714696d3120ac9b55f4 --from -

# Do whatever normal image build steps you would do here
# ...

# Next map the container artifact to the application release version (used for SBOM tracking)
anchorectl application artifact add app@v2.0.0 image <retrieved-image-sha-from-build-step>

# Now begin the analysis and evaluation of the image
anchorectl image add --wait ${IMAGE_NAME}
anchorectl image vulnerabilities ${IMAGE_NAME}
anchorectl image check -f --detail ${IMAGE_NAME}
# or
anchorectl image check -f -t ${IMAGE_NAME}
# Now if the image passed the policy check on the previous line, we can
# Continue our pipeline (e.g. push to QA, promote image to another registry, etc).
```
Most capabilities are exposed via the AnchoreCTL but all of them are exposed via the API that has a 100% coverage.
If that is more suitable for you in your CI/CD tooling.

### Policy Enforcement and a custom policy

Let's now create our own, using the example policy json stored in the examples directory
```bash
anchorectl policy add --input examples/lab-policy-example.json
```
TODO - Finish adding policy example

### Policy Enforcement with the runtime inventory

To set up and get inventory details from your clusters please review - https://docs.anchore.com/current/docs/integration/kubernetes/runtime/#deployment

> [!IMPORTANT]
> Whilst we support ECS Clusters. We do not currently show any ECS results in the web ui. Instead, you must use `anchorectl inventory list`

TODO - Finish adding example

### Policy Enforcement with the Kubernetes admission controller

This controller is based on the openshift generic admission controller and implements a Kubernetes Dynamic Webhook controller for interacting with Anchore and making admission decisions based image properties as determined during analysis and subsequent Anchore Enterprise policy review.

The Anchore admission controller supports 3 different modes of operation allowing you to tune tradeoff between control and intrusiveness for your environments.

- Strict Policy-Based Admission Gating Mode
- Analysis-Based Admission Gating Mode
- Passive Analysis Trigger Mode

To learn more about deployment, configuration and usage please review the [integration repo](https://github.com/anchore/kubernetes-admission-controller) in GitHb.

## Next Lab

Next: [Remediation](remediation.md)