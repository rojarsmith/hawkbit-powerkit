#!/bin/bash
set -ex # Debug

IMAGE=nginx-ssl
# Official image: https://hub.docker.com/_/nginx?tab=tags
NGINX_VERSIONS=(
    1.27.5
)

function build() {
    NGINX_VERSION=$1

    if [[ $1 =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        REVISION=${BASH_REMATCH[3]}
    else
        exit 1
    fi

    TAG_LATEST="${MAJOR}.${MINOR}"
    TAG_REVISION="${MAJOR}.${MINOR}.${REVISION}"

    docker build \
        --build-arg NGINX_VERSION="$NGINX_VERSION" \
        --tag $IMAGE:"latest" \
        --tag $IMAGE:"$TAG_LATEST" \
        --tag $IMAGE:"$TAG_REVISION" \
        .
}

for NGINX_VERSION in "${NGINX_VERSIONS[@]}"; do
    build "$NGINX_VERSION"
done
