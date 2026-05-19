# Reporting

By the end of Remediation, `app` has two versions with opposite policy verdicts: `v1.0.0` is `Status: fail` on the un-waived findings, and `v1.0.1` is `Status: pass` after the Python dependency upgrade. Reporting is how you turn that state into **evidence other people can act on** — the compliance CSV that proves `v1.0.1` is ship-ready for an audit ticket, the CycloneDX VDR that hands the disposition to a customer or regulator, the release-level SBOM that travels with the artifact, the "everything failing policy across the account" dashboard for the security team, the daily CSV that drops into a SIEM, the Kubernetes runtime inventory snapshot attached to a change ticket.

> [!IMPORTANT]
> This module assumes you completed the [Visibility](visibility.md), [Inspection](inspection.md), [Policy Enforcement](policy-enforcement.md), and [Remediation](remediation.md) modules. It uses the same `app`, the `v1.0.0` and `v1.0.1` versions, the four assets attached to `v1.0.0`, the Python asset attached to `v1.0.1`, the VEX annotations recorded against `v1.0.0`, and the `viperr-lab-policy` bundle with its log4j allowlist and 14-day grace rule.

## How this lab module is structured

Five phases. The first two pull together the per-version exports you've already used into a release workflow; the rest cover the account-wide reporting story plus the push-side notifications that pair with it.

1. **The 6.0 reporting story** — two layers (per-version exports vs account-wide reports) and when to reach for each.
2. **Per-version exports across a release line** — the six anchorectl exports (SBOM, vulnerabilities, packages, VEX, policy-compliance, VDR) and which audience each one is shaped for.
3. **Account-wide reports in the Web UI** — build a "Log4j across the whole account" report from the canonical questions security teams keep asking.
4. **Subscriptions and notifications** — push-side reporting; tell-me-when state changes on images / repos.
5. **Runtime inventory reports** — Kubernetes / ECS summaries when you've connected an inventory agent.

## Phase 1 — The 6.0 reporting story

Reporting in Anchore Enterprise 6.0 lives at two layers, and the right answer for any given hand-off is usually "use the layer at the right scope."

| Layer | Scope | Surface | Best for |
|---|---|---|---|
| **Per-version exports** | One application + one version. | `anchorectl app version export <type> VERSION --app APP` | Release-level hand-offs: "the SBOM/VDR/VEX for v1.0.1", "the compliance report for the audit ticket". |
| **Account-wide reports** | Every image, asset, and tag in the account. | Web UI under `/reports`. | Cross-cutting questions: "which images use vulnerable Log4j", "show all critical findings across every app". |

> [!NOTE]
> Account-wide reports in 6.0 alpha are still served by the v5 reports service and key on tags / images rather than the v6 app/version asset model. A v6-native reporting surface is on the roadmap; for now expect the vocabulary mismatch when you move between the per-version CLI and the account-wide UI.

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

## Phase 3 — Account-wide reports in the Web UI

Per-version exports answer "what about *this* release?" Account-wide reports answer "where across our estate is X true?" — the questions that don't fit cleanly into a single app/version.

The canonical example, straight from the security team's standing list:

> *Which images across our entire account are running a vulnerable version of Log4j?*

Walk through this in the Web UI.

1. **Open the Reports tab.** Navigate to `/reports` in the Web UI. You'll land on the reports list, with any saved reports for this account.
2. **Create a new report.** Click **New Report**. Anchore Enterprise ships templates for the questions teams ask most often — "Critical Vulnerabilities", "Failed Policy Evaluations", "Vulnerabilities by Tag", "Tags by Vulnerability". Pick **Tags by Vulnerability** (the canonical "which tags contain CVE X?" shape).
3. **Filter to the question.** Set the vulnerability filter to `CVE-2021-44228` (the log4j Critical from your Java SBOM). Optionally narrow the time window or the registry/repository.
4. **Run the report.** Anchore Enterprise evaluates the query against every image record in the account. With the v1.0.0 Java SBOM ingested, the Java application asset shows up here — every tag (or asset) that contributes a package matching the CVE.
5. **Save the report.** Click **Save**. Give it a name (`Tags Affected by CVE-2021-44228`). A saved report can be re-run from the list or shared with the team.
6. **Download the result.** Reports support JSON and CSV download. CSV is the format your GRC team wants; JSON is the format your scripts want.

The same UI walk-through applies to the other canonical questions:

| Question | Template |
|---|---|
| All Critical vulnerabilities across the account | *Vulnerabilities by Tag*, severity = Critical |
| Images failing policy evaluation | *Failed Policy Evaluations* |
| Tags newly affected by a given CVE | *Tags by Vulnerability*, with `detected_in_last` |
| Artifacts (PURLs) affected by a CVE | *Artifacts by Vulnerability* |

## Phase 4 — Subscriptions and notifications

Subscriptions are the **push side of reporting**: instead of asking for a state snapshot on demand, you ask Anchore Enterprise to tell you the moment the state changes — *the policy on this tag just started failing*, *a new CVE was just published against software you ship*, *the supplier just re-pushed the image you're tracking*. The state-change event flows into the same notification plumbing the Web UI uses for any other report event — webhooks, email, GitHub issues, Jira, Slack, MS Teams, SIEM forwarders.

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

Endpoints are configured per-deployment. In 6.0 alpha the management surface for those endpoints is the Web UI under `/system/notifications` and the `system_integrations` API — `anchorectl system integration` only supports `list`, `get`, and `delete`. To add a webhook, navigate to **System → Notifications → Endpoints** in the UI and provide the URL, optional auth header, and the subscription types it should receive.

> [!TIP]
> A common starter setup for a development team:
>
> - Critical / KEV → page on-call (PagerDuty webhook).
> - New `stop` finding on the production version → Slack #security-alerts.
> - Daily digest of any newly-failing tag → email to the application team.
>
> All three are the same Anchore subscription / notification plumbing — only the endpoint routing differs.

### See it in the UI

Open the Web UI at `/events`. Each event has a payload (the same JSON you'd see at the API), a timestamp, and the subscription that produced it. When you attach a webhook, that payload is what it'll deliver.

## Phase 5 — Runtime inventory reports

The reporting service has a small set of REST endpoints dedicated to runtime inventory — what's actually running in your Kubernetes and ECS clusters, cross-referenced against the SBOMs and vulnerability matches Anchore Enterprise already has.

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

The same data is surfaced under the Web UI's runtime inventory views once you've connected an inventory source. The "unscanned images" view is the underrated one — every running container that *isn't* in the catalog is a coverage blind spot, and the UI lets you see and triage that gap directly.

## Recap

You walked the full reporting surface for the two versions of `app` you built across the lab — `v1.0.0` with its un-waived `Status: fail`, and `v1.0.1` with its clean `Status: pass`:

1. Mapped the **two layers** — per-version exports for release hand-offs, account-wide reports for cross-cutting questions — and the alpha-state mismatch where the account-wide layer is still v5.
2. Walked the **six per-version exports** — SBOM, vulnerability CSV, package CSV, VEX, policy-compliance CSV, and VDR — and saw which audience each one is shaped for.
3. Built a **"Log4j across the account" report in the Web UI** using the *Tags by Vulnerability* template and saved it.
4. Activated `vuln_update` and `policy_eval` **subscriptions** on the Postgres tag and saw where the notification endpoints land in the Web UI.
5. Surveyed the **runtime inventory reporting surface** — the REST endpoints and the Web UI views that scope reports to what's actually running in K8s / ECS.

Useful 5.x → 6.0 mappings:

| 5.x                                                            | 6.0                                                                  |
|----------------------------------------------------------------|----------------------------------------------------------------------|
| Web UI `/reports` with templates and saved reports             | Unchanged — same surface, same templates                             |
| `anchorectl image vulnerabilities <image>`                     | `app version vuln list <version> --app <app>` for per-version (Inspection Phase 2); the Web UI for account-wide |
| Compliance CSV via UI download                                 | `app version export policy-compliance <version> --app <app>` (introduced in Phase 2)      |
| SBOM hand-off via per-image download                           | `app version export sbom <version> --app <app>` produces a merged release-level SBOM |
| Disclosure docs hand-assembled from VEX + vuln list            | `app version export vdr <version> --app <app>` produces a CycloneDX VDR in one shot |
| Kubernetes runtime reports under `/reports`                    | Unchanged — still the v5 reports service, still keyed on image records |
| `anchorectl subscription activate <image> vuln_update`         | Unchanged — subscriptions are still v5-backed and key on raw images  |
| Notification endpoint config in `/system/notifications`        | Unchanged — same Web UI surface, same payload shapes                 |

**Where to go from here:**

- For programmatic integration patterns (CI/CD gating using exports, attaching VDR documents to release artifacts), see the [Anchore Enterprise reporting documentation](https://docs.anchore.com/current/docs/vulnerability_management/reports/).
- For the Kubernetes / ECS inventory side, set up `anchorectl inventory` against a cluster and the runtime inventory views in Phase 5 start populating with real data — that's the natural follow-on to this module.
- For the VIPERR loop end-to-end on a different application: start a fresh `app`, run a release through Visibility → Inspection → Policy Enforcement → Remediation → Reporting, and notice how the same six exports and the same account-wide reports surface the new release alongside `v1.0.0` / `v1.0.1` with no extra plumbing.

That closes the VIPERR lab. You've taken a release from "we have an SBOM" through "we know what's in it", "we have rules about it", "we've triaged and shipped a fix", and finally "we can **prove** all of that to anyone who needs to see it" — `v1.0.0`'s compliance trail and disclosure docs for the audit, `v1.0.1`'s clean compliance CSV for the ship-review ticket, the VDR for the customer, the saved Web UI report for the security team, the webhook for the oncall engineer. The same five-module shape applies to every release that comes after — only the assets change.
