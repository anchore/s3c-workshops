# Visibility

Building an accurate Software Bill of Materials (SBOM) is a foundational activity. An SBOM can be built using a number of source locations (source code, container etc) at different stages in your SDLC.
This foundational SBOM data is needed in all downstream activities on everything from vulnerability management to other activities like compliance.
In this lab, you will be building SBOMs using the example applications packaged in both source and container image formats. With these SBOMs you can then get visibility into the application contents on everything from OS to language specific sofware components. You will learn the key processes of ingesting and building accurate SBOMs across a typical application lifecycle.

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

Build the v1.0.0 app image and tag it as v1.0.0
```bash
docker build . -t app:v1.0.0
```

Let's submit our new image to Anchore Enterprise using Distributed mode and instrict anchorectl to use the image from the Docker Daemon on our environment.
```bash
anchorectl image add app:v1.0.0 --from docker 
```

> [!NOTE] 
> Anchore can analyze an image in two modes: Distributed And Centralized. 
> Distributed Mode will instruct AnchoreCTL to locally analyze and image and send the SBOM to Anchore Enterprise.
> Centralized Mode will instruct Anchore Enterprise to pull the image from a registry to analyze (Centralized mode)
> Both have their own advantages. One thing to note, with Distributed mode, you do not get Malware scanning as this can only take place on the server in Centralized mode.

Let's look at Distributed and Centralized mode in more detail before continuing:

**Distributed Mode**

Instruct AnchoreCTL to pull an image from the Docker Dameon and locally analyze.
```bash
anchorectl image add app:v1.0.0 --from docker 
```

Instruct AnchoreCTL to pull an image from a remote Registry and locally analyze. _(requires local registry auth access)_
```bash
anchorectl image add docker.io/danperry/app:v2.0.0 --from registry 
```

Instruct AnchoreCTL to pull an image from a docker archived tar and locally analyze.
```bash
docker save app:v1.0.0 -o app-v1.0.0.tar
anchorectl image add app:v1.0.0 --from docker-archive:./app-v1.0.0.tar
```

**Centralized Mode**

Instruct AnchoreCTL to centrally analyze the image tag on the Anchore Enterprise Server.
```bash
anchorectl image add docker.io/danperry/app:v2.0.0
```

Now we will continue to explore some more options and build and ingest our app:v1.0.0 SBOM.

Instruct AnchoreCTL to set a custom registry, repo and tag name.
```bash
anchorectl image add image.fakehost.com:newapp:v1.0.0 --from docker:app:v1.0.0
anchorectl image add tar.fakehost.com:newapp:v1.0.0 --from docker-archive:./app-v1.0.0.tar
```

Instruct AnchoreCTL to analyze our local app image, and supplement with the common Dockerfile build artifact.
```bash
anchorectl image add app:v1.0.0 --from docker --dockerfile ./Dockerfile
```
Checking the UI for this image you may notice "No results" for the Dockerfile tab under images in the Web UI.
Anchore is clever when you scan the same image as it notices no differences and therefore will not perform certain scan steps as a result. 
However, in this case we want to tell Anchore to re analyze the image so that we can pick up and use the newly supplied Dockerfile data.
We can do this by using a command argument '--force'

Instruct AnchoreCTL to **re-analyze** our local app image, and supplement it with a new Dockerfile build artifact.
```bash
anchorectl image add app:v1.0.0 --from docker --dockerfile ./Dockerfile --force
```

Finally, using the digest output from the last step, let's associate this container image to v1.0.0 of the app in Anchore.
```bash
anchorectl application artifact add app@v1.0.0 image <retrieved-image-sha>
```

Now go and review both the `applications` and `images` sections in the web UI and inspect the app v1 image we added.

> [!NOTE]
> Why supply the Dockerfile?
> Simply - It will provide extra data about the image. Anchore does inspect and infer some of the image history using the layers, however this is limited and no substitute for a full Dockerfile.
> Once submitted, you can and your wider team can see the full Dockerfile contents in the Anchore Enterprise Web UI. Secondly, you can build policy rules based on the Dockerfile contents. 
> For example, raise a policy violation if my image is exposing port 22 with EXPOSE 22 or the container is running the application with USER root. More details in the policy section.

### SBOM Visibility of multi-architecture images

Anchore Enterprise can support multi-architecture images and as such we will need to generate separate SBOMs for each architecture.
This might be useful, if you ship a product or image that needs to work across many types of architectures. 
Let's run through an example

Let's first analyze a public multi-architecture image.
```bash
anchorectl image add docker.io/centos:latest
```
_Please note this image is hosted publicly so NO credentials are required. However, Anchore does support private repositories that conform to the docker_v2 api._

Now review this CentOS image in the `images` tab in the Web UI, once loaded select the 'Image MetaData' Tab. 
You will notice it contains several images, this is because the CentOS image is a multi architecture image.
Let's now re-add the CentOS image, but this time be specific and add only the ARM64 platform image.
```bash
anchorectl image add docker.io/centos:latest --from registry --platform  arm64 --force
```

Check the Web UI once again to see the arm64 architecture in the Image SHA and also check out the 'Changelog' UI tab.
You can see the new Architecture, but also which of the contents/software changed. This leads to another topic called SBOM drift. 
SBOM Drift can help detect deeper security issues, we will cover this more in a later lab on policy enforcement. 

### SBOM Visibility using watchers & subscriptions

Anchore has the capability to watch registries for updates to repositories/tags such as new tags and images. 
As new images are found, they can be configured to be automatically submitted for SBOM analysis and can later progress to onward stages.
Then you can, if configured, also set up a subscription which will generate an event notification. This can be sent to an external endpoint for downstream handling.

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
We can not only watch for new tags as they are pushed into the registry. But we can also add a subscription that will trigger an event and notification.
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
> Watches, Subscriptions and downstream notifications offer many possibilities to build very powerful workflows.
> Please review the [Notifications UI Walkthrough](https://docs.anchore.com/current/docs/configuration/notifications/#notifications-ui-walktrough) docs to learn more.

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

Next: [Inspection](inspection.md)
