# Inspection

The Visibility module gave you four assets attached to `app@v1.0.0`: a Java application SBOM, a centrally-analyzed Postgres image, a locally-analyzed Ubuntu image, and a filesystem scan of a Python application. Now we turn that inventory into something actionable — vulnerabilities, packages, prioritisation signals, and triage decisions.

In Anchore Enterprise 6.0, vulnerability data is presented at the **app version** level. Anchore Enterprise takes the package inventory from every asset attached to a version, deduplicates it, matches it against vulnerability data, and gives you one consolidated picture for the release. You can still pivot down to a single asset when you need to, but the version-level view is the primary lens.

> [!IMPORTANT]
> This module assumes you completed the [Visibility module](visibility.md) — it uses the same `app`, `v1.0.0` version, and the four assets attached to it. If you haven't worked through Visibility yet, do that first.

## How this lab module is structured

Six phases, fully sequential:

1. **Understand the data foundation** — feeds, namespaces, and the enrichment data (KEV, EPSS, CVSS) Anchore Enterprise uses to prioritise findings.
2. **List vulnerabilities at the version level** — get the consolidated view across all four assets.
3. **Filter and prioritise** — use `jq` against the JSON output to slice by severity, fix availability, KEV, and EPSS.
4. **Drill into a specific asset** — pull the original SBOM and inspect asset-specific metadata.
5. **Triage with VEX annotations** — record `not_affected` decisions on vulnerabilities you've reviewed.
6. **Export for downstream tools** — CSV vulnerability reports, CycloneDX VEX, and CSV package inventories.

## Phase 1 — Understand the data foundation

Anchore Enterprise matches the packages in your assets against vulnerability data sourced from many feeds. The accuracy of every vuln finding depends on the quality and freshness of those feeds, and on Anchore Enterprise picking the *most specific* feed for each package.

List the feeds Anchore Enterprise currently has loaded:

```bash
anchorectl feed list
```

Output (truncated):

```
 ✔ List feed
┌─────────────────────────────────────────────────┬────────────────────┬─────────┬──────────────────────┬──────────────┐
│ FEED                                            │ GROUP              │ ENABLED │ LAST UPDATED         │ RECORD COUNT │
├─────────────────────────────────────────────────┼────────────────────┼─────────┼──────────────────────┼──────────────┤
│ ClamAV Malware Database                         │ clamav_db          │ true    │ 2026-05-06T06:06:35Z │ 1            │
│ CISA Known Exploitable Vulnerabilities Database │ kev_db             │ true    │ 2026-05-06T06:08:08Z │ 1228         │
│ Exploit Prediction Scoring System Database      │ epss_db            │ true    │ 2026-05-06T06:04:42Z │ 269687       │
│ Vulnerabilities                                 │ github:composer    │ true    │ 2026-05-06T06:13:36Z │ 4216         │
│ Vulnerabilities                                 │ github:go          │ true    │ 2026-05-06T06:13:36Z │ 1991         │
│ Vulnerabilities                                 │ github:java        │ true    │ 2026-05-06T06:13:36Z │ 5154         │
│ Vulnerabilities                                 │ github:python      │ true    │ 2026-05-06T06:13:36Z │ 3847         │
│ Vulnerabilities                                 │ nvd                │ true    │ 2026-05-06T06:14:04Z │ 261013       │
│ Vulnerabilities                                 │ ubuntu:22.04       │ true    │ 2026-05-06T06:14:00Z │ 23147        │
│ Vulnerabilities                                 │ debian:11          │ true    │ 2026-05-06T06:14:01Z │ 18920        │
│ ...                                             │ ...                │ ...     │ ...                  │ ...          │
└─────────────────────────────────────────────────┴────────────────────┴─────────┴──────────────────────┴──────────────┘
```

A few things in that table matter for the rest of this module:

- **Distro-specific feeds** (`ubuntu:22.04`, `debian:11`, `alpine:3.18`, `rhel:9` …) are the most authoritative source of OS-package vulnerability data for each distro. When Anchore Enterprise scans the Postgres or Ubuntu image, it matches OS packages against the corresponding distro feed first, falling back to NVD only when no distro entry exists. That's why the `namespace` field on a vulnerability record matters — it tells you which feed produced the match.
- **Language ecosystem feeds** (`github:python`, `github:java`, `github:go`, `github:npm` …) drive matching for application-level dependencies — the Java archives in the Jenkins-style SBOM, the pinned versions in `requirements.txt`, and so on.
- **NVD** (`nvd`) is the catch-all. It's used when nothing more specific applies, and it's always available as a cross-reference (`related_cves` on a match often points back here).
- **KEV** (`kev_db`) is CISA's Known Exploited Vulnerabilities catalog — vulnerabilities with confirmed in-the-wild exploitation. A match flagged `kev: true` is one you almost certainly want to act on.
- **EPSS** (`epss_db`) is the Exploit Prediction Scoring System. Each CVE gets a score (0–1) representing the probability of exploitation in the next 30 days, and a percentile ranking. EPSS is great for prioritising the long tail of high-severity but unlikely-to-be-exploited findings.
- **ClamAV** (`clamav_db`) is the malware-signature database used for centralized image scanning.

> [!NOTE]
> Feeds in 6.0 alpha are still served by the v5 catalog and Data Syncer service. The data is shared across both v5 and v6 surfaces — the same `feed list` command you've used before still works, and the freshness of each group still drives every match the new asset model produces. Anchore Enterprise will sync new data on a regular cycle; you can force an immediate sync with `anchorectl feed sync` if you've just brought the deployment up.

To learn more about how Anchore Enterprise curates and prioritises feed data, see the [Anchore Enterprise vulnerability management docs](https://docs.anchore.com/current/docs/vulnerability_management/).

## Phase 2 — List vulnerabilities at the version level

The headline command for inspection in 6.0:

```bash
anchorectl app version vuln list v1.0.0 --app app
```

This returns the deduplicated set of vulnerability matches across **every asset** attached to `app@v1.0.0` — the Java SBOM, the Postgres image, the Ubuntu image, and the Python filesystem scan, all rolled up into one list. Output (truncated):

```
 ✔ Fetched vulns
┌────────────────┬──────────┬───────────────────────┬─────────────┬─────────────────┬───────────┬─────┬─────────────┐
│ VULNERABILITY  │ SEVERITY │ PACKAGE               │ VERSION     │ FIX             │ TYPE      │ KEV │ NAMESPACE   │
├────────────────┼──────────┼───────────────────────┼─────────────┼─────────────────┼───────────┼─────┼─────────────┤
│ CVE-2021-44228 │ Critical │ log4j-core            │ 2.14.1      │ 2.15.0          │ java      │ ✓   │ github:java │
│ CVE-2018-18074 │ High     │ requests              │ 2.19.1      │ 2.20.0          │ python    │     │ github:python│
│ CVE-2019-10906 │ High     │ Jinja2                │ 2.10        │ 2.10.1          │ python    │     │ github:python│
│ CVE-2020-14343 │ Critical │ PyYAML                │ 5.1         │ 5.4             │ python    │     │ github:python│
│ CVE-2024-12345 │ High     │ openssl               │ 3.0.2-0…    │ 3.0.2-0…+deb12u3│ deb       │     │ debian:12   │
│ CVE-2024-67890 │ Medium   │ libpq5                │ 13.10-0…    │ 13.11-0…        │ deb       │     │ debian:12   │
│ ...            │ ...      │ ...                   │ ...         │ ...             │ ...       │     │ ...         │
└────────────────┴──────────┴───────────────────────┴─────────────┴─────────────────┴───────────┴─────┴─────────────┘
```

> [!NOTE]
> **What just happened:** the API took the package inventory of every asset under `v1.0.0`, matched each package against the relevant feed (per the `namespace` column), enriched each match with KEV / EPSS / CVSS data where available, and returned the consolidated list. If two assets contain the same package at the same version, you'll see one row with the relevant package coordinates — not duplicates per asset.

A single match is much richer than the table shows. Re-run with JSON output for the full picture:

```bash
anchorectl app version vuln list v1.0.0 --app app -o json | jq '.[0]'
```

Output (single match):

```json
{
  "vulnerability_id": "CVE-2021-44228",
  "namespace": "github:java",
  "severity": "Critical",
  "fix_state": "fixed",
  "fix_versions": [
    { "version": "2.15.0", "date": "2021-12-09T00:00:00Z", "kind": "advisory" }
  ],
  "related_cves": ["CVE-2021-44228"],
  "package_name": "log4j-core",
  "package_version": "2.14.1",
  "package_type": "java-archive",
  "purl": "pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1",
  "epss_score": 0.97,
  "epss_percentile": 0.99987,
  "kev": true,
  "cvss_assessments": [
    { "source": "nvd@nist.gov", "is_primary": true,
      "v2_score": null, "v3_score": 10.0, "v4_score": null }
  ],
  "vex_status": null
}
```

The fields worth knowing:

| Field | What it tells you |
|---|---|
| `vulnerability_id` | The primary identifier — usually a `CVE-…` or a `GHSA-…`. |
| `namespace` | The feed that produced the match (`github:java`, `nvd`, `debian:12`, `ubuntu:22.04`, …). Distro namespaces win over `nvd` when both apply. |
| `severity` | Anchore Enterprise's normalised severity: `Critical`, `High`, `Medium`, `Low`, `Negligible`, `Unknown`. |
| `fix_state` / `fix_versions` | Whether a fix exists and at which version. `kind: "advisory"` is the vendor advisory date; `"first-observed"` is the date Anchore Enterprise first saw the fix in a package repository. |
| `kev` | `true` if the CVE is in CISA's Known Exploited Vulnerabilities catalog — confirmed real-world exploitation. |
| `epss_score` / `epss_percentile` | Probability of exploitation in the next 30 days (0–1) and percentile ranking against all CVEs. |
| `cvss_assessments` | Every CVSS score from every source — NVD, vendor advisories, etc. `is_primary: true` marks Anchore Enterprise's preferred source. |
| `related_cves` | Cross-references — useful when a GHSA-… match has an underlying CVE-…. |
| `vex_status` | If you've added a VEX annotation for this `(vulnerability, package)` pair under this version, the status is reflected here. We'll set one in Phase 5. |

## Phase 3 — Filter and prioritise

The CLI returns the full list; filtering is done client-side with `jq`. Four filters cover most real triage work:

**1. Critical and High severity only**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.severity == "Critical" or .severity == "High")]'
```

**2. Only matches with a fix available**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.fix_state == "fixed")]'
```

**3. CISA KEV — known exploited in the wild**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.kev == true)] | sort_by(-.epss_score)'
```

**4. Top 20 by EPSS — most likely to be exploited next**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.epss_score != null)] | sort_by(-.epss_score) | .[0:20]'
```

> [!TIP]
> If your org's prioritisation rule is "Critical/High **and** (KEV true **or** EPSS percentile ≥ 0.95)", that's one `jq` selector away — and the same rule expressed as an Anchore Enterprise policy will give you pass/fail evaluation, which is the next module's territory.

## Phase 4 — Drill into a specific asset

The CLI exposes vulnerabilities at the **version** level. To narrow to a single asset (say "what does the Postgres image specifically contribute?"), pull the asset details and the original SBOM, then cross-reference.

Get the asset's metadata — including the annotations you set in Visibility:

```bash
anchorectl app version asset get postgres \
  --app app --version v1.0.0 -o json | jq '{name, type, annotations, image_reference, system_metadata}'
```

Pull back the SBOM that was stored for the asset:

```bash
anchorectl app version asset sbom get postgres \
  --app app --version v1.0.0 \
  --file ./postgres-asset-sbom.json
```

The returned SBOM is exactly what Anchore Enterprise is matching against — every package the asset contributes to the version-level view. Once you have the SBOM in hand, narrowing version-level vulnerabilities to those that came from this asset is a `jq` join on `package_name` + `package_version`. For a concrete example:

```bash
# package coordinates from this asset's SBOM
jq -r '[.artifacts[] | "\(.name)\(.version)"] | unique | .[]' \
  ./postgres-asset-sbom.json > /tmp/postgres-pkgs.txt

# version-level vulns whose package matches
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq --slurpfile keys /tmp/postgres-pkgs.txt \
       '[.[] | select((.package_name + "" + .package_version) as $k | $keys[0] | index($k))]'
```

> [!NOTE]
> A first-class "vulnerabilities for this specific asset" CLI command isn't in the asset surface at this alpha — the version-level rollup with `jq` filtering covers the same ground. Each asset's SBOM is round-trippable, so any analysis you can do with an SBOM file you can do here.

## Phase 5 — Triage with VEX annotations

Not every vulnerability in the list is exploitable in your context. A library may be present but never invoked; a vulnerable code path may be reachable only with a configuration you don't ship; a fix may be backported by your distro vendor under a different name. **VEX annotations** capture those judgements in a machine-readable form, scoped to a specific `(vulnerability, package, version)` triple under an app version.

Let's record one against the Python asset. `CVE-2019-10906` (Jinja2 sandbox escape) is a real CVE that affects `Jinja2==2.10`. The demo Python application doesn't render any user-supplied templates — it just returns JSON via Flask — so the vulnerable code path is never executed. That's a textbook `not_affected` / `vulnerable_code_not_in_execute_path` case.

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
  --comment "Reviewed by security-team on 2026-05-06"
```

The `--status` and `--justification` values come from the CycloneDX/OpenVEX vocabulary:

| `--status` | Meaning |
|---|---|
| `not_affected` | The vulnerability does not affect this product/version. Requires a `--justification`. |
| `affected` | The vulnerability affects this product/version. Action expected. |
| `fixed` | A fix has been applied to this product/version. |
| `under_investigation` | Triage in progress; status will be revised. |

| `--justification` (used with `not_affected`) | Meaning |
|---|---|
| `component_not_present` | The vulnerable component isn't actually present despite what the SBOM says. |
| `vulnerable_code_not_present` | The component is present but the vulnerable code isn't (e.g. compiled-out feature). |
| `vulnerable_code_not_in_execute_path` | The vulnerable code is present but never reached at runtime. |
| `vulnerable_code_cannot_be_controlled_by_adversary` | An adversary has no input path to reach the vulnerable code. |
| `inline_mitigations_already_exist` | A control already prevents exploitation (WAF rule, sandbox, syscall filter, …). |

List the annotations you've made for this version:

```bash
anchorectl app version vex list v1.0.0 --app app
```

Re-run the version-level vuln list and notice the `vex_status` field on `CVE-2019-10906` for `Jinja2 2.10` is now populated:

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '.[] | select(.vulnerability_id == "CVE-2019-10906") | {vulnerability_id, package_name, package_version, severity, vex_status}'
```

Update an annotation as the situation evolves (status, justification, statements, comment all editable):

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
> VEX annotations are scoped to an **app version**. Recording `not_affected` for `(CVE-2019-10906, Jinja2, 2.10)` under `v1.0.0` does not silently apply to `v1.0.1` — each release is its own assessment. The Remediation module covers when to use app-level vs. version-level annotations and how to manage VEX over time.

## Phase 6 — Export for downstream tools

Anchore Enterprise produces four exports you'll reach for in audit, compliance, and integration work. Each export is created as a job, fetched on completion, and either streamed to stdout or written to a file.

**Combined SBOM (CycloneDX JSON)** — every asset under the version, merged into one CycloneDX SBOM document. Use this when a customer, an auditor, or a downstream tool wants "the SBOM for this release" rather than the per-asset SBOMs:

```bash
anchorectl app version export sbom v1.0.0 \
  --app app \
  --file ./app-v1.0.0-sbom.cdx.json
```

> [!NOTE]
> This is different from `app version asset sbom get` (which you used in Phase 4). `asset sbom get` returns the original SBOM Anchore Enterprise stored for a single asset, in whatever format you ingested it. `app version export sbom` aggregates the package inventory of every asset under the version and emits a single CycloneDX JSON document — convenient for a release-level hand-off, less faithful to each asset's original format.

**Vulnerability report (CSV)** — the canonical "send this to your security team / GRC tool" artifact:

```bash
anchorectl app version export vulnerabilities v1.0.0 \
  --app app \
  --file ./app-v1.0.0-vulnerabilities.csv
```

**Package inventory (CSV)** — every package across every asset, deduplicated, with location and source attribution:

```bash
anchorectl app version export packages v1.0.0 \
  --app app \
  --file ./app-v1.0.0-packages.csv
```

**VEX document (CycloneDX)** — every annotation you recorded in Phase 5, packaged as a CycloneDX VEX document you can hand to a customer, attach to a release, or feed into a downstream scanner:

```bash
anchorectl app version export vex v1.0.0 \
  --app app \
  --file ./app-v1.0.0-vex.cdx.json
```

The CycloneDX VEX uses the same status / justification vocabulary as `app version vex add`, so a downstream tool that understands CycloneDX VEX will pick up your `not_affected` decisions automatically.

## Recap

You walked the full inspection loop for `app@v1.0.0`:

1. Saw the **feed coverage** Anchore Enterprise is using — distro feeds, language-ecosystem feeds, NVD, KEV, EPSS, ClamAV.
2. Pulled the **version-level vulnerability list** that consolidates findings across all four assets.
3. Filtered with `jq` by severity, fix availability, KEV, and EPSS to get to the rows that matter.
4. Drilled into the **Postgres asset** specifically, pulling its SBOM and joining back to the version-level data.
5. Recorded a **VEX annotation** marking `CVE-2019-10906` in `Jinja2 2.10` as `not_affected / vulnerable_code_not_in_execute_path` for this release.
6. Exported the **combined SBOM, vulnerabilities, packages, and VEX** as artifacts you can hand to other tools or stakeholders.

Useful 5.x → 6.0 mappings to keep in mind:

| 5.x                                              | 6.0                                                                  |
|--------------------------------------------------|----------------------------------------------------------------------|
| `image vulnerabilities <image> -t os/non-os/all` | `app version vuln list <version> --app <app>` (filter via `jq` on namespace / package_type) |
| `image content <image> -t java`                  | `app version package list <version> --app <app>` for the package inventory |
| `image content <image> -t secret_search`         | Per-asset secret/malware/file content surfaces are not exposed at the asset CLI in 6.0 alpha; expected in a later iteration |
| `image ancestors <digest>`                       | No equivalent in the v6 asset model yet |
| Allowlists (in policy)                           | VEX annotations (`app version vex …`) for vulnerability suppression  |

## Next Module

Next: [Policy Enforcement](policy-enforcement.md) — turning the raw inspection data into pass/fail gates for releases.
