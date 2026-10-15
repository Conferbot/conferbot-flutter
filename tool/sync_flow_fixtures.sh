#!/bin/sh
# Copies the shared flow-node fixtures from the React Native SDK
# (scripts/parity/flows/fixtures) into test/fixtures/parity_flows and notes
# the RN revision they came from. Set RN_SDK if the repo is not next door.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
rn="${RN_SDK:-$here/../conferbot-react-native}"
src="$rn/scripts/parity/flows/fixtures"
dst="$here/test/fixtures/parity_flows"
[ -d "$src" ] || { echo "no fixtures at $src" >&2; exit 1; }
rm -rf "$dst"
mkdir -p "$dst"
cp "$src"/*.json "$dst"/
rev="$(git -C "$rn" log -1 --format=%h -- scripts/parity/flows/fixtures)"
printf '%s\n' "$rev" > "$dst/REVISION"
echo "synced $(ls "$dst"/*.json | wc -l | tr -d ' ') files from RN $rev"
