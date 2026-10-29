import json, os, sys
sys.path.insert(0, sys.argv[1] + "/gate/provenance")
from pathlib import Path
import common
from common import Records, Rejected, context, repository_identity
policy, _, impl = context(sys.argv[2])
mode = sys.argv[3]
seen = {}
def fake_fetch(url, records, label, *, token_name=None):
    s = policy["signer"]
    return json.dumps({"full_name": s["repository"], "id": s["repository_id"],
                       "owner": {"id": s["owner_id"]}, "private": mode == "private"}).encode()
common.fetch = fake_fetch
real_run = Records.run
def spy(self, argv, label, **kw):
    if label == "source-fetch":
        env = kw.get("env") or {}
        seen["token_var"] = "FORGE_VERIFIER_GITHUB_TOKEN" in env
        seen["header"] = env.get("GIT_CONFIG_KEY_0") == "http.https://github.com/.extraheader"
        raise Rejected("STOP_BEFORE_NETWORK")
    return real_run(self, argv, label, **kw)
Records.run = spy
os.environ["FORGE_VERIFIER_GITHUB_TOKEN"] = "github_pat_" + "B" * 82
try:
    repository_identity(policy, impl, "0" * 40, Records(Path(sys.argv[4])))
except Rejected as error:
    print(error.reason, json.dumps(seen, sort_keys=True))
