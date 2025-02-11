# Remediation

Recommendations and automation to help resolve issues more quickly. Give the developer what they need to move fast.

Anchore Enterprise provides capabilities to alert engineers of issues through the Web UI but also to other tools, such as Jira, GitHub issues or Slack. 
It also lets users define actionable remediation workflows with automated remediation recommendations that can assist a course of action. 
The capabilities here can can support many use-cases and here are our top 10:

1. Provide remediation steps for software violating secure coding standards
2. Automate the flow of CVE fix information to developers
3. Provide ownership who owns the fix (upstream or us)
4. Integrate remediation to your notification & build service
5. Prioritize remediation that are actively being exploited
6. Provide recommended remediation steps in developer workflows
7. Enforce remediation standards via policy
8. Centralize recommended remediation into a plan of action
9. Automated remediation responses to stakeholders
10. Create timeouts for remediation using policy

## Lab Exercises

### Remediation with the Action Workbench

For this lab we turn to some Web UI work to generate some remediation actions.
First navigate to an image, and load the policy compliance page. Below the donut chart you should see a list.  
Click on the down arrow or on the right hand side click on tools and then show remediation suggestions.
You then have some suggestions to chose from along with a notes field. Note: This can contain recommendations you have built into the policy itself. 
We call these rule creator recommendations. You can also see these with the show details button the recommendation column.
Add some notes and then press Add item to the Action Workbench.
Now in the tab click on Action Workbench, from here you can push out these actions to an endpoint such as GitHub issues or a custom webhook

> You can switch between policies by clicking on the right hand side dropdown view on the policy compliance page. 
> However, please note when the non-active policy is selected, you are only previewing the artifact evaluation output produced by the selected policy.

### Remediation as a Developer

As a developer, this section will cover how you can quickly identify and find fixes in your application that can resolved.
Remediation as an application developer can be tough. You can see lots of vulns that are OS focused or indeed related to the parent image manage by another team.
Finally mapping a vulnerability to the extract part of my code/application can also be a challenge. 

Let's walk through how Anchore can simplify this workflow

- Base Image Inheritance - filter out vulns in our golden images / parent images which might be managed centrally.
- Get details on the policy violation such as fix steps - anchorectl image check app:v3.0.0 --detail
- Get details on the non-os issues that I can fix as an application developer - anchorectl image vulnerabilities app:v2.0.0 -t non-os
- Get details on the specific issues and where are they being found - anchorectl image content app:v3.0.0 -t go

TODO: Add an inner loop steps on remediation and update go.mod with newer packages removing vulns
The team have decided to release this latest code with all the vulnerabilities removed (true at the time of writing)
```bash
anchorectl application version add app@v4.0.0
cd ./assets/app:v4.0.0
docker build . -t app:v4.0.0
anchorectl image add app:v4.0.0 --from docker --dockerfile ./Dockerfile --force
```
Make note of the digest in the image add output, we will use this in the next two steps.
```bash
anchorectl application artifact add app@v4.0.0 image <retrieved-image-sha>
```
Check out the vulns on this image now via the anchorectl or via the web UI. Tip: Filter out the base image vulns as these are from the golden image managed by the platforms team.

### Remediation with Allowlists

You may decide upon analysis that you can accept a risk with a discovered vulnerability or a non-compliant Dockerfile so that you can ship some important software.
Anchore helps, by providing you the ability to give a hall pass (add to the allowlist) for a policy item failure and you can time bound this allowlist item too.

TODO: Add an example of an allowlist addition in action.

### Remediation for a limited time only...

You can define policies that are contextual based on time.
For example, you can only configure policies to just 'WARN' for a software package that was only discovered x days ago.
Giving you time to set the workflow in place to resolve, but keep you shipping if that's a suitable risk for your scenario.

See the max_days_since_creation, max_days_since_fix trigger for examples - https://docs.anchore.com/current/docs/compliance_management/policy_overview_ctl/policy_checks/

### Remediation with automated notifications on Vulnerability and Policy Changes

You can subscribe to both vulnerability and policy changes for a given image. When enabled, the images in question are checked on a set cycle timer defined in your Anchore Enterprise deployment as shown below: 
```
anchoreConfig.catalog.cycle_timers.vulnerability_scan = 14400 (default in seconds)
anchoreConfig.catalog.cycle_timers.policy_eval = 3600 (default in seconds)
```
Subscriptions then throw a notification which can be sent onwards to many endpoints such as a webhook, email or Slack for processing and action. See the [Notifications documentation](https://docs.anchore.com/current/docs/configuration/notifications/) for more details.
Some use cases involve sending new data downstream to SIEM systems and other Cyber Security tooling.

By default both the policy and vulnerability subscriptions are disabled. The initial scan and later regular cycle timer in the reporting system will fetch and update both policy and vulnerability data (but not throw a notification). To enable subscriptions for a given image run the following:

Begin continuous updates of vulnerability matches
```bash
anchorectl subscription activate ${IMAGE_NAME} vuln_update
```

Begin continuous updates of policy evaluation
```bash
anchorectl subscription activate ${IMAGE_NAME} policy_eval   
```

You will now need to set up and configure a notification endpoint to receive these events. Alternatively, you can also see these subscriptions as events in the "Events & Notifications" tab in the Web UI. Here you can see the event and view the json payload too.

### Remediation using alerts on image tags

The UI and API can be configured to show stateful alerts that are raised for policy violations on tags to which you are subscribed for.
This raises a clear notification in the UI on the home dashboard to help initiate the remediation workflow and address the violations via the remediation feature. 
It also provides an API for which you can query and update to provide some external remediation integration/workflow.
Once all findings are addressed the alert is closed, allowing for an efficient workflow for users to bring their image's into compliance with their policy.

- Web UI - Home Dashboard
- Alerts API - Account-level alerting
    - GET /alerts/compliance-violations - List all compliance violation alerts scoped to the account
    - GET /alerts/compliance-violations/{uuid} - Get compliance violation alert by id
    - GET /alerts/summaries - List all alert summaries scoped to the account
    - PATCH /alerts/compliance-violations/{uuid} - Open or close a compliance violation alert

> [!NOTE] 
> No notification can be generated from this, and there is no anchorectl support instead the only options are the UI and Alerts API.

This raises a clear notification in the UI to help initiate the remediation workflow and address the violations via the remediation feature. Once all findings are addressed the alert is closed, allowing an efficient workflow for users to bring their image’s into compliance with their policy.

## Next Lab

Next: [Reporting](reporting.md)
