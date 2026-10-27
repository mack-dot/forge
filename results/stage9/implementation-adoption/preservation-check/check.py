"""Read-only preservation audit. No proof, signing or deployment execution."""
import hashlib
import json
from pathlib import Path
import tarfile

root = Path(__file__).resolve().parents[4]
records = root / 'results/stage9/implementation-adoption'
before = json.loads((records / 'before-identities.json').read_text())
sha = lambda data: hashlib.sha256(data).hexdigest()
changed = [p for p, entry in before.items() if sha((root / p).read_bytes()) != entry['sha256']]
assert set(changed) == {'ROADMAP.md', 'unsure.md'}, changed
history = before['unsure.md']
assert sha((root / 'unsure.md').read_bytes()[:history['bytes']]) == history['sha256']
manifest = root / 'proposals/provenance-implementation/approval-manifest.json'
assert sha(manifest.read_bytes()) == '5ea08fb8e32d875adc1ab3bb690599602cd622a7c61223f8cc56d4c5bbe972fa'
proposal = json.loads(manifest.read_text())
assert sha((root / 'proposals/provenance-implementation/proposed.diff').read_bytes()) == proposal['patch_sha256']
for item in proposal['changes']:
    data = (root / item['target']).read_bytes()
    assert len(data) == item['bytes'] and sha(data) == item['sha256']
    assert data == (root / item['candidate']).read_bytes()
inputs = json.loads((records / 'receipt-audit-0001/inputs.json').read_text())
for path, expected in inputs['historical_input_sha256'].items():
    assert sha((root / path).read_bytes()) == expected
archive = root / 'results/stage7/published/stage7-complete/records.tar.xz'
assert sha(archive.read_bytes()) == '103288d5e758874b013aacb8150a11f4ceaaff0f4ef71256011efa112fb53686'
log = 'results/stage7/own-proof/attempt-0001/linux/independent-kernel.log'
with tarfile.open(archive, 'r:xz') as source:
    assert sha(source.extractfile(log).read()) == inputs['historical_input_sha256'][log]
result = {
    'result': 'preserved', 'scope': 'file_identity_only', 'prior_files': len(before),
    'prior_files_unchanged': len(before) - len(changed), 'changed_prior_files': changed,
    'prior_protected_unchanged': sum(p == 'spec.lock' or p.startswith(('spec/', 'policy/', 'gate/')) for p in before),
    'approved_additions_exact': len(proposal['changes']), 'historical_unsure_prefix_exact': True,
    'historical_audit_inputs_unchanged': len(inputs['historical_input_sha256']),
    'public_archive_kernel_log_matches': True, 'end_to_end': False,
}
print(json.dumps(result, sort_keys=True))
