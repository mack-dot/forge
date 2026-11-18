"""Restore sources, runners and dependency lists named in plan.json. Copies only; no HOL run.

Usage: python3 -I -B restore.py results|tooltree

Rules: never overwrite an existing file with other content; never copy a built theory output;
write only under results/round4-m1-replay-20261118, results/refund-* folders that this run creates,
and new forge_*_experiment folders of the tool tree. Each created file is recorded with its SHA-256.
"""
from pathlib import Path
import hashlib, json, os, re, shutil, sys

ROOT = Path('<HOME>/forge')
OUT = Path(__file__).resolve().parent.parent
plan = json.loads((OUT / 'plan.json').read_text())
S3OLD = 'results/refund-slide-s3-local-20261117/attempt-0001'
S3NEW = 'results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001'
DAFNY = '.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/'
which = sys.argv[1]
RECORD = OUT / ('restore-record-' + which + '.json')
created = json.loads(RECORD.read_text())['created'] if RECORD.exists() else {}


def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()


def allowed(dest):
    if re.search(r'Theory\.(sig|sml|dat|ui|uo)$|/\.hol/|heap$', dest):
        return False
    if dest.startswith('results/refund-slide-s3-local-20261117'):
        return False
    if which == 'results':
        return dest.startswith('results/round4-m1-replay-20261118/') or re.match(r'results/refund-[A-Za-z0-9-]+/', dest) is not None
    return re.match(re.escape(DAFNY) + r'forge_[A-Za-z0-9_]+_experiment/[A-Za-z0-9_.]+$', dest) is not None


def put(dest, data, origin):
    if dest.startswith('results/') != (which == 'results'):
        return
    assert allowed(dest), 'destination not allowed: ' + dest
    target = ROOT / dest
    if target.exists():
        if target.read_bytes() != data:
            raise SystemExit('REFUSED: ' + dest + ' exists with other content')
        if dest not in created:
            raise SystemExit('REFUSED: ' + dest + ' existed before this run')
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + '.tmp-restore')
    tmp.write_bytes(data)
    os.replace(tmp, target)
    created[dest] = {'origin': origin, 'sha256': sha_bytes(data), 'bytes': len(data)}


for dest, r in sorted(plan['restore'].items()):
    data = (ROOT / r['source']).read_bytes()
    assert sha_bytes(data) == r['source_sha256'], dest
    origin = r['source']
    if dest in plan.get('restore_text_maps', {}):
        data = data.decode().replace(S3OLD, S3NEW).encode()
        origin += ' (lines path-mapped: ' + S3OLD + ' -> ' + S3NEW + ')'
    put(dest, data, origin)
for dest, g in sorted(plan.get('restore_generated', {}).items()):
    text = ''.join((ROOT / g['from']).read_text().splitlines(True)[:g['first_lines']])
    assert sha_bytes(text.encode()) == g['sha256'], dest
    put(dest, text.encode(), 'generated: first %d lines of %s; SHA-256 equals the recorded input hash' % (g['first_lines'], g['from']))
for dest, text in sorted(plan.get('extra_new_files', {}).items()):
    put(dest, text.encode(), 'recorded Holmakefile text (compiled-behavior-20261104/records/behavior-0001/Holmakefile)')
for s in plan['steps']:
    if s['kind'] == 'holmake':
        put(s['cwd'] + '/Holmakefile', s['holmakefile_text'].encode(), 'recorded Holmakefile text: ' + s['holmakefile_origin'])
if which == 'results':
    image = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
    digest = sha_bytes(image.read_bytes())
    assert digest == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8', 'executable SHA-256 differs: ' + digest
tmp = Path(str(RECORD) + '.tmp')
tmp.write_text(json.dumps({'rule': plan['restore_rule'], 'count': len(created), 'created': created}, indent=1, sort_keys=True) + '\n')
os.replace(tmp, RECORD)
print(which, 'files in record', len(created))
