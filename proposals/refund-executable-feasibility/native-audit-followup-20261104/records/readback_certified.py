"""Independent saved-record check of the new library candidate; no proof replay."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / 'results/refund-certified-library-2026-11-04/attempt-0001'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

records = []
for name in ['proof-library-0005', 'proof-repeat']:
    work = SOURCE / name
    r = json.loads((work / 'command.json').read_text())
    assert r['actual_exit'] == 0
    assert sha(work / 'forge_refundCertifiedProgScript.sml') == r['source_sha256']
    assert all(sha(work / 'objects' / n) == d for n, d in r['object_sha256'].items())
    records.append(r)
assert records[0]['source_sha256'] == records[1]['source_sha256']
assert records[0]['object_sha256'] == records[1]['object_sha256']
assert sha(SOURCE / 'forge_refundCertifiedProgScript.sml') == records[0]['source_sha256']

controls = []
for name, theorem in [('altered-amount', 'refund_fields_original_method'),
                      ('swapped-wrapper-ids', 'refund_verified_spec')]:
    work = SOURCE / ('proof-' + name)
    r = json.loads((work / 'command.json').read_text())
    assert r['actual_exit'] == 1
    assert sha(work / 'forge_refundCertifiedProgScript.sml') == r['source_sha256']
    log = (work / 'theory.log').read_text()
    assert re.findall(r'Tactic failure proving "([^"]+)"', log) == [theorem]
    assert r['object_sha256'] == {}
    controls.append(dict(case=name, actual_exit=1, failing_theorem=theorem,
                         source_sha256=r['source_sha256'], log_sha256=sha(work / 'theory.log')))

log = (SOURCE / 'closure-audit.log').read_text()
nodes = re.findall(r'^FORGE_PARENT (.+)$', log, re.M)
tags = re.findall(r'^FORGE_TAG (.+)$', log, re.M)
axioms = re.findall(r'^FORGE_CLOSURE_AXIOM (.+)$', log, re.M)
assert len(tags) == 7
assert all('oracles=DISK_THM axioms= hypotheses=0' in tag for tag in tags)
assert set(axioms) == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
assert 'FORGE_STATEMENT refund_fields_v_thm ⊢ (STRING_TYPE --> STRING_TYPE --> INT --> INT --> BOOL --> BOOL --> BOOL -->' in log
assert 'FORGE_STATEMENT refund_verified_spec ⊢ app p refund_verified_v' in log
baseline = json.loads((OUT.parent / 'attempt-0001/baseline.json').read_text())
assert all(sha(ROOT / n) == d for n, d in baseline['protected'].items())
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
journal = (ROOT / 'unsure.md').read_bytes()
assert hashlib.sha256(journal[:baseline['unsure_bytes']]).hexdigest() == baseline['unsure_prefix_sha256']
r = dict(actual_exit=0, classification='SAVED_RECORD_IDENTITY_AND_STATEMENT_REVIEW_ONLY',
         source_sha256=records[0]['source_sha256'], positive_repeat_actual_exits=[0, 0],
         identical_exports=records[0]['object_sha256'], controls=controls,
         recorded_dependency_nodes=len(nodes), recorded_tags=tags, recorded_foundation_axioms=axioms,
         independent_kernel_replay='NOT_RUN', protected_paths_unchanged=len(baseline['protected']),
         prior_journal_bytes_unchanged=baseline['unsure_bytes'],
         integration_obligation='Candidate returns nested PAIR_TYPE; old raw method and wrapper use a flat six-field tuple. Actual wrapper must preserve all six field positions with a checked adapter or nested pattern.',
         native_refund_execution='NOT_RUN', end_to_end=False)
(OUT / 'certified-library-readback.json').write_text(json.dumps(r, indent=2) + '\n')
print(json.dumps({k: v for k, v in r.items() if k not in ['identical_exports', 'recorded_tags']}))
