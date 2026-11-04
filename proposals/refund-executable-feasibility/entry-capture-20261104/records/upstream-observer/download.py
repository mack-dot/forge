"""Fetch a pinned upstream observer archive; do not install or execute it."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

OUT = Path(__file__).resolve().parent
STORE = Path('/Users/mackianni/forge/.toolchain/experiments/refund-entry-lldb-23.1.5')
STORE.mkdir(exist_ok=False)
selection = json.loads((OUT / 'selection.json').read_text())
names = ['LLVM-23.1.5-macOS-ARM64.tar.zst.jsonl',
         'LLVM-23.1.5-macOS-ARM64.tar.zst']
records = []
for name in names:
    asset = next(a for a in selection['assets'] if a['name'] == name)
    assert asset['browser_download_url'].startswith(
        'https://github.com/llvm/llvm-project/releases/download/llvmorg-23.1.5/')
    assert asset['digest'].startswith('sha256:')
    path = STORE / name
    argv = ['/usr/bin/curl', '--fail', '--location', '--silent', '--show-error',
            '--output', str(path), asset['browser_download_url']]
    started = time.monotonic()
    with (OUT / (name + '.download.log')).open('wb') as log:
        child = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    record = {'argv': argv, 'actual_exit': child.returncode,
              'wall_seconds': time.monotonic() - started, 'expected': asset}
    if child.returncode == 0:
        with path.open('rb') as stream:
            digest = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        record.update(bytes=path.stat().st_size, sha256=digest.hexdigest())
        record['identity_matches'] = (record['bytes'] == asset['size'] and
                                      'sha256:' + record['sha256'] == asset['digest'])
    records.append(record)
    (OUT / 'download.json').write_text(json.dumps(records, indent=2) + '\n')
    print(json.dumps(record), flush=True)
    if child.returncode != 0:
        raise SystemExit(child.returncode)
    assert record['identity_matches']
