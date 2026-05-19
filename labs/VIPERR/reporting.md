# Reporting

By the end of Remediation, `app` has two versions with opposite policy verdicts: `v1.0.0` is `Status: fail` on the un-waived findings, and `v1.0.1` is `Status: pass` after the Python dependency upgrade. Reporting is how you turn that state into **evidence other people can act on** — the compliance CSV that proves `v1.0.1` is ship-ready for an audit ticket, the CycloneDX VDR that hands the disposition to a customer or regulator, the release-level SBOM that travels with the artifact, the "everything failing policy across the account" dashboard for the security team, the daily CSV that drops into a SIEM, the Kubernetes runtime inventory snapshot attached to a change ticket.

> [!IMPORTANT]
> This module assumes you completed the [Visibility](visibility.md), [Inspection](inspection.md), [Policy Enforcement](policy-enforcement.md), and [Remediation](remediation.md) modules. It uses the same `app`, the `v1.0.0` and `v1.0.1` versions, the four assets attached to `v1.0.0`, the Python asset attached to `v1.0.1`, the VEX annotations recorded against `v1.0.0`, and the `viperr-lab-policy` bundle with its log4j allowlist and 14-day grace rule.

## How this lab module is structured

Seven phases. The first two pull together the per-version exports you've already used into a release workflow; the rest cover the account-wide reporting story plus the push-side notifications that pair with it.

1. **The 6.0 reporting story** — two layers (per-version exports vs account-wide reports) and when to reach for each.
2. **Per-version exports across a release line** — the six anchorectl exports as a release-notes pipeline, including VDR (the disclosure-report format we haven't covered yet).
3. **Account-wide reports in the Web UI** — build a "Log4j across the whole account" report from the canonical questions security teams keep asking.
4. **GraphQL — the API the UI sits on** — query the reports service directly, paginate, and integrate into your own tooling.
5. **Scheduled queries** — cron-schedule a recurring report and pick up the results.
6. **Subscriptions and notifications** — push-side companion to scheduled queries; tell-me-when state changes on images / repos.
7. **Runtime inventory reports** — Kubernetes / ECS summaries when you've connected an inventory agent.

## Phase 1 — The 6.0 reporting story

Reporting in Anchore Enterprise 6.0 lives at two layers, and the right answer for any given hand-off is usually "use the layer at the right scope."

| Layer | Scope | Surface | Best for |
|---|---|---|---|
| **Per-version exports** | One application + one version. | `anchorectl app version export <type> VERSION --app APP` | Release-level hand-offs: "the SBOM/VDR/VEX for v1.0.1", "the compliance report for the audit ticket". |
| **Account-wide reports** | Every image, asset, and tag in the account. | Web UI under `/reports`, GraphQL at `/v2/reports/graphql`, scheduled queries running on cron. | Cross-cutting questions: "which images use vulnerable Log4j", "show all critical findings across every app", "daily CSV to the GRC tool". |

> [!IMPORTANT]
> **Alpha-state caveat for account-wide reports:** in 6.0 alpha the account-wide reporting service is still the v5 reports/reports_worker pair. It keys on raw image records (registry / repo / tag / digest), not on the v6 app/version asset model. Reports you build today will surface images analyzed via either the v5 or v6 paths, but the questions they answer are still phrased in the v5 vocabulary. A native v6-asset reporting surface is on the roadmap; until then, expect a small impedance mismatch where account-wide reports talk about "tags" and "images" while your CLI day-to-day talks about "assets" and "versions". The per-version export surface (Phase 2) does not have this mismatch — it's fully v6-native.

There is no `anchorectl report` command at this alpha. The CLI's reporting surface is the per-version `app version export` family from Phase 2; the account-wide layer is Web UI plus GraphQL.

## Phase 2 — Per-version exports across a release line

Six per-version exports cover most release-level hand-offs:

| Command | Format | Best for |
|---|---|---|
| `app version export sbom VERSION` | CycloneDX JSON (merged across assets) | Release-level SBOM hand-off to customers or downstream tools |
| `app version export vulnerabilities VERSION` | CSV | Security-team and GRC hand-offs |
| `app version export packages VERSION` | CSV | Inventory snapshots and diffs across versions |
| `app version export vex VERSION` | CycloneDX VEX JSON | Internal triage tools and VEX-aware downstream scanners |
| `app version export policy-compliance VERSION` | CSV | Audit tickets, ship/no-ship reviews |
| `app version export vdr VERSION` | CycloneDX VDR JSON | Customer / regulator disclosure documents |

Every command shares the same shape: pass the version name, the `--app`, and either `--file <path>` (write to disk) or no flag (stream to stdout). Each export is created as a job, the CLI polls until it's complete, and the resulting download is written out.

### SBOM (CycloneDX JSON)

Every asset under the version, merged into one CycloneDX SBOM document. Use this when a customer, an auditor, or a downstream tool wants "the SBOM for this release" rather than the per-asset SBOMs:

```bash
anchorectl app version export sbom v1.0.0 \
  --app app \
  --file ./app-v1.0.0-sbom.cdx.json
```

> [!NOTE]
> This is different from `app version asset sbom get`, which returns the original SBOM Anchore Enterprise stored for a single asset, in whatever format you ingested it. `app version export sbom` aggregates the package inventory of every asset under the version and emits a single CycloneDX JSON document — convenient for a release-level hand-off.

### Vulnerability report (CSV)

The canonical "send this to your security team / GRC tool" artifact:

```bash
anchorectl app version export vulnerabilities v1.0.0 \
  --app app \
  --file ./app-v1.0.0-vulnerabilities.csv
```

### Package inventory (CSV)

Every package across every asset, deduplicated, with location and source attribution:

```bash
anchorectl app version export packages v1.0.0 \
  --app app \
  --file ./app-v1.0.0-packages.csv
```

### VEX document (CycloneDX VEX)

Every VEX annotation you recorded in Remediation Phase 1 (`not_affected`, `affected`, `under_investigation`), packaged as a CycloneDX VEX document you can hand to a customer, attach to a release, or feed into a downstream scanner:

```bash
anchorectl app version export vex v1.0.0 \
  --app app \
  --file ./app-v1.0.0-vex.cdx.json
```

The CycloneDX VEX uses the same status / justification vocabulary as `app version vex add`, so a downstream tool that understands CycloneDX VEX will pick up your decisions automatically.

### Compliance report (CSV)

The canonical artifact for an audit, a ticket attachment, or a ship/no-ship review — every finding from the most recent policy evaluation in CSV form:

```bash
anchorectl app version export policy-compliance v1.0.0 \
  --app app \
  --file ./app-v1.0.0-policy-compliance.csv
```

The CSV has one row per finding with rule, action, vulnerability, package, asset, and fix info — the same data `app version policy findings list` returns, in a format every tool downstream knows how to read.

### VDR — the disclosure report

VDR (Vulnerability Disclosure Report) is the CycloneDX format for "here are the vulnerabilities affecting this release, and the disposition of each." It merges the version-level vulnerability list with any VEX annotations you've recorded, producing one document that downstream consumers — customers, regulators, attestation pipelines — can ingest without separately reconciling SBOM, vuln-list, and VEX files.

```bash
anchorectl app version export vdr v1.0.0 \
  --app app \
  --file ./app-v1.0.0-vdr.cdx.json
```

The resulting document contains the components (from the merged SBOM), the vulnerabilities affecting each component, and the analysis fields populated from your VEX annotations — `state: not_affected` with the `vulnerable_code_not_in_execute_path` justification for the Jinja2 entry, `state: affected` with the requests upgrade plan, `state: under_investigation` with the supplier-pending statement for log4j.

> [!NOTE]
> VDR and the VEX-only export (`app version export vex`) overlap but are not the same. **VEX** is just the annotations as a CycloneDX VEX document. **VDR** is the full disclosure: components, vulnerabilities, *and* the VEX disposition attached to each. Give a customer the VDR; give an internal triage tool the VEX file.

### A release-notes pipeline using exports

For `v1.0.0` → `v1.0.1` you have everything you need to produce a clean release-notes artifact bundle. Run all six exports for both versions:

```bash
for v in v1.0.0 v1.0.1; do
  mkdir -p ./reports/$v
  anchorectl app version export sbom $v --app app \
    --file ./reports/$v/sbom.cdx.json
  anchorectl app version export vulnerabilities $v --app app \
    --file ./reports/$v/vulnerabilities.csv
  anchorectl app version export packages $v --app app \
    --file ./reports/$v/packages.csv
  anchorectl app version export vex $v --app app \
    --file ./reports/$v/vex.cdx.json
  anchorectl app version export policy-compliance $v --app app \
    --file ./reports/$v/policy-compliance.csv
  anchorectl app version export vdr $v --app app \
    --file ./reports/$v/vdr.cdx.json
done
```

Now the diffs that matter for release notes and audit hand-off:

```bash
diff ./reports/v1.0.0/packages.csv ./reports/v1.0.1/packages.csv \
  | head -40
diff ./reports/v1.0.0/vulnerabilities.csv ./reports/v1.0.1/vulnerabilities.csv \
  | head -40
diff ./reports/v1.0.0/policy-compliance.csv ./reports/v1.0.1/policy-compliance.csv
```

The package diff shows the seven Python pins that moved (Flask, requests, PyYAML, urllib3, Jinja2, cryptography, Pillow). The vulnerability diff shows the CVEs that came off the list as a result. Wire those two diffs into your release-notes generator and you have automated "here's what we fixed" copy.

The compliance-CSV pair is the **release-readiness signal**: `v1.0.0`'s file is non-empty (one row per un-waived `stop` finding driving the `Status: fail`), `v1.0.1`'s file is empty (the policy passed cleanly). For an audit ticket or ship/no-ship review, attaching both files is the evidence trail — *here's the state we found, here's the state we shipped, here's the rule book they were measured against.*

> [!TIP]
> The same pattern works for any pair of versions — `v1.0.0` vs `v1.0.0-rc1`, `production` vs `staging`, `last_release` vs `current`. As long as both versions are attached to the same app, the diff is meaningful.

## Phase 3 — Account-wide reports in the Web UI

Per-version exports answer "what about *this* release?" Account-wide reports answer "where across our estate is X true?" — the questions that don't fit cleanly into a single app/version.

The canonical example, straight from the security team's standing list:

> *Which images across our entire account are running a vulnerable version of Log4j?*

Walk through this in the Web UI.

1. **Open the Reports tab.** Navigate to `/reports` in the Web UI. You'll land on the reports list, with any saved reports for this account.
2. **Create a new report.** Click **New Report**. Anchore Enterprise ships templates for the questions teams ask most often — "Critical Vulnerabilities", "Failed Policy Evaluations", "Vulnerabilities by Tag", "Tags by Vulnerability". Pick **Tags by Vulnerability** (the canonical "which tags contain CVE X?" shape).
3. **Filter to the question.** Set the vulnerability filter to `CVE-2021-44228` (the log4j Critical from your Java SBOM). Optionally narrow the time window or the registry/repository.
4. **Run the report.** Anchore Enterprise evaluates the query against every image record in the account. With the v1.0.0 Java SBOM ingested, the Java application asset shows up here — every tag (or asset) that contributes a package matching the CVE.
5. **Save the report.** Click **Save**. Give it a name (`Tags Affected by CVE-2021-44228`). A saved report can be re-run from the list, scheduled (Phase 5), or shared with the team.
6. **Download the result.** Reports support JSON and CSV download. CSV is the format your GRC team wants; JSON is the format your scripts want.

The same UI walk-through applies to the other canonical questions:

| Question | Template |
|---|---|
| All Critical vulnerabilities across the account | *Vulnerabilities by Tag*, severity = Critical |
| Images failing policy evaluation | *Failed Policy Evaluations* |
| Tags newly affected by a given CVE | *Tags by Vulnerability*, with `detected_in_last` |
| Artifacts (PURLs) affected by a CVE | *Artifacts by Vulnerability* |

> [!NOTE]
> The report templates correspond one-to-one to the GraphQL queries we'll meet in Phase 4. The UI is the prettier surface; the API is the programmable one. Both hit the same reports service.

## Phase 4 — GraphQL: the API the UI sits on

Every report in the Web UI is, underneath, a GraphQL query against the reports service at `/v2/reports/graphql` (account-scoped) and `/v2/reports/global/graphql` (cross-account, admin-only). Hitting the API directly is the right call when you want to integrate reporting into your own pipelines — pull a daily snapshot into S3, feed findings into a SIEM, drive a custom dashboard.

Re-run the Log4j question from Phase 3, this time as a GraphQL query:

```bash
read -r -d '' QUERY <<'EOF'
{
  "query": "query Log4jExposure($vuln: VulnerabilityFilter!, $first: Int) { tagsByVulnerability(vulnerability: $vuln, first: $first) { results { tag { name } image { digest } registry { name } repository { name } vulnerabilities { id severity isKev } } pageInfo { nextToken count } } }",
  "variables": {
    "vuln": { "id": "CVE-2021-44228" },
    "first": 50
  }
}
EOF

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/reports/graphql" \
  -d "$QUERY" \
  | jq
```

The response is one page of `tagsByVulnerability` results — each entry has the tag name, image digest, registry, repository, and the matching vulnerabilities (with severity and `isKev`). Pagination follows the standard cursor pattern: take `pageInfo.nextToken`, pass it as `after` on the next call, repeat until `nextToken` is null.

### The queries worth knowing

The schema exposes a focused set of top-level queries. Most reporting needs map to one of these:

| Query | Returns | Common use |
|---|---|---|
| `tagsByVulnerability` | Tags / images contributing a given CVE. | "Which images use vulnerable X?" |
| `imagesByVulnerability` | Image digests + vulnerability matches. | The image-shaped variant of the same question. |
| `artifactsByVulnerability` | Specific package coordinates (PURLs) affected. | "Every place we ship `log4j-core@2.14.1`." |
| `policyEvaluationsByTag` | Per-tag policy evaluation outcomes. | "Which tags currently fail policy?" |
| `metricData` | Aggregate counts and trends. | Dashboards. |
| `runtimeInventoryImagesByVulnerability` | The above questions, scoped to images observed in K8s/ECS runtime inventory. | "Which *running* containers are affected?" |

### Filter inputs

Every "by vulnerability" query takes a `VulnerabilityFilter` plus optional filters for `artifact`, `registry`, `repository`, `tag`, and `image`. The vulnerability filter alone supports:

| Field | Effect |
|---|---|
| `id` | Filter by a specific CVE / GHSA. |
| `severities` | One or more of `Critical`, `High`, `Medium`, `Low`, `Negligible`, `Unknown`. |
| `isKev` | `true` to restrict to CISA Known Exploited Vulnerabilities. |
| `epssScore` | Threshold filter (e.g. `{ gte: 0.5 }`). |
| `willNotFix` | Toggle to exclude entries marked as wontfix in upstream feeds. |
| `inheritedFromBase` | Toggle to exclude base-image-inherited findings (you fix what *your* layer added). |
| `annotationStatus` / `missingAnnotation` | Find findings with or without specific VEX statuses applied. |

Combine them and you get the same prioritisation slices you used in Inspection Phase 3 — but against the entire account, not one version at a time.

> [!TIP]
> For exploration, point a GraphQL client (Insomnia, Postman, Apollo Sandbox) at `/v2/reports/graphql` with HTTP basic auth and the `x-anchore-account` header. Auto-completion against the schema makes building queries much faster than hand-rolling them in `curl`.

## Phase 5 — Scheduled queries

A scheduled query is a stored GraphQL query plus a cron schedule. The reports_worker service runs it on the schedule, persists each execution's result, and (if you've wired up notifications) emits an event when it completes.

The Web UI lets you save any report you've built as a scheduled query — open a saved report, click **Schedule**, pick a frequency, save. Equivalent at the API:

```bash
read -r -d '' MUTATION <<'EOF'
{
  "query": "mutation Schedule($name: String!, $description: String!, $cron: String!, $query: String!, $enabled: Boolean!) { createScheduledQuery(name: $name, description: $description, cronSchedule: $cron, query: $query, enabled: $enabled) { ok scheduledQuery { uuid name cronSchedule enabled } } }",
  "variables": {
    "name": "Daily KEV exposure",
    "description": "Tags affected by any KEV-listed vulnerability, refreshed every morning.",
    "cron": "0 7 * * *",
    "query": "{ tagsByVulnerability(vulnerability: { isKev: true }, first: 200) { results { tag { name } image { digest } vulnerabilities { id severity } } pageInfo { nextToken count } } }",
    "enabled": true
  }
}
EOF

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/reports/graphql" \
  -d "$MUTATION"
```

The schedule string is standard cron (`minute hour day-of-month month day-of-week`). `0 7 * * *` runs at 07:00 every day; `0 */6 * * *` every six hours; `0 7 * * 1` every Monday morning.

### Working with executions

List recent executions of every scheduled query:

```bash
read -r -d '' Q <<'EOF'
{
  "query": "{ scheduledQueryExecutions { results { uuid queryUuid status startedAt finishedAt rowCount } pageInfo { nextToken count } } }"
}
EOF

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/reports/graphql" \
  -d "$Q" \
  | jq
```

Each execution has a status (`queued`, `running`, `complete`, `failed`, `cancelled`), timing fields, and a row count. The persisted result for a complete execution is downloadable as JSON or CSV — the same downloads the Web UI surfaces under the saved report.

To trigger an out-of-band run of a scheduled query (without waiting for the next cron fire), use `executeScheduledQuery` (synchronous, blocks until done) or `executeScheduledQueryAsync` (returns a result UUID immediately).

> [!TIP]
> When a scheduled query completes, the reports_worker emits an event that flows through the same notification plumbing as the image-record subscriptions in the next phase. Configure a webhook endpoint receiving `scheduled_query_complete` events and you get "fresh report ready" deliveries straight into your downstream system — daily JSON drops to S3, Slack pings, automated SIEM ingestion.

## Phase 6 — Subscriptions and notifications

Subscriptions are the **push side of reporting**: instead of asking for a state snapshot on a cadence, you ask Anchore Enterprise to tell you the moment the state changes — *the policy on this tag just started failing*, *a new CVE was just published against software you ship*, *the supplier just re-pushed the image you're tracking*. Scheduled queries (Phase 5) deliver pre-defined reports on a clock; subscriptions deliver state-change reports on event. Both surface into the same event/notification plumbing — webhooks, email, GitHub issues, Jira, Slack, MS Teams, SIEM forwarders — so a team that wires up one usually wires up both.

> [!IMPORTANT]
> In 6.0 alpha, the subscription and event surfaces are still served by the v5 catalog and key on raw image records (registry / repo / tag), not on the app/version asset model. The subscriptions you activate here keep the underlying image record fresh; the v6 asset built on top of that record will reflect the refreshed data the next time you list vulnerabilities or re-run policy evaluation. Bridging subscriptions into the asset model directly is on the roadmap.

### The subscription types

| Type | What it does | Typical use |
|---|---|---|
| `tag_update` | New analysis when the same tag is re-pushed. | Catch supply-chain replacements where someone overwrites `:latest` or `:13`. |
| `vuln_update` | New analysis-pass when feed data changes for a known image. | Catch new CVEs published against software you've already scanned. |
| `policy_eval` | Re-run policy evaluation when the bound policy or the vulnerability picture changes. | Catch findings that newly cross a `stop` threshold. |
| `analysis_update` | Notify when an analysis completes. | Drive downstream pipelines that consume SBOMs. |

`tag_update` was already activated against `docker.io/library/postgres:13` in Visibility Phase 3. Add the other two for the same image — those are the ones that close the "state changed → tell me" loop:

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

### Events and notification endpoints

When a subscription fires it produces an *event*. Events are what get routed to your endpoints. List recent events:

```bash
anchorectl event list
```

Endpoints are configured per-deployment. In 6.0 alpha the management surface for those endpoints is the Web UI under `/system/notifications` and the `system_integrations` API — `anchorectl system integration` only supports `list`, `get`, and `delete`. To add a webhook, navigate to **System → Notifications → Endpoints** in the UI and provide the URL, optional auth header, and the subscription types it should receive. The same endpoint configuration delivers both subscription events and the `scheduled_query_complete` events from Phase 5 — one notification surface, two upstream producers.

> [!TIP]
> A common starter setup for a development team:
>
> - Critical / KEV → page on-call (PagerDuty webhook).
> - New `stop` finding on the production version → Slack #security-alerts.
> - `scheduled_query_complete` for the daily KEV report → daily Slack digest.
>
> All three are the same Anchore subscription / notification plumbing — only the endpoint routing differs.

### See it in the UI

Open the Web UI at `/events`. Each event has a payload (the same JSON you'd see at the API), a timestamp, and the subscription or scheduled query that produced it. When you attach a webhook, that payload is what it'll deliver.

## Phase 7 — Runtime inventory reports

The reporting service has a small set of REST endpoints (and matching GraphQL queries) dedicated to runtime inventory — what's actually running in your Kubernetes and ECS clusters, cross-referenced against the SBOMs and vulnerability matches Anchore Enterprise already has.

These endpoints only return data once you've connected an inventory source: the `anchorectl inventory` agent for Kubernetes, or an ECS inventory ingestion pipeline. The lab's `app@v1.0.0` doesn't have runtime inventory wired up; this phase is a *map of the surface* you can use when it is.

### REST endpoints

```bash
# Cluster + namespace summary
curl -sS \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/reports/kubernetes-clusters-summary" | jq

# Vulnerability summary scoped to the runtime inventory
curl -sS \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/reports/kubernetes-vulnerabilities-summary?severities=critical&severities=high" | jq

# Image summary with policy + vuln filters
curl -sS \
  -u "${ANCHORECTL_USERNAME}:${ANCHORECTL_PASSWORD}" \
  -H "x-anchore-account: admin" \
  "${ANCHORECTL_URL}/v2/reports/kubernetes-images-summary?compliance=fail&severities=critical" | jq
```

### GraphQL queries

The same data is accessible through the GraphQL schema, where you can combine the runtime scope with the vulnerability filters from Phase 4:

| Query | Returns |
|---|---|
| `runtimeInventoryImagesByVulnerability` | Running images affected by a given CVE / severity / KEV / EPSS. |
| `kubernetesRuntimeVulnerabilitiesByNamespace` | Vulnerabilities broken out by K8s namespace. |
| `vulnerabilitiesByKubernetesContainer` | Per-container vulnerability matches. |
| `vulnerabilitiesByEcsContainer` | The ECS equivalent. |
| `runtimeInventoryUnscannedImages` | Running images Anchore Enterprise hasn't analyzed yet — the gap list. |
| `policyEvaluationsByRuntimeInventoryImage` | Compliance state for the running fleet. |

> [!TIP]
> The "unscanned images" query is the underrated one. Compliance lives or dies on coverage — every running container that *isn't* in the catalog is a blind spot. A scheduled query against `runtimeInventoryUnscannedImages` with a webhook into your ticket tracker turns coverage drift into actionable work.

## Recap

You walked the full reporting surface for the two versions of `app` you built across the lab — `v1.0.0` with its un-waived `Status: fail`, and `v1.0.1` with its clean `Status: pass`:

1. Mapped the **two layers** — per-version exports for release hand-offs, account-wide reports for cross-cutting questions — and the alpha-state mismatch where the account-wide layer is still v5.
2. Ran the full **per-version export pipeline** for both `v1.0.0` and `v1.0.1`, including VDR, and diffed the package, vulnerability, and policy-compliance CSVs — the last pair being the audit-grade release-readiness evidence.
3. Built a **"Log4j across the account" report in the Web UI** using the *Tags by Vulnerability* template and saved it.
4. Re-ran the same question against the **reports GraphQL API**, with a tour of the filter inputs and the queries worth knowing.
5. **Scheduled a daily KEV exposure query**, learned how executions land, and noted the notification path for "report ready" events.
6. Activated `vuln_update` and `policy_eval` **subscriptions** on the Postgres tag, surveyed how events flow into the same notification endpoints as scheduled queries, and saw where webhooks land in the Web UI.
7. Surveyed the **runtime inventory reporting surface** — the REST endpoints and the GraphQL queries that scope reports to what's actually running in K8s / ECS.

Useful 5.x → 6.0 mappings:

| 5.x                                                            | 6.0                                                                  |
|----------------------------------------------------------------|----------------------------------------------------------------------|
| Web UI `/reports` with templates and saved reports             | Unchanged — same surface, same templates, same scheduling            |
| `POST /v1/reports/graphql`                                     | `POST /v2/reports/graphql` (and `/v2/reports/global/graphql`)        |
| `anchorectl image vulnerabilities <image>`                     | `app version vuln list <version> --app <app>` for per-version (Inspection Phase 2); GraphQL for account-wide |
| Compliance CSV via UI download                                 | `app version export policy-compliance <version> --app <app>` (introduced in Phase 2)      |
| SBOM hand-off via per-image download                           | `app version export sbom <version> --app <app>` produces a merged release-level SBOM |
| Disclosure docs hand-assembled from VEX + vuln list            | `app version export vdr <version> --app <app>` produces a CycloneDX VDR in one shot |
| Kubernetes runtime reports under `/reports`                    | Unchanged — still the v5 reports service, still keyed on image records |
| `anchorectl subscription activate <image> vuln_update`         | Unchanged — subscriptions are still v5-backed and key on raw images  |
| Notification endpoint config in `/system/notifications`        | Unchanged — same Web UI surface, same payload shapes                 |

**Where to go from here:**

- For programmatic integration patterns (CI/CD gating using exports, SIEM forwarding from scheduled queries, attaching VDR documents to release artifacts), see the [Anchore Enterprise reporting documentation](https://docs.anchore.com/current/docs/vulnerability_management/reports/).
- For the Kubernetes / ECS inventory side, set up `anchorectl inventory` against a cluster and the runtime inventory queries in Phase 7 start returning real data — that's the natural follow-on to this module.
- For the VIPERR loop end-to-end on a different application: start a fresh `app`, run a release through Visibility → Inspection → Policy Enforcement → Remediation → Reporting, and notice how the same six exports and the same account-wide reports surface the new release alongside `v1.0.0` / `v1.0.1` with no extra plumbing.

That closes the VIPERR lab. You've taken a release from "we have an SBOM" through "we know what's in it", "we have rules about it", "we've triaged and shipped a fix", and finally "we can **prove** all of that to anyone who needs to see it" — `v1.0.0`'s compliance trail and disclosure docs for the audit, `v1.0.1`'s clean compliance CSV for the ship-review ticket, the VDR for the customer, the daily KEV report for the security team, the webhook for the oncall engineer. The same five-module shape applies to every release that comes after — only the assets change.
