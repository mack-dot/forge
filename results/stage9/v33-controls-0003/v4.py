import json, shutil, subprocess, sys
from pathlib import Path
code, lock, proof, request_path, mode, out = sys.argv[1:7]
sys.path.insert(0, code + "/gate/provenance")
import common
from common import Records, Rejected, canonical, context, read, write
import release
def gh_fetch(url, records, label, *, token_name=None):
    # Read-only GitHub API through gh; the verifier itself uses its own token.
    child = subprocess.run(["gh", "api", url.replace("https://api.github.com/", "")], capture_output=True)
    if child.returncode:
        raise Rejected("GITHUB_HTTP_STATUS:gh-api-error")
    return child.stdout
common.fetch = gh_fetch
policy, lk, _ = context(lock)
request = read(Path(request_path))
copy = Path(out) / "proof"
shutil.copytree(proof, copy)
receipt = read(copy / "receipt.json")
new = dict(request, challenge="ab" * 32)
receipt["challenge"] = new["challenge"]
if mode.startswith("candidate"):
    run = mode.split(":")[1]
    receipt["execution"] = {"run_id": run, "run_attempt": mode.split(":")[2]}
write(copy / "receipt.json", receipt)
try:
    release.validate_receipt(copy, policy, lk, new)
    if mode.startswith("candidate"):
        common.run_identity(policy, new, receipt["execution"], Records(Path(out) / "records"))
    print("ACCEPTED")
except Rejected as error:
    print(error.reason)
