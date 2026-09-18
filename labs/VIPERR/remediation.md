# Remediation

The Policy Enforcement module turned the inspection data into pass/fail findings for `app@v1.0.0` — `Status: fail`, with the bundle's two rules between them stopping on `CVE-2021-44228` (log4j-core, caught both as a CISA KEV match and as a Critical-severity match), `CVE-2020-14343` (PyYAML, Critical), and every other High in the Python application. Remediation is how you close those findings out: triage decisions for the ones you can defend keeping, and a new version that actually fixes the rest.

In Anchore Enterprise 6.0 there are two complementary mechanisms for triage decisions before code changes, and one mechanism for when code does change:

| Mechanism | Scope | When to reach for it |
|---|---|---|
| **VEX annotations** | Per app version. | Evidence-backed, release-specific judgement — "this code path isn't reachable in *this* build", "we've triaged it and it's on the roadmap for next release." |
| **Policy allowlists** | Per policy bundle. | Blanket, policy-wide exception — "we never fail on this CVE in this trigger", "this dependency is supplier-managed and tracked elsewhere." |
| **New app version** | Per release. | You actually change the artifact: a bumped dependency, a different base image, a new SBOM from upstream. |

> [!IMPORTANT]
> This module assumes you completed the [Visibility](visibility.md), [Inspection](inspection.md), and [Policy Enforcement](policy-enforcement.md) modules. It uses the same `app`, the `v1.0.0` version, the four assets attached to it, and the `viperr-lab-policy` bundle bound to `app`.

**VEX is per-version.** An annotation you record against `(CVE-2019-10906, Jinja2, 2.10)` under `v1.0.0` does **not** silently carry forward to `v1.0.1`. Each release is its own assessment. Use VEX when the judgement is evidence-backed and specific to a release.

**Allowlists are per-bundle.** Entries live in the policy bundle's `allowlists` array and apply to every version that bundle evaluates. Use allowlists when the judgement is a property of the policy itself — independent of any specific release.

**Shipping a fix is `app version add`.** When you actually change the artifact, you create a new version (`v1.0.1`) and re-attach the fixed assets. The old version stays a faithful snapshot of what you shipped before; the new version is the snapshot of what you ship now. Both remain queryable for drift and audit.

## How this lab module is structured

Four phases, fully sequential:

1. **Triage with VEX annotations** — record `not_affected`, `affected`, and `under_investigation` decisions against specific findings on `v1.0.0`.
2. **Bundle-level allowlists** — add a long-lived, policy-wide exception with an expiry.
3. **VEX vs allowlists — when to use which** — the decision framework, side-by-side.
4. **Ship the fix as `v1.0.1`** — upgrade the Python application's dependencies, attach the new asset, and re-evaluate. Policy passes.

By the end you'll have used both per-finding triage mechanisms and shipped a clean `v1.0.1` that the policy passes cleanly.

## Phase 1 — Triage with VEX annotations

Not every vulnerability in the list is exploitable in your context. A library may be present but never invoked; a vulnerable code path may be reachable only with a configuration you don't ship; a fix may be backported by your distro vendor under a different name; an upstream supplier may own the dependency and need time to deliver a fixed SBOM. **VEX annotations** capture those judgements in a machine-readable form, scoped to a specific `(vulnerability, package, version)` triple under an app version.

The four 6.0 VEX statuses come from the CycloneDX / OpenVEX vocabulary:

| `--status` | Meaning |
|---|---|
| `not_affected` | The vulnerability does not affect this product/version. Requires a `--justification`. |
| `affected` | The vulnerability affects this product/version. Action expected. |
| `fixed` | A fix has been applied to this product/version. |
| `under_investigation` | Triage in progress; status will be revised. |

For `not_affected`, the justification names *why* the vulnerability doesn't apply:

| `--justification` (used with `not_affected`) | Meaning |
|---|---|
| `component_not_present` | The vulnerable component isn't actually present despite what the SBOM says. |
| `vulnerable_code_not_present` | The component is present but the vulnerable code isn't (e.g. compiled-out feature). |
| `vulnerable_code_not_in_execute_path` | The vulnerable code is present but never reached at runtime. |
| `vulnerable_code_cannot_be_controlled_by_adversary` | An adversary has no input path to reach the vulnerable code. |
| `inline_mitigations_already_exist` | A control already prevents exploitation (WAF rule, sandbox, syscall filter, …). |

We'll walk through three of these — `not_affected`, `affected`, and `under_investigation` — against findings on `v1.0.0`.

> [!IMPORTANT]
> Policy evaluation in 6.0 alpha doesn't apply VEX annotations to findings; a `not_affected` annotation does **not** suppress the matching finding in `app version policy findings list`. VEX in 6.0 alpha is a **record-keeping and disclosure mechanism** — the dispositions you record here flow into the CycloneDX VEX and VDR exports covered in the Reporting module so downstream consumers (customers, regulators, internal triage tools) see your decisions.

### `not_affected` — vulnerability is present but doesn't apply

`CVE-2019-10906` (Jinja2 sandbox escape) is a real CVE that affects `Jinja2==2.10` in the Python asset. The demo Python application doesn't render any user-supplied templates — it just returns JSON via Flask — so the vulnerable code path is never executed. That's a textbook `not_affected / vulnerable_code_not_in_execute_path` case.

```bash
anchorectl app version vex add v1.0.0 \
  --app app \
  --vuln-id CVE-2019-10906 \
  --pkg-name Jinja2 \
  --pkg-type python \
  --pkg-version 2.10 \
  --status not_affected \
  --justification vulnerable_code_not_in_execute_path \
  --impact-statement "The Flask routes in app.py never render user-supplied Jinja templates; the sandbox escape requires render_template_string() with attacker-controlled input, which is not present." \
  --action-statement "No action required for this release. Tracked for upgrade in v1.1.0." \
  --additional-details "Reviewed by security-team on 2026-05-07"
```

Output:

```
 ✔ Added vex
ID: <job-uuid>
Vuln ID: CVE-2019-10906
Status: not_affected
Package: Jinja2
```

### `affected` — yes, we know; here's what we're going to do

The Python application's `requests==2.19.1` pin trips `CVE-2018-18074`. We'll fix this in Phase 4 by bumping the dependency, but for now record the decision so consumers of the release know the issue is acknowledged and on a path to resolution.

```bash
anchorectl app version vex add v1.0.0 \
  --app app \
  --vuln-id CVE-2018-18074 \
  --pkg-name requests \
  --pkg-type python \
  --pkg-version 2.19.1 \
  --status affected \
  --action-statement "Upgrade to requests 2.20.0 scheduled for v1.0.1." \
  --additional-details "Triaged 2026-05-07 by security-team"
```

> [!NOTE]
> `--justification` is required for `not_affected` but **not** for `affected` — for `affected` you supply `--action-statement` instead, describing what you'll do (or have already done) about it.

### `under_investigation` — give us time to triage

The Java SBOM ingested in Visibility came from an upstream supplier. The log4j-core 2.14.1 entry trips `CVE-2021-44228` and fires Stop-on-KEV (and Stop-on-High-or-above too — log4j 2.14.1 is Critical) — but we don't own the Java application; the upstream supplier does. Record that we're working with them while we wait for a fixed SBOM:

```bash
anchorectl app version vex add v1.0.0 \
  --app app \
  --vuln-id CVE-2021-44228 \
  --pkg-name log4j-core \
  --pkg-type java-archive \
  --pkg-version 2.14.1 \
  --status under_investigation \
  --action-statement "Awaiting fixed SBOM from upstream supplier; tracked in TKT-4421." \
  --additional-details "Reviewed 2026-05-07; supplier acknowledged"
```

`under_investigation` is the honest answer when you've seen the finding but the decision isn't made yet.

### Confirm the state

```bash
anchorectl app version vex list v1.0.0 --app app
```

You'll see all three annotations you just recorded against `v1.0.0`. They'll all surface in the version's CycloneDX VEX and VDR exports in the Reporting module.

Re-run the version-level vuln list and pick out the `not_affected` entry to confirm the underlying match is still surfaced — VEX tags the finding, it doesn't remove it from inspection output:

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '.[] | select(.vulnerabilityId == "CVE-2019-10906") | {vulnerabilityId, packageName, packageVersion, severity}'
```

Update an annotation as the situation evolves (status, justification, statements, additional details all editable):

```bash
anchorectl app version vex update <vuln-annotation-id> \
  --app app --version v1.0.0 \
  --status affected \
  --action-statement "Upgrade scheduled for v1.0.1; mitigation in place via input validation."
```

Or remove it entirely:

```bash
anchorectl app version vex delete <vuln-annotation-id> \
  --app app --version v1.0.0
```

> [!NOTE]
> VEX annotations are scoped to an **app version**. Recording `not_affected` for `(CVE-2019-10906, Jinja2, 2.10)` under `v1.0.0` does **not** silently apply to `v1.0.1` — each release is its own assessment. Use VEX when the judgement is evidence-backed and specific to a release; use bundle-level allowlists (Phase 2) when the judgement belongs to the policy itself.

> [!TIP]
> If you change your mind — for example, the upstream supplier delivers a fixed SBOM — update the annotation rather than deleting and re-adding. `anchorectl app version vex update <id> --status fixed --action-statement "Resolved in v1.0.1 by ingesting supplier SBOM rev 2026-05-15."` keeps the audit trail intact.

## Phase 2 — Bundle-level allowlists

Allowlists are how you tell **policy evaluation** to stop counting a specific finding against a version. Unlike VEX (Phase 1), which 6.0 alpha treats as informational, an allowlist entry actually changes the evaluation result — matched findings come back marked `allowlisted: true` and no longer contribute to the version-level `Status: fail`. Allowlists are the right tool when the judgement belongs to the policy itself — a blanket "for this rule on this trigger, give us a pass" that applies to every version the bundle evaluates, ideally with an expiry so the exception doesn't outlive its reason.

Let's record one against `CVE-2021-44228+log4j-core` as a *platform-managed* waiver — we already noted in Phase 1 that the upstream supplier owns this dependency, and we don't want it failing every version while we wait. The waiver expires on `2026-06-30`, giving a hard deadline for follow-up.

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
    "rule_set_ids": ["d3a1d27b-28f4-4f9d-afe9-8fe1ab89f5ed"],
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

The remaining `CVE-2021-44228` findings (both the Stop-on-KEV one and the Stop-on-High-or-above one) now have `"allowlisted": true` and an `allowlist` object naming the waiver, its expiry, and the matching item. That's the policy-evaluation suppression in action — the rules still matched the findings, but the allowlist tells evaluation to exclude them from the version-level outcome calculation. The version-level status is still `fail` because `CVE-2020-14343` (PyYAML) and the Highs in the Python application haven't been waived and are still `stop`, but the log4j entries no longer count against the build. Phase 4 will fix the rest by shipping a new version.

## Phase 3 — VEX vs allowlists: when to use which

You've now used both mechanisms against `v1.0.0`. They sound similar — both record "we know about this finding and we're not failing the build over it" — but they differ in two ways that matter for every decision you'll make:

- **Effect on policy evaluation.** Allowlists actually change the evaluation result — matched findings come back `allowlisted: true` and stop contributing to the version status. VEX in 6.0 alpha does not; it's record-keeping for disclosure (CycloneDX VEX, VDR), not a policy suppression mechanism.
- **Lifecycle across releases.** VEX is per-version and does not carry forward; allowlists live in the bundle and apply to every version it evaluates.

This phase makes the rest of the decision framework explicit so you reach for the right tool without second-guessing.

### Side-by-side

| | **VEX annotation** | **Bundle allowlist** |
|---|---|---|
| **Stored on** | The app version. | The policy bundle. |
| **Scope** | Just this `(vuln, package, version)` under this app version. | Every app version that evaluates this bundle. |
| **Evidence model** | Required justification + impact/action statements. Carries *why* in machine-readable form. | Free-form description. Carries *that*, not *why*. |
| **Expiry** | None as a property; the next release re-asserts (or doesn't). | First-class `expires_on`. Auto-deactivates on the date. |
| **Lifecycle on a new release** | Does **not** carry forward. `v1.0.1` is its own assessment. | Carries forward — applies to `v1.0.1` automatically. |
| **CycloneDX / OpenVEX export** | Yes — the `not_affected`, `affected`, `under_investigation` statuses land in the VEX and VDR exports. | No — allowlists are an internal policy concept, not a disclosure format. |
| **6.0 alpha policy effect** | Currently informational — does not suppress findings in policy evaluation. | Suppresses the finding from contributing to the version status. |
| **Best for** | Evidence-backed, release-specific judgements. | Long-lived, policy-wide exceptions. |

### Two worked examples — read these as decision walkthroughs

**Example 1: the Jinja2 sandbox escape.** `CVE-2019-10906` affects `Jinja2 2.10`, present in the v1.0.0 Python asset. The decision is "the Flask routes don't render user-supplied Jinja templates, so the vulnerable code path is unreachable in *this* code." That's evidence-backed and specific to this build — `v1.0.1` is going to bump Jinja anyway, so the assessment doesn't need to carry forward. **VEX `not_affected`** is the right answer; Phase 1 records it.

**Example 2: the supplier-managed log4j.** `CVE-2021-44228` affects `log4j-core 2.14.1` in the upstream-supplied Java SBOM. The decision is "this dependency is owned by an upstream supplier; we don't fix it, they do." That's not a property of any specific release — it'll be true for every version of `app` until the supplier delivers a fixed SBOM. **Bundle allowlist** is the right answer; Phase 2 records it with an `expires_on` so the waiver has a deadline.

### Anti-patterns

- **Don't allowlist what you can VEX.** A `not_affected` justification carries evidence into the VDR your customers / auditors will read. An allowlist hides the finding without explaining why — fine for platform-managed exceptions, wrong for things you've actually triaged.
- **Don't VEX what should be allowlisted.** Repeating the same per-version VEX entry on every release is a smell; it means the exception is bundle-shaped and you're paying the per-release cost of re-asserting it. Promote it to an allowlist with an expiry.
- **Don't VEX or allowlist what you can fix.** Both mechanisms are for things you *won't* change. If the answer is "bump the dependency," go straight to Phase 4.

## Phase 4 — Ship the fix as `v1.0.1`

VEX and allowlists handle findings you've judged not worth fixing in *this* release. Everything else needs a code change — a bumped dependency, a different base image, a new SBOM from upstream. The remaining `stop` findings on `v1.0.0` (`CVE-2020-14343` in PyYAML, `CVE-2018-18074` in `requests`, `CVE-2019-10906` in Jinja2, and the other Highs in the Python application) are all "we have a fix available, just upgrade" cases. Ship the new version with the upgraded dependencies and verify it passes policy cleanly.

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
```

Output:

```
 ✔ Fetched status
Policy ID: viperr-lab-policy
Policy Name: VIPERR Lab Policy
Status: pass
```

`Status: pass` — the version makes it through clean. The CVEs that drove the `v1.0.0` failure (`CVE-2020-14343` in PyYAML, `CVE-2018-18074` in requests, `CVE-2019-10906` in Jinja2, the rest of the Highs in the Python application) are no longer in the package set, so neither Stop-on-KEV nor Stop-on-High-or-above has anything to fire on. Confirm with the findings list:

```bash
anchorectl app version policy findings list v1.0.1 --app app
```

Empty — no stops, no warnings. That's the outer loop closed: a code change resolved the findings, the policy evaluation reflects it, and the version is ship-ready.

> [!NOTE]
> The bundle's `CVE-2021-44228+*` allowlist from Phase 2 *would* apply to `v1.0.1` if you re-attached the Java asset — allowlists are bundle-scoped, so they travel to every new version automatically. The lab keeps `v1.0.1` focused on the Python upgrade, so the allowlist doesn't get exercised here; it's still in place and ready for the next release that brings the Java asset along.

### Compare versions for drift

Side-by-side counts at the CLI:

```bash
echo "v1.0.0:" && anchorectl app version vuln list v1.0.0 --app app -o json | jq 'length'
echo "v1.0.1:" && anchorectl app version vuln list v1.0.1 --app app -o json | jq 'length'
```

For the package-level diff, export the package inventories from both versions (the Reporting module walks through the per-version export surface in detail) and `diff` the CSVs:

```bash
anchorectl app version export packages v1.0.0 --app app --file /tmp/v1.0.0-packages.csv
anchorectl app version export packages v1.0.1 --app app --file /tmp/v1.0.1-packages.csv
diff /tmp/v1.0.0-packages.csv /tmp/v1.0.1-packages.csv
```

The diff is your release-note input: every package that changed, in one place.

> [!IMPORTANT]
> VEX annotations do **not** apply to `v1.0.1` automatically. The `not_affected` decision on `(CVE-2019-10906, Jinja2 2.10)` was scoped to `v1.0.0` — and that's correct, because `v1.0.1` has `Jinja2 3.1.4` and the finding doesn't exist there anyway. If a per-version triage decision you made on `v1.0.0` still applies to `v1.0.1` (same package version, same code path), re-record it explicitly with `vex add` against the new version. Bundle allowlists, by contrast, do carry forward automatically — that's the per-version vs per-bundle split Phase 3 made explicit.

## Recap

You closed out the remaining findings on `app@v1.0.0` with the two per-finding triage mechanisms and shipped a clean `v1.0.1`:

1. Recorded **VEX annotations** against `v1.0.0` — `not_affected` for the Jinja2 sandbox escape, `affected` for the `requests` upgrade, and `under_investigation` for the supplier-managed log4j entry — and saw that VEX is a record-keeping and disclosure mechanism, not a policy-suppression mechanism in 6.0 alpha.
2. Added a **bundle-level allowlist** with an expiry for `CVE-2021-44228+*`, wired the necessary `sbom_mappings` entry to activate it, and confirmed the log4j findings are now `allowlisted: true`.
3. Worked through the **VEX vs allowlists decision framework** — scope, evidence model, lifecycle on a new release — with two worked examples and the anti-patterns to avoid.
4. Created `v1.0.1`, re-scanned the **upgraded Python application** as the asset, re-evaluated the policy, and landed `Status: pass`.

Useful 5.x → 6.0 mappings:

| 5.x                                                           | 6.0                                                                  |
|---------------------------------------------------------------|----------------------------------------------------------------------|
| Allowlists only (per-bundle waivers)                          | Allowlists *and* VEX annotations — VEX for per-version evidence and disclosure, allowlists for bundle-wide exceptions |
| `anchorectl evaluation refresh`                               | `POST /v2/apps/<id>/jobs/evaluate-policy` (no CLI surface yet)       |
| `application version add app@v1.0.1` + `image add` + `application artifact add` | `app version add v1.0.1 --app app` + `app version asset add …`       |
| Allowlist entries with `whitelists` array                     | Same JSON; v5 names auto-aliased to `allowlists`                     |

**Outer-loop pattern for CI/CD.** When a release branch cuts:
1. `app version add <release> --app <app>` once.
2. For every artifact in the release, `app version asset add <type> … --version <release>` (centralized, distributed, SBOM, or filesystem as appropriate).
3. Re-record VEX annotations that still apply by replaying `app version vex add … --version <release>` (or feed in a CycloneDX VEX document from the previous version via your own tooling). Bundle allowlists carry forward automatically.
4. Trigger `POST /v2/apps/<id>/jobs/evaluate-policy` and poll `app version policy status get <release>`.
5. Treat `Status: fail` as exit-1; `Status: pass` as ship-ready.

## Next Module

Next: [Reporting](reporting.md) — turning the asset, vulnerability, policy, and remediation data you've accumulated across `v1.0.0` and `v1.0.1` into account-wide insights for security, engineering, and compliance audiences.
