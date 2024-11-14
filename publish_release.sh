#!/bin/bash

if [ -z "$TYPOSEARCH_VERSION" ]
then
  echo "\$TYPOSEARCH_VERSION is not provided. Quitting."
  exit 1
fi

set -ex
CURR_DIR=`dirname $0 | while read a; do cd $a && pwd && break; done`

aws s3 cp $CURR_DIR/build-Linux/typosearch-server-${TYPOSEARCH_VERSION}-linux-amd64.tar.gz s3://dl.typosearch.org/releases/typosearch-server-${TYPOSEARCH_VERSION}-linux-amd64.tar.gz --profile typosearch
aws s3 cp $CURR_DIR/typosearch-server-${TYPOSEARCH_VERSION}-amd64.deb s3://dl.typosearch.org/releases/ --profile typosearch
aws s3 cp $CURR_DIR/build-Darwin/typosearch-server-${TYPOSEARCH_VERSION}-darwin-amd64.tar.gz s3://dl.typosearch.org/releases/typosearch-server-${TYPOSEARCH_VERSION}-darwin-amd64.tar.gz --profile typosearch
