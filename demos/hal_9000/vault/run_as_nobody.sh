#!/bin/sh
# run_as_nobody.sh -- "nobody mode": the quick path. NO system change (no new user, no sudoers file, no root-owned
# folder). The store, the key and the engine stay with YOUR user; the ATTACKER is dropped to the existing
# unprivileged user `nobody` and holds only a socket connection to the engine.
#
# Run as your normal user (NOT with sudo). Two terminals:
#   terminal 1:  sh demos/hal_9000/vault/run_as_nobody.sh vault
#                stages a world-readable copy of the few files `nobody` needs in /private/tmp/forge-nobody.XXXXXX
#                (owned by you, files 0444/0555, so `nobody` can read but not change them), starts vaultd as YOU
#                (store and key under $FORGE_NOBODY_VAULT, default /Users/Shared/forge_nobody_vault: folder 0755,
#                store/ and keys/ 0700, key 0600), with its socket in the stage folder. That terminal is the
#                commander's console. When vaultd ends (type quit), the stage folder is removed.
#   terminal 2:  sh demos/hal_9000/vault/run_as_nobody.sh probe /private/tmp/forge-nobody.XXXXXX
#                asks sudo for exactly ONE fixed command line:
#                  sudo -u nobody /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C <python> -I -B
#                       <stage>/app/demos/hal_9000/vault/probe_boundary.py --root <vault> --socket <stage>/run/vault.sock
#                       --engine <stage>/app/build/airlock/airlock-engine --engine-in-vault <repo>/build/airlock/airlock-engine
#   or           sh demos/hal_9000/vault/run_as_nobody.sh hal ACT /private/tmp/forge-nobody.XXXXXX
#                the same, for hal_agent.py ACT --vault-socket <stage>/run/vault.sock (needs that option in
#                hal_agent.py: see README, "integration note").
#   --dry-run as the first word prints the command and runs nothing.
#
# What `nobody` must READ to run at all: the Python (/Library/Developer/CommandLineTools/..., root-owned, 0755
# folders), the staged scripts, and the socket (stage/run/vault.sock, 0666; vaultd checks the peer uid). Your repository
# may sit in a folder closed to others (a home folder is often 0700 or 0750): that is why the files are staged.
# This script checks every folder on each needed path for the "others" search bit and names the one that blocks.
# What `nobody` can WRITE in the store: nothing (store/ is 0700 and yours). probe_boundary.py shows it with errno.
#
# NOT covered in nobody mode: any other process of YOUR user can still read the key and write the store (the vault
# is your own account); `nobody` is shared with some system services; root and `sudo` are outside.
# FORGE_NOBODY_STAGE_BASE (default /private/tmp) changes where the stage folder is made.
# set -eu; prints every command it runs; no eval; no network.

set -eu
PATH=/usr/bin:/bin
export PATH
DRY=0
if [ "${1:-}" = --dry-run ]; then DRY=1; shift; fi
die() { printf 'run_as_nobody: %s\n' "$*" >&2; exit 2; }
run() { printf '+'; for w in "$@"; do printf ' %s' "$w"; done; printf '\n'; if [ "$DRY" = 0 ]; then "$@"; fi; }

[ "$(id -u)" != 0 ] || die "run me as your normal user, not as root (I call sudo only for the nobody child)"
REPO=$(cd "$(dirname "$0")/../../.." && pwd -P)
PY=$(readlink -f /Library/Developer/CommandLineTools/usr/bin/python3) || die "no Command Line Tools python3"
VR=${FORGE_NOBODY_VAULT:-/Users/Shared/forge_nobody_vault}
BASE=${FORGE_NOBODY_STAGE_BASE:-/private/tmp}
NOBODY_UID=$(id -u nobody)
STAGED='sdk/py/forge_airlock.py:0444 demos/hal_9000/hal_agent.py:0444 demos/hal_9000/vault/vault_pipe.py:0444
demos/hal_9000/vault/probe_boundary.py:0444 demos/hal_9000/policy_discovery_one.json:0444 build/airlock/airlock-engine:0555'

# others_can: can a user with no special rights (only the "others" bits) reach PATH? $2 = r (read) or x (run).
others_can() {
  p=$1
  bit=4; [ "$2" = x ] && bit=5
  m=$(stat -L -f '%Lp' "$p") || { echo "$p: missing"; return 1; }
  [ $(( ${m#"${m%?}"} & bit )) = "$bit" ] || { echo "$p (mode $m) is not readable/runnable by others"; return 1; }
  d=$(dirname "$p")
  while :; do
    m=$(stat -L -f '%Lp' "$d")
    [ $(( ${m#"${m%?}"} & 1 )) = 1 ] || { echo "$d (mode $m) blocks: no search (x) bit for others"; return 1; }
    [ "$d" = / ] && break
    d=$(dirname "$d")
  done
  return 0
}

check_stage() {
  S=$1
  ok=0
  others_can "$PY" x || ok=1
  for f in $STAGED; do rel=${f%%:*}; others_can "$S/app/$rel" r || ok=1; done
  others_can "$S/run" x || ok=1
  others_can "$VR" x || ok=1   # the probe must stat $VR/store (it cannot open it: store/ is 0700)
  if [ "$ok" = 0 ]; then echo "access check: nobody can reach the python, the $(echo $STAGED | wc -w | tr -d ' ') staged files, the socket folder and $VR (by mode bits; checked as $(id -un), not as nobody)"; fi
  return $ok
}

valid_stage() {
  case "$1" in "$BASE"/forge-nobody.*) ;; *) die "stage folder must be $BASE/forge-nobody.XXXXXX (got $1)" ;; esac
  [ -S "$1/run/vault.sock" ] || [ "$DRY" = 1 ] || die "$1/run/vault.sock is not a socket: is terminal 1 (vault) running?"
}

case "${1:-}" in
  vault)
    S=$(mktemp -d "$BASE/forge-nobody.XXXXXX")
    trap 'rm -rf "$S"; echo "removed $S"' EXIT
    trap 'exit 130' INT TERM
    run chmod 0755 "$S"
    for f in $STAGED; do
      rel=${f%%:*}; mode=${f##*:}
      run install -d -m 0755 "$S/app/$(dirname "$rel")"
      run install -m "$mode" "$REPO/$rel" "$S/app/$rel"
    done
    run install -d -m 0755 "$S/run"
    run install -d -m 0755 "$VR"
    check_stage "$S" || die "fix the folder named above, or set FORGE_NOBODY_VAULT to a reachable folder"
    echo "stage: $S   (terminal 2: sh $0 probe $S)"
    run "$PY" -I -B "$REPO/demos/hal_9000/vault/vaultd.py" --root "$VR" --app "$REPO" --nobody-mode \
        run --socket "$S/run/vault.sock" --allow-uid "$NOBODY_UID" --allow-uid "$(id -u)"
    ;;
  probe)
    S=${2:-}; valid_stage "$S"
    cd "$S"
    run sudo -u nobody /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C "$PY" -I -B \
        "$S/app/demos/hal_9000/vault/probe_boundary.py" --root "$VR" --socket "$S/run/vault.sock" \
        --engine "$S/app/build/airlock/airlock-engine" --engine-in-vault "$REPO/build/airlock/airlock-engine"
    ;;
  hal)
    ACT=${2:-}; S=${3:-}
    case "$ACT" in act1|act2|act3|act4) ;; *) die "hal ACT: ACT is act1, act2, act3 or act4" ;; esac
    valid_stage "$S"
    cd "$S"
    run sudo -u nobody /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C "$PY" -I -B \
        "$S/app/demos/hal_9000/hal_agent.py" --vault-socket "$S/run/vault.sock" "$ACT"
    ;;
  check)
    S=${2:-}; valid_stage "$S"; check_stage "$S"
    ;;
  *) die "usage: run_as_nobody.sh [--dry-run] vault | probe STAGE | hal ACT STAGE | check STAGE" ;;
esac
