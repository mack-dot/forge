"""Unit-level table: approval.authorize + incremental.protected_manifest on synthetic trees. No Dafny, no git."""
import sys, os, json, shutil, hashlib, subprocess, traceback
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'base', 'gate'))
from pathlib import Path
import approval, incremental
from common import Rejected
sha = lambda b: hashlib.sha256(b).hexdigest()
W = Path(HERE) / 'u2'
shutil.rmtree(W, ignore_errors=True)
PROP = 'proposals/p.md'
n = [0]

def tree(files):
    n[0] += 1
    root = W / ('t%03d' % n[0])
    for name, data in files.items():
        p = root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data if isinstance(data, bytes) else data.encode())
    return root

BASEFILES = {'gate/gate.py': 'old gate\n', 'gate/incremental.py': 'inc\n', 'gate/approval.py': 'app\n', 'gate/common.py': 'c\n',
             'gate/approvals/a.json': '{}\n', 'gate/provenance/common.py': 'p\n', 'toolchain/pins.json': '{"x":1}\n',
             'policy/tiers.yaml': 'p\n', 'spec/LedgerSpec.dfy': 's\n', 'spec.lock': '{}\n', 'schemas/s.json': '{}\n',
             'governance/ratifications/0001.json': '{}\n', 'bugs/off_by_one.dfy': 'bug\n', PROP: 'proposal text\n'}

def outcome(fn):
    try:
        value = fn()
        return 'RETURNED ' + ('None' if value is None else 'RATIFICATION(%s)' % ','.join(sorted(value.get('files', value.get('approved_inputs', {})))))
    except Rejected as e:
        return 'exit1 Rejected: ' + str(e)[:70]
    except (OSError, ValueError, KeyError, RuntimeError, ImportError) as e:
        return 'exit2 %s: %s' % (type(e).__name__, str(e)[:50])
    except Exception as e:
        return 'UNCAUGHT(traceback, exit1) %s: %s' % (type(e).__name__, str(e)[:50])

def case(label, cand_edit, record=None, mutate=None, trusted_extra=None, raw_record=None, record_name='governance/gate-ratifications/r.json', expect_ratified=False):
    """trusted = BASEFILES (+record made for the candidate); candidate = trusted copy + cand_edit."""
    files = dict(BASEFILES)
    files.update(trusted_extra or {})
    probe_t, probe_c = tree(files), None
    cfiles = dict(files)
    for k, v in cand_edit.items():
        if v is None: cfiles.pop(k, None)
        else: cfiles[k] = v
    probe_c = tree(cfiles)
    a, b = incremental.protected_manifest(probe_t), incremental.protected_manifest(probe_c)
    rec = None
    if record or raw_record is not None:
        rec = {'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False,
               'files': {k: {'old_sha256': a.get(k), 'new_sha256': b.get(k)} for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)},
               'controls': [], 'proposal': PROP, 'proposal_sha256': sha(files[PROP].encode())}
        if mutate: rec = mutate(rec) or rec
        text = raw_record if raw_record is not None else json.dumps(rec)
        files[record_name] = text; cfiles[record_name] = text      # the candidate is based on the trusted base
    t, c = tree(files), tree(cfiles)
    def run():
        tm, cm = incremental.protected_manifest(t), incremental.protected_manifest(c)
        return approval.authorize(t, tm, cm, c)
    result = outcome(run)
    flag = ''
    if result.startswith('RETURNED RATIFICATION') != expect_ratified: flag = '   <<<<<< UNEXPECTED'
    if result.startswith('UNCAUGHT'): flag += '   <<<<<< UNCAUGHT CLASS'
    print('%-78s -> %s%s' % (label, result, flag))

G = {'gate/gate.py': 'new gate\n'}
case('01 valid record, gate/gate.py changed', G, record=True, expect_ratified=True)
case('02 no record', G)
case('03 record in a subfolder', G, record=True, record_name='governance/gate-ratifications/sub/r.json')
case('04 record with suffix .JSON', G, record=True, record_name='governance/gate-ratifications/r.JSON')
case('05 record in governance/ (wrong folder)', G, record=True, record_name='governance/r.json')
case('06 record in governance/ratifications/', G, record=True, record_name='governance/ratifications/r.json')
case('07 record folder spelled Gate-Ratifications (this FS ignores case)', G, record=True, record_name='governance/Gate-Ratifications/r.json', expect_ratified=(W / 'x').parent.joinpath('..').exists() and os.path.exists(str(W).upper()))
for i, raw in enumerate(['[]', '"x"', '0', 'null', 'true', '{}', '{"files": []}', '{"files": {}}', '[{"files": {}}]']):
    case('08.%d raw record %s' % (i, raw), G, raw_record=raw)
case('09 invalid JSON record', G, raw_record='{not json')
case('10 duplicate key in record', G, raw_record='{"tier": 0, "tier": 0}')
case('11 invalid UTF-8 record', G, raw_record=b'\xff\xfe{}'.decode('latin-1').encode('latin-1').decode('latin-1'))
for label, m in [('tier "0"', lambda r: r.update(tier='0')), ('tier 0.0', lambda r: r.update(tier=0.0)), ('tier false', lambda r: r.update(tier=False)),
                 ('tier true', lambda r: r.update(tier=True)), ('tier null', lambda r: r.update(tier=None)), ('tier 1', lambda r: r.update(tier=1)),
                 ('tier -0', lambda r: r.update(tier=-0)),
                 ('decision approved_as_written', lambda r: r.update(decision='approved_as_written')), ('end_to_end null', lambda r: r.update(end_to_end=None)),
                 ('end_to_end 0', lambda r: r.update(end_to_end=0)), ('end_to_end true', lambda r: r.update(end_to_end=True)),
                 ('files value list', lambda r: r['files'].update({'gate/gate.py': ['a', 'b']})),
                 ('files value extra key', lambda r: r['files']['gate/gate.py'].update(x=1)),
                 ('files new digest uppercase', lambda r: r['files']['gate/gate.py'].update(new_sha256=r['files']['gate/gate.py']['new_sha256'].upper())),
                 ('files new digest null', lambda r: r['files']['gate/gate.py'].update(new_sha256=None)),
                 ('files old digest wrong', lambda r: r['files']['gate/gate.py'].update(old_sha256='0' * 64)),
                 ('files extra name', lambda r: r['files'].update({'gate/zz.py': {'old_sha256': None, 'new_sha256': '0' * 64}})),
                 ('files key ./gate/gate.py', lambda r: r.update(files={'./gate/gate.py': r['files']['gate/gate.py']})),
                 ('files key gate//gate.py', lambda r: r.update(files={'gate//gate.py': r['files']['gate/gate.py']})),
                 ('files key gate/gate.py/', lambda r: r.update(files={'gate/gate.py/': r['files']['gate/gate.py']})),
                 ('files key gate/../gate/gate.py', lambda r: r.update(files={'gate/../gate/gate.py': r['files']['gate/gate.py']})),
                 ('files key Gate/gate.py', lambda r: r.update(files={'Gate/gate.py': r['files']['gate/gate.py']})),
                 ('files key gate/Gate.py', lambda r: r.update(files={'gate/Gate.py': r['files']['gate/gate.py']})),
                 ('controls missing', lambda r: r.pop('controls')), ('controls null', lambda r: r.update(controls=None)), ('controls dict', lambda r: r.update(controls={})),
                 ('control not dict', lambda r: r.update(controls=['bugs/x.dfy'])),
                 ('control path NUL', lambda r: r.update(controls=[{'path': 'bugs/x\x00.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control path newline', lambda r: r.update(controls=[{'path': 'bugs/x\n.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control path nested', lambda r: r.update(controls=[{'path': 'bugs/a/x.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control path ..', lambda r: r.update(controls=[{'path': 'bugs/..x.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control path int', lambda r: r.update(controls=[{'path': 5, 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control sha int', lambda r: r.update(controls=[{'path': 'bugs/x.dfy', 'sha256': 5, 'expect': 'rejected'}])),
                 ('control sha 64 hex + newline', lambda r: r.update(controls=[{'path': 'bugs/x.dfy', 'sha256': '0' * 64 + '\n', 'expect': 'rejected'}])),
                 ('control expect accepted', lambda r: r.update(controls=[{'path': 'bugs/x.dfy', 'sha256': '0' * 64, 'expect': 'accepted'}])),
                 ('control replaces trusted bug', lambda r: r.update(controls=[{'path': 'bugs/off_by_one.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control replaces trusted bug, other case', lambda r: r.update(controls=[{'path': 'bugs/OFF_BY_ONE.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}])),
                 ('control duplicate', lambda r: r.update(controls=[{'path': 'bugs/x.dfy', 'sha256': '0' * 64, 'expect': 'rejected'}] * 2)),
                 ('proposal missing', lambda r: r.pop('proposal')), ('proposal list', lambda r: r.update(proposal=['a'])), ('proposal empty', lambda r: r.update(proposal='')),
                 ('proposal absolute', lambda r: r.update(proposal='/etc/hosts')), ('proposal ..', lambda r: r.update(proposal='proposals/../../x')),
                 ('proposal NUL', lambda r: r.update(proposal='proposals/p\x00.md')), ('proposal directory', lambda r: r.update(proposal='proposals')),
                 ('proposal not present', lambda r: r.update(proposal='proposals/none.md')),
                 ('proposal_sha256 wrong', lambda r: r.update(proposal_sha256='0' * 64)), ('proposal_sha256 missing', lambda r: r.pop('proposal_sha256')),
                 ('proposal_sha256 null', lambda r: r.update(proposal_sha256=None))]:
    case('12 ' + label, G, record=True, mutate=m)
print('--- scope: one changed protected file each, with a record that names it exactly')
for name in ['gate/incremental.py', 'gate/approval.py', 'gate/common.py', 'gate/approvals/a.json', 'gate/provenance/common.py', 'policy/tiers.yaml',
             'spec/LedgerSpec.dfy', 'spec.lock', 'schemas/s.json', 'governance/ratifications/0001.json']:
    case('13 change ' + name, {name: 'changed\n'}, record=True)
for name in ['gate/Incremental.py', 'gate/APPROVAL.PY', 'gate/ratification.py', 'gate/coverage.py', 'gate/obligations.py', 'gate/pr_check.py', 'gate/post_pr_report.py',
             'gate/approvals/new.json', 'gate/Approvals2/new.json', 'gate/provenance/new.py', 'governance/gate-ratifications/planted.json', 'governance/new.txt',
             '.github/workflows/w.yml', 'AGENTS.md', 'package.json', 'scripts/build_model.py', 'governance/spec.lock', 'gate/spec.lock']:
    case('14 add ' + name, {name: 'added\n'}, record=True, expect_ratified=(name == 'gate/spec.lock'))
for name in ['gate/common/__init__.py', 'gate/approval/__init__.py', 'gate/common.so', 'gate/json.py', 'gate/obligationſ.py', 'gate/ratiﬁcation.py',
             'toolchain/install_ci.py', 'gate/core.py', 'gate/dependencies.py', 'gate/backends/dafny.py', 'gate/backends/__init__.py']:
    case('15 add (record names it) ' + name, {name: 'added\n'}, record=True, expect_ratified=True)
case('16 delete gate/gate.py with record', {'gate/gate.py': None}, record=True, expect_ratified=True)
case('17 delete gate/approval.py with record', {'gate/approval.py': None}, record=True)
case('18 gate change + policy change with record', {'gate/gate.py': 'new\n', 'policy/tiers.yaml': 'x\n'}, record=True)
case('19 gate change + record edited by candidate only', {'gate/gate.py': 'new\n', 'governance/gate-ratifications/r.json': '{}'}, record=True)
case('20 gate change, candidate removes the record', {'gate/gate.py': 'new\n', 'governance/gate-ratifications/r.json': None}, record=True)
shutil.rmtree(W, ignore_errors=True)
