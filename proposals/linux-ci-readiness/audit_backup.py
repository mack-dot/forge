"""Exercise the existing backup checker against real copies; no transport mocks."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile

ROOT = Path('/Users/mackianni/forge')
SOURCE = Path('/Users/mackianni/forge-backups')
CHECK = ROOT / 'results/ops-readiness/integration-2026-11-02/check_archives.py'
COPY = ROOT / 'results/ops-readiness/integration-2026-11-02/copy_backup.sh'
OUT = ROOT / 'results/ops-readiness/review-2026-11-02'
scratch = Path(tempfile.mkdtemp(prefix='forge-backup-audit-', dir='/private/tmp'))
rows = []
for case in ('intact', 'truncated-archive', 'altered-manifest'):
    target = scratch / case
    target.mkdir()
    for kind in ('raw', 'sanitized'):
        for suffix in ('.tar.xz', '.manifest.json'):
            name = 'forge-records-' + kind + '-2026-11-01' + suffix
            shutil.copyfile(SOURCE / name, target / name)
    if case == 'truncated-archive':
        file = target / 'forge-records-raw-2026-11-01.tar.xz'
        file.write_bytes(file.read_bytes()[:-1])
    elif case == 'altered-manifest':
        file = target / 'forge-records-sanitized-2026-11-01.manifest.json'
        file.write_bytes(file.read_bytes() + b' ')
    command = ['python3', '-I', '-S', '-B', str(CHECK), str(target)]
    p = subprocess.run(command, capture_output=True, text=True)
    rows.append({'case': case, 'command': command, 'exit_code': p.returncode,
                 'output': json.loads(p.stdout), 'expected_exit': 0 if case == 'intact' else 1})
    (OUT / 'backup-controls.json').write_text(json.dumps(rows, indent=2) + '\n')
    assert p.returncode == rows[-1]['expected_exit']
    if case != 'intact':
        assert 'digest mismatch' in rows[-1]['output']['error']
p = subprocess.run(['sh', str(COPY), '-invalid-host'], capture_output=True, text=True)
rows.append({'case': 'invalid-host-before-network', 'exit_code': p.returncode, 'stderr': p.stderr})
(OUT / 'backup-controls.json').write_text(json.dumps(rows, indent=2) + '\n')
assert p.returncode == 2 and 'configured SSH host' in p.stderr
print('Intact copies: 0. Truncated archive: 1. Altered manifest: 1. Invalid host: 2. No SSH connection attempted.')
