"""Verify upstream observer provenance with the existing GitHub CLI."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

OUT = Path(__file__).resolve().parent
STORE = Path('/Users/mackianni/forge/.toolchain/experiments/refund-entry-lldb-23.1.5')
expected = json.loads((OUT / 'expected-producer.json').read_text())
downloads = json.loads((OUT / 'download.json').read_text())
assert len(downloads) == 2 and all(x['actual_exit'] == 0 and x['identity_matches'] for x in downloads)
artifact = STORE / 'LLVM-23.1.5-macOS-ARM64.tar.zst'
bundle = STORE / (artifact.name + '.jsonl')
tool = shutil.which('gh')
assert tool
argv = [tool, 'attestation', 'verify', str(artifact), '--bundle', str(bundle),
        '--repo', expected['expected_repository'],
        '--cert-identity', expected['certificate_identity'],
        '--source-ref', expected['source_ref'],
        '--source-digest', expected['commit'],
        '--signer-digest', expected['commit'],
        '--deny-self-hosted-runners', '--format', 'json']
assert not (OUT / 'verification.json').exists()
started = time.monotonic()
with (OUT / 'verified-attestation.json').open('wb') as stdout, (OUT / 'verification.stderr').open('wb') as stderr:
    child = subprocess.run(argv, stdout=stdout, stderr=stderr)
record = {'argv': argv, 'actual_exit': child.returncode,
          'wall_seconds': time.monotonic() - started,
          'github_cli_sha256': hashlib.sha256(Path(tool).read_bytes()).hexdigest(),
          'expectations': expected, 'observer_execution': 'NOT RUN',
          'forge_release_authentication': 'NOT_ESTABLISHED', 'end_to_end': False}
(OUT / 'verification.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
print((OUT / 'verification.stderr').read_text(), flush=True)
raise SystemExit(child.returncode)
