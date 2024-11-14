#!/bin/bash
# TYPOSEARCH_VERSION=nightly TYPOSEARCH_TARGET=typosearch-server|typosearch-test bash ci_build.sh

set -ex
PROJECT_DIR=`dirname $0 | while read a; do cd $a && pwd && break; done`
BUILD_DIR=bazel-bin

if [ -z "$TYPOSEARCH_VERSION" ]; then
  TYPOSEARCH_VERSION="nightly"
fi

ARCH_NAME="amd64"

if [[ "$@" == *"--graviton2"* ]] || [[ "$@" == *"--arm"* ]]; then
  ARCH_NAME="arm64"
fi

docker run --user $UID:$GID --volume="/etc/group:/etc/group:ro" --volume="/etc/passwd:/etc/passwd:ro" \
--volume="/etc/shadow:/etc/shadow:ro" -it --rm -v /bazeld:/bazeld -v $PROJECT_DIR:/src \
--workdir /src typosearch/bazel_dev:24032023 bazel --output_user_root=/bazeld/cache build --verbose_failures \
--jobs=6 --action_env=LD_LIBRARY_PATH="/usr/local/gcc-10.3.0/lib64" \
--define=TYPOSEARCH_VERSION=\"$TYPOSEARCH_VERSION\" //:$TYPOSEARCH_TARGET

if [[ "$@" == *"--build-deploy-image"* ]]; then
    echo "Creating deployment image for Typosearch $TYPOSEARCH_VERSION server ..."
    docker build --platform linux/${ARCH_NAME} --file $PROJECT_DIR/docker/deployment.Dockerfile \
          --tag typosearch/typosearch:$TYPOSEARCH_VERSION $PROJECT_DIR/$BUILD_DIR
fi

if [[ "$@" == *"--package-binary"* ]]; then
    OS_FAMILY=linux
    RELEASE_NAME=typosearch-server-$TYPOSEARCH_VERSION-$OS_FAMILY-$ARCH_NAME
    printf `md5sum $PROJECT_DIR/$BUILD_DIR/typosearch-server | cut -b-32` > $PROJECT_DIR/$BUILD_DIR/typosearch-server.md5.txt
    tar -cvzf $PROJECT_DIR/$BUILD_DIR/$RELEASE_NAME.tar.gz -C $PROJECT_DIR/$BUILD_DIR typosearch-server typosearch-server.md5.txt
    echo "Built binary successfully: $PROJECT_DIR/$BUILD_DIR/$RELEASE_NAME.tar.gz"
fi
