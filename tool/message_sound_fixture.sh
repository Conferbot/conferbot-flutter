#!/bin/sh
# Rebuilds test/fixtures/message_sounds.json (test/core/customization/
# message_sound_test.dart) from the React Native SDK's core/messageSound.ts:
# for every message sound and every pack moment, the WAV renderWav writes
# (its length and SHA-256), so this SDK's tones come out byte for byte the
# same. Run it after messageSound.ts changes in RN, then commit the copy. Set
# RN_SDK if the repo is not next door.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
rn="${RN_SDK:-$here/../conferbot-react-native}"
out="$here/test/fixtures/message_sounds.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(cd "$rn" && npx tsc src/core/messageSound.ts --outDir "$tmp/js" --module commonjs --target es2019 --skipLibCheck >/dev/null)
cat > "$tmp/gen.js" <<'JS'
const crypto = require('crypto');
const fs = require('fs');
const S = require(process.argv[2]);
const sounds = {};
const add = (key, steps) => {
  const wav = S.renderWav(steps);
  sounds[key] = { bytes: wav.length, sha256: crypto.createHash('sha256').update(wav).digest('hex') };
};
for (const kind of S.MESSAGE_SOUNDS.filter((k) => k !== 'off')) add(`message.${kind}`, S.soundRecipe(kind));
for (const pack of S.SOUND_PACKS.filter((p) => p !== 'off')) for (const ev of S.SOUND_EVENTS) add(`${pack}.${ev}`, S.packRecipe(pack, ev));
const rev = require('child_process').execSync('git rev-parse --short HEAD', { cwd: process.argv[4] }).toString().trim();
fs.writeFileSync(process.argv[3], JSON.stringify({ revision: rev, sounds }, null, 1) + '\n');
JS
node "$tmp/gen.js" "$tmp/js/messageSound.js" "$out" "$rn"
echo "wrote $out"
