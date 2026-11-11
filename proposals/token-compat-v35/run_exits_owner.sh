#!/bin/bash
# Stage 9 official EXITs under v3.5. The OWNER runs this in the owner's own terminal.
# It reads the read-only verifier token without echo and never prints, stores or
# passes it as an argument. Usage: run_exits_owner.sh CLONE_AT_C
set -u
CLONE=$1
LOCK=a177cb07e3d1efa3f70c4af62cd707c6a1f2e1df62da8b4c53e23300a7a22be1
unset GITHUB_TOKEN GH_TOKEN GITHUB_ACTIONS ACTIONS_ID_TOKEN_REQUEST_URL
cd "$CLONE" || exit 2
[ -f .toolchain/stage9/controller.json ] || { echo "EXIT_SETUP_NOT_ESTABLISHED: no controller.json"; exit 1; }
read -rs -p "Read-only verifier token (input hidden): " FORGE_VERIFIER_GITHUB_TOKEN; echo
export FORGE_VERIFIER_GITHUB_TOKEN
OUT=results/stage9/exit-run-$(date -u +%Y%m%dT%H%M%SZ).txt
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "head $(git rev-parse HEAD)"
  python3 -I -S -B -c 'import hashlib, json, sys
lock = open("gate/provenance/implementation.lock", "rb").read()
if hashlib.sha256(lock).hexdigest() != sys.argv[1]: sys.exit("IMPLEMENTATION_LOCK")
boot = open("gate/provenance/bootstrap.py", "rb").read()
if hashlib.sha256(boot).hexdigest() != json.loads(lock)["files"]["gate/provenance/bootstrap.py"]: sys.exit("BOOTSTRAP_BYTES")' "$LOCK"
  echo "inline check exit $?"
  python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 "$LOCK" --check; echo "bootstrap check exit $?"
  for c in valid-bundle unsigned wrong-signer wrong-digest wrong-policy deployed-identity; do
    python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 "$LOCK" -- scripts/exit_stage_9.py --case "$c" 2>&1 | tail -3
    echo "EXIT $c exit ${PIPESTATUS[0]}"
  done
  echo "files containing the verifier token: $(grep -rlF -- "$FORGE_VERIFIER_GITHUB_TOKEN" results/stage9 .toolchain/stage9 2>/dev/null | wc -l | tr -d ' ')"
} 2>&1 | tee "$OUT"
unset FORGE_VERIFIER_GITHUB_TOKEN
echo "Saved: $CLONE/$OUT"
