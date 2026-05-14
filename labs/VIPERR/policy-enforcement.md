# Policy Enforcement

The Inspection module gave you a way to *see* the vulnerabilities and packages across `app@v1.0.0`. Policy enforcement is how you turn that data into a pass/fail signal for releases — codifying the rules your organisation already has ("never ship a Critical", "never ship a CISA-listed exploited vulnerability", "Highs are OK if a fix exists, but log them") into something Anchore Enterprise evaluates automatically every time the version changes.

In Anchore Enterprise 6.0 a **policy** is a JSON bundle of rules. Each rule names a **gate** (the kind of check), a **trigger** (the specific condition), an **action** (`stop`, `warn`, `go`), and **parameters** (the threshold). The bundle is bound to your application; evaluation runs against the version's deduplicated assets and produces a per-rule list of findings.

> [!IMPORTANT]
> This module assumes you completed the [Visibility module](visibility.md) and the [Inspection module](inspection.md). It uses the same `app`, `v1.0.0` version, the four assets attached to it, and the VEX annotation you recorded against `CVE-2019-10906` in `Jinja2 2.10`.

> [!NOTE]
> **Alpha-state caveat:** in 6.0 alpha the only ported gate is `vulnerabilities` (with three triggers — `package`, `denylist`, `stale_feed_data`) plus a small `always` gate used internally. v5.x had many more gates (Dockerfile, files, secrets, malware, packages, …); those are expected back as 6.0 progresses. Everything in this module is built around the gate that's available today and applies cleanly to the broader gate set when it lands.

## How this lab module is structured

Six phases, fully sequential:

1. **Understand the policy model** — bundles, rule sets, gates, triggers, allowlists, app-level binding.
2. **Survey the policies on the system** — list and read what's already loaded.
3. **Author and import a custom policy** — bring your organisation's rules in via JSON.
4. **Bind the policy to your application** — make it the active policy for `app`.
5. **Evaluate `v1.0.0` and read the findings** — see what passes, what stops, what warns.
6. **Suppress with VEX, then export the compliance report** — round-trip from the Inspection module's VEX into a policy outcome.

## Phase 1 — Understand the policy model

A policy bundle is a JSON document with three parts that matter for this module:

| Part | What it does |
|---|---|
| `rule_sets` | One or more named groups of rules. Each rule names a `gate`, a `trigger`, an `action` (`stop`, `warn`, `go`), and a list of `params`. Rule sets are evaluated against assets attached to a version. |
| `allowlists` | Items that suppress specific findings *inside the policy itself* — usually by `(gate, trigger_id)` with an optional expiry. Useful for blanket exceptions that should travel with the policy bundle. |
| `sbom_mappings` | Which rule sets and allowlists apply to which artifacts. In simple deployments you'll have one mapping covering everything; large deployments use mappings to apply different rule sets to different SBOM names/versions. |

> [!NOTE]
> Policy bundles in 6.0 alpha are stored and managed by the v5 catalog (under `anchorectl policy …`). Anchore Enterprise's component_catalog service reads a bundle from there, parses it into the v6 model, and runs evaluation against the asset model. v5 field names (`whitelists`, `policies`) are auto-aliased to v6 names (`allowlists`, `rule_sets`), so existing bundles import unchanged.

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

For the rest of the module we'll use a small custom policy bundled at `./assets/policies/lab-policy.json`. Open it and you'll see three rules in one rule set, all on the `vulnerabilities` gate:

| Rule ID | Gate / trigger | Action | What it fires on |
|---|---|---|---|
| `stop-on-critical` | `vulnerabilities / package` | `stop` | Any package with a Critical-severity match. |
| `warn-high-with-fix` | `vulnerabilities / package` | `warn` | High-severity matches that already have a fix available — easy wins, surfaced but not blocking. |
| `stop-on-kev` | `vulnerabilities / package` | `stop` | Any vulnerability in the CISA Known Exploited Vulnerabilities catalog, regardless of severity. |

Each rule is a small object:

```json
{
  "id": "stop-on-critical",
  "gate": "vulnerabilities",
  "trigger": "package",
  "action": "stop",
  "params": [
    {"name": "package_type",        "value": "all"},
    {"name": "severity_comparison", "value": ">="},
    {"name": "severity",            "value": "critical"}
  ]
}
```

The `vulnerabilities / package` trigger has a rich set of parameters available — `severity_comparison` (`=`, `!=`, `<`, `>`, `<=`, `>=`), CVSS v3 base/exploitability/impact comparisons and thresholds, EPSS score and percentile comparisons, `fix_available`, `vendor_only`, `max_days_since_creation`, `max_days_since_fix`, and `known_exploited_vulnerability` (the KEV flag). The bundle in `lab-policy.json` only uses three; build your real policies up from these primitives.

Import the bundle:

```bash
anchorectl policy add --input ./assets/policies/lab-policy.json
```

Output:

```
 ✔ Added policy
Policy Id: viperr-lab-policy
Name: VIPERR Lab Policy
Active: false
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
anchorectl app get app -o json | jq '{name, active_policy_id}'
```

**Option B — Account-level activation:** make `viperr-lab-policy` the account default. Apps without their own `policy-id` will use it.

```bash
anchorectl policy activate viperr-lab-policy
```

For this module use **Option A** — it makes the binding explicit and lets the existing account default keep applying to anything else.

> [!NOTE]
> Changing the active policy doesn't re-evaluate prior versions on its own. Existing `app version policy status get` results were produced against the policy that was active *at the time of evaluation*; the next evaluation cycle will use the new binding.

## Phase 5 — Evaluate `v1.0.0` and read the findings

Anchore Enterprise evaluates policy as an asynchronous job — like SBOM ingest and image analysis. There's no anchorectl `policy evaluate` command in 6.0 alpha yet, so we trigger the evaluation by calling the API directly and then read the results with the CLI.

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

The response contains a job ID. Track it like any other v6 job:

```bash
anchorectl app job list app --status processing
anchorectl app job list app --status complete
```

Once the evaluate-policy job finishes, fetch the version-level outcome:

```bash
anchorectl app version policy status get v1.0.0 --app app
```

Output:

```
 ✔ Got policy status
Status: fail
Last Evaluated: 2026-05-07T09:42:11Z
Policy ID: viperr-lab-policy
Policy Digest: sha256:a4f9…
```

`Status: fail` means at least one `stop` rule fired. To see *which* rules fired and on *which* findings, list the findings:

```bash
anchorectl app version policy findings list v1.0.0 --app app
```

Output (truncated):

```
 ✔ List findings
┌──────────────────┬──────┬────────────────┬───────────┬─────────────┬──────────────────────────────────────────────┐
│ RULE             │ ACTION│ VULNERABILITY  │ PACKAGE   │ ASSET       │ DETAIL                                       │
├──────────────────┼──────┼────────────────┼───────────┼─────────────┼──────────────────────────────────────────────┤
│ stop-on-critical │ stop │ CVE-2021-44228 │ log4j-core│ my-java-app │ Critical, fix 2.15.0 available, KEV          │
│ stop-on-critical │ stop │ CVE-2020-14343 │ PyYAML    │ my-python-…│ Critical, fix 5.4 available                  │
│ stop-on-kev      │ stop │ CVE-2021-44228 │ log4j-core│ my-java-app │ Listed in CISA KEV catalog                   │
│ warn-high-with-… │ warn │ CVE-2018-18074 │ requests  │ my-python-…│ High, fix 2.20.0 available                   │
│ warn-high-with-… │ warn │ CVE-2019-10906 │ Jinja2    │ my-python-…│ High, fix 2.10.1 available                   │
│ ...              │ ...  │ ...            │ ...       │ ...         │ ...                                          │
└──────────────────┴──────┴────────────────┴───────────┴─────────────┴──────────────────────────────────────────────┘
```

Each finding cites the rule that fired, the action, the vulnerability, the package, and which asset contributed the package. JSON output gives you the full detail blob (CVSS, EPSS, fix info, the `vex_status` if any) per finding:

```bash
anchorectl app version policy findings list v1.0.0 --app app -o json \
  | jq '.[] | select(.action == "stop") | {rule_id, vulnerability_id, package_name, package_version, asset_name}'
```

> [!TIP]
> `findings list` is paginated under the hood — for a large deployment, prefer `-o json` and process programmatically. The CSV export in Phase 6 is the right shape for hand-off to a security team or GRC tool.

## Phase 6 — Suppress with VEX, then export the compliance report

In the Inspection module you marked `CVE-2019-10906` in `Jinja2 2.10` as `not_affected / vulnerable_code_not_in_execute_path` — recording that the vulnerable code path isn't reachable in the demo Python app. Policy evaluation is VEX-aware: a `not_affected` annotation suppresses the matching finding so a triaged-and-justified vulnerability doesn't keep failing your pipeline.

Re-trigger the evaluation (same `curl` call as Phase 5) and re-list the findings:

```bash
anchorectl app version policy findings list v1.0.0 --app app -o json \
  | jq '.[] | select(.vulnerability_id == "CVE-2019-10906")'
```

The result is empty — the rule didn't fire on that match because the VEX annotation marked it as `not_affected`. Other High-with-fix findings still surface (we didn't VEX them); only the one you explicitly triaged was suppressed.

> [!NOTE]
> Allowlists in the policy bundle (`allowlists` field) and VEX annotations on the version both suppress findings, but they're for different purposes. **Use allowlists** for blanket, policy-wide exceptions that travel with the bundle ("we never fail on this one CVE in this one trigger"). **Use VEX annotations** for per-version, evidence-backed `not_affected` decisions with justifications. The Remediation module covers when to reach for each.

Finally, export the compliance report — the canonical artifact for an audit, a ticket attachment, or a ship/no-ship review:

```bash
anchorectl app version export policy-compliance v1.0.0 \
  --app app \
  --file ./app-v1.0.0-policy-compliance.csv
```

The CSV has one row per finding, with rule, action, vulnerability, package, asset, fix info, and any VEX status — the same data the `findings list` command returns, in a format every tool downstream knows how to read.

## Recap

You walked the full policy enforcement loop for `app@v1.0.0`:

1. Saw what a 6.0 **policy bundle** is — rule sets, gates, triggers, allowlists, mappings — and how it binds to applications.
2. Surveyed the **policies already on the system** with `policy list / get`.
3. Authored and imported your own bundle (`viperr-lab-policy`) with three rules on the vulnerabilities gate.
4. **Bound** it to `app` via `app update --policy-id`.
5. Triggered an **evaluation**, read the version-level **status**, and inspected the per-rule **findings**.
6. Saw a **VEX annotation suppress** a finding without changing the policy itself, and exported the **compliance report** as CSV.

Useful 5.x → 6.0 mappings:

| 5.x                                        | 6.0                                                                  |
|--------------------------------------------|----------------------------------------------------------------------|
| `image check <image> --detail`             | `app version policy findings list <version> --app <app>`             |
| `image check -f <image>` (exit on fail)    | `app version policy status get <version> --app <app>` + your own gating script |
| `image check -p <policy-id>`               | `app update <app> --policy-id <id>` then evaluate                    |
| Policy bundle JSON (`whitelists`, `policies`) | Same JSON; v5 names auto-aliased to `allowlists` / `rule_sets`     |
| `policy add/get/list/update/activate`      | Unchanged — still managed via the v5 catalog                          |
| Allowlists (in-bundle) for waivers         | Allowlists *or* VEX annotations (`app version vex …`) per-version    |

**CI/CD pattern.** A pipeline gate is the same shape as the manual flow: ingest your assets (Visibility), call `POST /jobs/evaluate-policy`, poll `app job` until complete, then read `app version policy status get -o id`. Treat `Status: fail` as exit-1 to break the build. The VIPERR Remediation module covers feeding the resulting findings back to developers via webhook, Slack, or issue tracker.

## Next Module

Next: [Remediation](remediation.md) — closing the loop from "we found something" to "we did something about it."
