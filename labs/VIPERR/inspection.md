# Inspection

The Visibility module gave you four assets attached to `app@v1.0.0`: a Java application SBOM, a centrally-analyzed Postgres image, a locally-analyzed Ubuntu image, and a filesystem scan of a Python application. Now we turn that inventory into something actionable — vulnerabilities, packages, prioritisation signals, and triage decisions.

In Anchore Enterprise 6.0, vulnerability data is presented at the **app version** level. Anchore Enterprise takes the package inventory from every asset attached to a version, deduplicates it, matches it against vulnerability data, and gives you one consolidated picture for the release. You can still pivot down to a single asset when you need to, but the version-level view is the primary lens.

> [!IMPORTANT]
> This module assumes you completed the [Visibility module](visibility.md) — it uses the same `app`, `v1.0.0` version, and the four assets attached to it. If you haven't worked through Visibility yet, do that first.

## How this lab module is structured

Four phases, fully sequential:

1. **Understand the data foundation** — feeds, namespaces, and the enrichment data (KEV, EPSS, CVSS) Anchore Enterprise uses to prioritise findings.
2. **List vulnerabilities at the version level** — get the consolidated view across all four assets.
3. **Filter and prioritise** — use `jq` against the JSON output to slice by severity, fix availability, KEV, and EPSS.
4. **Drill into a specific asset** — pull the original SBOM and inspect asset-specific metadata.

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
- **NVD** (`nvd`) is the catch-all. It's used when nothing more specific applies, and it's always available as a cross-reference (`relatedCves` on a match often points back here).
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
  "vulnerabilityId": "CVE-2022-37434",
  "namespace": "alpine",
  "severity": "critical",
  "fixState": "fixed",
  "fixVersions": [
    { "version": "1.2.12-r2", "date": "2026-02-24T00:00:00Z", "kind": "first-observed" }
  ],
  "relatedCves": [],
  "packageName": "zlib",
  "packageVersion": "1.2.11-r3",
  "packageType": "apk",
  "purl": "pkg:apk/alpine/zlib@1.2.11-r3?arch=x86_64&distro=alpine-3.15.0",
  "epssScore": 0.92745,
  "epssPercentile": 0.99761,
  "kev": false,
  "cvssAssessments": [
    { "source": "nvd@nist.gov", "isPrimary": true,
      "v2Score": null, "v3Score": 9.8, "v4Score": null }
  ]
}
```

The fields worth knowing:

| Field | What it tells you |
|---|---|
| `vulnerabilityId` | The primary identifier — usually a `CVE-…` or a `GHSA-…`. |
| `namespace` | The feed that produced the match (`alpine`, `debian:distro:debian:13`, `github:language:java-archive`, `github:language:python`, `nvd:cpe`, …). Distro and language namespaces win over `nvd:cpe` when both apply. |
| `severity` | Anchore Enterprise's normalised severity, lowercased: `critical`, `high`, `medium`, `low`, `negligible`, `unknown`. |
| `fixState` / `fixVersions` | Whether a fix exists and at which version. `kind: "advisory"` is the vendor advisory date; `"first-observed"` is the date Anchore Enterprise first saw the fix in a package repository. |
| `kev` | `true` if the CVE is in CISA's Known Exploited Vulnerabilities catalog — confirmed real-world exploitation. |
| `epssScore` / `epssPercentile` | Probability of exploitation in the next 30 days (0–1) and percentile ranking against all CVEs. May be `null` for older CVEs that aren't in EPSS. |
| `cvssAssessments` | Every CVSS score from every source — NVD, vendor advisories, etc. `isPrimary: true` marks Anchore Enterprise's preferred source. |
| `relatedCves` | Cross-references — useful when a `GHSA-…` match has an underlying `CVE-…`. |

## Phase 3 — Filter and prioritise

The CLI returns the full list; filtering is done client-side with `jq`. Four filters cover most real triage work:

**1. Critical and High severity only**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.severity == "critical" or .severity == "high")]'
```

**2. Only matches with a fix available**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.fixState == "fixed")]'
```

**3. CISA KEV — known exploited in the wild**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.kev == true)] | sort_by(.epssScore // -1) | reverse'
```

The `// -1` coalesces a `null` EPSS score to `-1` so the sort is well-defined even when (as is common with KEV entries) EPSS data hasn't been published for the vulnerability. `reverse` flips ascending into descending, putting the highest-EPSS KEV entries first and the null-EPSS entries at the bottom.

**4. Top 20 by EPSS — most likely to be exploited next**

```bash
anchorectl app version vuln list v1.0.0 --app app -o json \
  | jq '[.[] | select(.epssScore != null)] | sort_by(-.epssScore) | .[0:20]'
```

> [!TIP]
> If your org's prioritisation rule is "Critical/High **and** (KEV true **or** EPSS percentile ≥ 0.95)", that's one `jq` selector away — and the same rule expressed as an Anchore Enterprise policy will give you pass/fail evaluation, which is the next module's territory.

## Phase 4 — Drill into vulns in a specific asset

The CLI exposes vulnerabilities at the **version** level. To narrow to a single asset (say "what does the Postgres image specifically contribute?"), pull the asset's metadata and cross-reference against the version-level vuln list.

Get the asset's metadata — including the annotations you set in Visibility:

```bash
anchorectl app version asset get postgres \
  --app app --version v1.0.0 -o json | jq '{name, type, annotations, image_reference, system_metadata}'
```

## Recap

You walked the full inspection loop for `app@v1.0.0`:

1. Saw the **feed coverage** Anchore Enterprise is using — distro feeds, language-ecosystem feeds, NVD, KEV, EPSS, ClamAV.
2. Pulled the **version-level vulnerability list** that consolidates findings across all four assets.
3. Filtered with `jq` by severity, fix availability, KEV, and EPSS to get to the rows that matter.
4. Drilled into the **Postgres asset** to view its asset-level metadata — annotations, type, and image reference — via `app version asset get`.

Useful 5.x → 6.0 mappings to keep in mind:

| 5.x                                              | 6.0                                                                  |
|--------------------------------------------------|----------------------------------------------------------------------|
| `image vulnerabilities <image> -t os/non-os/all` | `app version vuln list <version> --app <app>` (filter via `jq` on `namespace` / `packageType`) |
| `image content <image> -t java`                  | `app version package list <version> --app <app>` for the package inventory |
| `image content <image> -t secret_search`         | Per-asset secret/malware/file content surfaces are not exposed at the asset CLI in 6.0 alpha; expected in a later iteration |
| `image ancestors <digest>`                       | No equivalent in the v6 asset model yet |

## Next Module

Next: [Policy Enforcement](policy-enforcement.md) — turning the raw inspection data into pass/fail gates for releases.
