# Remediation

The Policy Enforcement module turned the inspection data into pass/fail findings for `app@v1.0.0` — `Status: fail`, with `stop-on-critical` firing on `CVE-2021-44228` (log4j-core) and `CVE-2020-14343` (PyYAML), `stop-on-kev` firing on the log4j entry, and `warn-high-with-fix` warning on a handful of others. Remediation is how you close those loops — communicating decisions to downstream consumers, granting evidence-backed exceptions, putting fixes on a clock, and shipping a new version with the issues actually resolved.

In Anchore Enterprise 6.0 there are three loops of remediation, and this module touches each:

| Loop  | What it is | Mechanism in 6.0 |
|---|---|---|
| **Inner** | An engineer gets told something they need to act on. | Subscriptions, notifications, Action Workbench. |
| **Middle** | You don't change the code, but you record a judgement that suppresses or defers a finding. | VEX annotations (per-version), policy allowlists (per-bundle), time-bound rules. |
| **Outer** | You change the artifact: a bumped dependency, a different base image, a new SBOM from upstream. | A new app version with the fixed assets attached. |

> [!IMPORTANT]
> This module assumes you completed the [Visibility](visibility.md), [Inspection](inspection.md), and [Policy Enforcement](policy-enforcement.md) modules. It uses the same `app`, the `v1.0.0` version, the four assets attached to it, the VEX annotation against `CVE-2019-10906` in `Jinja2 2.10`, and the `viperr-lab-policy` bundle bound to `app`.

## How this lab module is structured

Seven phases, fully sequential:

1. **The 6.0 remediation model** — the three loops above and how they map to anchorectl surfaces.
2. **Triage with VEX beyond `not_affected`** — record `affected` and `under_investigation` decisions for findings you can't immediately fix.
3. **Bundle-level allowlists** — add a long-lived, policy-wide exception with an expiry.
4. **Time-bound rules** — give Highs a grace period before they start failing the build.
5. **Subscriptions and notifications** — wire continuous re-scan and re-evaluation to an endpoint.
6. **Recommended actions in the Web UI** — drive remediation through the Action Workbench.
7. **Ship the fix as `v1.0.1`** — upgrade the Python application's dependencies and create a new app version with the fixed asset attached.

By the end you'll have used every per-version triage mechanism, configured a feedback loop into engineering, and shipped a clean `v1.0.1` that the policy passes.

## Phase 1 — The 6.0 remediation model

A few principles inform every command in this module.

**VEX is per-version.** An annotation you record against `(CVE-2019-10906, Jinja2, 2.10)` under `v1.0.0` does **not** silently carry forward to `v1.0.1`. Each release is its own assessment. Use VEX when the judgement is evidence-backed and specific to a release — "this code path isn't reachable in *this* build", "this CVE is mitigated by *this* config we ship in *this* version."

**Allowlists are per-bundle.** Entries live in the policy bundle's `allowlists` array and apply to every version that bundle evaluates. Use allowlists when the judgement is a property of the policy itself — "we never fail on this CVE in this trigger", "platform-managed dependencies are tracked elsewhere."

**Time-bound rules are per-bundle.** Parameters like `max_days_since_fix` and `max_days_since_creation` build a clock into the rule itself: a High doesn't have to stop the build the moment a fix appears, but it can become blocking after, say, 14 days.

**Subscriptions are per-image-or-repo.** A `vuln_update` subscription on a tag triggers a re-scan when feeds change; a `policy_eval` subscription triggers a re-evaluation. These remain v5-backed in 6.0 alpha — the result of a re-scan flows into the v5 catalog, and the same record is what backs the v6 asset.

**Action Workbench is Web UI in 6.0 alpha.** Recommendation lookup, ticket attachment, and the push to GitHub / Jira / Slack / webhook live in `/applications/<app>/...` in the Web UI. There is no `anchorectl recommend` or `anchorectl workbench` command at this alpha.

**The outer loop is `app version add`.** When you actually change the artifact, you create a new version (`v1.0.1`) and re-attach the fixed assets. The old version stays a faithful snapshot of what you shipped before; the new version is the snapshot of what you ship now. Both remain queryable for drift and audit.

## Phase 2 — Triage with VEX beyond `not_affected`

In Inspection you set `(CVE-2019-10906, Jinja2 2.10)` to `not_affected / vulnerable_code_not_in_execute_path` because the Python app never renders user-supplied templates. That suppressed the finding cleanly. The other 6.0 VEX statuses cover the cases where the vulnerability *is* relevant but you want to communicate the state to downstream consumers — and to policy evaluation — without pretending it's gone.

### `affected` — yes, we know; here's what we're going to do

The Python application's `requests==2.19.1` pin trips `CVE-2018-18074`. We'll fix this in Phase 7 by bumping the dependency, but for now let the policy and any downstream VEX consumer know we've triaged it.

```bash
anchorectl app version vex add v1.0.0 \
  --app app \
  --vuln-id CVE-2018-18074 \
  --pkg-name requests \
  --pkg-type python \
  --pkg-version 2.19.1 \
  --status affected \
  --action-statement "Upgrade to requests 2.20.0 scheduled for v1.0.1." \
  --comment "Triaged 2026-05-07 by security-team"
```

`affected` does **not** suppress the finding — the policy will still warn (and we'd want it to, until we ship the fix). What it does is record the decision and put it in the CycloneDX VEX export so consumers of the release know the issue is acknowledged and on a path to resolution.

> [!NOTE]
> `--justification` is required for `not_affected` but **not** for `affected` — for `affected` you supply `--action-statement` instead, describing what you'll do (or have already done) about it.

### `under_investigation` — give us time to triage

The Java SBOM ingested in Visibility came from an upstream supplier. The log4j-core 2.14.1 entry trips `CVE-2021-44228` and `stop-on-kev` — but we don't own the Java application; the upstream supplier does. Record that we're working with them while we wait for a fixed SBOM:

```bash
anchorectl app version vex add v1.0.0 \
  --app app \
  --vuln-id CVE-2021-44228 \
  --pkg-name log4j-core \
  --pkg-type java-archive \
  --pkg-version 2.14.1 \
  --status under_investigation \
  --action-statement "Awaiting fixed SBOM from upstream supplier; tracked in TKT-4421." \
  --comment "Reviewed 2026-05-07; supplier acknowledged"
```

`under_investigation` is the honest answer when you've seen the finding but the decision isn't made yet. Like `affected`, it does not suppress.

### Confirm the state

```bash
anchorectl app version vex list v1.0.0 --app app
```

You'll see all three annotations — the `not_affected` from Inspection, plus the two you just added. They'll all also surface in the version's CycloneDX VEX export from Inspection Phase 6.

> [!TIP]
> If you change your mind — for example, the upstream supplier delivers a fixed SBOM — update the annotation rather than deleting and re-adding. `anchorectl app version vex update <id> --status fixed --action-statement "Resolved in v1.0.1 by ingesting supplier SBOM rev 2026-05-15."` keeps the audit trail intact.

## Phase 3 — Bundle-level allowlists

VEX is the right tool when the judgement is per-version and evidence-backed. Allowlists are the right tool when the judgement belongs to the policy itself — a blanket "for this rule on this trigger, give us a pass" that applies to every version the bundle evaluates, ideally with an expiry so the exception doesn't outlive its reason.

Let's record one against `CVE-2021-44228+log4j-core` as a *platform-managed* waiver — we already noted in Phase 2 that the upstream supplier owns this dependency, and we don't want it failing every version while we wait. The waiver expires on `2026-06-30`, giving a hard deadline for follow-up.

Open `./assets/policies/lab-policy.json` and replace the empty `allowlists` and `sbom_mappings` arrays with these blocks. (Keep `rule_sets` exactly as it was.)

```json
"allowlists": [
  {
    "id": "platform-managed-waivers",
    "name": "Platform-managed waivers",
    "version": "2",
    "description": "Findings tracked by the platform team or an upstream supplier — not actionable from our pipeline.",
    "items": [
      {
        "id": "log4j-2021-44228-platform-managed",
        "gate": "vulnerabilities",
        "trigger_id": "CVE-2021-44228+*",
        "expires_on": "2026-06-30T00:00:00Z",
        "description": "Java application is supplier-managed; awaiting fixed SBOM. TKT-4421."
      }
    ]
  }
],
"sbom_mappings": [
  {
    "id": "default-mapping",
    "name": "Default mapping",
    "rule_set_ids": ["vuln-rules"],
    "allowlist_ids": ["platform-managed-waivers"]
  }
]
```

> [!NOTE]
> The `trigger_id` for vulnerability findings has the shape `<CVE-ID>+<package>`. Allowlist matching for the `vulnerabilities` gate keys on the CVE portion only, so `CVE-2021-44228+*` and `CVE-2021-44228+log4j-core` both match the same set of findings. The `*` form is the conventional spelling when you want any package contributing the CVE.

> [!IMPORTANT]
> Allowlists only take effect if they're referenced by an `sbom_mappings` entry. An allowlist sitting in the `allowlists` array without a mapping reference is parsed but never activated — that's why we added a `default-mapping` here. Rule sets, by contrast, are evaluated whether or not they appear in a mapping (the alpha applies all `sbom`-type rule sets by default).

Re-import the edited bundle. `policy update` replaces the rule sets, allowlists, and mappings in place — the policy ID and its app binding don't change.

```bash
anchorectl policy update --input ./assets/policies/lab-policy.json
```

Re-trigger evaluation against `v1.0.0` (same `curl` pattern as Policy Enforcement Phase 5):

```bash
APP_ID=$(anchorectl app get app -o id)
VERSION_ID=$(anchorectl app version get v1.0.0 --app app -o id)

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/apps/${APP_ID}/jobs/evaluate-policy" \
  -d "{\"app_version_id\": \"${VERSION_ID}\"}"
```

Once the job completes, re-read the findings:

```bash
anchorectl app version policy findings list v1.0.0 --app app -o json \
  | jq '.[] | select(.vulnerability_id == "CVE-2021-44228")'
```

The remaining `CVE-2021-44228` finding now has `"allowlisted": true` and an `allowlist` object naming the waiver, its expiry, and the matching item. The version-level status moves from `fail` to `pass with warnings` — `CVE-2020-14343` (PyYAML) is still a `stop`, but the log4j entry no longer counts against the build.

> [!TIP]
> Allowlists vs VEX, when in doubt:
> - **VEX `not_affected`** when you can justify *why this code in this release is not exploitable*. Travels with the version. Survives policy changes.
> - **Allowlist** when the exception belongs to the bundle. Applies to every version. Best with an expiry. Doesn't carry evidence the same way VEX does.

## Phase 4 — Time-bound rules

The current `warn-high-with-fix` rule fires the moment a fix is available. That's accurate but ungenerous — engineers need *some* runway between "an advisory dropped" and "your build starts complaining." Time-bound parameters let the rule grant that runway automatically.

Edit `./assets/policies/lab-policy.json` again and update the `warn-high-with-fix` rule. Replace its `params` block with this one (the rest of the rule stays as-is):

```json
"params": [
  {"name": "package_type", "value": "all"},
  {"name": "severity_comparison", "value": "="},
  {"name": "severity", "value": "high"},
  {"name": "fix_available", "value": "true"},
  {"name": "max_days_since_fix", "value": "14"}
]
```

The new parameter means *"only fire this rule when the fix has been available for more than 14 days."* A High that became fixable yesterday won't trigger; a High that became fixable two months ago will.

> [!NOTE]
> The `vulnerabilities / package` trigger supports two clock parameters:
>
> | Parameter | Fires when … |
> |---|---|
> | `max_days_since_fix` | The fix has been available for **more than** N days. Best for "you've had time to upgrade." |
> | `max_days_since_creation` | The CVE has existed for **more than** N days. Best for "this isn't a zero-day anymore." |
>
> Use `max_days_since_fix` for actionable Highs and `max_days_since_creation` when you also want to surface long-known issues that don't have fixes yet.

Re-import and re-evaluate:

```bash
anchorectl policy update --input ./assets/policies/lab-policy.json

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/apps/${APP_ID}/jobs/evaluate-policy" \
  -d "{\"app_version_id\": \"${VERSION_ID}\"}"
```

Inspect the warn-action findings:

```bash
anchorectl app version policy findings list v1.0.0 --app app -o json \
  | jq '[.[] | select(.action == "warn" and .rule_id == "warn-high-with-fix")]'
```

The Python application's `CVE-2018-18074` (`requests`) and the other Highs we surfaced earlier all have fix advisory dates well past 14 days, so they continue to warn — these are genuinely overdue. A hypothetical High whose fix landed within the last fortnight wouldn't appear at all.

> [!TIP]
> A common shape in real policies is two complementary rules on the same trigger:
>
> - `warn-high-with-fix` with `max_days_since_fix=14` — warning during the runway.
> - `stop-high-with-fix` with `max_days_since_fix=30` — blocking once the runway is up.
>
> The two together encode "you have two weeks of warning and four weeks of grace" cleanly into the bundle.

## Phase 5 — Subscriptions and notifications

Triage decisions are only useful when the right engineer hears about state changes. Subscriptions and notifications are how Anchore Enterprise pushes those changes out to your endpoints — webhook, Slack, email, GitHub, Jira, or SIEM.

> [!IMPORTANT]
> In 6.0 alpha, the subscription and event surfaces are still served by the v5 catalog and key on raw image records (registry / repo / tag), not on the app/version asset model. The subscriptions you activate here will keep the underlying image record fresh; the v6 asset built on top of that record will reflect the refreshed data the next time you list vulnerabilities. Bridging subscriptions into the asset model directly is on the roadmap.

### The subscription types that matter for remediation

| Type | What it does | Typical use |
|---|---|---|
| `tag_update` | New analysis when the same tag is re-pushed. | Catch supply-chain replacements where someone overwrites `:latest` or `:13`. |
| `vuln_update` | New analysis-pass when feed data changes for a known image. | Catch new CVEs published against software you've already scanned. |
| `policy_eval` | Re-run policy evaluation when the bound policy or the vulnerability picture changes. | Catch findings that newly cross a `stop` threshold. |
| `analysis_update` | Notify when an analysis completes. | Drive downstream pipelines that consume SBOMs. |

`tag_update` was already activated against `docker.io/library/postgres:13` in Visibility Phase 3. Let's add the other two for the same image — those are the ones that close the remediation feedback loop.

```bash
anchorectl subscription activate docker.io/library/postgres:13 vuln_update
anchorectl subscription activate docker.io/library/postgres:13 policy_eval
```

List the active subscriptions to confirm:

```bash
anchorectl subscription list
```

Output (truncated):

```
 ✔ List subscription
┌──────────────────────────────────┬─────────────────┬────────┐
│ KEY                              │ TYPE            │ ACTIVE │
├──────────────────────────────────┼─────────────────┼────────┤
│ docker.io/library/postgres:13    │ tag_update      │ true   │
│ docker.io/library/postgres:13    │ vuln_update     │ true   │
│ docker.io/library/postgres:13    │ policy_eval     │ true   │
│ docker.io/library/postgres       │ repo_update     │ true   │
└──────────────────────────────────┴─────────────────┴────────┘
```

By default Anchore Enterprise runs `vulnerability_scan` every 14400 seconds (4 hours) and `policy_eval` every 3600 seconds (1 hour); both timers are configurable on the deployment side.

### Notification endpoints

When a subscription fires it produces an *event*. Events are what get routed to your endpoints. List recent events:

```bash
anchorectl event list
```

Endpoints (webhook, email, GitHub issues, Jira, Slack, MS Teams, SIEM forwarders) are configured per-deployment. In 6.0 alpha the management surface for those endpoints is the Web UI under `/system/notifications` and the `system_integrations` API — `anchorectl system integration` only supports `list`, `get`, and `delete`. To add a webhook, navigate to **System → Notifications → Endpoints** in the UI and provide the URL, optional auth header, and the subscription types it should receive.

> [!TIP]
> A common starter setup for a development team:
> - Critical / KEV → page on-call (PagerDuty webhook).
> - New `stop` finding on the production version → Slack #security-alerts.
> - Any `warn` → daily digest email to the application team.
>
> All three are the same Anchore subscription / notification plumbing — only the endpoint routing differs.

### See it in the UI

Open the Web UI at `/events`. Each event has a payload (the same JSON you'd see at the API), a timestamp, and the subscription that produced it. When you eventually attach a webhook, that payload is what it'll deliver.

## Phase 6 — Recommended actions in the Web UI

The Action Workbench is where remediation goes from "we found something" to "someone has a ticket." It lives in the Web UI; there's no anchorectl surface for it in 6.0 alpha.

The workflow follows the same trail you've already walked in the CLI, but with the suggestion / hand-off step layered on top.

1. **Open the application.** Navigate to `/applications` and select `app`, then `v1.0.0`. You'll land on the version view showing the four assets and the latest policy status.
2. **Open the policy compliance page** for `v1.0.0`. Below the summary donut you'll see the list of findings from Phase 4 of Policy Enforcement — minus the entries you VEX-suppressed and allowlist-waived in Phases 2 and 3 above.
3. **Pull recommendations for a finding.** Click into one of the remaining `stop` findings (e.g. `CVE-2020-14343` in PyYAML), open the tools menu on the right of its row, and choose **Show remediation suggestions**. Anchore Enterprise will surface the upgrade path (`PyYAML 5.4`), the relevant advisory link, and any *rule-creator recommendations* that the policy bundle's author embedded in the rule's description.
4. **Add a note** describing what you intend to do (or who you're routing it to), and click **Add to Action Workbench**.
5. **Open the Action Workbench tab.** From here, push the queued actions to the endpoints you've configured under **System → Integrations**:
   - GitHub issues — opens an issue against the configured repository.
   - Jira — creates a ticket in the configured project.
   - Custom webhook — POSTs the action payload to a URL of your choice.

> [!NOTE]
> You can switch between policies on the compliance page using the dropdown on the right. Selecting a non-active policy gives you a **preview** of what evaluation under that policy would look like — it does not change the binding on the app, and it does not produce a stored `policy status` record. To change the binding, use `anchorectl app update app --policy-id <id>` as in Policy Enforcement Phase 4.

> [!IMPORTANT]
> The compliance page surfaces both **policy findings** (from the bundle) and **alerts** (from the per-account alerts API). Alerts are stateful — opened when a subscribed tag starts failing policy, closed when all findings are addressed. There is no anchorectl support for alerts in 6.0 alpha; manage them via the Web UI or the `/alerts/compliance-violations` API directly. Once you have a webhook configured, alert transitions are a natural input to whatever ticket system your team already uses.

## Phase 7 — Ship the fix as `v1.0.1`

You've now used every remediation surface that doesn't change the artifact. The remaining `stop` findings on `v1.0.0` (`CVE-2020-14343` in PyYAML, the rest of the Highs that crossed the new 14-day clock) are genuine "fix it" cases — we need a new version with upgraded dependencies. This is the outer loop.

### Upgrade the Python application's dependencies

You should already have `/tmp/my-python-app/` from Visibility Phase 4. (If not, re-extract: `tar -xzf ./assets/my-python-app.tar.gz -C /tmp/`.)

Open `/tmp/my-python-app/requirements.txt`. You'll see the original pins:

```
Flask==1.0.2
requests==2.19.1
PyYAML==5.1
urllib3==1.24.1
Jinja2==2.10
cryptography==3.2
Pillow==8.0.0
```

Replace it with the fixed pins — every package bumped to a release that resolves its known CVEs:

```
Flask==2.3.3
requests==2.32.0
PyYAML==6.0.1
urllib3==1.26.18
Jinja2==3.1.4
cryptography==42.0.4
Pillow==10.3.0
```

### Create the new app version

```bash
anchorectl app version add v1.0.1 \
  --app app \
  --description "Dependency upgrades to resolve CVEs surfaced in v1.0.0" \
  --status in_progress
```

> [!NOTE]
> `v1.0.0` keeps everything it had — same four assets, same VEX annotations, same policy findings. A new version is a fresh slate that *can* import the same assets again, but doesn't inherit per-version state automatically.

### Re-scan the fixed Python directory as an asset under `v1.0.1`

```bash
anchorectl app version asset add filesystem /tmp/my-python-app \
  --app app \
  --version v1.0.1 \
  --asset my-python-app \
  --type application \
  --annotations "language=python,role=worker,source=upstream-tarball,upgrade-pass=2026-05-07" \
  --supplier "Internal CI" \
  --wait
```

This produces a new SBOM from the updated source tree and attaches it as an asset under `v1.0.1`. The packages in this asset reflect the upgraded pins; the deduplicated vulnerability set under `v1.0.1` will be visibly smaller than under `v1.0.0`.

> [!TIP]
> The Java, Postgres, and Ubuntu assets in `v1.0.0` were owned by other teams — upstream supplier, platform team, base image team. In a real release of `v1.0.1` you'd also re-attach those assets (or their updated equivalents — a new supplier SBOM, `postgres:14`, an `ubuntu:noble` base) under `v1.0.1` so the version is a complete picture of what ships. The point is the same: each version captures the assets *as they exist at that release*. You can keep this lab focused on the Python upgrade and that's fine.

### Re-evaluate `v1.0.1` against the policy

```bash
VERSION_ID_V11=$(anchorectl app version get v1.0.1 --app app -o id)

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/apps/${APP_ID}/jobs/evaluate-policy" \
  -d "{\"app_version_id\": \"${VERSION_ID_V11}\"}"
```

Once the job completes:

```bash
anchorectl app version policy status get v1.0.1 --app app
anchorectl app version policy findings list v1.0.1 --app app
```

The CVEs that drove the `v1.0.0` failure on the Python side — `CVE-2020-14343` (PyYAML), `CVE-2018-18074` (requests), `CVE-2019-10906` (Jinja2) — are no longer in the package set, so the rules don't fire. The version-level outcome reflects whatever's left from the *other* assets you still attach to `v1.0.1`.

### Compare versions for drift

Side-by-side counts at the CLI:

```bash
echo "v1.0.0:" && anchorectl app version vuln list v1.0.0 --app app -o json | jq 'length'
echo "v1.0.1:" && anchorectl app version vuln list v1.0.1 --app app -o json | jq 'length'
```

For the package-level diff, export the package inventories from both versions (Inspection Phase 6) and `diff` the CSVs:

```bash
anchorectl app version export packages v1.0.0 --app app --file /tmp/v1.0.0-packages.csv
anchorectl app version export packages v1.0.1 --app app --file /tmp/v1.0.1-packages.csv
diff /tmp/v1.0.0-packages.csv /tmp/v1.0.1-packages.csv
```

The diff is your release-note input: every package that changed, in one place.

> [!IMPORTANT]
> VEX annotations and allowlist entries do **not** apply to `v1.0.1` automatically. The `not_affected` decision on `(CVE-2019-10906, Jinja2 2.10)` was scoped to `v1.0.0` — and that's correct, because `v1.0.1` has `Jinja2 3.1.4` and the finding doesn't exist there anyway. If a triage decision you made on `v1.0.0` still applies to `v1.0.1` (same package version, same code path), re-record it explicitly with `vex add` against the new version. The allowlist on `CVE-2021-44228+*` *does* still apply to `v1.0.1` — allowlists are bundle-scoped, not version-scoped.

## Recap

You closed the three loops of remediation for `app@v1.0.0` and shipped a clean `v1.0.1`:

1. Mapped the **6.0 remediation model** — per-version VEX, per-bundle allowlists and time-bound rules, per-image subscriptions, Web UI Action Workbench, new app versions.
2. Recorded **VEX annotations** beyond `not_affected` — `affected` for the `requests` upgrade and `under_investigation` for the supplier-managed log4j entry.
3. Added a **bundle-level allowlist** with an expiry for `CVE-2021-44228+*`, and wired the necessary `sbom_mappings` entry to activate it.
4. Gave Highs a **14-day grace period** with `max_days_since_fix`, so a freshly-fixed High doesn't immediately stop the build.
5. Activated **`vuln_update` and `policy_eval` subscriptions** on the Postgres tag and surveyed how events flow to notification endpoints.
6. Walked the **Action Workbench** in the Web UI — recommendations, notes, and the push to GitHub / Jira / webhook.
7. Created `v1.0.1`, re-scanned the **upgraded Python application** as an asset, re-evaluated the policy, and diffed the package inventory against `v1.0.0`.

Useful 5.x → 6.0 mappings:

| 5.x                                                           | 6.0                                                                  |
|---------------------------------------------------------------|----------------------------------------------------------------------|
| `image check <image> --detail` for remediation suggestions    | Action Workbench in the Web UI under `/applications/<app>/...`       |
| Allowlists only (per-bundle waivers)                          | Allowlists *and* VEX annotations — VEX for per-version evidence, allowlists for bundle-wide policy |
| `anchorectl evaluation refresh`                               | `POST /v2/apps/<id>/jobs/evaluate-policy` (no CLI surface yet)       |
| `anchorectl subscription activate <image> vuln_update`        | Unchanged — subscriptions are still v5-backed and key on raw images  |
| `application version add app@v1.0.1` + `image add` + `application artifact add` | `app version add v1.0.1 --app app` + `app version asset add …`       |
| Allowlist entries with `whitelists` array                     | Same JSON; v5 names auto-aliased to `allowlists`                     |

**Outer-loop pattern for CI/CD.** When a release branch cuts:
1. `app version add <release> --app <app>` once.
2. For every artifact in the release, `app version asset add <type> … --version <release>` (centralized, distributed, SBOM, or filesystem as appropriate).
3. Re-record VEX annotations that still apply by replaying `app version vex add … --version <release>` (or feed in a CycloneDX VEX document from the previous version via your own tooling).
4. Trigger `POST /v2/apps/<id>/jobs/evaluate-policy` and poll `app version policy status get <release>`.
5. Treat `Status: fail` as exit-1; treat `pass with warnings` as a notification to the team; treat `pass` as ship-ready.

## Next Module

Next: [Reporting](reporting.md) — turning the asset, vulnerability, policy, and remediation data you've accumulated across `v1.0.0` and `v1.0.1` into account-wide insights for security, engineering, and compliance audiences.
