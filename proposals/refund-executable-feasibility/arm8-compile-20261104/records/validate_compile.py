"""Check byte identities and saved numeric results; do not judge proofs."""
import hashlib
import json
from pathlib import Path

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


first = json.loads((OUT / 'compile-0001/command.json').read_text())
repeat = json.loads((OUT / 'compile-repeat/command.json').read_text())
readback = json.loads((OUT / 'compile-repeat-readback.json').read_text())
assert first['actual_exit'] == repeat['actual_exit'] == readback['actual_exit'] == 0
assert first['status'] == repeat['status'] == 'FINISHED'
assert first['source_sha256'] == repeat['source_sha256'] == readback['source_sha256']
assert first['object_sha256'] == repeat['object_sha256'] == readback['object_sha256']
assert len(first['object_sha256']) == 6
work = Path(repeat['cwd'])
for folder in (OUT / 'compile-0001', OUT / 'compile-repeat', work):
    assert sha(folder / 'forge_refundArm8CompileScript.sml') == first['source_sha256']
    assert sha(folder / 'refund.S') == first['assembly_sha256'] == repeat['assembly_sha256']
    objects = folder / ('.hol/objs' if folder == work else 'objects')
    for name, expected in first['object_sha256'].items():
        assert sha(objects / name) == expected, str(objects / name)
for folder in (OUT / 'compile-0001', OUT / 'compile-repeat'):
    text = (folder / 'theory.log').read_text()
    for marker in ('FORGE_THEOREM refund_arm8_compiled', 'FORGE_HYPOTHESES 0',
                   'LENGTH code = 130436', 'LENGTH data = 2531'):
        assert marker in text, (str(folder), marker)
baseline = json.loads((ROOT / 'results/refund-caller-2026-11-04/attempt-0001/'
                       'original-inputs-postflight.json').read_text())['input_sha256']
for name, expected in baseline.items():
    assert sha(ROOT / name) == expected, name
assert sha(ROOT / 'FORGE_MISSION.md') == '7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c'
record = {
    'actual_exit': 0,
    'saved_compile_exits': [first['actual_exit'], repeat['actual_exit']],
    'matching_exports': len(first['object_sha256']),
    'assembly_sha256': first['assembly_sha256'],
    'frozen_inputs_checked': len(baseline),
    'scope': 'Saved results and identity only; no new proof or native execution.',
    'end_to_end': False,
}
target = OUT / 'compile-validation.json'
assert not target.exists()
target.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
