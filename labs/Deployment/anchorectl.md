# AnchoreCTL

AnchoreCTL is a tool used to interact with Anchore Enterprise across many scenarios and use cases. AnchoreCTL will be required for most labs.

_If you have chosen the AWS Anchore Free Trial route, the AnchoreCTL has [already been installed and configured](https://sites.google.com/anchore.com/anchore-enterprise-trial#h.g74u7lejv5m1) for you. Otherwise, please continue with the following steps:_

Download and install the AnchoreCTL
```bash
curl -sSfL  https://anchorectl-releases.anchore.io/anchorectl/install.sh  | sh -s -- -b <DESTINATION_DIR> v5.12.0
```

Test your access to the Anchore Enterprise API. This is used by AnchoreCTL
```bash
open http://localhost:8228/v2/
```
you should get the following output:
```
"v2"
```
_Any issues you might need to check your networking configuration and/or run port forwarding._

Create the AnchoreCTL environment variables to point to your deployment
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
Your output should look something like the following with 'available' for all rows:
```
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

## Next Step

Now that you have Anchore Enterprise & AnchoreCTL operational. Now [proceed to wrap up this lab](./README.md).