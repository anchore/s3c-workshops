# Inspection

The Visibility module gave you four assets attached to `app@v1.0.0`: a Java application SBOM, a centrally-analyzed Postgres image, a locally-analyzed Ubuntu image, and a filesystem scan of a Python application. Now we turn that inventory into something actionable — vulnerabilities, packages, prioritisation signals, and triage decisions.

In Anchore Enterprise 6.0, vulnerability data is presented at the **app version** level. Anchore Enterprise takes the package inventory from every asset attached to a version, deduplicates it, matches it against vulnerability data, and gives you one consolidated picture for the release. You can still pivot down to a single asset when you need to, but the version-level view is the primary lens.

> [!IMPORTANT]
> This module assumes you completed the [Visibility module](visibility.md) — it uses the same `app`, `v1.0.0` version, and the four assets attached to it. If you haven't worked through Visibility yet, do that first.

## How this lab module is structured

Five phases, fully sequential:

1. **Understand the data foundation** — feeds, namespaces, and the enrichment data (KEV, EPSS, CVSS) Anchore Enterprise uses to prioritise findings.
2. **Inspecting contents of assets** — survey the asset roster and drill into per-asset metadata before turning to vulnerabilities.
3. **List vulnerabilities at the version level** — get the consolidated view across all four assets.
4. **Filter and prioritise** — use `jq` against the JSON output to slice by severity, fix availability, KEV, and EPSS.
5. **Drill into a specific asset** — pull the original SBOM and inspect asset-specific metadata.

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

To learn more about how Anchore Enterprise curates and prioritises feed data, see the [Anchore Enterprise vulnerability management docs](https://docs.anchore.com/current/docs/vulnerability_management/).

## Phase 2 — Inspecting contents of assets

Every asset under `v1.0.0` is backed by an SBOM that Anchore Enterprise stored at ingestion — a package inventory plus the metadata that frames it. This phase walks how to inspect those SBOMs at three levels: the roster of assets that have SBOMs attached, the per-asset metadata that describes each SBOM, and the SBOM document itself.

### The asset roster

List the assets (and therefore the SBOMs) attached to the version:

```bash
anchorectl app version asset list v1.0.0 --app app
```

Output:

```
 ✔ Fetched assets
┌────────────────┬──────────────────────────────────────┬─────────────┬──────────────────────┐
│ NAME           │ ID                                   │ TYPE        │ UPDATED              │
├────────────────┼──────────────────────────────────────┼─────────────┼──────────────────────┤
│ my-java-app    │ 7c4a9a8b-…                           │ application │ 2026-05-05T10:22:00Z │
│ postgres       │ 1f2b3c4d-…                           │ container   │ 2026-05-05T10:24:11Z │
│ ubuntu-jammy   │ 9e8d7c6b-…                           │ container   │ 2026-05-05T10:26:32Z │
│ my-python-app  │ 5a4b3c2d-…                           │ application │ 2026-05-05T10:28:55Z │
└────────────────┴──────────────────────────────────────┴─────────────┴──────────────────────┘
```

Two pieces of context to keep in mind as you read this list:

- **`TYPE`** classifies the asset (and the shape of the SBOM behind it). `application` covers imported SBOMs and locally-produced filesystem scans; `container` covers images that were analyzed centrally (server-side) or distributed (client-side).
- **`UPDATED`** is when the asset record last changed — useful when a re-scan or a metadata edit has happened since ingestion. The `system_metadata` block we'll inspect below has the matching `created_at` if you want to distinguish first-ingest from last-touch.

> [!TIP]
> `asset list` accepts `--name <pattern>` if you want to filter the roster — handy when an app has dozens of assets across many versions. For four assets you can skim the whole table; at scale, filter or `-o json | jq` it.

### Per-asset SBOM metadata

Drill into a single asset to see the metadata Anchore Enterprise stores about its SBOM. The JSON form of `asset get` is the richest view:

```bash
anchorectl app version asset get my-python-app \
  --app app --version v1.0.0 -o json | jq
```

Output (abridged):

```json
{
  "name": "my-python-app",
  "type": "application",
  "reference": "/tmp/my-python-app",
  "annotations": {
    "language": "python",
    "role": "worker",
    "source": "upstream-tarball"
  },
  "artifacts": {
    "item_count": 14
  },
  "system_metadata": {
    "id": "5a4b3c2d-…",
    "created_at": "2026-05-05T10:28:55Z",
    "updated_at": "2026-05-05T10:28:55Z"
  }
}
```

The fields worth knowing:

| Field | What it tells you |
|---|---|
| `name` | The asset name you chose at ingestion (and may have updated since via `asset update`). |
| `type` | `application` or `container`. |
| `reference` | What this SBOM is *about*: a filesystem path for filesystem scans, an image reference for container assets, or a hand-off identifier for imported SBOMs. The provenance line. |
| `annotations` | The free-form metadata set during ingestion or updated since — supplier, language, role, ownership, anything you want searchable later. |
| `artifacts.item_count` | How many packages this SBOM contains. The headline composition number. |
| `system_metadata` | The asset's internal UUID and the create / update timestamps. |

Run `asset get` against the other three assets to compare:

```bash
anchorectl app version asset get my-java-app   --app app --version v1.0.0 -o json | jq
anchorectl app version asset get postgres      --app app --version v1.0.0 -o json | jq
anchorectl app version asset get ubuntu-jammy  --app app --version v1.0.0 -o json | jq
```

A few things you'll notice:

- The `container` assets carry an image reference (`registry/repo:tag@sha256:…`) in `reference`; the `application` assets carry a path or a hand-off identifier instead.
- Each asset's `artifacts.item_count` is the size of its SBOM in packages. The four counts add up to *roughly* the total package inventory for `v1.0.0`, with deduplication absorbing any packages two SBOMs happen to share.
- The annotations you set in Visibility (`analysis=centralized` / `analysis=distributed` on the two container assets, `language` and `role` on the filesystem-scanned Python asset, and so on) are all preserved — they're what makes per-asset filtering possible at scale.

> [!TIP]
> If you only want one field from the JSON, pass it to `jq`. For example, `… -o json | jq '.artifacts.item_count'` returns just the package count for that SBOM — useful for scripted per-asset rollups, dashboards, or sanity checks that all expected assets ingested cleanly.

### The SBOM document itself

The metadata above tells you *about* the SBOM. To look at the SBOM document itself — every component, with its name, version, type, PURL, and licensing — fetch it with `asset sbom get`. Without `--file`, the SBOM is streamed to stdout so you can pipe it through `jq`:

```bash
anchorectl app version asset sbom get my-python-app \
  --app app --version v1.0.0 \
  | jq '{bomFormat, specVersion, componentCount: (.components | length)}'
```

Output:

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "componentCount": 14
}
```

That confirms shape and size match the `artifacts.item_count` you read above. Look at a single component:

```bash
anchorectl app version asset sbom get my-python-app \
  --app app --version v1.0.0 \
  | jq '.components[] | select(.name == "Flask")'
```

Output:

```json
{
  "bom-ref": "pkg:pypi/Flask@1.0.2",
  "type": "library",
  "name": "Flask",
  "version": "1.0.2",
  "purl": "pkg:pypi/Flask@1.0.2",
  "licenses": [
    { "license": { "id": "BSD-3-Clause" } }
  ]
}
```

Each component carries:

| Field | What it tells you |
|---|---|
| `type` | What kind of component — `library`, `application`, `operating-system`, `container`, etc. |
| `name` / `version` | The package coordinates. |
| `purl` | The canonical Package URL — the identifier downstream tools key on for matching, license auditing, and attestation. |
| `licenses` | The license expression(s) Syft or the source SBOM detected. |
| `bom-ref` | A within-document reference; CycloneDX uses it for relationship and dependency edges. |

Two cross-cutting views worth knowing:

```bash
# Component count grouped by type
anchorectl app version asset sbom get my-python-app \
  --app app --version v1.0.0 \
  | jq '.components | group_by(.type) | map({type: .[0].type, count: length})'

# Every license expression that appears, deduplicated
anchorectl app version asset sbom get my-python-app \
  --app app --version v1.0.0 \
  | jq '[.components[] | .licenses[]? | .license.id // .license.name // .expression] | unique'
```

> [!NOTE]
> The SBOM you get back is the document Anchore Enterprise stored at ingestion, in its original format. For the Python asset that's a CycloneDX JSON produced by Syft during the filesystem analyze; for `my-java-app` it's whatever CycloneDX or SPDX shape the upstream supplier handed off; for the container assets it's the CycloneDX SBOM Anchore Enterprise produced (centrally or via `image-analyze`). The shape of the components array is consistent across CycloneDX flavours; SPDX-formatted SBOMs use a different top-level structure (`packages` instead of `components`) — switch your `jq` selectors accordingly.

With the asset roster, per-asset SBOM metadata, and the SBOM documents themselves surveyed, you have a complete picture of what `v1.0.0` contains.

## Phase 3 — List vulnerabilities at the version level

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

## Phase 4 — Filter and prioritise

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

## Phase 5 — Drill into vulns in a specific asset

The CLI exposes vulnerabilities at the **version** level. To narrow to a single asset (say "what does the Postgres image specifically contribute?"), pull the asset's metadata and cross-reference against the version-level vuln list.

Get the asset's metadata — including the annotations you set in Visibility:

```bash
anchorectl app version asset get postgres \
  --app app --version v1.0.0 -o json | jq '{name, type, annotations, image_reference, system_metadata}'
```

## Recap

You walked the full inspection loop for `app@v1.0.0`:

1. Saw the **feed coverage** Anchore Enterprise is using — distro feeds, language-ecosystem feeds, NVD, KEV, EPSS, ClamAV.
2. Surveyed the **asset roster** under `v1.0.0` with `asset list`, then drilled into each asset's metadata — type, reference, annotations, and package count — with `asset get -o json`.
3. Pulled the **version-level vulnerability list** that consolidates findings across all four assets.
4. Filtered with `jq` by severity, fix availability, KEV, and EPSS to get to the rows that matter.
5. Drilled into the **Postgres asset** to view its asset-level metadata — annotations, type, and image reference — via `app version asset get`.

Useful 5.x → 6.0 mappings to keep in mind:

| 5.x                                              | 6.0                                                                  |
|--------------------------------------------------|----------------------------------------------------------------------|
| `image vulnerabilities <image> -t os/non-os/all` | `app version vuln list <version> --app <app>` (filter via `jq` on `namespace` / `packageType`) |
| `image content <image> -t java`                  | `app version package list <version> --app <app>` for the package inventory |
| `image content <image> -t secret_search`         | Per-asset secret/malware/file content surfaces are not exposed at the asset CLI in 6.0 alpha; expected in a later iteration |
| `image ancestors <digest>`                       | No equivalent in the v6 asset model yet |

## Next Module

Next: [Policy Enforcement](policy-enforcement.md) — turning the raw inspection data into pass/fail gates for releases.
