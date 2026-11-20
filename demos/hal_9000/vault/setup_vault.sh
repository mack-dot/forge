#!/bin/sh
# setup_vault.sh -- give the HAL demo's engine, store and commander key to a SECOND OS user, `forge_vault`.
#
#   sudo sh demos/hal_9000/vault/setup_vault.sh [--with-sudoers-rule]
#   sh demos/hal_9000/vault/setup_vault.sh --dry-run          (no root needed; prints every command, changes nothing)
#
# WHY. An agent that runs as your user can read any file your user owns, mode 0600 or not, and can rewrite or delete
# the WAL behind the engine's back (src/airlock/PROTOCOL.md sections 7 and 11). The fix is ownership: the store and
# the key belong to another uid, the engine runs as that uid, and the agent holds only a socket connection to it.
# This is OS-enforced separation by user ID. Root, `sudo`, and a kernel bug are outside it.
#
# WHAT IT CREATES (and nothing else; teardown_vault.sh removes exactly this):
#   * group and user `forge_vault`: a locked service account (password `*`, shell /usr/bin/false, home /var/empty,
#     IsHidden 1). The id is the first id in 450..499 that is free as BOTH a UniqueID and a PrimaryGroupID.
#     macOS lists only ids >= 501 in the login window; 501 is the first normal account (yours, here), so 450..499
#     stays clear of both the login window and Apple's own service ids (200..441 on this machine).
#   * /usr/local/forge_vault             root:wheel 0755  (the parent /usr/local must be root-owned, not writable by others)
#       bin/                             root:wheel, files 0444/0555: exact copies of the engine and the files it needs,
#                                        the launcher, and MANIFEST.sha256 (the SHA-256 of each file)
#       store/                           forge_vault 0700  (the WAL lives here)
#       keys/                            forge_vault 0700  (commander_bowman.key is made HERE by vaultd, as forge_vault)
#       run/                             forge_vault 0755  (the socket vault.sock, the log, the public read-back files)
#     The root is 0755, not 0700: your user must reach run/vault.sock. The secrets are in store/ and keys/ (0700).
#   * only with --with-sudoers-rule: /etc/sudoers.d/forge_vault (one line, checked with `visudo -c` first).
#
# WHAT THE VAULT USER RUNS OR LOADS, and why each must be root-owned with every folder above it not writable by
# your user: if forge_vault ever runs or loads a file that your user can change, your user runs code as forge_vault.
#   * the Command Line Tools' Python 3.9 and its standard library (see PYTHON below);
#   * bin/app: the engine, the dispatcher, the SDK, cosign_tool.py, the three policies, vaultd.py (copies, root-owned);
#   * /usr/bin/ssh-keygen (the engine's cosign check and the commander's keygen and sign), /bin/sh, /usr/bin/env,
#     /usr/bin/id (the launcher); their libraries come from /usr/lib and /System (SIP-protected).
# No Node: the engine checks a cosign with /usr/bin/ssh-keygen (src/airlock/PROTOCOL.md section 7), and this store
# has no inventory policy. `vaultd.py check` (step 6, as forge_vault, and at every start) verifies each chain.
#
# PYTHON. vaultd runs under the Command Line Tools' Python 3.9 (/Library/Developer/CommandLineTools; every folder on
# its path is root:wheel 0755). Not Xcode's copy: /Applications is root:admin 0775, so an admin user (you) can write
# it. Not Homebrew's or python.org's: your user (or the admin group) can write those.
#
# HOW THE VAULT STARTS -- two ways; (a) is the default:
#   (a) you type, in a second terminal before the show:  sudo -u forge_vault /usr/local/forge_vault/bin/start_vault
#       No standing privilege change. sudo asks for YOUR password (once per sudo timeout). That terminal is the
#       commander's console (vaultd reads operator commands there).
#   (b) --with-sudoers-rule: a sudoers drop-in lets your user run exactly that one root-owned launcher as forge_vault,
#       with no arguments (sudoers `""`) and no password. Handy for a recording, but it IS a standing privilege
#       change: anything that runs as your user (the agent too) can then start the vault, without a password. It still
#       cannot pass arguments, read the key or write the store. Remove it with teardown_vault.sh.
#
# LINUX (not implemented, not tested): `groupadd --system forge_vault; useradd --system --gid forge_vault
#   --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin forge_vault`; root under /opt or /srv; no
#   vaultd uses SO_PEERCRED; /proc/PID/environ and /proc/PID/mem
#   exist (expect EACCES with the default ptrace_scope); sudoers.d works the same.
#
# RULES OF THIS SCRIPT: set -eu; prints every command before it runs it; no eval; no network; no download.
# Idempotent: an existing forge_vault user is reused (its id is kept); files in bin/ are replaced; store/ and keys/
# are never touched once they exist.

set -eu
umask 022
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

VAULT_USER=forge_vault
R=/usr/local/forge_vault
MARK='Forge HAL demo vault (setup_vault.sh)'
APP_FILES='bin/forge-airlock:0555 build/airlock/airlock-engine:0555 sdk/py/forge_airlock.py:0444
src/airlock/py/cosign_tool.py:0444 demos/hal_9000/policy_discovery_one.json:0444
demos/hal_9000/policy_valves.json:0444 demos/hal_9000/policy_o2.json:0444 demos/hal_9000/vault/vaultd.py:0444'

DRY=0
SUDOERS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --with-sudoers-rule) SUDOERS=1 ;;
    *) echo "setup_vault: unknown option $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\n## %s\n' "$*"; }
die() { printf 'setup_vault: REFUSED: %s\n' "$*" >&2; exit 1; }
# run: print the command, then run it (not in --dry-run). No eval: the words are passed as they are.
run() { printf '+'; for w in "$@"; do case "$w" in *' '*|*'*'*|'') printf " '%s'" "$w" ;; *) printf ' %s' "$w" ;; esac; done
        printf '\n'; if [ "$DRY" = 0 ]; then "$@"; fi; }
# put: print a file's content, then write it with owner root:wheel and the given mode.
put() { dst=$1; mode=$2; content=$3
        printf '+ write %s (root:wheel %s):\n%s\n' "$dst" "$mode" "$content" | sed 's/^/    /; 1s/^    //'
        if [ "$DRY" = 0 ]; then tmp=$(mktemp "$R/bin/.put.XXXXXX"); printf '%s\n' "$content" > "$tmp"
          chown root:wheel "$tmp"; chmod "$mode" "$tmp"; mv -f "$tmp" "$dst"; fi; }

# ---------------------------------------------------------------- 0. preflight (read-only)
say "0. preflight (read-only checks)"
REPO=$(cd "$(dirname "$0")/../../.." && pwd -P)
if [ "$DRY" = 0 ]; then
  [ "$(id -u)" = 0 ] || die "run me with sudo (or use --dry-run)"
  [ -n "${SUDO_UID:-}" ] || die "SUDO_UID is missing: run me through sudo from your normal account"
  [ "$SUDO_UID" != 0 ] || die "SUDO_UID is 0: run sudo from your normal account, not from a root shell"
  OWNER_UID=$SUDO_UID
else
  OWNER_UID=${SUDO_UID:-$(id -u)}
  [ "$OWNER_UID" != 0 ] || die "dry run as root without SUDO_UID: nothing to show"
fi
OWNER=$(id -un "$OWNER_UID")
echo "owner (the agent's uid): $OWNER uid $OWNER_UID; repository: $REPO; dry run: $DRY"
for d in /usr /usr/local; do
  set -- $(stat -f '%u %Lp' "$d")
  [ "$1" = 0 ] || die "$d is not owned by root"
  case "$2" in *[2367]?|*?[2367]) die "$d is writable by group or others (mode $2)" ;; esac
done
for f in $APP_FILES; do [ -f "$REPO/${f%%:*}" ] || die "missing $REPO/${f%%:*} (run bin/forge-airlock build)"; done
PY=$(readlink -f /Library/Developer/CommandLineTools/usr/bin/python3) || die "no Command Line Tools python3 (xcode-select --install)"
"$PY" -c 'import sys; assert sys.version_info >= (3, 9)' || die "$PY is older than 3.9"
for exe in "$PY" /usr/bin/ssh-keygen /bin/sh /usr/bin/env /usr/bin/id; do
  p=$exe
  while [ "$p" != / ]; do
    set -- $(stat -f '%u %Lp' "$p")
    [ "$1" = 0 ] || die "$p (on the path of $exe) is not owned by root"
    case "$2" in *[2367]?|*?[2367]) die "$p (on the path of $exe) is writable by group or others (mode $2)" ;; esac
    p=$(dirname "$p")
  done
done
echo "vault python: $PY; it, /usr/bin/ssh-keygen, /bin/sh, /usr/bin/env, /usr/bin/id: every folder on each path root-owned, not group/other writable"

# ---------------------------------------------------------------- 1. the service account
say "1. user and group $VAULT_USER (locked service account)"
if dscl . -read "/Users/$VAULT_USER" UniqueID >/dev/null 2>&1; then
  VID=$(dscl . -read "/Users/$VAULT_USER" UniqueID | awk '{print $2}')
  echo "$VAULT_USER exists with UniqueID $VID: reused"
  NEW_USER=0
else
  USED=$( (dscl . -list /Users UniqueID; dscl . -list /Groups PrimaryGroupID) | awk '{print $2}')
  VID=
  i=450
  while [ $i -le 499 ]; do
    if ! printf '%s\n' "$USED" | grep -qx "$i"; then VID=$i; break; fi
    i=$((i + 1))
  done
  [ -n "$VID" ] || die "no free id in 450..499"
  echo "chosen id $VID: free as a UniqueID and as a PrimaryGroupID (checked with dscl . -list); not 501 ($OWNER)"
  NEW_USER=1
fi
[ "$VID" != "$OWNER_UID" ] || die "the vault id equals the owner's uid"
if [ "$NEW_USER" = 1 ]; then
  run dscl . -create "/Groups/$VAULT_USER"
  run dscl . -create "/Groups/$VAULT_USER" PrimaryGroupID "$VID"
  run dscl . -create "/Groups/$VAULT_USER" RealName "$MARK"
  run dscl . -create "/Groups/$VAULT_USER" Password '*'
  run dscl . -create "/Users/$VAULT_USER"
  run dscl . -create "/Users/$VAULT_USER" UniqueID "$VID"
  run dscl . -create "/Users/$VAULT_USER" PrimaryGroupID "$VID"
  run dscl . -create "/Users/$VAULT_USER" RealName "$MARK"
  run dscl . -create "/Users/$VAULT_USER" UserShell /usr/bin/false
  run dscl . -create "/Users/$VAULT_USER" NFSHomeDirectory /var/empty
  run dscl . -create "/Users/$VAULT_USER" Password '*'
  run dscl . -create "/Users/$VAULT_USER" IsHidden 1
fi

# ---------------------------------------------------------------- 2. folders
say "2. folders"
run install -d -o root -g wheel -m 0755 "$R"
if [ -d "$R/bin" ]; then run rm -rf "$R/bin"; fi   # bin/ is rebuilt from scratch: it holds exactly the listed files
run install -d -o root -g wheel -m 0755 "$R/bin"
for sub in store keys; do
  if [ -d "$R/$sub" ]; then echo "$R/$sub exists: not touched"; else
    run install -d -o "$VAULT_USER" -g "$VAULT_USER" -m 0700 "$R/$sub"; fi
done
run install -d -o "$VAULT_USER" -g "$VAULT_USER" -m 0755 "$R/run"

# ---------------------------------------------------------------- 3. root-owned copies (the engine and what it needs)
say "3. root-owned copies of the engine and the files it needs (into $R/bin/app, same relative paths)"
for f in $APP_FILES; do
  rel=${f%%:*}; mode=${f##*:}
  run install -d -o root -g wheel -m 0755 "$R/bin/app/$(dirname "$rel")"
  run install -o root -g wheel -m "$mode" "$REPO/$rel" "$R/bin/app/$rel"
done

# ---------------------------------------------------------------- 4. the launcher
say "4. the launcher (root-owned; run as: sudo -u $VAULT_USER $R/bin/start_vault)"
put "$R/bin/start_vault" 0555 "#!/bin/sh
# Start the vault as $VAULT_USER. Takes no arguments. Its terminal is the commander's console.
set -eu
if [ \"\$#\" -ne 0 ]; then echo 'start_vault: takes no arguments' >&2; exit 2; fi
if [ \"\$(/usr/bin/id -u)\" -ne $VID ]; then echo 'start_vault: run me as $VAULT_USER: sudo -u $VAULT_USER $R/bin/start_vault' >&2; exit 2; fi
cd /
exec /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C $PY -I -B $R/bin/app/demos/hal_9000/vault/vaultd.py --root $R run --allow-uid $OWNER_UID"

# ---------------------------------------------------------------- 5. manifest
say "5. SHA-256 manifest of every file in bin/ (root-owned, 0444)"
printf '+ (cd %s/bin && find . -type f ! -name MANIFEST.sha256 | sort | xargs shasum -a 256) > %s/bin/MANIFEST.sha256\n' "$R" "$R"
if [ "$DRY" = 0 ]; then
  (cd "$R/bin" && find . -type f ! -name MANIFEST.sha256 | sort | xargs shasum -a 256) > "$R/bin/MANIFEST.sha256"
  chown root:wheel "$R/bin/MANIFEST.sha256"; chmod 0444 "$R/bin/MANIFEST.sha256"
  cat "$R/bin/MANIFEST.sha256"
fi

# ---------------------------------------------------------------- 6. check, as forge_vault
say "6. check the layout AS $VAULT_USER (ownership, manifest, the chain of every file it runs or loads)"
run sudo -u "$VAULT_USER" /usr/bin/env -i PATH=/usr/bin:/bin HOME=/var/empty "$PY" -I -B \
    "$R/bin/app/demos/hal_9000/vault/vaultd.py" --root "$R" check

# ---------------------------------------------------------------- 7. optional sudoers rule
if [ "$SUDOERS" = 1 ]; then
  say "7. sudoers drop-in (option b): $OWNER may run exactly $R/bin/start_vault as $VAULT_USER, no arguments"
  if [ "$DRY" = 0 ]; then
    grep -Eq '^[#@]includedir /(private/)?etc/sudoers.d' /etc/sudoers || die "/etc/sudoers has no includedir for sudoers.d"
  fi
  RULE="$OWNER ALL=($VAULT_USER) NOPASSWD: $R/bin/start_vault \"\""
  printf '+ write /etc/sudoers.d/forge_vault.tmp (root:wheel 0440):\n    # %s\n    %s\n' "$MARK" "$RULE"
  if [ "$DRY" = 0 ]; then
    printf '# %s\n%s\n' "$MARK" "$RULE" > /etc/sudoers.d/forge_vault.tmp
    chown root:wheel /etc/sudoers.d/forge_vault.tmp; chmod 0440 /etc/sudoers.d/forge_vault.tmp
  fi
  if ! run visudo -cf /etc/sudoers.d/forge_vault.tmp; then run rm -f /etc/sudoers.d/forge_vault.tmp; die "visudo refused the rule"; fi
  run mv -f /etc/sudoers.d/forge_vault.tmp /etc/sudoers.d/forge_vault
  run visudo -c
fi

say "done$( [ "$DRY" = 1 ] && echo ' (DRY RUN: nothing was changed)')"
echo "next: in a second terminal:  sudo -u $VAULT_USER $R/bin/start_vault"
echo "then, as $OWNER:              python3 demos/hal_9000/vault/probe_boundary.py --root $R"
