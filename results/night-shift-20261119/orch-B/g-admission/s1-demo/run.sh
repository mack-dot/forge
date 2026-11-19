#!/bin/sh
# S1 design check with TEST keys only (no owner key, no hardware key). Each line: label exit code.
set -u
cd "$(dirname "$0")"
rm -rf work && mkdir work && cd work
ssh-keygen -q -t ed25519 -N '' -C test-owner -f owner >/dev/null; echo "keygen owner exit $?"
ssh-keygen -q -t ed25519 -N '' -C test-attacker -f attacker >/dev/null; echo "keygen attacker exit $?"
printf 'forge-approval-v1\nrepository mack-dot/forge\ndecision approved_as_written\ninput spec.lock %s %s\ninput spec/LedgerSpec.dfy %s %s\nproposal_sha256 %s\n' \
  $(printf a%.0s $(seq 64)) $(printf b%.0s $(seq 64)) $(printf c%.0s $(seq 64)) $(printf d%.0s $(seq 64)) $(printf e%.0s $(seq 64)) > statement.txt
echo "forge-owner namespaces=\"forge-approval-v1\" $(cat owner.pub)" > allowed_signers
ssh-keygen -q -Y sign -f owner -n forge-approval-v1 statement.txt 2>/dev/null; echo "sign owner exit $?"
v() { ssh-keygen -Y verify -f allowed_signers -I forge-owner -n "$1" -s "$2" < "$3" >/dev/null 2>&1; echo "$4 exit $?"; }
v forge-approval-v1 statement.txt.sig statement.txt "POS verify genuine (want 0)"
sed 's/^decision approved_as_written/decision approved_as_writtem/' statement.txt > flipped.txt
v forge-approval-v1 statement.txt.sig flipped.txt "NEG one byte changed (want !=0)"
cp statement.txt s2.txt; ssh-keygen -q -Y sign -f attacker -n forge-approval-v1 s2.txt 2>/dev/null
v forge-approval-v1 s2.txt.sig statement.txt "NEG signed by an unregistered key (want !=0)"
cp statement.txt s3.txt; ssh-keygen -q -Y sign -f owner -n git s3.txt 2>/dev/null
v forge-approval-v1 s3.txt.sig statement.txt "NEG owner key, other namespace (want !=0)"
v git s3.txt.sig statement.txt "NEG namespace not allowed for the signer (want !=0)"
ssh-keygen -Y verify -f allowed_signers -I someone-else -n forge-approval-v1 -s statement.txt.sig < statement.txt >/dev/null 2>&1; echo "NEG wrong principal (want !=0) exit $?"
