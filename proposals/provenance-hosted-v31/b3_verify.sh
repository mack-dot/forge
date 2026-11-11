#!/bin/bash
# B3: bounded authenticated verification. The owner runs this in their own
# terminal; the coding agent never runs it with a real credential.
#
#   b3_verify.sh CHECKOUT COMMIT OUTPUT [KEYCHAIN_SERVICE [UNDERSCOPED_SERVICE]]
#
# CHECKOUT is a clean clone of test/v31-candidate at COMMIT (v3.1 applied).
# The token is read from the macOS Keychain into this shell, passed only to the
# verifier process, never printed, and searched for in every record afterwards.
set -euo pipefail
CHECKOUT=$1 COMMIT=$2 OUT=$3 SERVICE=${4:-forge-verifier-readonly} UNDERSCOPED=${5:-}
LOCK=6f3aafe60b45897a31b6fbdc90ece068ccd4d96904bf2d43241320755b6e4510
[[ $COMMIT =~ ^[0-9a-f]{40}$ ]] || { echo "B3: COMMIT must be 40 lowercase hex"; exit 2; }
[[ ! -e $OUT ]] || { echo "B3: OUTPUT must not exist"; exit 2; }
cd "$CHECKOUT"
[[ $(git rev-parse HEAD) == "$COMMIT" && -z $(git status --porcelain --ignored -- gate scripts examples) ]] \
  || { echo "B3: checkout is not exactly $COMMIT"; exit 2; }
python3 -I -S -B -c 'import hashlib, json, sys
lock = open("gate/provenance/implementation.lock", "rb").read()
if hashlib.sha256(lock).hexdigest() != sys.argv[1]: sys.exit("IMPLEMENTATION_LOCK")
boot = open("gate/provenance/bootstrap.py", "rb").read()
if hashlib.sha256(boot).hexdigest() != json.loads(lock)["files"]["gate/provenance/bootstrap.py"]: sys.exit("BOOTSTRAP_BYTES")' "$LOCK"
python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 "$LOCK" --check
mkdir -p "$OUT"
TOKEN=$(security find-generic-password -s "$SERVICE" -w) || { echo "B3: no Keychain item $SERVICE"; exit 3; }
WEAK=""
if [[ -n $UNDERSCOPED ]]; then WEAK=$(security find-generic-password -s "$UNDERSCOPED" -w) || { echo "B3: no Keychain item $UNDERSCOPED"; exit 3; }; fi
# The verifier: positive check, then identity substitution and a bogus token.
FORGE_VERIFIER_GITHUB_TOKEN=$TOKEN FORGE_B3_UNDERSCOPED=$WEAK python3 -I -S -B -X pycache_prefix="$OUT/pycache" -c '
import json, os, sys
sys.path.append("gate/provenance")
from pathlib import Path
from common import Records, Rejected, context, repository_identity
commit, out = sys.argv[1], Path(sys.argv[2])
policy, _, impl = context(sys.argv[3])
def case(name, pol, token):
    os.environ["FORGE_VERIFIER_GITHUB_TOKEN"] = token
    try:
        repository_identity(pol, impl, commit, Records(out / name)); result = "ACCEPTED"
    except Rejected as error:
        result = error.reason
    print(json.dumps({"case": name, "result": result}), flush=True)
real = os.environ["FORGE_VERIFIER_GITHUB_TOKEN"]
case("authenticated-exact-commit", policy, real)
wrong = json.loads(json.dumps(policy)); wrong["signer"]["repository_id"] = 1
case("repository-identity-substitution", wrong, real)
case("bogus-token", policy, "github_pat_" + "A" * 82)
if os.environ.get("FORGE_B3_UNDERSCOPED"):
    case("under-scoped-token", policy, os.environ["FORGE_B3_UNDERSCOPED"])
' "$COMMIT" "$OUT" "$LOCK" | tee "$OUT/results.jsonl"
B64=$(printf 'x-access-token:%s' "$TOKEN" | base64)
LEAK=(-e "$TOKEN" -e "$B64"); [[ -n $WEAK ]] && LEAK+=(-e "$WEAK")
if grep -rqF "${LEAK[@]}" "$OUT"; then echo "B3: TOKEN FOUND IN RECORDS"; STATUS=4; else echo "B3: no token copy in records"; STATUS=0; fi
unset TOKEN B64 WEAK LEAK
exit $STATUS
