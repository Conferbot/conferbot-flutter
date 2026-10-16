#!/bin/sh
# Copies the launcher effects golden (Chrome's own frames of every entrance,
# attention and idle-call track) from the React Native SDK
# (scripts/parity/launcherfx/golden.json) into
# test/fixtures/launcherfx_golden.json and notes the RN revision it came
# from. Set RN_SDK if the repo is not next door.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
rn="${RN_SDK:-$here/../conferbot-react-native}"
src="$rn/scripts/parity/launcherfx/golden.json"
dst="$here/test/fixtures/launcherfx_golden.json"
[ -f "$src" ] || { echo "no golden at $src" >&2; exit 1; }
cp "$src" "$dst"
rev="$(git -C "$rn" log -1 --format=%h -- scripts/parity/launcherfx/golden.json)"
printf '%s\n' "$rev" > "$here/test/fixtures/launcherfx_golden.REVISION"
echo "synced launcherfx golden from RN $rev"
