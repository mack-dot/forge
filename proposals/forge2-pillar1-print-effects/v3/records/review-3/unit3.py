"""Unit-level: record-path cases with the record placed explicitly on each side. No Dafny, no git."""
import sys, os, json, shutil, hashlib
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'base', 'gate'))
from pathlib import Path
import approval, incremental
from common import Rejected
sha = lambda b: hashlib.sha256(b).hexdigest()
W = Path(HERE) / 'u3'
shutil.rmtree(W, ignore_errors=True)
PROP = 'proposals/p.md'
R = 'governance/gate-ratifications/r.json'
BASE = {'gate/gate.py': b'old gate\n', 'gate/approval.py': b'app\n', 'toolchain/pins.json': b'{}\n', 'spec.lock': b'{}\n',
        'governance/ratifications/0001.json': b'{}\n', PROP: b'proposal text\n'}
n = [0]
def tree(files, links=None):
    n[0] += 1
    root = W / ('t%03d' % n[0])
    root.mkdir(parents=True)
    for name, data in files.items():
        p = root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    for name, target in (links or {}).items():
        p = root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        if p.exists() and p.is_dir(): shutil.rmtree(p)
        os.symlink(target, p)
    return root
def record(old, new, names=('gate/gate.py',)):
    return json.dumps({'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False, 'controls': [],
                       'files': {k: {'old_sha256': sha(old[k]) if k in old else None, 'new_sha256': sha(new[k]) if k in new else None} for k in names},
                       'proposal': PROP, 'proposal_sha256': sha(BASE[PROP])}).encode()
def run(label, tfiles, cfiles, tlinks=None, clinks=None):
    t, c = tree(tfiles, tlinks), tree(cfiles, clinks)
    try:
        v = approval.authorize(t, incremental.protected_manifest(t), incremental.protected_manifest(c), c)
        out = 'RETURNED ' + ('None (no protected change)' if v is None else 'RATIFICATION')
    except Rejected as e: out = 'exit1 Rejected: ' + str(e)[:95]
    except (OSError, ValueError, KeyError, RuntimeError, ImportError) as e: out = 'exit2 %s: %s' % (type(e).__name__, str(e)[:60])
    except Exception as e: out = 'UNCAUGHT %s: %s' % (type(e).__name__, str(e)[:60])
    print('%-74s -> %s' % (label, out))
NEW = dict(BASE); NEW['gate/gate.py'] = b'new gate\n'
rec = record(BASE, NEW)
run('a record on BOTH sides (as after the owner merge)', {**BASE, R: rec}, {**NEW, R: rec})
run('b record ONLY in the candidate', BASE, {**NEW, R: rec})
run('c record in trusted, candidate REMOVED it', {**BASE, R: rec}, NEW)
run('d record in trusted, candidate EDITED it', {**BASE, R: rec}, {**NEW, R: rec + b' '})
run('e candidate only adds a record, no other change', BASE, {**BASE, R: rec})
run('f candidate only adds governance/x.txt', BASE, {**BASE, 'governance/x.txt': b'x'})
run('g candidate deletes governance/ratifications/0001.json', BASE, {k: v for k, v in BASE.items() if k != 'governance/ratifications/0001.json'})
run('h candidate governance is a FILE', BASE, {**{k: v for k, v in BASE.items() if not k.startswith('governance/')}, 'governance': b'x'})
run('i candidate governance is a LINK to its own folder', BASE, {**{k: v for k, v in BASE.items() if not k.startswith('governance/')}, 'gov2/gate-ratifications/r.json': rec}, clinks={'governance': 'gov2'})
run('j candidate record folder is a LINK', BASE, {**NEW, 'other/r.json': rec}, clinks={'governance/gate-ratifications': '../other'})
run('k trusted record is a LINK to a trusted file', {**BASE, 'other/r.json': rec}, {**NEW, 'other/r.json': rec}, tlinks={R: '../../other/r.json'}, clinks={R: '../../other/r.json'})
run('l trusted record folder is a FILE', {**BASE, 'governance/gate-ratifications': b'x'}, {**NEW, 'governance/gate-ratifications': b'x'})
run('m trusted has a directory named x.json in the folder', {**BASE, 'governance/gate-ratifications/x.json/y': b'{}', R: rec}, {**NEW, 'governance/gate-ratifications/x.json/y': b'{}', R: rec})
run('n candidate adds record under GOVERNANCE/ (this FS ignores case)', BASE, {**NEW, 'GOVERNANCE/gate-ratifications/r.json': rec})
run('o trusted without governance at all; candidate adds record', {k: v for k, v in BASE.items() if not k.startswith('governance/')}, {**{k: v for k, v in NEW.items() if not k.startswith('governance/')}, R: rec})
run('p two records: malformed-shape first, valid second', {**BASE, 'governance/gate-ratifications/a.json': b'[]', R: rec}, {**NEW, 'governance/gate-ratifications/a.json': b'[]', R: rec})
run('q record names gate.py; candidate also adds gate/__pycache__/x.pyc', {**BASE, R: rec}, {**NEW, R: rec, 'gate/__pycache__/common.cpython-310.pyc': b'pyc'})
shutil.rmtree(W, ignore_errors=True)
