# AnchoreCTL

AnchoreCTL is a CLI tool used to interact with Anchore Enterprise across many scenarios and use cases. AnchoreCTL will be required for most labs.

See the official [AnchoreCTL Deployment page](https://docs.anchore.com/current/docs/deployment/anchorectl/) for instructions on how to download and install AnchoreCTL.

After AnchoreCTL is installed, see the [AnchoreCTL Configuration page](https://docs.anchore.com/current/docs/configuration/anchorectl/). Configure your AnchoreCTL to connect to the Anchore Enterprise instance that you deployed.

Create the AnchoreCTL environment variables to point to your deployment:
```bash
export ANCHORECTL_URL="http://localhost:8228"
export ANCHORECTL_USERNAME="admin"
export ANCHORECTL_PASSWORD="anchore12345" 
```

Test your AnchoreCTL and Anchore Enterprise deployment
```bash
anchorectl system status
```
Your output should look something like the following with 'available' for all rows:
```
✔ Status system                                                                                                                                                                                                                                                                        
┌───────────────────┬──────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────┬──────┬────────────────┬────────────┬──────────────┐
│ SERVICE           │ HOST ID                                              │ URL                                                                       │ UP   │ STATUS MESSAGE │ DB VERSION │ CODE VERSION │
├───────────────────┼──────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────┼──────┼────────────────┼────────────┼──────────────┤
│ catalog           │ anchore-enterprise-catalog-5b977d5574-hnmxg          │ http://anchore-enterprise-catalog.anchore.svc.cluster.local:8082          │ true │ available      │ 6020       │ 6.2.0        │
│ simplequeue       │ anchore-enterprise-simplequeue-776765d464-pghd5      │ http://anchore-enterprise-simplequeue.anchore.svc.cluster.local:8083      │ true │ available      │ 6020       │ 6.2.0        │
│ notifications     │ anchore-enterprise-notifications-6796588b9c-vkcr8    │ http://anchore-enterprise-notifications.anchore.svc.cluster.local:8668    │ true │ available      │ 6020       │ 6.2.0        │
│ reports           │ anchore-enterprise-reports-6f799cc6f4-x9gvm          │ http://anchore-enterprise-reports.anchore.svc.cluster.local:8558          │ true │ available      │ 6020       │ 6.2.0        │
│ reports_worker    │ anchore-enterprise-reportsworker-5f4b864f8f-jsp68    │ http://anchore-enterprise-reportsworker.anchore.svc.cluster.local:8559    │ true │ available      │ 6020       │ 6.2.0        │
│ data_syncer       │ anchore-enterprise-datasyncer-888c9b764-gc44v        │ http://anchore-enterprise-datasyncer.anchore.svc.cluster.local:8778       │ true │ available      │ 6020       │ 6.2.0        │
│ analyzer          │ anchore-enterprise-analyzer-54d4fd6f65-7v2bv         │ http://anchore-enterprise-analyzer.anchore.svc.cluster.local:8084         │ true │ available      │ 6020       │ 6.2.0        │
│ policy_engine     │ anchore-enterprise-policy-58c74dddd4-qjx86           │ http://anchore-enterprise-policy.anchore.svc.cluster.local:8087           │ true │ available      │ 6020       │ 6.2.0        │
│ component_catalog │ anchore-enterprise-componentcatalog-75db5f797f-t8prb │ http://anchore-enterprise-componentcatalog.anchore.svc.cluster.local:8228 │ true │ available      │ 6020       │ 6.2.0        │
│ apiext            │ anchore-enterprise-api-58df798dfd-pz52h              │ http://anchore-enterprise-api.anchore.svc.cluster.local:8228              │ true │ available      │ 6020       │ 6.2.0        │
└───────────────────┴──────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────┴──────┴────────────────┴────────────┴──────────────┘
```

## Next Step

Now that you have Anchore Enterprise & AnchoreCTL operational, [proceed to wrap up this lab](./README.md).
