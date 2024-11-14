#!/bin/bash

set -ex
PROJECT_DIR=`dirname $0 | while read a; do cd $a && pwd && break; done`
SYSTEM_NAME=Linux
BUILD_DIR=build-$SYSTEM_NAME
TEST_BUILD_DIR=test-$BUILD_DIR

if [ -z "$TYPOSEARCH_VERSION" ]; then
  TYPOSEARCH_VERSION="nightly"
fi

if [[ "$@" == *"--clean"* ]]; then
  echo "Cleaning..."
  rm -rf $PROJECT_DIR/$BUILD_DIR
  mkdir $PROJECT_DIR/$BUILD_DIR
fi

if [[ "$@" == *"--clean-test"* ]]; then
  echo "Cleaning..."
  rm -rf $PROJECT_DIR/$TEST_BUILD_DIR
  mkdir $PROJECT_DIR/$TEST_BUILD_DIR
fi

if [[ "$@" == *"--depclean"* ]]; then
  echo "Cleaning dependencies..."
  rm -rf $PROJECT_DIR/external-$SYSTEM_NAME
  mkdir $PROJECT_DIR/external-$SYSTEM_NAME
fi


TYPOSEARCH_DEV_IMAGE="typosearch-development:03-JAN-2023-1"
ARCH_NAME="amd64"

if [[ "$@" == *"--graviton2"* ]] || [[ "$@" == *"--arm"* ]]; then
  TYPOSEARCH_DEV_IMAGE="typosearch-development-arm:27-JUN-2022-1"
  ARCH_NAME="arm64"
fi

echo "Building Typosearch $TYPOSEARCH_VERSION..."
docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE cmake -DTYPOSEARCH_VERSION=$TYPOSEARCH_VERSION \
 -DCMAKE_BUILD_TYPE=Release -H/typosearch -B/typosearch/$BUILD_DIR
docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE make typosearch-server -C/typosearch/$BUILD_DIR

if [[ "$@" == *"--test"* ]]; then
    echo "Running tests"
    docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE cp /typosearch/$BUILD_DIR/Makefile /typosearch/$TEST_BUILD_DIR
    docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE cp -R /typosearch/$BUILD_DIR/CMakeFiles /typosearch/$TEST_BUILD_DIR/
    docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE make typosearch-test -C/typosearch/$TEST_BUILD_DIR
    docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE chmod +x /typosearch/$TEST_BUILD_DIR/typosearch-test
    docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/$TYPOSEARCH_DEV_IMAGE /typosearch/$TEST_BUILD_DIR/typosearch-test
fi

if [[ "$@" == *"--build-deploy-image"* ]]; then
    echo "Creating deployment image for Typosearch $TYPOSEARCH_VERSION server ..."

    cp $PROJECT_DIR/docker/deployment.Dockerfile $PROJECT_DIR/$BUILD_DIR
    docker build --platform linux/${ARCH_NAME} --file $PROJECT_DIR/$BUILD_DIR/deployment.Dockerfile --tag typosearch/typosearch:$TYPOSEARCH_VERSION \
                        $PROJECT_DIR/$BUILD_DIR
fi

if [[ "$@" == *"--package-binary"* ]]; then
    OS_FAMILY=linux
    RELEASE_NAME=typosearch-server-$TYPOSEARCH_VERSION-$OS_FAMILY-$ARCH_NAME
    printf `md5sum $PROJECT_DIR/$BUILD_DIR/typosearch-server | cut -b-32` > $PROJECT_DIR/$BUILD_DIR/typosearch-server.md5.txt
    tar -cvzf $PROJECT_DIR/$BUILD_DIR/$RELEASE_NAME.tar.gz -C $PROJECT_DIR/$BUILD_DIR typosearch-server typosearch-server.md5.txt
    echo "Built binary successfully: $PROJECT_DIR/$BUILD_DIR/$RELEASE_NAME.tar.gz"
fi

#
#if [[ "$@" == *"--create-deb-upload"* ]]; then
#    docker run -it --platform linux/${ARCH_NAME} -v $PROJECT_DIR:/typosearch typosearch/typosearch-development:09-AUG-2021-1 cmake -DTYPOSEARCH_VERSION=$TYPOSEARCH_VERSION \
#    -DCMAKE_BUILD_TYPE=Debug -H/typosearch -B/typosearch/$BUILD_DIR
#fi

echo "Done... quitting."
