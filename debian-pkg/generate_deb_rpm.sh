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

rm -rf /tmp/typosearch-deb-build && mkdir /tmp/typosearch-deb-build
cp -r $CURR_DIR/typosearch-server /tmp/typosearch-deb-build

# Download Typosearch, extract and make it executable

#curl -o /tmp/typosearch-server-$TSV.tar.gz https://dl.typosearch.org/releases/$TSV/typosearch-server-$TSV-linux-${ARCH}.tar.gz
rm -rf /tmp/typosearch-server-$TSV && mkdir /tmp/typosearch-server-$TSV
tar -xzf $CURR_DIR/../bazel-bin/typosearch-server-$TSV-linux-${ARCH}.tar.gz -C /tmp/typosearch-server-$TSV

downloaded_hash=`md5sum /tmp/typosearch-server-$TSV/typosearch-server | cut -d' ' -f1`
original_hash=`cat /tmp/typosearch-server-$TSV/typosearch-server.md5.txt`

if [ "$downloaded_hash" == "$original_hash" ]; then
    mkdir -p /tmp/typosearch-deb-build/typosearch-server/usr/bin
    cp /tmp/typosearch-server-$TSV/typosearch-server /tmp/typosearch-deb-build/typosearch-server/usr/bin
else
    >&2 echo "Typosearch server binary is corrupted. Quitting."
    exit 1
fi

rm -rf /tmp/typosearch-server-$TSV /tmp/typosearch-server-$TSV.tar.gz

sed -i "s/\$VERSION/$TSV/g" `find /tmp/typosearch-deb-build -maxdepth 10 -type f`
sed -i "s/\$ARCH/$ARCH/g" `find /tmp/typosearch-deb-build -maxdepth 10 -type f`

dpkg-deb -Zgzip -z6 \
         -b /tmp/typosearch-deb-build/typosearch-server "/tmp/typosearch-deb-build/typosearch-server-${TSV}-${ARCH}.deb"

# Generate RPM

rm -rf /tmp/typosearch-rpm-build && mkdir /tmp/typosearch-rpm-build
cp "/tmp/typosearch-deb-build/typosearch-server-${TSV}-${ARCH}.deb" /tmp/typosearch-rpm-build
cd /tmp/typosearch-rpm-build && alien --scripts -k -r -g -v /tmp/typosearch-rpm-build/typosearch-server-${TSV}-${ARCH}.deb

sed -i 's#%dir "/"##' `find /tmp/typosearch-rpm-build/*/*.spec -maxdepth 10 -type f`
sed -i 's#%dir "/usr/bin/"##' `find /tmp/typosearch-rpm-build/*/*.spec -maxdepth 10 -type f`
sed -i 's/%config/%config(noreplace)/g' `find /tmp/typosearch-rpm-build/*/*.spec -maxdepth 10 -type f`

SPEC_FILE="/tmp/typosearch-rpm-build/typosearch-server-${TSV}/typosearch-server-${TSV}-1.spec"
SPEC_FILE_COPY="/tmp/typosearch-rpm-build/typosearch-server-${TSV}/typosearch-server-${TSV}-copy.spec"

cp $SPEC_FILE $SPEC_FILE_COPY

PRE_LINE=`grep -n "%pre" $SPEC_FILE_COPY | cut -f1 -d:`
START_LINE=`expr $PRE_LINE - 1`

head -$START_LINE $SPEC_FILE_COPY > $SPEC_FILE

echo "%prep" >> $SPEC_FILE
echo "cat >/tmp/find_requires.sh <<EOF
#!/bin/sh
%{__find_requires} | grep -v GLIBC_PRIVATE
exit 0
EOF" >> $SPEC_FILE

echo "chmod +x /tmp/find_requires.sh" >> $SPEC_FILE
echo "%define _use_internal_dependency_generator 0" >> $SPEC_FILE
echo "%define __find_requires /tmp/find_requires.sh" >> $SPEC_FILE

tail -n+$START_LINE $SPEC_FILE_COPY >> $SPEC_FILE

rm $SPEC_FILE_COPY

cd /tmp/typosearch-rpm-build/typosearch-server-${TSV} && \
  rpmbuild --target=${RPM_ARCH} --buildroot /tmp/typosearch-rpm-build/typosearch-server-${TSV} -bb \
  $SPEC_FILE

cp "/tmp/typosearch-rpm-build/typosearch-server-${TSV}-${ARCH}.deb" $CURR_DIR/../bazel-bin
cp "/tmp/typosearch-rpm-build/typosearch-server-${TSV}-1.${RPM_ARCH}.rpm" $CURR_DIR/../bazel-bin
