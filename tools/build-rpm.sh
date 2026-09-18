#!/bin/sh
# Builds the noarch RPM on the build host (rpmbuild, RPM v4 format, gzip
# payload so that the Sailfish OS rpm can read it) and copies it to
# ~/ps/rpms/sailfish-weather-wind/. Run from the repository on the phone.
set -e
cd "$(dirname "$0")/.."
name=sailfish-weather-wind
version=$(sed -n 's/^Version: *//p' rpm/$name.spec)
release=$(sed -n 's/^Release: *//p' rpm/$name.spec)
host=${BUILD_HOST:-}
if [ -z "$host" ]; then
    if ssh -o ConnectTimeout=4 -o BatchMode=yes sebastian@192.168.1.21 true 2>/dev/null; then
        host=sebastian@192.168.1.21
    else
        host=arch
    fi
fi
out=$HOME/ps/rpms/$name
mkdir -p "$out"
tar=$name-$version.tar.gz
git archive --format=tar.gz --prefix="$name-$version/" -o "/tmp/$tar" HEAD
ssh "$host" "rm -rf /tmp/$name-build && mkdir -p /tmp/$name-build/SOURCES /tmp/$name-build/SPECS"
scp -q "/tmp/$tar" "$host:/tmp/$name-build/SOURCES/"
scp -q rpm/$name.spec "$host:/tmp/$name-build/SPECS/"
ssh "$host" "cd /tmp/$name-build && rpmbuild -bb --define '_topdir /tmp/$name-build' \
    --define '_rpmformat 4' --define '_binary_payload w9.gzdio' \
    --define '_build_id_links none' --define 'dist %{nil}' SPECS/$name.spec" | tail -3
scp -q "$host:/tmp/$name-build/RPMS/noarch/$name-$version-$release.noarch.rpm" "$out/"
rm -f "/tmp/$tar"
ls -la "$out/$name-$version-$release.noarch.rpm"
