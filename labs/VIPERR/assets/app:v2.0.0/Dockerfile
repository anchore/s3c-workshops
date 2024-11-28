FROM xmrig/xmrig:latest AS xmrig

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
FROM docker.io/redhat/ubi9-minimal:latest

# copy the binary from the `build-stage`
COPY --from=build-stage /go/src/go-app/app /bin

CMD app

# Now for some more bad stuff

HEALTHCHECK --timeout=10s CMD /bin/true || exit 1

### if you need to use the actual rpm rather than the hints file, use this COPY and comment out the other one
### COPY Dockerfile sudo-1.8.29-5.el8.x86_64.rpm ./
COPY anchore_hints.json log4j-core-2.15.0.jar /
COPY --from=xmrig /xmrig/xmrig /xmrig/xmrig

RUN set -ex && \
    echo "aws_access_key_id=01234567890123456789" > /aws_access && \
    echo "-----BEGIN OPENSSH PRIVATE KEY-----" > /ssh_key && \
    microdnf -y install yum-utils python3-devel python3 python3-pip nodejs shadow-utils tar gzip && \
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    microdnf -y install terraform && \
    curl -sSfL  https://anchorectl-releases.anchore.io/anchorectl/install.sh  | sh -s -- -b $HOME/.local/bin && \
    adduser -d /xmrig mining && \
    pip3 install --index-url https://pypi.org/simple --no-cache-dir aiohttp pytest urllib3 botocore six numpy protobuf==3.20 && \
    npm install -g --cache /tmp/empty-cache debug chalk commander xmldom && \
    npm cache clean --force && \
    microdnf -y clean all && \
    echo "trigger package verification for gzip" >> /usr/share/doc/gzip/TODO && \
    rm -rf /var/cache/yum /tmp 

## just to make sure we have a unique build each time
RUN date > /image_build_timestamp && \
    touch image_build_timestamp_$(date +%Y-%m-%d_%T)

USER mining
WORKDIR /xmrig
ENTRYPOINT /bin/false