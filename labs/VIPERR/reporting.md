# Reporting

Anchore Enterprise Reports aggregates data to provide insightful analytics and metrics for account-wide artifacts.

Report out timely information quickly at any step of the development process.

You have so far seen all the steps from SBOM generation, inspection and policy enforcement.
Now armed with some data about our source code / containers we can generate some useful information.
Below are the top 10 capabilities for how Anchore delivers reporting:

1. Provide timely reports in compliance with DoD standards
2. Include reports that have accurate temporal data
3. Reports should have relational context
4. Reporting should be 100% automated
5. Reports should target accurate artifacts
6. Reports should reference impacted artifacts
7. Reports should be provided to every team and developer
8. Reports should include accurate timestamps
9. Included Reports in Risk Assessment/Risk Mgmt Process
10. Regularly update reporting mechanisms for new checks

> [!TIP]
> For a visual walkthrough checkout the [Reporting workshop materials](https://viperr.anchore.com/reporting/) (_there are some slight differences on ui_).

## Lab Exercises

For this lab, we turn to the Web UI to generate reports that will help surface some of the capabilities and information on offer to help you manage your software. 
Reports can be created and managed in many ways: They can be saved, run on a schedule and made into a template for others to use. 
Additionally, you can download your report results as JSON or CSV and set up notifications to webhooks to be notified when a report has been generated.

> Note: with reporting there is no direct anchorectl support, instead reports are built and managed in the Web UI itself under `/reports` tab in the top navigation.

### Reporting for vulnerability & compliance management

Here are some objectives to try yourself:

- Run a report to find all images that are using a vulnerable version of Log4j (CVE-2021-45046 or GHSA-7rjr-3q55-vv33).
- Run a report to show all critical vulnerabilities.
- Run a report to show which images are failing policy evaluation.
- Run a runtime report to show issues in a Kubernetes or ECS Namespace/Container.
- Build a scheduled report that will run daily.

Please review the docs for extra details and examples to guide you https://docs.anchore.com/current/docs/vulnerability_management/reports/
