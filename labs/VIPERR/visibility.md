# Visibility

Anchore Enterprise generates detailed SBOMs at each step in the SDLC process, providing a complete inventory of the software components on everything from OS packages, files and any direct and transitive dependencies used in your language specific applications.
These SBOMs are stored and managed by Anchore Enterprise to facilitate ongoing visibility across many use cases from vulnerability management to compliance.

## Lab Exercise

An application starts life as code, and eventually (in the cloud native world) transforms into a distributable image that can be deployed as production container. 
The end-to-end process is commonly referred to as the SDLC (Software Delivery Lifecycle), and across the different stages Anchore Enterprise can track and manage the associated SBOM.
In this lab, you will utilize examples that take you through the lifecycle from source code to container images to create SBOMs, get visibility into their "ingredients" and use tooling that showcase useful capabilities e.g. multi-arch images.

### Working with source code

Let's change into the directory containing our amazing new Go application code that our dev team have just produced.
```bash
cd ./assets/app
```
Now we need to create a new Anchore Enterprise application "instance", with which we can later map our source code and images.
```bash
anchorectl application add app --description "Webinar Demo App"
```
> [!NOTE]
> You can only currently - add, edit and delete applications via the anchorectl or Anchore Enterprise API

Review the first example application source code and generate an SBOM (locally) for it. 
Then we can map the source code reference and SBOM into Anchore. 
This would be a typical task that gets carried out during CI.
```bash
anchorectl syft --source-name app --source-version HEAD -o json . | anchorectl source add github.com/anchore/webinar-demo@73522db08db1758c251ad714696d3120ac9b55f4 --from -
```
Make note of the UUID in the output we will use this later.
> [!TIP]
> If you already have Syft installed you can use it $ syft -o json . | anchorectl source add ...

Now we associate the source artifact to our application tag HEAD. As you continuously integrate you also can update Anchore Enterprise with the latest code. 
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
First let's look at these changes to the app.
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

### Working with images

The v1.0.0 app like many in the cloud native world, is now ready to be turned into an image. When we do this we might also use bring in additional software and place it into an OS base image such as ubuntu minimal.
With extra software our SBOM will grow and as such we will want to get insight into this artifact. This section will cover how we can add such an image.

Build the v1.0.0 app image and tag it as v1.0.0.
```bash
docker build . -t app:v1.0.0
```

Let's submit our new image to Anchore Enterprise using Distributed mode and instruct anchorectl to use the image from the Docker Daemon on our environment.
```bash
anchorectl image add app:v1.0.0 --from docker 
```

> [!NOTE] 
> Anchore Enterprise can analyze an image in two modes: Distributed And Centralized. 
> Distributed Mode will instruct AnchoreCTL to locally analyze and image and send the SBOM to Anchore Enterprise.
> Centralized Mode will instruct Anchore Enterprise to pull the image from a registry to analyze (Centralized mode)
> Both have their own advantages. One thing to note, with Distributed mode, you do not get Malware scanning as this can only take place on the server in Centralized mode.

Let's look at Distributed and Centralized mode in more detail before continuing:

**Distributed Mode**

Instruct AnchoreCTL to pull an image from the Docker Dameon and locally analyze. _(using this approach is NOT recommended for anything other than testing)_
```bash
anchorectl image add app:v1.0.0 --from docker 
```

Instruct AnchoreCTL to pull an image from a remote Registry and locally analyze. _(might require local registry credential setup)_
```bash
anchorectl image add docker.io/danperry/app:v2.0.0 --from registry 
```

Instruct AnchoreCTL to pull an image from a docker archived tar and locally analyze.
```bash
docker save app:v1.0.0 -o app-v1.0.0.tar
anchorectl image add app:v1.0.0 --from docker-archive:./app-v1.0.0.tar
```

**Centralized Mode**

Instruct AnchoreCTL to centrally analyze the image tag on the Anchore Enterprise Server. _(might require remote registry credential setup)_
```bash
anchorectl image add docker.io/danperry/app:v2.0.0
```

Now we will continue to explore some more options and build and ingest our app:v1.0.0 SBOM.

Instruct AnchoreCTL to set a custom registry, repo and tag name.
```bash
anchorectl image add image.fakehost.com:newapp:v1.0.0 --from docker:app:v1.0.0
anchorectl image add tar.fakehost.com:newapp:v1.0.0 --from docker-archive:./app-v1.0.0.tar
```

### Working with Dockerfile's

Anchore Enterprise can inspect an image and determine/rebuild/guess the Dockerfile. For some use cases this can be enough to determine critical details about how the image was built.
In other use cases and some scenarios (different image builders other than Docker Dameon store history data differently).
For these cases you might want to supply a Dockerfile when adding the image to Anchore Enterprise.
Let's cover how both of these options can get you the visibility needed.

Let's use AnchoreCTL to get the Dockerfile for a third-party image. This is an image we don't have or have not supplied a Dockerfile for.
```bash
anchorectl image get centos:latest -o json | jq -r '.imageDetail[0].dockerfile' | base64 --decode
FROM scratch
ADD file:420712a90b0934202b326dc06b73638ab8e4603d12be2c23d67d834eb6cfc052 in /
LABEL org.label-schema.schema-version=1.0 org.label-schema.name=CentOS Base Image org.label-schema.vendor=CentOS org.label-schema.license=GPLv2 org.label-schema.build-date=20210915
CMD ["/bin/bash"]
```

Using AnchoreCTL we can see that the dockerfileMode shows "guessed". Which checks out.
```bash
anchorectl -o json image get centos:latest | jq '.imageContent'
{
  "metadata": {
    "arch": "arm64",
    "distro": "centos",
    "distroVersion": "8",
    "dockerfileMode": "Guessed",
    "imageSize": 83941353,
    "layerCount": 1
  }
}
```

Instruct AnchoreCTL to analyze our local app image, and supplement with the common Dockerfile build artifact.
```bash
anchorectl image add app:v1.0.0 --from docker --dockerfile ./Dockerfile
```
As we have already analysis/submitted/scanned this image, Anchore Enterprise is clever and uses the image digest it notices no differences and will not perform certain scan steps as a result. 
However, in this case we want to tell Anchore Enterprise to re analyze the image so that we can pick up and use the newly supplied Dockerfile data.
We can do this by using a command argument '--force'

Instruct AnchoreCTL to **re-analyze** our local app image, and supplement it with a new Dockerfile build artifact.
```bash
anchorectl image add app:v1.0.0 --from docker --dockerfile ./Dockerfile --force
```

Now we should see the dockerfileMode show "Actual"
```bash
anchorectl -o json image get app:v1.0.0 | jq '.imageContent'
{
  "metadata": {
    "arch": "arm64",
    "distro": "alpine",
    "distroVersion": "3.10.4",
    "dockerfileMode": "Actual",
    "imageSize": 14856704,
    "layerCount": 2
  }
}
```

Finally, using AnchoreCTL, lets checkout our app:v1.0.0 and see if we can grab the Dockerfile data.
```bash
anchorectl image get app:v1.0.0 -o json | jq -r '.imageDetail[0].dockerfile' | base64 --decode
# first stage does the building
# for UX purposes, I'm naming this stage `build-stage`

FROM golang:1.20-alpine AS build-stage
WORKDIR /go/src/go-app
COPY app.go .
COPY go.mod go.sum ./
RUN go mod tidy
RUN go mod download
RUN go build -o app .

# starting second stage
FROM alpine:3.10.4

# copy the binary from the `build-stage`
COPY --from=build-stage /go/src/go-app/app /bin

CMD app
```

Now let's associate this container image to v1.0.0 of the app for our Application
```bash
anchorectl application artifact add app@v1.0.0 image $(anchorectl image get app:v1.0.0 -o json | jq -r '.imageDetail[0].imageDigest')
```

BTW, you can also use image get -o id to get the unique sha digest
```bash
anchorectl image get app:v1.0.0 -o id
```

Use AnchoreCTL to inspect your new application artifact list
```bash
anchorectl application artifact list app@v1.0.0
```

> [!NOTE]
> Why supply the Dockerfile?
> Simply - It will provide extra data about the image. Anchore Enterprise does inspect and infer some of the image history using the layers, however this is limited and no substitute for a full Dockerfile.
> Once submitted, you can and your wider team can see the full Dockerfile contents in the Anchore Enterprise Web UI. Secondly, you can build policy rules based on the Dockerfile contents. 
> For example, raise a policy violation if my image is exposing port 22 with EXPOSE 22 or the container is running the application with USER root. More details in the policy section.

### Working with multi-architecture images

Anchore Enterprise can support multi-architecture images and as such we will need to generate separate SBOMs for each architecture.
This might be useful, if you ship a product or image that needs to work across many types of architectures. 
Let's run through an example

Let's first analyze a public multi-architecture image.
```bash
anchorectl image add docker.io/centos:latest
```
_Please note this image is hosted publicly so NO credentials are required. However, Anchore Enterprise does support private repositories that conform to the docker_v2 api._

Now review this CentOS image in the `images` tab in the Web UI, once loaded select the 'Image MetaData' Tab. 
You will notice it contains several images, this is because the CentOS image is a multi architecture image.
Let's now re-add the CentOS image, but this time be specific and add only the ARM64 platform image.
```bash
anchorectl image add docker.io/centos:latest --from registry --platform  arm64 --force
```

Check the Web UI once again to see the arm64 architecture in the Image SHA and also check out the 'Changelog' UI tab.
You can see the new Architecture, but also which of the contents/software changed. This leads to another topic called SBOM drift. 
SBOM Drift can help detect deeper security issues, we will cover this more in a later lab on policy enforcement. 

### Using your own Annotations

Sometimes you might want to add your own metadata about a particular image, for example which team 'owns' or has responsibility. 
Anchore Enterprise allows you to add your own annotation(s) to images, which can later be queried and visible.

First let's set a test annotation
```bash
anchorectl image add  ubuntu:latest --annotation test=123
```

Second let's retrieve our annotation(s)
```bash
anchorectl image get -o=json ubuntu:latest | jq '.annotations'
{
  "test": "123"
}
```

### Using watch, subscription & notifications

Anchore Enterprise can be configured to watch registries for new images. When discovered they will automatically be submitted for analysis.
Additionally, you can also enable several types of subscriptions that can trigger a notification (email, slack, webhook) when an event like a new image from a watch occurs.
Let's run through this with some examples below.

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

Using AnchoreCTL check out the generated events. 
```bash
anchorectl event list
```

Now that we have events being triggered from an enabled subscriptions. We can capture these events and send them as notifications.
Please review the [Notifications UI Walkthrough](https://docs.anchore.com/current/docs/configuration/notifications/#notifications-ui-walktrough) docs to learn more.
Watches, Subscriptions and downstream notifications offer many possibilities to build very powerful workflows.

### Retrieve your SBOM and content details

We have all this data about our software now. Let's go into one or two examples on how to visualise some data.

Let's retrieve ALL types of metadata we can list
```bash
anchorectl image content app:v1.0.0 -a
✔ Fetched content                           [fetching available types]                                                                                                                                                                               app:v2.0.0
binary
conan
content_search
dart-pub
erlang-otp
files
gem
github-action
github-action-workflow
go
hackage
hex
java
linux-kernel
linux-kernel-module
lua-rocks
malware
npm
nuget
opam
os
php-composer
php-pecl
pod
python
r-package
retrieved_files
rust-crate
secret_search
swift
swiplpack
terraform
wordpress-plugin
```

Let's retrieve ALL the gem packages and associated metadata
```bash
anchorectl image content app:v1.0.0 -t go
```

Use AnchoreCTL to export an entire SBOM in SPDX format
```bash
anchorectl image sbom app:v1.0.0 -o spdx-json
```

There is so much data to explore and see here. In the next inspection lab, we cover a few more examples specific to software itself.

### Wrap up & one last thing...

So far, we have explored how we can add source and container images and map those to an application and a tag or release. 
We also explored the many ways to add and query the data around both source and images.
Now that v2.0.0 has passed ALL the tests, and we are ready to build the image as part of the CD process and deliver the image artifact to our production environment.

Before we wrap up... we noticed one last thing we need to do.

We see that some bespoke packages are not getting discovered by Anchore Enterprise, and we want to add or 'hint' that these exist. 
Additionally, we have some other associated images that our new application relies on.
Let's talk through how we can cover both of these asks:

First we can submit the source code for v2.0.0. Then we move onto building an image, and look at the hints process.
```bash
cd ./assets/app:v2.0.0
anchorectl source add github.com/anchore/webinar-demo@106c2d9fffe01f564d889763d904cace7f32be3f --branch 'v2.0.0' --author 'author-from-ci@example.com' --application 'app@v2.0.0' --workflow-name 'default' --from -
```

Anchore Enterprise can use extra data from a hints file. Let's now build our image locally (with the hints file) and tag it as v2.0.0.
```bash
cat anchore_hints.json
docker build . -t app:v2.0.0
```
You should now see the "added/hinted" packages. (btw this software doesn't exist!)
```bash
anchorectl image content app:v2.0.0 -t gem
✔ Fetched content                           [1 packages] [0 files]                                                                                                                                                                                   app:v2.0.0
Packages:
┌─────────┬─────────┬──────┬──────┬──────────┬───────────────────────────────────────────────┐
│ PACKAGE │ VERSION │ TYPE │ SIZE │ ORIGIN   │ LOCATION                                      │
├─────────┼─────────┼──────┼──────┼──────────┼───────────────────────────────────────────────┤
│ wicked  │ 0.6.1   │ GEM  │      │ schneems │ /app/gems/specifications/wicked-0.9.0.gemspec │
└─────────┴─────────┴──────┴──────┴──────────┴───────────────────────────────────────────────┘
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

Let's associate this container image to our v2.0.0 of the application in Anchore.
```bash
anchorectl application artifact add app@v2.0.0 image $(anchorectl image get app:v2.0.0 -o json | jq -r '.imageDetail[0].imageDigest')
```

As the tech stack / application evolves we might add new pieces of dependant images like nginx or redis. 
Additionally, we will very likely add newer versions of our own code application such as commits or continuous integrations of code and eventually release candidates of built container images from a CD pipeline.
To see how this changes over time, with Anchore Enterprise you can 'index or catalog' each build or release of the software and containers. Let's run through a quick example:

For our app:v2.0.0 application we have a dependency on two other containers nginx and postgres. Let's add these supporting containers to our application construct
```bash
anchorectl image add docker.io/library/postgres:13
anchorectl application artifact add app@v2.0.0 image $(anchorectl image get docker.io/library/postgres:13 -o id)
anchorectl image add docker.io/nginx:alpine3.18
anchorectl application artifact add app@v2.0.0 image $(anchorectl image get docker.io/nginx:alpine3.18 -o id)
```

Now checkout the artifacts list for the application for v2.0.0 of the app.
```bash
anchorectl application artifact list app@v2.0.0
```

Finally, you can request an SBOM for the entire application suite for version 2.0.0 with the following command.
```bash
anchorectl application sbom app@v2.0.0 > all_the_sboms_appv2.0.0.json
```
This is helpful, when for example, a customer asks for a tech stack wide SBOM. You don't need to make individual requests for SBOMs, and instead you can perform one bulk query. 
Equally, if you need a single SBOM for just one container you can request this too and with application management you can ensure you request the correct one.

## Next Lab

We have seen how both Source and Image SBOMs can be generated and managed by Anchore Enterprise. 
We also showed how these can be mapped to a construct we call application which helps you maintain provenance and history about your releases and the source and containers associated with them.
In future labs, we will unpack ways that you can utilize this foundational data to achieve important tasks like compliance, remediation and much more.

Next: [Inspection](inspection.md)