"""Check held input identities and use the unchanged published assumption parser.

Metadata audit only. This is not a machine verifier or release authority.
"""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path('/Users/mackianni/forge')
HERE = Path(__file__).resolve().parent
MAIN = Path('/private/tmp/forge-campaign-main-20261102')
OLD = ROOT / 'results/runtime-process-prefix-kernel-2026-11-03/attempt-0001'
expected = json.loads((OLD / 'expected-inputs.json').read_text())
invocation = json.loads((OLD / 'kernel-invocation.json').read_text())['argv']
mounts = {}
for i, arg in enumerate(invocation):
    if arg == '--mount':
        fields = dict(x.split('=', 1) for x in invocation[i + 1].split(',') if '=' in x)
        mounts[fields['target']] = Path(fields['source'])

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

identities = {}
for inside, digest in expected['closure_sha256'].items():
    path = Path(inside)
    candidates = [key for key in mounts if path == Path(key) or Path(key) in path.parents]
    if not candidates:
        # Image-internal standard-library objects are checked in the archived
        # full recursive replay, not inferred from host filesystem paths.
        continue
    key = max(candidates, key=len)
    host = mounts[key] / path.relative_to(key)
    actual = sha(host)
    assert actual == digest, 'HELD_DEPENDENCY_CHANGED:' + str(host)
    identities[str(host)] = actual
for source, digest in expected['source_sha256'].items():
    assert sha(Path(source)) == digest, 'HELD_SOURCE_CHANGED:' + source

policy = json.loads((MAIN / 'policy/provenance.json').read_text())
assert policy['end_to_end'] is False
assert policy['deployment']['riscv_execution_claimed'] is False
assert policy['deployment']['scope'] == 'deployed_file_identity'
base = Path('/Users/mackianni/forge-stage9-signing-0003/artifacts/r1-signed/x')
assert sha(base / 'packaged.elf') == policy['release_artifact']['sha256']
prior = ROOT / 'results/campaign-consumer-controls-2026-11-02/attempt-0002'
historical = json.loads((prior / 'runs/positive-after/result.json').read_text())
assert historical['result'] == 'authenticated_provenance'
fresh = json.loads((HERE / 'consumer-runs/historical-positive/result.json').read_text())
assert fresh['result'] == 'authenticated_provenance' and fresh['signature_exit_code'] == 0
# Decode only the exact bundle just authenticated by the unchanged consumer.
# This code does not implement signature verification.
bundle = json.loads((base / 'release.sigstore.json').read_text())
statement = json.loads(base64.b64decode(bundle['dsseEnvelope']['payload'], validate=True))
assert sha(base / 'evidence.json') == statement['predicate']['canonical_evidence_sha256']

sys.path[:0] = [str(ROOT / '.toolchain/stage7/upstream/tools'), str(ROOT / '.toolchain/stage7/pydeps')]
from oft.check import wrapper_assumptions, allowed_axioms
actual = wrapper_assumptions((HERE / 'positive.log').read_text())
allowed = allowed_axioms('/', str(ROOT / '.toolchain/stage7/upstream/toolchain/allowed-axioms.txt'))
assert actual and not actual - allowed
assert actual <= set(json.loads((OLD / 'kernel-output/actual-assumptions.json').read_text()))
positive = json.loads((HERE / 'positive-command.json').read_text())
negative = json.loads((HERE / 'negative-command.json').read_text())
assert positive['actual_exit'] == 0 and negative['actual_exit'] == 1
assert 'Z.gcd 1071 462 = 22%Z' in (HERE / 'negative.log').read_text()
result = {'actual_exit': 0, 'held_host_dependency_objects_checked': len(identities),
          'held_source_count_checked': len(expected['source_sha256']),
          'held_dependency_sha256': identities, 'assumptions': sorted(actual),
          'assumptions_subset_of_previous_full_kernel': True,
          'source_sha256': sha(HERE / 'positive/Behavior.v'),
          'object_sha256': sha(HERE / 'positive/Behavior.vo'),
          'old_policy_execution_scope': policy['deployment']['scope'],
          'old_policy_claims_riscv_execution': False,
          'new_independent_recursive_kernel': 'NOT RUN',
          'accepted_claim': False, 'end_to_end': False}
(HERE / 'identity-audit.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'held_dependency_sha256'}))
