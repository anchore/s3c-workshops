# Inspection

Security checks inspecting for vulnerabilities, secrets, permissions, and malware.

In the previous lab, we looked into the SBOM capability as a vital foundation for gaining visibility into our software and containers. 
In this lab, we will explore deeper and inspect this data to uncover useful information that can aid compliance and/or security.
To achieve this, you need vulnerability feed data, and for this we briefly touch on how feed source information is gathered and made available to enrich the SBOMs.
Just like SBOM data, vulnerability data is foundational and without it, you won't have accurate data to make informed decisions.

Inspecting the results of SBOMs and vulnerabilities across source applications and containers can help you identify many issues, here are our top 10:

1. Inspect files for malicious content
2. Inspect packages for malicious content
3. Analyze each vulnerability to gather sufficient information about risk to plan its remediation
4. Inspect for license abuse/misuse
5. Inspect source code repos for vulns
6. Inspect & monitor file permissions
7. Inspect for misconfiguration in the Dockerfiles
8. Detect known exploited vulnerabilities
9. Inspect for vulns inherited by base images
10. Inspect relational analysis to identify vulns across images and stages

> [!TIP]
> For a visual walkthrough checkout the [inspection workshop materials](https://viperr.anchore.com/inspection/).

## Lab Exercises

### Inspection of feed sources
Anchore Enterprise uses security vulnerability data from a number of different sources from NVD to more specific sources such as GHSA (GitHub Advisory Database) and vendor specific sources.
The Anchore Feed Service collects this vulnerability source data and normalizes it into a dataset, which in turn is used to show vulnerabilities for specific images/source and well as used by the Policy Engine to evaluate policies and make decisions.
For the demo environment, don't worry we have pre-configured and bundled this vulnerability dataset for you. The demo does however, miss some enterprise sources such as MSRC and Anchore's own exclusions' data.

Anchore prefers to use the most specific data to enable the best possible vulnerability findings. For example, whilst a general CVE might apply to a particular version of Bash, the way an OS vendor like Ubuntu could install Bash, might mean that the general CVE has a lower risk and rating.
Having up to date, relevant and specific vulnerability data is paramount. In combination with accurate SBOMs, the correctness of vulnerability data helps steer you away from false positives and false negatives and get you the insights about the software that you need.

Let's first check what vulnerability data we have in our new deployment. Is it up to date? Does it cover what we need?
```bash
anchorectl feed list
```
Output
```
┌─────────────────┬────────────────────┬─────────┬──────────────────────┬──────────────┐
│ FEED            │ GROUP              │ ENABLED │ LAST SYNC            │ RECORD COUNT │
├─────────────────┼────────────────────┼─────────┼──────────────────────┼──────────────┤
│ vulnerabilities │ github:composer    │ true    │ 2024-03-14T12:55:47Z │ 2821         │
│ vulnerabilities │ github:dart        │ true    │ 2024-03-14T12:55:47Z │ 6            │
│ vulnerabilities │ github:gem         │ true    │ 2024-03-14T12:55:47Z │ 763          │
│ vulnerabilities │ github:go          │ true    │ 2024-03-14T12:55:47Z │ 1504         │
│ vulnerabilities │ github:java        │ true    │ 2024-03-14T12:55:47Z │ 4777         │
│ vulnerabilities │ github:npm         │ true    │ 2024-03-14T12:55:47Z │ 13363        │
│ vulnerabilities │ github:nuget       │ true    │ 2024-03-14T12:55:47Z │ 566          │
│ vulnerabilities │ github:python      │ true    │ 2024-03-14T12:55:47Z │ 2488         │
│ vulnerabilities │ github:rust        │ true    │ 2024-03-14T12:55:47Z │ 730          │
│ vulnerabilities │ github:swift       │ true    │ 2024-03-14T12:55:47Z │ 30           │
│ vulnerabilities │ nvd                │ true    │ 2024-03-14T12:55:47Z │ 241467       │
│ vulnerabilities │ alpine:3.19        │ true    │ 2024-03-14T12:55:47Z │ 6087         │
│ vulnerabilities │ alpine:3.2         │ true    │ 2024-03-14T12:55:47Z │ 305          │
...
│ vulnerabilities │ alpine:edge        │ true    │ 2024-03-14T12:55:47Z │ 6096         │
│ vulnerabilities │ amzn:2             │ true    │ 2024-03-14T12:55:47Z │ 1990         │
│ vulnerabilities │ amzn:2022          │ true    │ 2024-03-14T12:55:47Z │ 276          │
│ vulnerabilities │ amzn:2023          │ true    │ 2024-03-14T12:55:47Z │ 579          │
│ vulnerabilities │ chainguard:rolling │ true    │ 2024-03-14T12:55:47Z │ 1593         │
│ vulnerabilities │ debian:10          │ true    │ 2024-03-14T12:55:47Z │ 29569        │
...
│ vulnerabilities │ debian:7           │ true    │ 2024-03-14T12:55:47Z │ 20455        │
│ vulnerabilities │ debian:unstable    │ true    │ 2024-03-14T12:55:47Z │ 32200        │
│ vulnerabilities │ mariner:1.0        │ true    │ 2024-03-14T12:55:47Z │ 2092         │
│ vulnerabilities │ mariner:2.0        │ true    │ 2024-03-14T12:55:47Z │ 2148         │
│ vulnerabilities │ ol:5               │ true    │ 2024-03-14T12:55:47Z │ 1255         │
..
│ vulnerabilities │ rhel:5             │ true    │ 2024-03-14T12:55:47Z │ 7202         │
..
│ vulnerabilities │ rhel:9             │ true    │ 2024-03-14T12:55:47Z │ 2331         │
│ vulnerabilities │ sles:11            │ true    │ 2024-03-14T12:55:47Z │ 594          │
..
│ vulnerabilities │ sles:15.5          │ true    │ 2024-03-14T12:55:47Z │ 8731         │
│ vulnerabilities │ ubuntu:12.04       │ true    │ 2024-03-14T12:55:47Z │ 14934        │
...
│ vulnerabilities │ ubuntu:23.10       │ true    │ 2024-03-14T12:55:47Z │ 15359        │
│ vulnerabilities │ wolfi:rolling      │ true    │ 2024-03-14T12:55:47Z │ 1449         │
└─────────────────┴────────────────────┴─────────┴──────────────────────┴──────────────┘
```
You also inspect the events data to see when each source was last updated and if there were any problems.

Keeping Anchore fresh with relevant data is one of the key tenants of the product and service.

> [!TIP]
> We can also see this feed information in the Web UI under `system` when logged in as Admin.

### Inspection of vulnerabilities

During the analysis of container images, Anchore Enterprise performs deep inspection, collecting data on all artifacts in the image including files, operating system packages and software artifacts such as Ruby GEMs and Node.JS NPM modules.

When we add an image, it takes time to analyze. We can find out if that analysis has been completed. We could run this with --wait if we put this into a pipeline.
```bash
anchorectl image get app:v2.0.0
```
Output
```
Tag: docker.io/app:v2.0.0
Digest: sha256:30c82fbf2de5a357a91f38bf68b80c2cd5a4b9ded849dbdf4b4e82e807511ffa
ParentDigest: sha256:30c82fbf2de5a357a91f38bf68b80c2cd5a4b9ded849dbdf4b4e82e807511ffa
ID: c0f2aa60caaed2d504b23b9fd280f73341906b00ffcd8a6ecfe52acda252d359
Analysis: analyzed
Status: active
```
We could then show OS, Non-OS or ALL the vulnerabilities we find.
```bash
anchorectl image vulnerabilities app:v2.0.0 -a
```
Output 
```
all
non-os
os
```

Let's grab the Non-OS vulns in a table format (handy for pipeline output)
```bash
anchorectl image vulnerabilities app:v2.0.0 -t non-os
```
Output
```
┌─────────────────────┬──────────┬──────────────────────────────────┬────────────────────────────────────┬────────┬──────────────┬────────┬───────────────┬────────────────┬───────────────────────────────────────────────────┐
│ ID                  │ SEVERITY │ NAME                             │ VERSION                            │ FIX    │ WILL NOT FIX │ TYPE   │ FEED GROUP    │ CVES           │ URL                                               │
├─────────────────────┼──────────┼──────────────────────────────────┼────────────────────────────────────┼────────┼──────────────┼────────┼───────────────┼────────────────┼───────────────────────────────────────────────────┤
│ CVE-2023-45290      │ Unknown  │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │                │ https://nvd.nist.gov/vuln/detail/CVE-2023-45290   │
│ CVE-2023-44487      │ High     │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-44487 │ https://nvd.nist.gov/vuln/detail/CVE-2023-44487   │
│ CVE-2023-45285      │ High     │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-45285 │ https://nvd.nist.gov/vuln/detail/CVE-2023-45285   │
│ CVE-2024-24785      │ Unknown  │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │                │ https://nvd.nist.gov/vuln/detail/CVE-2024-24785   │
│ CVE-2023-39326      │ Medium   │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-39326 │ https://nvd.nist.gov/vuln/detail/CVE-2023-39326   │
│ GHSA-hpxr-w9w7-g4gv │ Medium   │ github.com/anchore/stereoscope   │ v0.0.0-20230627195312-cd49355d934e │ 0.0.1  │ false        │ go     │ github:go     │ CVE-2024-24579 │ https://github.com/advisories/GHSA-hpxr-w9w7-g4gv │
│ GHSA-m425-mq94-257g │ High     │ google.golang.org/grpc           │ v1.55.0                            │ 1.56.3 │ false        │ go     │ github:go     │                │ https://github.com/advisories/GHSA-m425-mq94-257g │
│ GHSA-2wrh-6pvc-2jm9 │ Medium   │ golang.org/x/net                 │ v0.11.0                            │ 0.13.0 │ false        │ go     │ github:go     │ CVE-2023-3978  │ https://github.com/advisories/GHSA-2wrh-6pvc-2jm9 │
│ GHSA-jq35-85cj-fj4p │ Medium   │ github.com/docker/docker         │ v24.0.2+incompatible               │ 24.0.7 │ false        │ go     │ github:go     │                │ https://github.com/advisories/GHSA-jq35-85cj-fj4p │
│ CVE-2023-39319      │ Medium   │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-39319 │ https://nvd.nist.gov/vuln/detail/CVE-2023-39319   │
│ GHSA-4374-p667-p6c8 │ High     │ golang.org/x/net                 │ v0.11.0                            │ 0.17.0 │ false        │ go     │ github:go     │ CVE-2023-39325 │ https://github.com/advisories/GHSA-4374-p667-p6c8 │
│ GHSA-7ww5-4wqc-m92c │ Medium   │ github.com/containerd/containerd │ v1.7.0                             │ 1.7.11 │ false        │ go     │ github:go     │                │ https://github.com/advisories/GHSA-7ww5-4wqc-m92c │
│ CVE-2023-45287      │ High     │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-45287 │ https://nvd.nist.gov/vuln/detail/CVE-2023-45287   │
│ CVE-2023-45289      │ Unknown  │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │                │ https://nvd.nist.gov/vuln/detail/CVE-2023-45289   │
│ GHSA-qppj-fm5r-hxr3 │ Medium   │ golang.org/x/net                 │ v0.11.0                            │ 0.17.0 │ false        │ go     │ github:go     │ CVE-2023-44487 │ https://github.com/advisories/GHSA-qppj-fm5r-hxr3 │
│ GHSA-8489-44mv-ggj8 │ Medium   │ log4j-core                       │ 2.15.0                             │ 2.17.1 │ false        │ java   │ github:java   │ CVE-2021-44832 │ https://github.com/advisories/GHSA-8489-44mv-ggj8 │
│ GHSA-45x7-px36-x8w8 │ Medium   │ golang.org/x/crypto              │ v0.10.0                            │ 0.17.0 │ false        │ go     │ github:go     │ CVE-2023-48795 │ https://github.com/advisories/GHSA-45x7-px36-x8w8 │
│ GHSA-9763-4f94-gfch │ High     │ github.com/cloudflare/circl      │ v1.3.3                             │ 1.3.7  │ false        │ go     │ github:go     │                │ https://github.com/advisories/GHSA-9763-4f94-gfch │
│ GHSA-crh6-fp67-6883 │ Critical │ xmldom                           │ 0.6.0                              │ None   │ false        │ npm    │ github:npm    │ CVE-2022-39353 │ https://github.com/advisories/GHSA-crh6-fp67-6883 │
│ GHSA-mw99-9chc-xw7r │ High     │ github.com/go-git/go-git/v5      │ v5.7.0                             │ 5.11.0 │ false        │ go     │ github:go     │ CVE-2023-49568 │ https://github.com/advisories/GHSA-mw99-9chc-xw7r │
│ GHSA-p6xc-xr62-6r2g │ High     │ log4j-core                       │ 2.15.0                             │ 2.17.0 │ false        │ java   │ github:java   │ CVE-2021-45105 │ https://github.com/advisories/GHSA-p6xc-xr62-6r2g │
│ GHSA-5fg8-2547-mr8q │ Medium   │ xmldom                           │ 0.6.0                              │ None   │ false        │ npm    │ github:npm    │ CVE-2021-32796 │ https://github.com/advisories/GHSA-5fg8-2547-mr8q │
│ CVE-2023-39318      │ Medium   │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-39318 │ https://nvd.nist.gov/vuln/detail/CVE-2023-39318   │
│ GHSA-qppj-fm5r-hxr3 │ Medium   │ google.golang.org/grpc           │ v1.55.0                            │ 1.56.3 │ false        │ go     │ github:go     │ CVE-2023-44487 │ https://github.com/advisories/GHSA-qppj-fm5r-hxr3 │
│ CVE-2024-24783      │ Unknown  │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │                │ https://nvd.nist.gov/vuln/detail/CVE-2024-24783   │
│ GHSA-8gq9-2x98-w8hf │ High     │ protobuf                         │ 3.20.0                             │ 3.20.2 │ false        │ python │ github:python │ CVE-2022-1941  │ https://github.com/advisories/GHSA-8gq9-2x98-w8hf │
│ CVE-2024-24784      │ Unknown  │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │                │ https://nvd.nist.gov/vuln/detail/CVE-2024-24784   │
│ GHSA-7rjr-3q55-vv33 │ Critical │ log4j-core                       │ 2.15.0                             │ 2.16.0 │ false        │ java   │ github:java   │ CVE-2021-45046 │ https://github.com/advisories/GHSA-7rjr-3q55-vv33 │
│ CVE-2023-39323      │ High     │ stdlib                           │ go1.19.12                          │ None   │ false        │ go     │ nvd           │ CVE-2023-39323 │ https://nvd.nist.gov/vuln/detail/CVE-2023-39323   │
│ GHSA-449p-3h89-pw88 │ Critical │ github.com/go-git/go-git/v5      │ v5.7.0                             │ 5.11.0 │ false        │ go     │ github:go     │ CVE-2023-49569 │ https://github.com/advisories/GHSA-449p-3h89-pw88 │
└─────────────────────┴──────────┴──────────────────────────────────┴────────────────────────────────────┴────────┴──────────────┴────────┴───────────────┴────────────────┴───────────────────────────────────────────────────
```

We can inspect an image from other "view points" as well. This can be handy to trigger rules, checks or steps, based on what is discovered
```bash
anchorectl image content app:v2.0.0 -a
```
Output
```
binary
content_search
files
gem
go
java
malware
npm
nuget
os
python
retrieved_files
secret_search
```

Now let's check out something specific.
```bash
anchorectl image content app:v2.0.0 -t java
```
Output
```
Java Packages:
┌────────────┬───────────────┬───────────────┬───────────────┬──────────┬──────────────────────────┬────────────────────────┬─────────┐
│ PACKAGE    │ IMPL. VERSION │ SPEC. VERSION │ MAVEN VERSION │ TYPE     │ ORIGIN                   │ LOCATION               │ VERSION │
├────────────┼───────────────┼───────────────┼───────────────┼──────────┼──────────────────────────┼────────────────────────┼─────────┤
│ log4j-core │ 2.15.0        │ 2.15.0        │ 2.15.0        │ JAVA-JAR │ org.apache.logging.log4j │ /log4j-core-2.15.0.jar │ 2.15.0  │
└────────────┴───────────────┴───────────────┴───────────────┴──────────┴──────────────────────────┴────────────────────────┴─────────┘
```
We should really get someone to check this package out a little more...

One cool thing in the example above is that you can see where the software is being found as per the location column.
This is great when you might have many binaries and packages nested all over and then mapping these to vulnerabilities helps you understand the situation faster.

> We can also see this vuln information in the Web UI under `image` or via the `application` page.

### Inspection of base image(s)

Container images often include a parent or base image (the FROM syntax). This is typically an OS image like Ubuntu or Alpine but it could be a corporate or application 'golden image' provided with a bunch of standardised software.
In either case, it's helpful to be able to separate out, where did this policy, vulnerability of otherwise originate from.
And with Anchore you have Base Image support where you can filter out results and understand that hierarchy. 

Let's start by adding our base image, which is named 'base' with no originality in mind. Is it happens the app:v2.0.0 was using this image as a parent.
```bash
anchorectl application add base --description "Webinar Demo Base Image"
anchorectl application version add base@v1.0.0
cd ./assets/base:v1.0.0
docker build . -t base:v1.0.0
anchorectl image add base:v1.0.0 --from docker 
```
Make note of the digest in the image add output, we will use this in the next step.
```bash
anchorectl application artifact add base@v1.0.0 image <retrieved-image-sha>
```

Now we add the v3.0.0 image that uses base:v1.0.0 as it's base image
```bash
anchorectl application version add app@v3.0.0
cd ./assets/app:v3.0.0
docker build . -t app:v3.0.0
anchorectl image add app:v3.0.0 --from docker --dockerfile ./Dockerfile --force
```
Make note of the digest in the image add output, we will use this in the next two steps.
```bash
anchorectl application artifact add app@v3.0.0 image <retrieved-image-sha>
```
We can see the ancestors of our app:v3.0.0 (here we use the image digest)
```bash
anchorectl image ancestors <retrieved-image-sha>
```
Output
```
 ✔ Fetched ancestors
┌─────────────────────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────────────────────────┬───────────────────────┐
│ ANCESTOR IMAGE DIGEST                                                   │ LAYERS                                                                  │ TAGS                  │
├─────────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┼───────────────────────┤
│ sha256:f227723f265bcdf9adf8b72aeb84c0a384a29381c8afeb4211cba956de0b60ca │ sha256:b0aa185466d38ea4aa9fc2f44a0df75f2a2fb532718e08b5f6e5ea188f1ab0b2 │ docker.io/base:v1.0.0 │
│                                                                         │ sha256:158225b8095a6cf7919fcd3b0730218a7bb47439bb26670629c6676a7ac6595a │                       │
│                                                                         │ sha256:b0d0e74e8939f17782fd628559705564fdf75512d4f5de23e9a70ef140d57415 │                       │
└─────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────────────────────────────────────────┴───────────────────────┘
```
The web UI here is useful, under vulnerabilities click on `CVEs Not Inherited From Base`. which will filter out and ignore base image vulnerabilities. 
Helping you focus on the application containers issues and avoid the wider noise, which can be targeted in other processes.

> Learn more about [base images](https://docs.anchore.com/current/docs/overview/concepts/images/base_images/)

### Inspection of secrets, retrieved files, file content and malware

You can configure Anchore to scan for secrets (like AWS_ACCESS_KEY for example) as well as files and/or content in files that perhaps you might want to block from your containers.
In addition, you can also scan a container for malware to catch situations where a binary with questionable provenance could make it into your pipeline (for example a cyptominer).

Anchore can be configured to look for these unknowns as well as known matches with regexes, and it can be configured to do this locally (when scanning an image in distributed mode) as well as the core Anchore deployment itself ( centralized mode ). 

> [!NOTE]
> Malware checks can only be run in centralized mode. Anchore must pull the image and scan server-side in order to check each file.
> Malware, secrets and retrieved files have been enabled in this webinar demo and pre-configured. Content search has been disabled.

Let's check if we have any secrets in our v2.0.0 app?
```bash
anchorectl image content app:v2.0.0 -t secret_search
```
Output
```
Secret Search:
┌────────────────┬─────────────────────────────────────────────────────────────┬────────────┐
│ SEARCH NAME    │ PATH                                                        │ AT LINE(S) │
├────────────────┼─────────────────────────────────────────────────────────────┼────────────┤
│ PRIV_KEY       │ /usr/bin/ssh-add                                            │ 335        │
│ PRIV_KEY       │ /usr/bin/ssh-keygen                                         │ 631        │
│ PRIV_KEY       │ /usr/share/doc/perl-Net-SSLeay/assets/server_key.pem      │ 0          │
│ PRIV_KEY       │ /usr/share/doc/perl-IO-Socket-SSL/example/simulate_proxy.pl │ 292        │
│ PRIV_KEY       │ /usr/bin/ssh                                                │ 1475       │
│ AWS_ACCESS_KEY │ /aws_access                                                 │ 0          │
│ PRIV_KEY       │ /usr/libexec/openssh/ssh-keysign                            │ 345        │
└────────────────┴─────────────────────────────────────────────────────────────┴────────────┘
```
Oh dear, looks like we found a few issues. This was found using the following regex configuration:
```
  secret_search:
    match_params:
      - MAXFILESIZE=10000
      - STOREONMATCH=n
    regexp_match:
      - "AWS_ACCESS_KEY=(?i).*aws_access_key_id( *=+ *).*(?<![A-Z0-9])[A-Z0-9]{20}(?![A-Z0-9]).*"
      - "AWS_SECRET_KEY=(?i).*aws_secret_access_key( *=+ *).*(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=]).*"
      - "PRIV_KEY=(?i)-+BEGIN(.*)PRIVATE KEY-+"
      - "DOCKER_AUTH=(?i).*\"auth\": *\".+\""
      - "API_KEY=(?i).*api(-|_)key( *=+ *).*(?<![A-Z0-9])[A-Z0-9]{20,60}(?![A-Z0-9]).*"
```
Let's list retrieve some known files
```bash
anchorectl image content centos:latest -t retrieved_files
```
Output
```
Retrieved Files:
┌─────────────┐
│ PATH        │
├─────────────┤
│ /etc/passwd │
└─────────────┘
```
Oh dear, looks like we added a password file. This was found using the following regex configuration:
```
  retrieve_files:
    file_list:
      - '/etc/passwd'
      - '/etc/services'
      - '/etc/sudoers'
```
Finally, with malware we need to analyze in centralized mode and therefore need to pull an image from a registry.
```bash
anchorectl image add docker.io/danperry/app:v2.0.0 --wait
anchorectl image content docker.io/danperry/app:v2.0.0 -t malware
```
Output
```
Malware:
┌─────────┬──────────────────────────────────────────┬──────────────┐
│ SCANNER │ MATCHED SIGNATURE                        │ PATH         │
├─────────┼──────────────────────────────────────────┼──────────────┤
│ clamav  │ Multios.Trojan.CryptocoinMiner-6448864-1 │ /xmrig/xmrig │
│ clamav  │ Multios.Coinminer.Miner-6781728-2        │ /xmrig/xmrig │
└─────────┴──────────────────────────────────────────┴──────────────┘
```
Oh, dear... it looks like this image has some malware baked in. We better not deploy this!

> [!TIP]
> You can see ALL of this information in the web UI for the image in question under the SBOM navigation tab.
> Later you will learn how this information can be used at a policy enforcement level.

## Next Lab

Next: [Policy Enforcement](policy-enforcement.md)