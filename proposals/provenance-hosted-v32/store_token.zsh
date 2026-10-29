#!/bin/zsh -f
# Stores a GitHub fine-grained token for B3 in the macOS Keychain, from the
# clipboard. Start it first, then copy the token: it waits for a github_pat_
# value. The token never appears on screen or in a process argument (printf is
# a builtin; security reads its command from standard input). The clipboard is
# cleared after the token is stored.
#
#   /bin/zsh -f store_token.zsh [KEYCHAIN_SERVICE [SECONDS]]
SERVICE=${1:-forge-verifier-readonly} WAIT=${2:-180}
R='^github_pat_[A-Za-z0-9_]{20,244}$'
echo "Now copy the token on GitHub (copy icon). Waiting up to $WAIT seconds..."
for i in {1..$WAIT}; do
  T=$(pbpaste)
  if [[ $T =~ $R ]]; then
    printf 'add-generic-password -U -s %s -a mack-dot -w %s\n' "$SERVICE" "$T" | /usr/bin/security -i
    unset T
    pbcopy < /dev/null
    /usr/bin/security find-generic-password -s "$SERVICE" -w \
      | /usr/bin/awk '{ok = ($0 ~ /^github_pat_[A-Za-z0-9_]+$/); print "stored:", length($0), (ok ? "token shape OK" : "NOT a token")}'
    echo "Clipboard cleared."
    exit 0
  fi
  sleep 1
done
unset T
echo "No github_pat_ token on the clipboard after $WAIT seconds; nothing stored."
exit 1
