#!/bin/sh
# Night shift 2026-11-19, task h-minter2 (C-ATT-14, C-ATT-31). Builds a CLOSED issuer directory: pre-compiled
# JavaScript, no TypeScript transform at run time (no tsx, so no transform cache), every file the issuer loads inside
# the directory, and a manifest of SHA-256 digests. The printed manifest digest is the value that an operator pins
# and passes to minter-launch.sh. TESTED-UNPROVED.
# Usage: minter-build.sh <tree root> <compiled IssueAuth module (.cjs)> <new output directory>
# Output directory: minter.cjs (esbuild bundle of minter.ts + encoding.ts; bignumber.js left external), core.cjs (a
# copy of the module), minter.ts and encoding.ts (copies: the checker id is computed from them, unchanged),
# node_modules/bignumber.js/{package.json,bignumber.js} (copies of the resolved files), MANIFEST.sha256.
# The build itself runs with the caller's tools (esbuild, node, shasum): build on a trusted machine state.
set -eu
umask 022
ROOT=$(cd "$1" && pwd -P); CORE=$2; OUT=$3
[ -f "$CORE" ] || { echo "minter-build.sh: no core module: $CORE" >&2; exit 2; }
[ -e "$OUT" ] && { echo "minter-build.sh: the output directory exists: $OUT" >&2; exit 2; }
mkdir -p "$OUT/node_modules/bignumber.js"
OUT=$(cd "$OUT" && pwd -P)
"$ROOT/node_modules/.bin/esbuild" "$ROOT/ts/refund-finality/minter.ts" --bundle --platform=node --format=cjs \
  --target=node24 --external:bignumber.js --log-level=warning --outfile="$OUT/minter.cjs"
cp "$ROOT/ts/refund-finality/minter.ts" "$ROOT/ts/refund-finality/encoding.ts" "$OUT/"
cp "$CORE" "$OUT/core.cjs"
BN=$(cd "$ROOT/ts/refund-finality" && node -p 'require.resolve("bignumber.js")')
cp "$BN" "$OUT/node_modules/bignumber.js/bignumber.js"
cp "$(dirname "$BN")/package.json" "$OUT/node_modules/bignumber.js/package.json"
chmod -R a-w "$OUT"/*
(cd "$OUT" && find . -type f ! -name MANIFEST.sha256 | LC_ALL=C sort | while read -r f; do /usr/bin/shasum -a 256 "$f"; done) > "$OUT/MANIFEST.sha256"
chmod a-w "$OUT/MANIFEST.sha256" "$OUT/node_modules/bignumber.js" "$OUT/node_modules" "$OUT"
/usr/bin/shasum -a 256 "$OUT/MANIFEST.sha256" | cut -d' ' -f1
