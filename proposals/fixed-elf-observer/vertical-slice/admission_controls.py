"""Exercise the unchanged historical consumer. No signing or admission."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
BASE = Path('/Users/mackianni/forge-stage9-signing-0003/artifacts/r1-signed/x')
OLD = Path('/Users/mackianni/forge/results/campaign-consumer-controls-2026-11-02/attempt-0002')
PYTHON = '/Library/Frameworks/Python.framework/Versions/3.10/bin/python3'
helper = HERE / 'check_bundle.py'
assert not helper.exists()
helper.write_bytes((OLD / 'check_bundle.py').read_bytes())
assert hashlib.sha256(helper.read_bytes()).digest() == hashlib.sha256((OLD / 'check_bundle.py').read_bytes()).digest()
token = subprocess.check_output(['gh', 'auth', 'token', '--hostname', 'github.com', '--user', 'mack-dot'], text=True).strip()
env = dict(os.environ, FORGE_VERIFIER_GITHUB_TOKEN=token)
rows = []
for label, field, value in [('historical-positive', None, None),
                          ('unsigned-execution-upgrade', 'riscv_execution_claimed', True),
                          ('unsigned-correspondence-upgrade', 'concrete_abstract_correspondence', 'established')]:
    candidate = BASE
    if field:
        candidate = HERE / 'fixtures' / label
        candidate.mkdir(parents=True, exist_ok=False)
        for name in ['evidence.json', 'request.json', 'release.sigstore.json', 'packaged.elf', 'package.json']:
            os.link(BASE / name, candidate / name)
        for name in ['proof', 'package-identity']:
            shutil.copytree(BASE / name, candidate / name, copy_function=os.link)
        target = candidate / 'evidence.json'
        payload = json.loads(target.read_text())
        payload[field] = value
        # Unlink first. Never write through a hard link to held evidence.
        target.unlink()
        target.write_text(json.dumps(payload, sort_keys=True, separators=(',', ':'), ensure_ascii=True) + '\n')
    out = HERE / 'consumer-runs' / label
    argv = [PYTHON, '-I', '-S', '-B', str(helper), str(candidate), str(out)]
    start = time.monotonic()
    with (HERE / (label + '.log')).open('wb') as log:
        proc = subprocess.run(argv, env=env, stdout=log, stderr=subprocess.STDOUT)
    result = json.loads((out / 'result.json').read_text())
    expected = 0 if field is None else 1
    row = {'case': label, 'argv': argv, 'actual_exit': proc.returncode,
           'expected_exit': expected, 'result': result, 'wall_seconds': time.monotonic() - start,
           'evidence_sha256': hashlib.sha256((candidate / 'evidence.json').read_bytes()).hexdigest(),
           'signature_sha256': hashlib.sha256((candidate / 'release.sigstore.json').read_bytes()).hexdigest()}
    rows.append(row)
    (HERE / 'consumer-results.json').write_text(json.dumps({'cases': rows, 'admission_executed': False,
        'source_of_authority': 'unchanged historical lock only', 'end_to_end': False}, indent=2) + '\n')
    print(json.dumps(row), flush=True)
    assert proc.returncode == expected and not result.get('setup_error')
    if field:
        assert result.get('reason') == 'EVIDENCE_DIGEST'
    else:
        assert result.get('result') == 'authenticated_provenance'
