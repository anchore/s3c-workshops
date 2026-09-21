# Cleanup

Please continue testing Anchore Enterprise, you can easily add your own source, images and test other integrations (such as CI/CD, SSO and more).
More information and examples can be found in the docs pages - https://docs.anchore.com/current/docs/.

If you need to spin down resources, please review the relevant steps below.

**AnchoreCTL**
```bash
# Simply remove anchorectl binary from where you installed it.
rm ~/.local/bin/anchorectl
```
**Compose**

Run these from the directory containing `docker-compose.yaml`.
```bash
# Stop and remove the containers, keeping your database
docker compose down

# Or, for a total cleanup, also delete the anchore-enterprise-db volume.
# This permanently removes all analysis data, policies and accounts.
docker compose down -v
```
**Kubernetes**
```bash
# Uninstall Anchore from your existing cluster
helm uninstall anchore -n anchore

# Remove your local Kind cluster entirely if desired
kind delete cluster --name anchore
```
