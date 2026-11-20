#!/bin/sh
# Night shift 2026-11-19, task h-minter2 (C-ATT-14, C-ATT-31). The CLOSED LAUNCH of the issuer. TESTED-UNPROVED.
# Usage: minter-launch.sh <built directory> <pinned manifest SHA-256> <refund spec lock> on <key file> <sink store path> <mint memory file>
# The mint memory file (mintmemory.ts) must exist (created empty by the operator); minter.cjs opens and checks it.
# The key file (OWNER DECISION D-1) is NOT in the built directory and NOT in the manifest. This script does not stat,
# test or read it: it only makes the path absolute (the directory part is resolved; the last component is kept as
# given, so a symbolic link there still reaches minter.cjs and is refused by its O_NOFOLLOW open: keyfile.ts).
# h-minter3 (owner decision D-2): the closed launch is the PRODUCTION launch: memory rule "on" and the sink's store are
# REQUIRED (I1: at most one valid token per (charge id, request id)). The test modes (no store, or "off") run only
# through `node --import tsx minter.ts` and print a warning.
# Before Node starts: the manifest has the pinned digest; every listed file has its digest (/usr/bin/shasum); the
# directory holds no other file. Then: `env -i` with an allow-list (PATH, LANG, TZ, HOME, FORGE_MINTER_CLOSED), the
# fixed Node binary, fixed node options, the working directory = the built directory, and pre-compiled JavaScript
# (no tsx: no transform cache; TMPDIR, NODE_OPTIONS, NODE_PATH, NODE_COMPILE_CACHE, DYLD_* and the like of the caller
# do not reach the process). minter.cjs checks the same things again after it has loaded every module.
# NOT excluded: a process of the same user (it can change files between the checks and the reads, attach a debugger,
# or replace the Node binary and its libraries, which this script does not check): assumptions SAME-UID, FIXED-DEPS.
set -eu
NODE=/opt/homebrew/bin/node
NODE_VERSION=v24.3.0
[ $# -eq 7 ] || { echo "usage: minter-launch.sh <built dir> <manifest sha256> <spec lock> on <key file> <store> <mint memory file>" >&2; exit 2; }
case "$7" in "") echo "minter-launch.sh: refused: empty mint memory path" >&2; exit 2;; esac
MEM=$(cd "$(dirname "$7")" && pwd -P)/$(basename "$7")
DIR=$(cd "$1" && pwd -P); PIN=$2; LOCK=$3; MODE=$4
case "$5" in "") echo "minter-launch.sh: refused: empty key file path" >&2; exit 2;; esac
KEY=$(cd "$(dirname "$5")" && pwd -P)/$(basename "$5")
[ "$MODE" = on ] || { echo "minter-launch.sh: refused: production needs memory rule \"on\" (owner decision D-2)" >&2; exit 2; }
case "$PIN" in *[!0-9a-f]*|"") echo "minter-launch.sh: refused: the pin is not lowercase hex" >&2; exit 2;; esac
[ ${#PIN} -eq 64 ] || { echo "minter-launch.sh: refused: the pin is not 64 hex digits" >&2; exit 2; }
LOCK=$(cd "$(dirname "$LOCK")" && pwd -P)/$(basename "$LOCK")
cd "$DIR"
got=$(/usr/bin/shasum -a 256 MANIFEST.sha256 | cut -d' ' -f1)
[ "$got" = "$PIN" ] || { echo "minter-launch.sh: refused: MANIFEST.sha256 does not have the pinned digest" >&2; exit 2; }
/usr/bin/shasum -a 256 -s -c MANIFEST.sha256 || { echo "minter-launch.sh: refused: a listed file has another digest" >&2; exit 2; }
listed=$(sed -E 's/^[0-9a-f]{64}  //' MANIFEST.sha256 | LC_ALL=C sort)
present=$(find . -type f ! -name MANIFEST.sha256 | LC_ALL=C sort)
[ "$listed" = "$present" ] || { echo "minter-launch.sh: refused: the directory holds files that are not listed (or misses some)" >&2; exit 2; }
[ -z "$(find . -type l)" ] || { echo "minter-launch.sh: refused: the directory holds a symbolic link" >&2; exit 2; }
v=$(/usr/bin/env -i "$NODE" --version)
[ "$v" = "$NODE_VERSION" ] || { echo "minter-launch.sh: refused: node is $v, not $NODE_VERSION" >&2; exit 2; }
STORE=$(cd "$(dirname "$6")" && pwd -P)/$(basename "$6"); set -- "$STORE" "$MEM"
exec /usr/bin/env -i PATH=/usr/bin:/bin LANG=C TZ=UTC HOME=/var/empty FORGE_MINTER_CLOSED="$PIN" \
  "$NODE" --no-addons --disallow-code-generation-from-strings "$DIR/minter.cjs" "$DIR/core.cjs" "$LOCK" "$MODE" "$KEY" "$@"
