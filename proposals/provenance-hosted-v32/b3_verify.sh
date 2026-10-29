#!/bin/bash
# B3 for v3.2: bounded authenticated verification. The owner runs this in their
# own terminal; the coding agent never runs it with a real credential.
#
#   b3_verify.sh CHECKOUT /ABSOLUTE/NEW/OUTPUT [KEYCHAIN_SERVICE [UNDERSCOPED_SERVICE]]
#
# CHECKOUT: a fresh, clean clone of test/v32-candidate at the commit below.
# Tokens come from the macOS Keychain, live only in shell variables and one
# verifier process environment, never in argv, and are searched for in every
# record afterwards (patterns through a pipe). What a pass shows: the API
# identity was read with the token, and the source bytes match the commit hash.
# On a public repository git fetch needs no token, so git authentication itself
# is not tested. Exit 0: every case matched and no credential copy was found.
# Exit 3: a Keychain item is missing or does not have the GitHub token format
# (stopped before any network request; only counts are printed, never the value).
set -euo pipefail
CHECKOUT=$1 OUT=$2 SERVICE=${3:-forge-verifier-readonly} UNDERSCOPED=${4:-}
LOCK=be23ec85ec2d9652bd1c87f6870c0d7130862af169319af24975b941ac3b5f57
COMMIT=edb729a8bea278a77a1bd33451859958a4b7b3e4
MAIN=3670d688f90acb9c00b1af36fa4cdc36d1bdb361
PY=$(command -v python3)
[[ $OUT == /* ]] || { echo "B3: OUTPUT must be an absolute path"; exit 2; }
mkdir "$OUT" || { echo "B3: OUTPUT must not exist"; exit 2; }
mkdir "$OUT/tmp" "$OUT/home"
# Read credentials first, so no prompt falls between the checks and the run.
shape() {  # $1 service, $2 value: the verifier's token format, checked in this shell
  local value=$2 pattern='^[A-Za-z0-9_]{20,255}$' bad blank prefix=other
  [[ $value =~ $pattern ]] && return 0
  bad=${value//[A-Za-z0-9_]/} blank=${value//[^[:space:]]/}
  [[ $value == github_pat_* ]] && prefix=github_pat_
  [[ $value == ghp_* ]] && prefix=ghp_
  echo "B3: Keychain item $1 is not a GitHub token: length ${#value}, prefix $prefix," \
       "${#bad} characters outside A-Z a-z 0-9 _, ${#blank} of them blank"
  exit 3
}
TOKEN=$(/usr/bin/security find-generic-password -s "$SERVICE" -w) || { echo "B3: no Keychain item $SERVICE"; exit 3; }
shape "$SERVICE" "$TOKEN"
WEAK=""
if [[ -n $UNDERSCOPED ]]; then
  WEAK=$(/usr/bin/security find-generic-password -s "$UNDERSCOPED" -w) || { echo "B3: no Keychain item $UNDERSCOPED"; exit 3; }
  shape "$UNDERSCOPED" "$WEAK"
fi
scan() {
  local status=0
  /usr/bin/grep -rqF -f <(printf '%s\n' "$TOKEN" "$(printf 'x-access-token:%s' "$TOKEN" | /usr/bin/base64)" \
    ${WEAK:+"$WEAK"} ${WEAK:+"$(printf 'x-access-token:%s' "$WEAK" | /usr/bin/base64)"}) "$OUT" || status=$?
  case $status in
    1) echo "B3: no credential copy in records" ;;
    0) echo "B3: CREDENTIAL FOUND IN RECORDS"; STATUS=4 ;;
    *) echo "B3: leak scan failed (grep status $status)"; STATUS=4 ;;
  esac
  unset TOKEN WEAK
}
STATUS=6
trap 'scan; echo "B3: interrupted"; exit 130' INT TERM
cd "$CHECKOUT"
[[ $(/usr/bin/git rev-parse HEAD) == "$COMMIT" && -z $(/usr/bin/git status --porcelain --ignored) ]] \
  || { echo "B3: checkout is not a clean clone at $COMMIT"; scan; exit 2; }
"$PY" -I -S -B -c 'import hashlib, json, sys
lock = open("gate/provenance/implementation.lock", "rb").read()
if hashlib.sha256(lock).hexdigest() != sys.argv[1]: sys.exit("IMPLEMENTATION_LOCK")
boot = open("gate/provenance/bootstrap.py", "rb").read()
if hashlib.sha256(boot).hexdigest() != json.loads(lock)["files"]["gate/provenance/bootstrap.py"]: sys.exit("BOOTSTRAP_BYTES")' "$LOCK" \
  || { scan; exit 2; }
"$PY" -I -S -B gate/provenance/bootstrap.py --implementation-sha256 "$LOCK" --check || { scan; exit 2; }
set +e
(
  # A clean environment: nothing from the owner's shell reaches Python or git.
  for name in $(compgen -e); do unset "$name"; done
  export HOME="$OUT/home" TMPDIR="$OUT/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 \
         GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
  FORGE_B3_TOKEN=$TOKEN FORGE_B3_UNDERSCOPED=$WEAK exec "$PY" -I -S -B -X pycache_prefix="$OUT/pycache" -c '
import json, os, sys
sys.path.append("gate/provenance")
from pathlib import Path
from common import Records, Rejected, context, repository_identity
commit, main, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
policy, _, impl = context(sys.argv[4])
real, weak = os.environ.pop("FORGE_B3_TOKEN"), os.environ.pop("FORGE_B3_UNDERSCOPED")
failures = 0
def report(name, expected, result):
    global failures
    verdict = "NOT_DISCRIMINATING" if expected is None else ("PASS" if result == expected else "FAIL")
    failures += verdict == "FAIL"
    print(json.dumps({"case": name, "expected": expected, "result": result, "verdict": verdict}), flush=True)
def case(name, expected, pol, token, target):
    os.environ.pop("FORGE_VERIFIER_GITHUB_TOKEN", None)
    if token is not None:
        os.environ["FORGE_VERIFIER_GITHUB_TOKEN"] = token
    try:
        repository_identity(pol, impl, target, Records(out / name)); result = "ACCEPTED"
    except Rejected as error:
        result = error.reason
    report(name, expected, result)
def store(name):
    # None when the case stopped before it made a store: then this check fails.
    path = next((out / name).glob("*source-store.invocation.json"), None)
    return path and json.loads(path.read_text())["argv"][-1]
wrong = json.loads(json.dumps(policy)); wrong["signer"]["repository_id"] = 1
case("api-authenticated-exact-commit", "ACCEPTED", policy, real, commit)
case("repeat-exact-commit", "ACCEPTED", policy, real, commit)
first, second = store("api-authenticated-exact-commit"), store("repeat-exact-commit")
report("repeat-used-a-fresh-store", True, None not in (first, second) and first != second)
case("repository-identity-substitution", "REPOSITORY_IDENTITY", wrong, real, commit)
case("wrong-commit-main", "IMPLEMENTATION_LOCK_AT_COMMIT", policy, real, main)
case("nonexistent-commit", "COMMAND_FAILED:source-fetch", policy, real, "f" * 40)
case("bogus-token", "GITHUB_HTTP_STATUS:401", policy, "github_pat_" + "A" * 82, commit)
case("no-token", "GITHUB_TOKEN_REQUIRED:FORGE_VERIFIER_GITHUB_TOKEN", policy, None, commit)
if weak:
    # Public repositories are readable with any valid token: this cannot fail.
    case("under-scoped-token", None, policy, weak, commit)
sys.exit(5 if failures else 0)
' "$COMMIT" "$MAIN" "$OUT" "$LOCK"
) | /usr/bin/tee "$OUT/results.jsonl"
STATUS=${PIPESTATUS[0]}
set -e
trap - INT TERM
scan
echo "B3: exit $STATUS"
exit "$STATUS"
