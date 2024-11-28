# Visibility

Building an accurate Software Bill of Materials (SBOM) from source to a built and running container across the SDLC is vital.
This data is needed to aid compliance as well as operational tasks such as analysis, policy enforcement and remediation.
In this lab, you will be adding some example applications across source and container origins to get visibility into their contents and application at the different stages of the SDLC.

There are many goals around SBOM visibility, here are our top 10:

1. Identification of OS + Language packages
2. Identification of package licensing
3. Identification of package origin
4. Identification of package size
5. Identification of all files
6. Identification of file size
7. Identification of file permissions
8. Identification of files unique identifiers
9. Identification of relevant image/pkg metadata
10. Collect, safeguard, maintain, and share provenance data for all components of each software release

> [!TIP]
> For a visual walkthrough checkout the [visibility workshop materials](https://viperr.anchore.com/visibility/).

## Lab Exercises

An application starts life as code, and eventually (in the cloud native world) transforms into a distributable container. 
The end-to-end process is commonly referred to as the SDLC (Software Delivery Lifecycle), and across the different stages Anchore Enterprise can track and manage the SBOM.
Let's now unpack how you can create, track and manage those SBOMs within Anchore.

### SBOM Visibility of source code

Let's change into the directory containing the code that our dev team have just produced.
Do check out what's in this amazing Go application...
```bash
cd ./assets/app
```
Create a new Anchore application, with which we can associate source code and containers.
```bash
anchorectl application add app --description "Webinar Demo App"
```
> [!NOTE]
> You can only currently - add, edit and delete applications via the anchorectl or Anchore API

Review the first example application source code and generate an SBOM (locally) for it. 
Then we can map the source code reference and SBOM into Anchore. 
This would be a typical task that gets carried out during CI.
```bash
anchorectl syft --source-name app --source-version HEAD -o json . | anchorectl source add github.com/anchore/webinar-demo@73522db08db1758c251ad714696d3120ac9b55f4 --from -
```
Make note of the UUID in the output we will use this later.
> [!TIP]
> If you already have Syft installed you can use it $ syft -o json . | anchorectl source add ...

Now we associate the source artifact to our application tag HEAD. As you continuously integrate you also can update Anchore with the latest code. 
```bash
anchorectl application artifact add app@HEAD source <retrieved-source-UUID>
```
Now output the SBOM contents to screen in the table format. This could be useful for reporting or as output step in CI.
```bash
anchorectl source sbom <retrieved-source-UUID> -o table
```
Check out the new application in the Web UI by visiting `/applications` and see the mapping over to our source control commit.
Finally, please explore how you can export an SBOM.

The team would repeat the above process for each commit they make in the code repository. 
In fact, they could automate this, by adding these steps into their pipeline scripts.

**Now we are ready for release v1.0.0!**

The dev team has been working hard over a long sprint to add "Docker support"! 
First let's look at these changes to the app
```bash
cd ./assets/app:v1.0.0
```
As we did before, let's create a new release called v1.0.0 for the 'app' in Anchore.
```bash
anchorectl application version add app@v1.0.0
```
Now let's build the SBOM for this release and associate a source artifact to our app v1.0.0 version. All in one line!
```bash
anchorectl syft --source-name app --source-version v1.0.0 -o json . | anchorectl source add github.com/anchore/webinar-demo@88ae9c020d4b730d510e97a31848e181c4934bf0 --branch 'v1.0.0' --author 'author-from-ci@example.com' --application 'app@v1.0.0' --workflow-name 'default' --from -
```
This time they added some richer metadata to the source code associations.

Check out the new application in the Web UI by visiting `/applications` and see the Dockerfile getting picked up.
Finally drill in and export an SBOM.

This release contained a Dockerfile, so let's move on to build an image.

### SBOM Visibility of images

The v1.0.0 app like many in the cloud native world, is now ready to be turned into an image. When we do this we might also use bring in additional software and place it into an OS base image such as ubuntu minimal.
With extra software our SBOM will grow and as such we will want to get insight into this artifact. This section will cover how we can add such an image 

Build the v1.0.0 app image locally and tag it as v1.0.0
```bash
docker build . -t app:v1.0.0
```
Submit the new image to Anchore Enterprise (anchorectl will perform full local image analysis locally in Distributed mode)
```bash
anchorectl image add app:v1.0.0 --from docker 
```

Anchore can use scan/analyse a local image (Distributed mode) or tell Anchore Enterprise to pull the image from a registry in order to scan/analyse (Centralized mode)

Distributed image analysis can be useful if for example you have the image built locally already in your CI/CD environment. 
This can save time on analysis as in Centralized mode the Anchore Enterprise Server would need to download the image and then scan.
There is one limitation with Distributed mode, Malware scanning is not possible, as this can only take place on the server in Centralized mode.

Let's look at some examples

Distributed Mode

Using a local image and using the known local image tag.
```bash
anchorectl image add app:v1.0.0 --from docker 
```

Using a local image and using the known registry image tag.
```bash
anchorectl image add app:v1.0.0 --from registry 
```

Using a local image tar.
```bash
docker save app:v1.0.0  -o app-v1.0.0.tar
anchorectl image add app:v1.0.0 --from docker-archive:./app-v1.0.0.tar
```

Centralized Mode

Using the registry and repo reference to pull and scan/analyse the image.
```bash
anchorectl image add docker.io/danperry/app:v2.0.0
```

Give your image a custom registry and repo name.
```bash
anchorectl image add image.fakehost.com:newapp:v1.0.0 --from docker:app:v1.0.0
anchorectl image add tar.fakehost.com:newapp:v1.0.0 --from docker-archive:./app-v1.0.0.tar
```

Let's resubmit our local app image, but this time add the Dockerfile as extra data.
```bash
anchorectl image add app:v1.0.0 --from docker --dockerfile ./Dockerfile
```
When reviewing the UI for this image you may notice "No results" for the Dockerfile tab under images in the Web UI.

Anchore is clever when you scan the same image as it notices no differences and therefore will not perform certain scan steps as a result. 
However, in this case we want to tell Anchore to re analyse the image so that we can pick up and use the newly supplied Dockerfile data.
We can do this by using --force
> [!NOTE]
> --force can be handy in many other use-cases too, lets say you have just enabled malware and now want to rescan and see the results
```bash
anchorectl image add app:v1.0.0 --from docker --dockerfile ./Dockerfile --force
```
Make note of the digest in the output, we will use this in the next step. 

Finally, let's associate this container image to v1.0.0 of the app in Anchore.
```bash
anchorectl application artifact add app@v1.0.0 image <retrieved-image-sha>
```

Now go and review both the `applications` and `images` sections in the web UI and inspect the app v1 image we added.

Why supply the Dockerfile?
Simply - It will provide extra data about the image. Anchore does inspect and infer some of the image history using the layers, however this is limited and no substitute for a full Dockerfile.
Firstly, this allows you to inspect and see the full Dockerfiles contents in the Anchore Enterprise Web UI. Secondly, you can define additional policy rules using Dockerfile policy gates based on your image's Dockerfile. 
For example, raise a policy violation if my image is exposing port 22 with EXPOSE 22 or the container is running the application with USER root. More details in the policy section.

### SBOM Visibility of multi-architecture images

Another lens to cover with SBOMs for container images, is that Anchore can support multi-architecture images. 
Perhaps you ship a product or container that needs to work across many types of architectures. 
In any case, you will need to manage the SBOMs and associated security data and here Anchore can support your efforts. Let's run through an example

Submit image for addition to Anchore Enterprise (Anchore Enterprise will pull image from a public registry and perform full analysis)
This is called centralized analysis. 
Please note this image is hosted publicly so NO credentials are required. However, Anchore does support private repositories that conform to the docker_v2 api.
```bash
anchorectl image add docker.io/centos:latest
```
Review this new CentOS image in the `images` tab in the Web UI, once loaded select the SBOM Tab. 
You will notice it contains several images, this is because the CentOS image is a multi architecture image.
Let's now re-add the CentOS image, but this time be specific and add only the ARM64 platform image.
```bash
anchorectl image add docker.io/centos:latest --from registry --platform  arm64 --force
```
> [!NOTE]
> Remember `--force` tells Anchore Enterprise to re analyse or scan the image. And not just reload the latest vulnerabilities.

Check the Web UI once again to see the arm64 architecture in the Image SHA and also check out the Changelog tab.
You can see the new Architecture but also how this changed over time. This is what we call SBOM drift. 
Drift can help us detect deeper security issues, we will cover this more in a later lab on policy enforcement. 
This can uncover changes in everything from Architecture changes like this example to more nuanced package changes.

### SBOM Visibility using watchers & subscriptions

Anchore has the capability to monitor/watch external:
 - Docker Registries for updates to tags as well as new images pushed into a repository. 
 - Runtime environments such as Kubernetes and ECS for containers deployed into those environments.
As new updates or images are found, they are automatically submitted for SBOM analysis and can later progress to onward stages.
Then you can, if required, set up a subscription which will generate a notification when the event is triggered, such as a new tag, or policy/vulnerability update. 
For example, when a new image has been added to the registry or when Anchore has spotted a new vulnerability, submit a notice to the configured JIRA endpoint.

Let's run through an example:

Check if we are watching the repo we have scanned (in this case we are not)
```bash
anchorectl repo add --dry-run docker.io/danperry/nocode
```
Output
```
 ✔ Added repo
┌───────────────────────────┬─────────────┬────────┐
│ KEY                       │ TYPE        │ ACTIVE │
├───────────────────────────┼─────────────┼────────┤
│ docker.io/danperry/nocode │ repo_update │ false  │
└───────────────────────────┴─────────────┴────────┘
```
We can subscribe to every new tag, or in this case any change being submitted to the repository
```bash
anchorectl repo add --auto-subscribe docker.io/danperry/nocode
```
Output
```
✔ Added repo
┌───────────────────────────┬─────────────┬────────┐
│ KEY                       │ TYPE        │ ACTIVE │
├───────────────────────────┼─────────────┼────────┤
│ docker.io/danperry/nocode │ repo_update │ true   │
└───────────────────────────┴─────────────┴────────┘
```
We can not only watch for new tags as they are pushed into the registry.
But we can also add a subscription that will trigger an event and downstream notification.
```bash
anchorectl subscription list
```
Output
```
✔ Fetched subscriptions
┌─────────────────────────────────┬─────────────────┬────────┐
│ KEY                             │ TYPE            │ ACTIVE │
├─────────────────────────────────┼─────────────────┼────────┤
│ docker.io/danperry/nocode       │ repo_update     │ true   │
│ docker.io/danperry/nocode:1.0.0 │ alerts          │ true   │
└─────────────────────────────────┴─────────────────┴────────┘
```
Let's activate the tag_update subscription
```bash
anchorectl subscription activate docker.io/danperry/nocode:1.0.0 tag_update
```
Output
```
✔ Activate subscription
Key: docker.io/danperry/nocode:1.0.0
Type: tag_update
Id: e737986c26126b062de917d36b6eb33c
Active: true
```
Finally, we can list all of our subscriptions to see the state of play.
```bash
anchorectl subscription list
```
Output
```
✔ Fetched subscriptions
┌─────────────────────────────────┬─────────────────┬────────┐
│ KEY                             │ TYPE            │ ACTIVE │
├─────────────────────────────────┼─────────────────┼────────┤
│ docker.io/danperry/nocode:1.0.0 │ policy_eval     │ false  │
│ docker.io/danperry/nocode:1.0.0 │ vuln_update     │ false  │
│ docker.io/danperry/nocode:1.0.0 │ analysis_update │ true   │
│ docker.io/danperry/nocode       │ repo_update     │ true   │
│ docker.io/danperry/nocode:1.0.0 │ alerts          │ true   │
│ docker.io/danperry/nocode:1.0.0 │ tag_update      │ true   │
└─────────────────────────────────┴─────────────────┴────────┘
```
Try for yourself with the centos repo in the docker.io registry.

Set up a subscription to new tag updates for the centos repo from the container registry. 
Then submit a bunch of images and checkout the "Event's & Notifications Web" UI.

```bash
anchorectl image add docker.io/centos:8 --force --wait
anchorectl image add docker.io/centos:7
```
Check out the events generated in the Web UI by visiting `/events`

> [!TIP]
> If you want to send an event notification from a subscription to an endpoint, please review our [UI Walkthrough](https://docs.anchore.com/current/docs/configuration/notifications/#notifications-ui-walktrough) docs.

Watches and Subscriptions offer many possibilities and combined with notifications, you can start to build very powerful workflows.

### SBOM Visibility using content hints

Now that v2.0.0 of the app has passed ALL the tests we are ready to build the container as part of the CD process and deliver the artifact to our production environment.
However, we know that some bespoke packages are not getting discovered, and we want to manually flag or 'hint' that these exist. 
We can achieve this by adding a hints json file that contains the metadata Anchore can detect and process.

Let's first "check and submit" the source code as v2.0.0. Then we move onto building an image, and look at the hints process.
```bash
cd ./assets/app:v2.0.0
anchorectl source add github.com/anchore/webinar-demo@106c2d9fffe01f564d889763d904cace7f32be3f --branch 'v2.0.0' --author 'author-from-ci@example.com' --application 'app@v2.0.0' --workflow-name 'default' --from -
```

Review the hints file, then build the image locally and tag it as v2.0.0.
```
cat anchore_hints.json
docker build . -t app:v2.0.0
```
Add version v2.0.0 for our application
```bash
anchorectl application version add app@v2.0.0
```
Submit our new v2.0.0 image for addition to Anchore Enterprise 
With `--from docker/registry` AnchoreCTL will perform a 'distributed/local' SBOM-generation and analysis (secret scans, filesystem metadata, and content searches) and upload the results to Anchore Enterprise without ever having that image touched or loaded by your Enterprise deployment.
```bash
anchorectl image add app:v2.0.0 --from docker --dockerfile ./Dockerfile
```
Make note of the digest in the output, we will use this in the next step.

Let's associate this container image to our v2.0.0 of the application in Anchore.
```bash
anchorectl application artifact add app@v2.0.0 image <retrieved-image-sha>
```

Now go and review both the `applications` and `images` sections in the web UI and inspect the app v2 image we added.

Anchore Enterprise includes the ability to read a user-supplied ‘hints’ file to allow users to add software artifacts to Anchore’s analysis report. The hints file, if present, contains records that describe a software package’s characteristics explicitly, and are then added to the software bill of materials (SBOM).
You may have noticed but v2.0.0 has a hints file called anchore_hints.json. Check it out and also look in the UI/SBOM for these artifacts.

### SBOM Visibility across an application

So far, we have explored how we can add source and container images and map those to an application and a tag or release.
As the tech stack / application develops over time we might add new pieces of software like nginx or redis. 
Additionally, we will very likely add newer versions of our own code application such as commits or continuous integrations of code and eventually release candidates of built container images from a CD pipeline.
To see how this changes over time, with Anchore you can 'index or catalog' each build or release of the software and containers. Let's run through a quick example:

For our app:v2.0.0 application we have a dependency on two other containers nginx and postgres. Let's add these supporting containers to our application construct
```bash
anchorectl image add docker.io/library/postgres:13
anchorectl application artifact add app@v2.0.0 image sha256:8a8289d4999b47a5a9a585c775d33deadc43fa0a2a6b647c58cdaf1e59703977
anchorectl image add docker.io/nginx:alpine3.18
anchorectl application artifact add app@v2.0.0 image sha256:cb3218c8a053881bd00f4fa93e9f87e2c6204761e391b3aafc942f104362e538
```
Now checkout the Web UI and under Application view the container sources for v2.0.0 of the app.

You can also view some of the data via the AnchoreCTL
```bash
anchorectl application artifact list app@v2.0.0
```
Output
```
✔ List artifacts
┌─────────────────────────────────┬────────┬─────────────────────────────────────────────────────────────────────────┐
│ DESCRIPTION                     │ TYPE   │ HASH                                                                    │
├─────────────────────────────────┼────────┼─────────────────────────────────────────────────────────────────────────┤
│ rhel:9.3                        │ image  │ sha256:30c82fbf2de5a357a91f38bf68b80c2cd5a4b9ded849dbdf4b4e82e807511ffa │
│ debian:12                       │ image  │ sha256:8a8289d4999b47a5a9a585c775d33deadc43fa0a2a6b647c58cdaf1e59703977 │
│ alpine:3.18.6                   │ image  │ sha256:cb3218c8a053881bd00f4fa93e9f87e2c6204761e391b3aafc942f104362e538 │
│ github.com/anchore/webinar-demo │ source │ 106c2d9fffe01f564d889763d904cace7f32be3f                                │
└─────────────────────────────────┴────────┴─────────────────────────────────────────────────────────────────────────┘
```
Finally, you can request an SBOM for the entire application suite for version 2.0.0 with the following command.
```bash
anchorectl application sbom app@v2.0.0 > all_the_sboms_appv2.0.0.json
```
This is helpful, when for example, a customer asks for a tech stack wide SBOM. You don't need to make individual requests for SBOMs and instead you can perform one bulk query. 
Equally, if you need a single SBOM for just one container you can request this too and with application management you can ensure you request the correct one.

## Next Lab

We have seen how both Source and Image SBOMs can be generated and imported into Anchore. 
We also showed how these can be mapped to a construct we call application which helps you maintain provenance and history about your releases and the source and containers associated with them.
In future labs, we will unpack more ways in which you gain visibility into your container to help you achieve important tasks like remediation.

Next: [Inspection](inspection)