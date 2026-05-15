# Policy Enforcement

The Inspection module gave you a way to *see* the vulnerabilities and packages across `app@v1.0.0`. Policy enforcement is how you turn that data into a pass/fail signal for releases — codifying the rules your organisation already has ("never ship a Critical", "never ship a CISA-listed exploited vulnerability", "Highs are OK if a fix exists, but log them") into something Anchore Enterprise evaluates automatically every time the version changes.

In Anchore Enterprise 6.0 a **policy** is a JSON bundle of rules. Each rule names a **gate** (the kind of check), a **trigger** (the specific condition), an **action** (`stop`, `warn`, `go`), and **parameters** (the threshold). The bundle is bound to your application; evaluation runs against the version's deduplicated assets and produces a per-rule list of findings.

> [!IMPORTANT]
> This module assumes you completed the [Visibility module](visibility.md) and the [Inspection module](inspection.md). It uses the same `app`, `v1.0.0` version, and the four assets attached to it.

> [!NOTE]
> **Application Policies:** in 6.0 the only gate applied to applications is `vulnerabilities` (with three triggers — `package`, `denylist`, `stale_feed_data`) plus a small `always` gate used internally. 

## How this lab module is structured

Five phases, fully sequential:

1. **Understand the policy model** — bundles, rule sets, gates, triggers, allowlists, app-level binding.
2. **Survey the policies on the system** — list and read what's already loaded.
3. **Author and import a custom policy** — bring your organisation's rules in via JSON.
4. **Bind the policy to your application** — make it the active policy for `app`.
5. **Evaluate `v1.0.0` and read the findings** — see what passes, what stops, what warns.

## Phase 1 — Understand the policy model

A policy bundle is a JSON document with three parts that matter for this module:

| Part | What it does |
|---|---|
| `rule_sets` | One or more named groups of rules. Each rule set names an `artifact_type` (today, always `sbom`) and contains rules; each rule names a `gate`, a `trigger`, an `action` (`STOP`, `WARN`, `GO`), and a list of `params`. Rule sets are evaluated against the version's assets that match the named `artifact_type`. |
| `allowlists` | Items that suppress specific findings *inside the policy itself* — usually by `(gate, trigger_id)` with an optional expiry. Useful for blanket exceptions that should travel with the policy bundle. |
| `sbom_mappings` | Which rule sets and allowlists apply to which artifacts. In simple deployments you'll have one mapping covering everything; large deployments use mappings to apply different rule sets to different SBOM names/versions. |

> [!NOTE]
> Policy bundles in 6.0 alpha are stored and managed by the v5 catalog (under `anchorectl policy …`). Anchore Enterprise's component_catalog service reads a bundle from there, parses it into the v6 model, and runs evaluation against the asset model. v5 field names (`whitelists`, `policies`) are auto-aliased to v6 names (`allowlists`, `rule_sets`), so existing bundles import unchanged. The one v6-only field you must set on each rule set is `artifact_type: "sbom"` — the executable policy skips any rule set whose `artifact_type` isn't `sbom`, so a bundle without it imports cleanly but evaluates to zero findings.

**Binding.** A policy applies to an application either through:

- **App-level binding** — a specific policy ID is set on the application via `anchorectl app update <app> --policy-id <id>`. This wins over the account default.
- **Account-level activation** — `anchorectl policy activate <id>` marks one policy as the account's default. Applications without their own policy fall back to it.

**Outcomes.** Every rule produces zero or more findings. The version-level outcome is the most severe action that fired:

- `stop` → the version fails policy.
- `warn` → the version passes with warnings.
- nothing fired → the version passes cleanly.

## Phase 2 — Survey the policies on the system

Before authoring our own bundle, see what's already loaded. Anchore Enterprise ships several reference policies you can use as-is or as a starting point:

```bash
anchorectl policy list
```

Output:

```
 ✔ Fetched policies
┌───────────────────────────────────────┬────────────────────────┬────────┬──────────────────────┐
│ NAME                                  │ POLICY ID              │ ACTIVE │ UPDATED              │
├───────────────────────────────────────┼────────────────────────┼────────┼──────────────────────┤
│ Anchore Enterprise - Secure v20260101 │ anchore_secure_default │ true   │ 2026-05-13T11:24:28Z │
└───────────────────────────────────────┴────────────────────────┴────────┴──────────────────────┘
```

Any of these can serve as a starting point — the security-only and CIS bundles are common templates customers extend. For the rest of this module we'll author our own from scratch so you see exactly what goes into a bundle.

## Phase 3 — Author and import a custom policy

For the rest of the module we'll use a small custom policy bundled at `./assets/policies/lab-policy.json`. Open it and you'll see two rules in one `sbom`-typed rule set, both on the `vulnerabilities` gate:

| Rule (by behaviour) | Gate / trigger | Action | What it fires on |
|---|---|---|---|
| Stop-on-KEV | `vulnerabilities / package` | `STOP` | Any package match for a vulnerability in the CISA Known Exploited Vulnerabilities catalog, regardless of severity. |
| Stop-on-High-or-above | `vulnerabilities / package` | `STOP` | Any package with a High or Critical severity match. |

> [!NOTE]
> The bundle's `rule_set` and `rule` IDs are UUIDs assigned by the catalog rather than human-friendly slugs. The UUIDs are stable across re-imports of the same bundle; we'll refer to rules by their behaviour throughout this module and only quote IDs where the API output forces us to.

Each rule is a small object — here's the Stop-on-High-or-above rule from the bundle:

```json
{
  "id": "d7b4a6af-107f-4b6d-be00-bb06e26b2350",
  "gate": "vulnerabilities",
  "trigger": "package",
  "action": "STOP",
  "description": "",
  "params": [
    {"name": "package_type", "value": "all"},
    {"name": "severity", "value": "high"},
    {"name": "severity_comparison", "value": ">="}
  ]
}
```

The `vulnerabilities / package` trigger has a rich set of parameters available — `severity_comparison` (`=`, `!=`, `<`, `>`, `<=`, `>=`), CVSS v3 base/exploitability/impact comparisons and thresholds, EPSS score and percentile comparisons, `fix_available`, `vendor_only`, `max_days_since_creation`, `max_days_since_fix`, and `known_exploited_vulnerability` (the KEV flag). The bundle in `lab-policy.json` only uses three (`package_type`, `severity` + `severity_comparison`, `known_exploited_vulnerability`); build your real policies up from these primitives.

Import the bundle:

```bash
anchorectl policy add --input ./assets/policies/lab-policy.json
```

Output:

```
 ✔ Added policy
Name: VIPERR Lab Policy
Policy Id: viperr-lab-policy
Active: false
Updated: 2026-05-14T13:34:11Z
```

Confirm it's now in the catalog:

```bash
anchorectl policy list
```

You should see `viperr-lab-policy` in the table alongside the reference policies from Phase 2.

> [!TIP]
> To iterate on the bundle, edit the JSON locally and re-import with `anchorectl policy update --input ./assets/policies/lab-policy.json`. Policy IDs are stable across updates; the rule set bodies and allowlists get replaced.

## Phase 4 — Bind the policy to your application

Two ways to make `viperr-lab-policy` the policy that gets evaluated against `app`:

**Option A — App-level binding (preferred):** set the policy on the application directly. This is the explicit, traceable choice — the policy travels with the app record and is visible in `app get`.

```bash
anchorectl app update app --policy-id viperr-lab-policy
```

Verify:

```bash
anchorectl app get app -o json | jq '{name, policyId}'
```

**Option B — Account-level activation:** make `viperr-lab-policy` the account default. Apps without their own `policy-id` will use it.

```bash
anchorectl policy activate viperr-lab-policy
```

Output:

```
 ✔ Activate policy
Name: VIPERR Lab Policy
Policy Id: viperr-lab-policy
Active: true
Updated: 2026-05-14T13:36:48Z
```

For this module use **Option A** — it makes the binding explicit and lets the existing account default keep applying to anything else.

> [!NOTE]
> Changing the active policy doesn't re-evaluate prior versions on its own. Existing `app version policy status get` results were produced against the policy that was active *at the time of evaluation*; the next evaluation cycle will use the new binding.

## Phase 5 — Evaluate `v1.0.0` and read the findings

Anchore Enterprise evaluates policy as an asynchronous job — like SBOM ingest and image analysis. Unlike those jobs, you don't have to enqueue a policy evaluation by hand. When you call `app version policy status get` or `app version policy findings list` for a version that hasn't been evaluated against the current policy digest yet, Anchore Enterprise auto-enqueues a high-priority evaluation job for you and returns a `409` telling you to retry shortly. Subsequent calls return the stored result.

Ask for the version-level status:

```bash
anchorectl app version policy status get v1.0.0 --app app
```

The first call after binding the policy returns an error saying "Policy evaluation is stale or missing. … Retry after re-evaluation completes." That's the auto-enqueue — Anchore Enterprise has just queued an `evaluate-policy` job for `v1.0.0`. Track it like any other v6 job:

```bash
anchorectl app job list app --status processing
anchorectl app job list app --status complete
```

Once the most recent `evaluate-policy` entry is `complete`, re-run the status call:

```bash
anchorectl app version policy status get v1.0.0 --app app
```

Output:

```
 ✔ Fetched status
Policy ID: viperr-lab-policy
Policy Name: VIPERR Lab Policy
Status: fail
```

`Status: fail` means at least one `STOP` rule fired. To see *which* rules fired and on *which* findings, list the findings:

```bash
anchorectl app version policy findings list v1.0.0 --app app
```

Output (truncated):

```
 ✔ List findings
┌──────────────┬──────┬────────────────┬───────────┬─────────────┬──────────────────────────────────────────────┐
│ RULE         │ ACTION│ VULNERABILITY  │ PACKAGE   │ ASSET       │ DETAIL                                       │
├──────────────┼──────┼────────────────┼───────────┼─────────────┼──────────────────────────────────────────────┤
│ 17ed63bd-…   │ stop │ CVE-2021-44228 │ log4j-core│ my-java-app │ Listed in CISA KEV catalog                   │
│ d7b4a6af-…   │ stop │ CVE-2021-44228 │ log4j-core│ my-java-app │ Critical, fix 2.15.0 available               │
│ d7b4a6af-…   │ stop │ CVE-2020-14343 │ PyYAML    │ my-python-…│ Critical, fix 5.4 available                  │
│ d7b4a6af-…   │ stop │ CVE-2018-18074 │ requests  │ my-python-…│ High, fix 2.20.0 available                   │
│ d7b4a6af-…   │ stop │ CVE-2019-10906 │ Jinja2    │ my-python-…│ High, fix 2.10.1 available                   │
│ ...          │ ...  │ ...            │ ...       │ ...         │ ...                                          │
└──────────────┴──────┴────────────────┴───────────┴─────────────┴──────────────────────────────────────────────┘
```

`17ed63bd-…` is Stop-on-KEV; `d7b4a6af-…` is Stop-on-High-or-above. Both fire on `CVE-2021-44228` (log4j) — KEV catches it once for the KEV flag, severity catches it again as a Critical. Every other High/Critical match shows up under the severity rule.

> [!NOTE]
> Findings serialize `action` as a lowercased string (`"stop"` / `"warn"` / `"go"`) even though the policy bundle JSON requires the uppercased enum (`STOP` / `WARN` / `GO`). The v5 catalog stores the bundle in one case; the v6 component_catalog returns findings in the other. Filter on the lowercase form when querying findings output.

Each finding cites the rule that fired, the action, the vulnerability, the package, and which asset contributed the package. JSON output gives you the full detail blob — explore it for fields like the rule ID, the matched vulnerability, the package coordinates, and any allowlist state attached to the finding:

```bash
anchorectl app version policy findings list v1.0.0 --app app -o json \
  | jq '.[] | select(.action == "stop")'
```

> [!TIP]
> `findings list` is paginated under the hood — for a large deployment, prefer `-o json` and process programmatically.

> [!IMPORTANT]
> The auto-enqueue fires only when the **policy digest has changed** (e.g. you re-imported the bundle with `policy update --input ...`) or when no evaluation exists for the version yet. Changes to the version itself (attaching new assets, for instance) don't bump the digest, so subsequent `status get` calls return the cached evaluation until either the digest moves or you trigger a fresh evaluation explicitly via `POST /v2/apps/<id>/jobs/evaluate-policy`. The Remediation module shows that explicit-trigger pattern.

## Recap

You walked the full policy enforcement loop for `app@v1.0.0`:

1. Saw what a 6.0 **policy bundle** is — rule sets, gates, triggers, allowlists, mappings — and how it binds to applications.
2. Surveyed the **policies already on the system** with `policy list / get`.
3. Authored and imported your own bundle (`viperr-lab-policy`) with two rules on the vulnerabilities gate.
4. **Bound** it to `app` via `app update --policy-id`.
5. Triggered an **evaluation**, read the version-level **status**, and inspected the per-rule **findings**.

Useful 5.x → 6.0 mappings:

| 5.x                                        | 6.0                                                                  |
|--------------------------------------------|----------------------------------------------------------------------|
| `image check <image> --detail`             | `app version policy findings list <version> --app <app>`             |
| `image check -f <image>` (exit on fail)    | `app version policy status get <version> --app <app>` + your own gating script |
| `image check -p <policy-id>`               | `app update <app> --policy-id <id>` then evaluate                    |
| Policy bundle JSON (`whitelists`, `policies`) | Same JSON; v5 names auto-aliased to `allowlists` / `rule_sets`     |
| `policy add/get/list/update/activate`      | Unchanged — still managed via the v5 catalog                          |
| Allowlists (in-bundle) for waivers         | Allowlists (in-bundle) — same shape, same purpose                    |

**CI/CD pattern.** A pipeline gate is the same shape as the manual flow: ingest your assets (Visibility), call `app version policy status get` — which auto-enqueues an evaluation when one is needed — poll `anchorectl app job list app --status processing,complete` until the latest `evaluate-policy` job is done, then re-read `app version policy status get` for the final outcome. Treat `Status: fail` as exit-1 to break the build. When you need an explicit re-trigger (e.g. after attaching new assets to an existing version), `POST /v2/apps/<id>/jobs/evaluate-policy` is the manual escape hatch — the Remediation module walks through it. The VIPERR Remediation module also covers feeding the resulting findings back to developers via webhook, Slack, or issue tracker.

## Next Module

Next: [Remediation](remediation.md) — closing the loop from "we found something" to "we did something about it."
