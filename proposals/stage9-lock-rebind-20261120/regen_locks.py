"""Regenerate the two Stage 9 lock files from the tracked tree of a checkout. Usage: regen.py ROOT [--write]"""
import hashlib, json, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1]); write = '--write' in sys.argv
CODE = ('.py', '.pyc', '.pyo', '.pyd', '.so', '.dylib', '.pth', '.v', '.vo', '.vos', '.vok', '.glob', '.c', '.h', '.sh')
ROOTS = ('gate/provenance/', 'scripts/', 'examples/binary/')
IMPL = 'gate/provenance/implementation.lock'; SPEC = 'spec/provenance/spec.lock'
def sha(p): return hashlib.sha256((root / p).read_bytes()).hexdigest()
def dump(d): return (json.dumps(d, indent=2, sort_keys=True) + '\n').encode()
tracked = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'], capture_output=True, check=True).stdout.decode().split('\0')
tracked = [t for t in tracked if t]
impl_raw = (root / IMPL).read_bytes(); spec_raw = (root / SPEC).read_bytes()
impl = json.loads(impl_raw); spec = json.loads(spec_raw)
print('roundtrip impl', dump(impl) == impl_raw, 'spec', dump(spec) == spec_raw)
print('old impl', hashlib.sha256(impl_raw).hexdigest()); print('old spec', hashlib.sha256(spec_raw).hexdigest())
for key in ('contract', 'policy'):
    print('spec', key, spec[key]['path'], sha(spec[key]['path']) == spec[key]['sha256'])
print('== spec.lock locked_existing_files changes')
for item in spec['locked_existing_files']:
    new = sha(item['path'])
    if new != item['sha256']:
        print('  CHG', item['path'], item['sha256'][:12], new[:12]); item['sha256'] = new
new_spec = dump(spec)
if write: (root / SPEC).write_bytes(new_spec)
spec_digest = hashlib.sha256(new_spec).hexdigest()
print('== implementation.lock changes')
files = impl['files']
for path in sorted(files):
    if not (root / path).is_file(): print('  MISSING', path); continue
    new = spec_digest if path == SPEC else sha(path)
    if new != files[path]:
        print('  CHG', path, files[path][:12], new[:12]); files[path] = new
for path in sorted(tracked):
    if path.startswith(ROOTS) and path != IMPL and path not in files and (path.startswith('gate/provenance/') or path.endswith(CODE)):
        files[path] = sha(path); print('  ADD', path, files[path][:12])
if 'gate/ratification.py' not in files:
    files['gate/ratification.py'] = sha('gate/ratification.py'); print('  ADD', 'gate/ratification.py', files['gate/ratification.py'][:12], '(owner-named, not rule-required)')
new_impl = dump(impl)
if write: (root / IMPL).write_bytes(new_impl)
print('entries', len(files)); print('new spec', spec_digest); print('new impl', hashlib.sha256(new_impl).hexdigest())
print('unlocked non-code in roots:', [p for p in tracked if p.startswith(ROOTS) and p != IMPL and p not in files])
