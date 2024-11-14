#!/bin/bash

# TSV is passed as an environment variable to the script

if [ -z "$TSV" ]
then
  echo '$TSV is not provided. Quitting.'
  exit 1
fi

if [ -z "$ARCH" ]
then
  echo '$ARCH is not provided. Quitting.'
  exit 1
fi

RPM_ARCH=$ARCH
if [ "$ARCH" == "amd64" ]; then
  RPM_ARCH="x86_64"
fi

set -ex
CURR_DIR=`dirname $0 | while read a; do cd $a && pwd && break; done`

rm -rf /tmp/typosearch-gpu-deb-build && mkdir /tmp/typosearch-gpu-deb-build
cp -r $CURR_DIR/typosearch-gpu-deps /tmp/typosearch-gpu-deb-build

rm -rf /tmp/typosearch-gpu-deps-$TSV && mkdir /tmp/typosearch-gpu-deps-$TSV
tar -xzf $CURR_DIR/../bazel-bin/typosearch-gpu-deps-$TSV-linux-${ARCH}.tar.gz -C /tmp/typosearch-gpu-deps-$TSV
mkdir -p /tmp/typosearch-gpu-deb-build/typosearch-gpu-deps/usr/lib/
cp /tmp/typosearch-gpu-deps-$TSV/*.so /tmp/typosearch-gpu-deb-build/typosearch-gpu-deps/usr/lib/

rm -rf /tmp/typosearch-gpu-deps-$TSV /tmp/typosearch-gpu-deps-$TSV.tar.gz

sed -i "s/\$VERSION/$TSV/g" `find /tmp/typosearch-gpu-deb-build -maxdepth 10 -type f`
sed -i "s/\$ARCH/$ARCH/g" `find /tmp/typosearch-gpu-deb-build -maxdepth 10 -type f`

dpkg-deb -Zgzip -z6 \
         -b /tmp/typosearch-gpu-deb-build/typosearch-gpu-deps "/tmp/typosearch-gpu-deb-build/typosearch-gpu-deps-${TSV}-${ARCH}.deb"

# Generate RPM

rm -rf /tmp/typosearch-gpu-rpm-build && mkdir /tmp/typosearch-gpu-rpm-build
cp "/tmp/typosearch-gpu-deb-build/typosearch-gpu-deps-${TSV}-${ARCH}.deb" /tmp/typosearch-gpu-rpm-build
cd /tmp/typosearch-gpu-rpm-build && alien --scripts -k -r -g -v /tmp/typosearch-gpu-rpm-build/typosearch-gpu-deps-${TSV}-${ARCH}.deb

sed -i 's#%dir "/"##' `find /tmp/typosearch-gpu-rpm-build/*/*.spec -maxdepth 10 -type f`
sed -i 's#%dir "/usr/bin/"##' `find /tmp/typosearch-gpu-rpm-build/*/*.spec -maxdepth 10 -type f`
sed -i 's/%config/%config(noreplace)/g' `find /tmp/typosearch-gpu-rpm-build/*/*.spec -maxdepth 10 -type f`

SPEC_FILE="/tmp/typosearch-gpu-rpm-build/typosearch-gpu-deps-${TSV}/typosearch-gpu-deps-${TSV}-1.spec"
cd /tmp/typosearch-gpu-rpm-build/typosearch-gpu-deps-${TSV} && \
  rpmbuild --target=${RPM_ARCH} --buildroot /tmp/typosearch-gpu-rpm-build/typosearch-gpu-deps-${TSV} -bb \
  $SPEC_FILE

cp "/tmp/typosearch-gpu-rpm-build/typosearch-gpu-deps-${TSV}-${ARCH}.deb" $CURR_DIR/../bazel-bin
cp "/tmp/typosearch-gpu-rpm-build/typosearch-gpu-deps-${TSV}-1.${RPM_ARCH}.rpm" $CURR_DIR/../bazel-bin
