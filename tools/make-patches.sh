#!/bin/sh
# Regenerates patches/*.diff from src/ against the pristine files of the
# sailfish-weather release named in UPSTREAM_TAG (fetched from GitHub).
set -e
cd "$(dirname "$0")/.."
tag=${UPSTREAM_TAG:-1.3.11}
base="https://raw.githubusercontent.com/sailfishos/sailfish-weather/$tag"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for f in src/components/*.qml src/backends/*.qml; do
    sub=$(basename "$(dirname "$f")")
    name=$(basename "$f")
    curl -sf -o "$tmp/$name" "$base/$sub/$name"
    diff -u --label "a/$sub/$name" --label "b/$sub/$name" "$tmp/$name" "$f" > "patches/$name.diff" || true
    printf '%s: %s lines\n' "$name" "$(wc -l < "patches/$name.diff")"
done
