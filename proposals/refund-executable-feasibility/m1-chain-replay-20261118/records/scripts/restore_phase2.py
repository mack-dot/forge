"""Restore sources, runners and support files named in plan-phase2.json (part B). Copies only; no HOL run.
Rules as in restore.py: never overwrite other content; never copy a built theory output.
Usage: python3 -I -B restore_phase2.py"""
from pathlib import Path
import hashlib, json, os, re
ROOT = Path('<HOME>/forge')
OUT = Path(__file__).resolve().parent.parent
plan = json.loads((OUT / 'plan-phase2.json').read_text())['B']
DAFNY = '.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/'
mine = {}
for name in ('restore-record-results.json', 'restore-record-tooltree.json', 'restore-record-phase2.json'):
    if (OUT / name).exists():
        mine.update(json.loads((OUT / name).read_text())['created'])
RECORD = OUT / 'restore-record-phase2.json'
created = json.loads(RECORD.read_text())['created'] if RECORD.exists() else {}
def ok(dest):
    if re.search(r'Theory\.(sig|sml|dat|ui|uo)$|/\.hol/|heap$', dest) or dest.startswith('results/refund-slide-s3-local-20261117'):
        return False
    return (dest.startswith('results/round4-m1-replay-20261118/') or re.match(r'results/refund-[A-Za-z0-9-]+/', dest) is not None
            or re.match(re.escape(DAFNY) + r'forge_[A-Za-z0-9_]+_experiment/[A-Za-z0-9_.]+$', dest) is not None)
def put(dest, data, origin):
    assert ok(dest), 'destination not allowed: ' + dest
    target = ROOT / dest
    if target.exists():
        if target.read_bytes() != data:
            raise SystemExit('REFUSED: ' + dest + ' exists with other content')
        if dest not in mine:
            raise SystemExit('REFUSED: ' + dest + ' existed before this run')
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + '.tmp-restore')
    tmp.write_bytes(data)
    os.replace(tmp, target)
    created[dest] = {'origin': origin, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
for dest, r in sorted(plan['restore'].items()):
    data = (ROOT / r['source']).read_bytes()
    assert hashlib.sha256(data).hexdigest() == r['source_sha256'], dest
    put(dest, data, r['source'])
for s in plan['steps']:
    if s['kind'] == 'holmake':
        put(s['cwd'] + '/Holmakefile', s['holmakefile_text'].encode(), 'recorded Holmakefile: ' + s['holmakefile_origin'])
tmp = Path(str(RECORD) + '.tmp')
tmp.write_text(json.dumps({'count': len(created), 'created': created}, indent=1, sort_keys=True) + '\n')
os.replace(tmp, RECORD)
print('phase 2 files created', len(created))
