# Cleanup

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

## Next Step

Please come back to learn more. There are more labs coming.