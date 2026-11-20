#!/bin/sh
# teardown_vault.sh -- remove exactly what setup_vault.sh created, and nothing else.
#
#   sudo sh demos/hal_9000/vault/teardown_vault.sh
#   sh demos/hal_9000/vault/teardown_vault.sh --dry-run      (no root needed; prints every command, changes nothing)
#
# Removes: /etc/sudoers.d/forge_vault (only if its first line is setup_vault.sh's marker), the folder
# /usr/local/forge_vault (only if bin/MANIFEST.sha256 is there: setup_vault.sh made it), the user and the group
# forge_vault (only if their RealName is setup_vault.sh's marker). The store and the commander's key go with the
# folder: that is the point of a teardown. It touches no other path. It refuses while a forge_vault process runs.
# set -eu; prints every command before it runs it; no eval; no network.

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
VAULT_USER=forge_vault
R=/usr/local/forge_vault
SUDOERS_FILE=/etc/sudoers.d/forge_vault
MARK='Forge HAL demo vault (setup_vault.sh)'

DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    *) echo "teardown_vault: unknown option $arg (this script takes no path: it removes only $R)" >&2; exit 2 ;;
  esac
done
die() { printf 'teardown_vault: REFUSED: %s\n' "$*" >&2; exit 1; }
run() { printf '+'; for w in "$@"; do printf ' %s' "$w"; done; printf '\n'; if [ "$DRY" = 0 ]; then "$@"; fi; }

if [ "$DRY" = 0 ]; then
  [ "$(id -u)" = 0 ] || die "run me with sudo (or use --dry-run)"
  [ -n "${SUDO_UID:-}" ] && [ "$SUDO_UID" != 0 ] || die "run me through sudo from your normal account"
fi

# 0. nothing of forge_vault may still run (stop the vault first: type `quit` in its terminal)
if id "$VAULT_USER" >/dev/null 2>&1; then
  if pgrep -u "$VAULT_USER" >/dev/null 2>&1; then
    pgrep -l -u "$VAULT_USER" || true
    die "processes of $VAULT_USER are running: stop the vault first (type quit in its terminal)"
  fi
fi

# 1. the optional sudoers drop-in
if [ -e "$SUDOERS_FILE" ]; then
  if [ "$DRY" = 0 ] && [ "$(head -n 1 "$SUDOERS_FILE")" != "# $MARK" ]; then
    die "$SUDOERS_FILE does not carry the marker of setup_vault.sh: not removed"
  fi
  run rm -f "$SUDOERS_FILE"
  run visudo -c
else
  echo "no $SUDOERS_FILE"
fi

# 2. the vault folder (this exact path only; the marker file must be present)
if [ -d "$R" ]; then
  [ "$R" = /usr/local/forge_vault ] || die "unexpected vault root $R"
  [ ! -L "$R" ] || die "$R is a symbolic link: not removed"
  [ -f "$R/bin/MANIFEST.sha256" ] || die "$R has no bin/MANIFEST.sha256: not made by setup_vault.sh, not removed"
  run rm -rf "$R"
else
  echo "no $R"
fi

# 3. the user and the group (only those made by setup_vault.sh)
for kind in Users Groups; do
  if dscl . -read "/$kind/$VAULT_USER" RealName >/dev/null 2>&1; then
    dscl . -read "/$kind/$VAULT_USER" RealName | grep -qF "$MARK" || die "/$kind/$VAULT_USER was not made by setup_vault.sh"
    run dscl . -delete "/$kind/$VAULT_USER"
  else
    echo "no /$kind/$VAULT_USER"
  fi
done
echo "done$( [ "$DRY" = 1 ] && echo ' (DRY RUN: nothing was changed)')"
