# Visibility

Anchore Enterprise generates and stores detailed SBOMs at every stage of the SDLC, giving you a complete inventory of the software components in your applications — from OS packages and files to direct and transitive dependencies in your language ecosystems. These SBOMs feed every other capability in the platform: vulnerability matching, policy compliance, VEX, and reporting.

In Enterprise 6.0 this data is organised around three concepts:

- **Application** — a logical product or service you ship.
- **Application Version** — a specific release or build of that application (`v1.0.0`, `2026-Q2-rc1`, `HEAD`, …).
- **Asset** — a concrete artifact that belongs to a version: an SBOM you imported, a container image you scanned, a binary, a disk image, etc.

> [!IMPORTANT]
> **What's new in 6.0:** in 5.x you would `image add` first and then `application artifact add` to associate it. In 6.0 the act of adding an SBOM or scanning an image *is* the act of attaching it to a version — assets are created already-bound to their app and version. There is no separate "associate" step.

## How this lab module is structured

This module will walk you through the following tasks or activities: 

1. **Define the application and a version** — the container that everything else attaches to.
2. **Import an SBOM as an asset** — use a bundled SPDX SBOM that represents an externally-produced hand-off.
3. **Scan container images as assets** — try both centralized (Anchore Enterprise pulls) and distributed (anchorectl pulls and scans locally) flows against public images.
4. **Scan a filesystem as an asset** — extract a bundled tarball of a small Python application and let anchorectl generate the SBOM directly from the source tree.
5. **Inspect what you've collected** — list assets, fetch SBOMs, view aggregated vulnerabilities.
6. **Update asset metadata** — edit annotations, rename, or reclassify an existing asset in place without re-scanning.

The workflow is fully sequential — each phase builds on the last. By the end you'll have one application, one version, and four assets attached to it from four different ingestion paths, with metadata that's been refined after the fact. You'll then be ready to start collecting insights on this inventory in the next module.

We'll use the demo assets in `./assets/` throughout.

## Phase 1 — Define the application and a version

Create a new application in Anchore Enterprise. The `--contact-name` flag is required.

```bash
anchorectl app add app \
  --description "Webinar Demo App" \
  --contact-name "Platform Team"
```

Output:

```
 ✔ Created app
Name: app
Description: Webinar Demo App
Contact Name: Platform Team
ID: <app-uuid>
```

Confirm the new application is in place:

```bash
anchorectl app list
```

> [!NOTE]
> An application can also be created with `--policy-id` to bind it to a specific policy at creation time. We'll cover policy assignment in the Policy Enforcement module.

Now add the first version. Versions live under an application, so you have to tell anchorectl which app the version belongs to with `--app`.

```bash
anchorectl app version add v1.0.0 \
  --app app \
  --description "First release with Docker support" \
  --status in_progress
```

Output:

```
 ✔ Created app version
Name: v1.0.0
App: app
Status: in_progress
ID: <version-uuid>
```

List the versions for the app:

```bash
anchorectl app version list --app app
```

Anything you ingest from here on will be attached to a specific `app` + `version`. You can supply these explicitly with `--app` / `--version` on every command, or you can set environment variables to default them:

```bash
export ANCHORECTL_APP=app
export ANCHORECTL_VERSION=v1.0.0
```

The remaining commands in this module will pass `--app` / `--version` explicitly so the workflow is easy to copy-paste, but feel free to use the env vars instead.

## Phase 2 — Import an SBOM as an asset

A common 6.0 pattern is to ingest SBOMs that were produced *outside* of Anchore Enterprise — by a vendor, by a build pipeline, by a different scanner, or by a hand-off from another team. Anchore Enterprise accepts every mainstream SBOM format and treats each one as a first-class asset.

### Supported SBOM formats

| Format               | Spec versions          | File extensions       |
|----------------------|------------------------|-----------------------|
| Syft JSON            | current Syft schema    | `.json`               |
| CycloneDX JSON       | 1.x                    | `.cdx.json`, `.json`  |
| CycloneDX XML        | 1.x                    | `.cdx.xml`, `.xml`    |
| SPDX 2 JSON          | SPDX-2.x               | `.spdx.json`, `.json` |
| SPDX 2 tag-value     | SPDX-2.x               | `.spdx`               |
| SPDX 3 JSON          | 3.x                    | `.spdx.json`, `.json` |

> [!NOTE]
> Format is auto-detected from the file contents.

For this module we've bundled an example SPDX SBOM at `./assets/sboms/my_java_app.spdx.json` — treat it as if it landed in your inbox from a build pipeline or an upstream supplier. It represents a real-world Java application and includes packages with known vulnerabilities, so you'll have something interesting to look at in later modules.

> [!NOTE]
> You can produce SBOMs with Syft, AnchoreCTL, or any other ecosystem tool that emits one of the [supported formats](#supported-sbom-formats). For this module we're skipping the generation step and using the file as-is.

Import the SBOM as an asset under `app@v1.0.0`. Every asset needs a logical `--asset` name — this is how you'll refer to it later (it doesn't have to match anything in the SBOM itself). Use `--annotations` to capture metadata that doesn't fit into the asset name — supplier, format, license terms, source URL, build commit, anything you want surfaced in the UI and queryable later. Recording the source format in an annotation is a small habit that pays off when you're auditing a vendor hand-off months later.

```bash
anchorectl app version asset add sbom ./assets/sboms/my_java_app.spdx.json \
  --app app \
  --version v1.0.0 \
  --asset my-java-app \
  --type application \
  --annotations "supplier=upstream-vendor,format=spdx-2-json,received=2026-05-05" \
  --wait
```

The `--wait` flag tells anchorectl to block until the underlying ingestion job has completed. Without `--wait` you get the job ID back immediately and can poll separately — we'll cover that in Phase 3.

Output (truncated):

```
 ✔ Submitted SBOM asset
Asset: my-java-app
Type: application
Version: v1.0.0
Job ID: <job-uuid>
Status: complete
```

> [!NOTE]
> **What just happened:** Anchore Enterprise queued a job that decomposed the SBOM into packages, persisted them under the version, and ran a vulnerability scan against the deduplicated package set. All of this happens asynchronously through the Jobs API.

The same command handles every supported format the same way — drop a CycloneDX XML, an SPDX tag-value, or an SPDX 3 JSON document in and the server detects and routes it automatically. Adjust the `--type` and `--annotations` to fit what you're ingesting (for example `--type firmware` for a partner-supplied embedded device SBOM, `--type library` for an upstream library hand-off).

## Phase 3 — Scan container images as assets

In 6.0 you can attach a container image to a version two different ways, and we'll do one of each so you see both flows:

- **Centralized analysis** (`app version asset add container-image-remote`) — Anchore Enterprise pulls the image from your registry and analyzes it server-side. The SBOM is produced inside Enterprise.
- **Distributed analysis** (`app version asset add container-image`) — anchorectl pulls (or reads) the image where you're running the command, generates the SBOM **locally**, and uploads the result. Enterprise never sees the image bytes.

Both end up as container assets under `app@v1.0.0`, and from Phase 4 onward they're indistinguishable — the difference is only *where the SBOM was generated* and *which side made the network connection to the registry*.

### Centralized analysis with `add container-image-remote`

We'll start by letting Anchore Enterprise pull `docker.io/library/postgres:13` and analyze it server-side. Imagine this is the database image that ships alongside the Java application whose SBOM you ingested in Phase 2.

> [!NOTE]
> The image we're using is public, so no credentials are needed. For private registries, register credentials first with `anchorectl registry add <registry> --username <user>` (the password is supplied via the `ANCHORECTL_REGISTRY_PASSWORD` environment variable). The registry argument supports wildcards like `gcr.io/myproject/*`. Inspect what's configured with `anchorectl registry list`.

```bash
anchorectl app version asset add container-image-remote docker.io/library/postgres:13 \
  --app app \
  --version v1.0.0 \
  --asset postgres \
  --type container \
  --annotations "role=database,purpose=primary-store,analysis=centralized" \
  --wait
```

Output (truncated):

```
 ✔ Submitted container image asset
Asset: postgres
Type: container
Version: v1.0.0
Image Reference: docker.io/library/postgres:13
Job ID: <job-uuid>
Status: complete
```

> [!NOTE]
> **What just happened:** Anchore Enterprise queued a job that pulled the image from Docker Hub, generated an SBOM server-side, persisted the packages and image metadata under the version, and ran a vulnerability scan. The Jobs API does the work asynchronously — `--wait` just polls until it finishes.

> [!TIP]
> Drop `--wait` and the command returns the job ID immediately — useful in CI pipelines where you want to fan out work and check results later. Track in-flight jobs with `anchorectl app job list app --status processing` and inspect a single job with `anchorectl app job get <job-id> --app app`. Job statuses are `pending`, `processing`, `complete`, `failed`, `cancelled`.

### Distributed analysis with `add container-image`

Now we'll do the same thing the other way round — anchorectl pulls a small public image (`docker.io/library/ubuntu:jammy`, around 30 MB compressed), generates the SBOM locally, and uploads only the result. Use this flow when the image shouldn't leave your build host (air-gapped builds, ephemeral CI runners, embargoed artifacts), or when Anchore Enterprise can't reach your registry but you can.

```bash
anchorectl app version asset add container-image docker.io/library/ubuntu:jammy \
  --app app \
  --version v1.0.0 \
  --asset ubuntu-jammy \
  --type container \
  --annotations "role=base-image,os=ubuntu-22.04,analysis=distributed" \
  --wait
```

Output (truncated):

```
 ✔ Submitted container image asset
Asset: ubuntu-jammy
Type: container
Version: v1.0.0
Image Reference: docker.io/library/ubuntu:jammy
Job ID: <job-uuid>
Status: complete
```

> [!NOTE]
> **What just happened:** anchorectl pulled `ubuntu:jammy` from Docker Hub to your local machine, ran the analysis client-side (the embedded Syft scans the image, the embedded analyzers extract metadata), packaged the result, and uploaded the SBOM to Enterprise as an asset. The Jobs API still tracks the upload server-side, but the image itself was never touched by Enterprise.

By default `add container-image` reads from the registry. The `--from` flag changes the source:

| Source                       | Use it when …                                                       |
|------------------------------|---------------------------------------------------------------------|
| `--from registry` (default)  | The image is in a registry you can reach.                           |
| `--from docker`              | The image is loaded in a local Docker daemon.                       |
| `--from podman`              | The image is loaded in a local Podman.                              |
| `--from docker-archive:<path>` | You have a `docker save` tarball on disk.                         |

### Centralized vs distributed — when to choose which

| Centralized (`add container-image-remote`)        | Distributed (`add container-image`)                       |
|---------------------------------------------------|-----------------------------------------------------------|
| Anchore Enterprise pulls the image from the registry | anchorectl pulls or reads the image where it's running |
| SBOM is generated server-side                     | SBOM is generated client-side and uploaded                |
| Best when Anchore Enterprise has direct registry access | Best when the image stays on the build host         |
| Compute happens in Enterprise                     | Compute happens wherever you run anchorectl               |
| One network egress (Anchore Enterprise → registry) | No exposure of the registry to Anchore Enterprise        |

### Watching the registry for new tags

For images that change frequently — base images, third-party services you depend on, your own published artifacts — Anchore Enterprise can watch a repository continuously and analyze new tags as they appear. Set up a watch on the Postgres repository you analyzed centrally:

```bash
anchorectl repo add docker.io/library/postgres --auto-subscribe
```

`--auto-subscribe` enables a `tag_update` subscription on the **repository**, so any new tag pushed becomes a fresh analysis automatically.

For the specific tag you analyzed earlier (`docker.io/library/postgres:13`), explicitly activate a `tag_update` subscription on that exact tag so a re-push of the same tag triggers a re-analysis as well:

```bash
anchorectl subscription activate docker.io/library/postgres:13 tag_update
```

Confirm both are active:

```bash
anchorectl repo list
anchorectl subscription list
```

> [!IMPORTANT]
> Repo watches and subscriptions in 6.0 alpha are still served by the v5 catalog and operate on raw image records. Tags discovered through a watch get analyzed and show up in the system, but they are **not automatically attached to your app/version as assets** — you'll still run `app version asset add container-image-remote` to bind a specific tag to a release. Treat watches as a "keep this image inventory fresh" mechanism, separate from your release tracking.

## Phase 4 — Scan a filesystem as an asset

Not everything you ship is a container image, and not every artifact comes with a pre-produced SBOM. For source code that hasn't been packaged yet, an unpacked tarball, a virtual machine root filesystem, or any other on-disk content, anchorectl can scan a directory locally and ingest the result as an asset in one step using `app version asset add filesystem DIRECTORY`.

For this phase we've bundled a small Python application as a tarball at `./assets/my-python-app.tar.gz`. It contains application source plus a `requirements.txt` pinning a handful of dependencies at versions with known vulnerabilities — exactly the kind of artifact a build pipeline might hand off mid-flight.

Extract it somewhere convenient:

```bash
tar -xzf ./assets/my-python-app.tar.gz -C /tmp/
```

You'll get `/tmp/my-python-app/` containing `app.py`, `requirements.txt`, and a `README.md`. Take a quick look at `requirements.txt` if you want to know what's in there — Flask, requests, PyYAML, urllib3, Jinja2, cryptography, and Pillow, each pinned to an old release with documented CVEs.

Now point anchorectl at the extracted directory:

```bash
anchorectl app version asset add filesystem /tmp/my-python-app \
  --app app \
  --version v1.0.0 \
  --asset my-python-app \
  --type application \
  --annotations "language=python,role=worker,source=upstream-tarball" \
  --supplier "Internal CI" \
  --wait
```

Output (truncated):

```
 ✔ Analyzed filesystem asset
Asset: my-python-app
Type: application
Version: v1.0.0
Job ID: <job-uuid>
Status: complete
```

> [!NOTE]
> **What just happened:** anchorectl walked the directory tree, generated an SBOM client-side from the files it found (including the dependency declarations in `requirements.txt`), and uploaded that SBOM to Enterprise as a new asset. No image was built; nothing was installed; Enterprise never sees the directory contents — just the resulting SBOM. The Python CVEs you'll see in Phase 5 come straight from the version pins in `requirements.txt`.

> [!NOTE]
> The same `add filesystem` command works against any directory you can point it at — you could use this to scan things like a VM root filesystem, a mounted disk image, an unpacked golden image, a host snapshot, a directory of artifacts pulled from object storage, and so on.

## Phase 5 — Inspect everything you've collected

You now have one application, one version, and four assets attached to it: an imported SBOM (the Java application), two container images — one analyzed centrally (Postgres), one analyzed locally (Ubuntu Jammy) — and a filesystem-derived SBOM (the Python application). Let's look at what's in there.

List all assets under the version:

```bash
anchorectl app version asset list v1.0.0 --app app
```

Output:

```
 ✔ Listed assets
┌────────────────┬─────────────┬──────────────────────┬──────────────────────┐
│ NAME           │ TYPE        │ CREATED              │ ID                   │
├────────────────┼─────────────┼──────────────────────┼──────────────────────┤
│ my-java-app    │ application │ 2026-05-05T10:22:00Z │ <uuid>               │
│ postgres       │ container   │ 2026-05-05T10:24:11Z │ <uuid>               │
│ ubuntu-jammy   │ container   │ 2026-05-05T10:26:32Z │ <uuid>               │
│ my-python-app  │ application │ 2026-05-05T10:28:55Z │ <uuid>               │
└────────────────┴─────────────┴──────────────────────┴──────────────────────┘
```

The `analysis` annotation we set on each container asset (`centralized` vs `distributed`) is preserved on the asset record — drill into either container with `asset get` to confirm:

```bash
anchorectl app version asset get postgres \
  --app app --version v1.0.0 -o json
anchorectl app version asset get ubuntu-jammy \
  --app app --version v1.0.0 -o json
```

Pull back the SBOM that was stored for an asset — useful for hand-offs and customer requests. Both ingestion paths (server-side and client-side) leave a queryable SBOM in Enterprise:

```bash
anchorectl app version asset sbom get my-java-app \
  --app app --version v1.0.0 \
  --file ./my-java-app-sbom-roundtrip.json
```

See vulnerabilities aggregated across **every asset** in the version:

```bash
anchorectl app version vuln list v1.0.0 --app app
```

This is the version-level view: deduplicated CVE matches across the imported Java SBOM, the centrally-analyzed Postgres image, the locally-analyzed Ubuntu image, and the Python application's pinned dependencies — all treated as one release. The Inspection module dives deeper into filtering, severity, and fix data.

Audit the ingestion history for the app:

```bash
anchorectl app job list app --status complete
```

Open the Web UI at `/applications`, find `app`, click into `v1.0.0`, and you'll see all four assets, the package inventory, the vulnerability picture, and the original SBOMs available for download.

## Phase 6 — Update asset metadata

You don't always know everything about an asset at the moment you import it. A vendor hand-off might land before you know the real supplier name; an asset might be classified with the wrong `--type`; a placeholder name might slip in from CI and need cleaning up. `anchorectl app version asset update` lets you change asset metadata — annotations, name, type — in place, without re-scanning or re-importing the underlying SBOM.

### Updating annotations

When we imported the Java SBOM in Phase 2 we used a placeholder annotation `supplier=upstream-vendor`. Imagine the security team has now confirmed the real upstream supplier and wants to capture that for the audit trail. Update the annotations:

```bash
anchorectl app version asset update my-java-app \
  --app app \
  --version v1.0.0 \
  --annotations "supplier=apache-foundation,reviewed-by=security-team,reviewed-on=2026-05-06"
```

> [!NOTE]
> Annotations passed to `update` **merge with the existing set** rather than replacing them outright. To remove a single annotation, set its value to empty: `--annotations "key="` clears that specific annotation but leaves the others alone.

### Renaming an asset

If the asset name no longer fits — perhaps a placeholder slipped in from CI, or the team renamed the component — change it with `--name`:

```bash
anchorectl app version asset update my-python-app \
  --app app \
  --version v1.0.0 \
  --name python-worker
```

The asset keeps its UUID, its SBOM contents, and its place under `app@v1.0.0` — only the human-facing name changes. Any subsequent commands need to use the new name.

### Reclassifying an asset

If you decide an asset should be tracked under a different `--type` — for example, promoting an entry from `application` to `library` because it turned out to be a reusable component — `update --type` does that without disturbing anything else:

```bash
anchorectl app version asset update python-worker \
  --app app \
  --version v1.0.0 \
  --type library
```

Confirm the changes landed by listing again:

```bash
anchorectl app version asset list v1.0.0 --app app
anchorectl app version asset get python-worker --app app --version v1.0.0 -o json
```

> [!IMPORTANT]
> `asset update` is metadata-only. It does **not** replace the SBOM contents, re-trigger analysis, or change the underlying scan results. To re-scan an artifact after a content change, the recommended pattern in 6.0 is to create a new app version (e.g. `v1.0.1`) and re-add the artifact there — each version captures a point-in-time view of its assets, and you can compare versions for drift.

## Recap

You created an application, gave it a version, and attached four assets to that version: an imported SBOM (the Java application hand-off), a centrally-analyzed container (Postgres), a locally-analyzed container (Ubuntu Jammy), and a filesystem-derived SBOM (the Python application). Everything you ingested is automatically scoped to `app@v1.0.0` — there's no follow-up step to associate artifacts with the release.

The 6.0 asset-add commands all live under `app version asset add <type>`:

| Asset type            | Command                                              |
|-----------------------|------------------------------------------------------|
| Pre-existing SBOM     | `app version asset add sbom SBOM_FILE`              |
| Container, centralized| `app version asset add container-image-remote IMAGE`|
| Container, distributed| `app version asset add container-image IMAGE`       |
| Filesystem / VM       | `app version asset add filesystem DIRECTORY`        |

The big shifts from 5.x to remember:

| 5.x                                               | 6.0                                                              |
|---------------------------------------------------|------------------------------------------------------------------|
| `image add` then `application artifact add`       | One step: `app version asset add container-image[-remote] …`     |
| `source add` and `sbom add` were separate flows   | Both go through `app version asset add sbom <file>`              |
| `--from docker/registry/docker-archive` on image add | Same flag now lives on `add container-image` (distributed)    |
| Synchronous calls                                 | Job-based; use `--wait` or poll `app job get/list`               |
| `anchorectl source add` for source-tree SBOMs     | `app version asset add filesystem <dir>` covers source, VMs, hosts |

And things that look the same in 6.0 alpha but are still served by v5 underneath: `registry`, `repo`, `subscription`, `event`. They work, but they don't yet integrate with the app/version asset model — bridging that gap is on the roadmap.

## Next Module

Next: [Inspection](inspection.md) — turning all this visibility into actionable security findings.
