"""Prepare a separate exact diff. Never edit or publish PR #30."""
import difflib
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from reproduce import export

REPO = Path('/Users/mackianni/forge-linux')
HERE = Path(__file__).resolve().parent
OUT = Path('/private/tmp/forge-receipt-auth-repair-20261102')
export(REPO, OUT)
original = {}


def replace(path, old, new):
    target = OUT / path
    before = target.read_text()
    original.setdefault(path, before)
    assert before.count(old) == 1, (path, old)
    target.write_text(before.replace(old, new))


replace('gate/obligations.py',
        'from common import PIN_FILES, ROOT, Rejected, canonical, digest, host_profile, pin_file, read_json\n',
        'from common import PIN_FILES, ROOT, Rejected, canonical, digest, host_profile, pin_file, read_json\n'
        'from provenance.common import files as provenance_files, Rejected as ProvenanceRejected\n')
replace('gate/obligations.py', '\ndef run(names, tree,',
        '\n' + (HERE / 'session_support.py.inc').read_text() + '\n\ndef run(names, tree,')
replace('gate/obligations.py', '''        cached = cache / (key + '.json') if key else None
        if cached is not None and cached.is_file():
            previous = read_json(cached)
            if previous.get('result') == 'established' and previous.get('cache_key') == key:
                records[name] = dict(previous, reused=True)
                continue
''', '''        previous = reused_receipt(name, key, tree, trusted_root, verified, cache) if key else None
        if previous is not None:
            records[name] = previous
            continue
''')
replace('gate/obligations.py', '''                records[name] = dict(result, reused=False, cache_key=key)
    return records
''', '''                records[name] = dict(result, reused=False, cache_key=key)
    remember_fresh(records, cache, tree, work)
    return records
''')
replace('gate/obligations.py', '''    """Cache established, freshly run records. Call only after the verification tree re-hashed identically."""
    for record in records.values():
        if record.get('result') == 'established' and not record.get('reused') and record.get('cache_key'):
            cache.mkdir(parents=True, exist_ok=True)
            (cache / (record['cache_key'] + '.json')).write_bytes(canonical(record))
''', '''    """Authorize only real fresh results after complete coverage and input integrity checks."""
    for record in records.values():
        if record.get('result') == 'established' and record.get('reused') is False and record.get('cache_key'):
            slot = receipt_slot(cache, record['cache_key'])
            anchor = _PENDING_RECEIPTS.pop(slot, None)
            if (anchor is None or canonical(record) != anchor['receipt']
                    or output_files(anchor['tree'], anchor['work']) != anchor['files']):
                raise Rejected('CACHE_PRODUCER: fresh result lacks intact producer evidence')
            cache.mkdir(parents=True, exist_ok=True)
            path = cache / (record['cache_key'] + '.json')
            # Existing data is never overwritten or promoted into trusted state.
            with path.open('xb') as stream:
                stream.write(anchor['receipt'])
            _TRUSTED_RECEIPTS[slot] = anchor
''')
replace('gate/incremental.py', 'import os\n', 'import os\nimport platform\n')
replace('gate/incremental.py',
        'def run_obligations(candidate, entries, proposed_before, trusted_before, approval, affected, changed, work, operation):',
        'def run_obligations(candidate, entries, proposed_before, trusted_before, approval, affected, changed, work, operation, cache):')
replace('gate/incremental.py',
        "               'javascript_pins': digest((ROOT / pin_file('javascript')).read_bytes())}",
        "               'javascript_pins': digest((ROOT / pin_file('javascript')).read_bytes()),\n"
        "               'runtime': {'system': platform.system(), 'machine': platform.machine(),\n"
        "                           'python_version': platform.python_version(),\n"
        "                           'python_sha256': digest(Path(sys.executable).read_bytes())}}")
replace('gate/incremental.py', "                              ROOT / 'build/obligation-cache')", '                              cache)')
replace('gate/incremental.py', "    obligations.store(records, ROOT / 'build/obligation-cache')\n", '')
replace('gate/incremental.py', "def check(candidate, output, work, operation, profile='local'):\n", 
        "def check(candidate, output, work, operation, profile='local', *, cache=None):\n"
        "    # New CLI processes never restore receipt authority from disk. A trusted\n"
        "    # in-process caller may share a cache; only live producer entries authorize hits.\n"
        "    cache = cache if cache is not None else work / 'obligation-cache'\n")
replace('gate/incremental.py', '                              affected, changed, work, operation)\n',
        '                              affected, changed, work, operation, cache)\n')
replace('gate/incremental.py', "    staged_evidence = work / 'accepted-evidence.json'\n", 
        "    obligations.store(records, cache)\n"
        "    staged_evidence = work / 'accepted-evidence.json'\n")
lock_path = 'gate/provenance/implementation.lock'
original[lock_path] = (OUT / lock_path).read_text()
lock = json.loads(original[lock_path])
for path in ('gate/obligations.py', 'gate/incremental.py'):
    lock['files'][path] = hashlib.sha256((OUT / path).read_bytes()).hexdigest()
(OUT / lock_path).write_text(json.dumps(lock, indent=2, sort_keys=True) + '\n')
patch = ''.join(''.join(difflib.unified_diff(original[p].splitlines(True), (OUT / p).read_text().splitlines(True),
              fromfile='a/' + p, tofile='b/' + p)) for p in original)
(HERE / 'repair.patch').write_text(patch)
print(json.dumps({'prepared_checkout': str(OUT), 'files': list(original),
                  'patch_sha256': hashlib.sha256(patch.encode()).hexdigest(),
                  'implementation_lock_sha256': hashlib.sha256((OUT / lock_path).read_bytes()).hexdigest()}))
