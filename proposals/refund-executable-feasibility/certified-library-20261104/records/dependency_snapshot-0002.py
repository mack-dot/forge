"""Hash files named by existing HOL loader records; no proof acceptance logic."""
import hashlib
import json
from pathlib import Path

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
tc = root / '.toolchain/experiments/refund-cakeml-20261104'
work = tc / 'cakeml/compiler/dafny/forge_refundCertifiedProg_experiment'

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def expand(path):
    path = path.replace('$(HOLDIR)', str(tc / 'HOL'))
    path = path.replace('$(CAKEMLDIR)', str(tc / 'cakeml'))
    assert '$(' not in path, path
    return Path(path)

def locate(base, extension):
    candidates = [Path(str(base) + extension),
                  base.parent / '.hol/objs' / (base.name + extension)]
    existing = {p.resolve() for p in candidates if p.exists()}
    assert len(existing) == 1, (str(base), extension, sorted(map(str, existing)))
    return existing.pop()

todo = [work / 'forge_refundCertifiedProgTheory']
theories = {}
while todo:
    base = todo.pop()
    name = base.name.removesuffix('Theory')
    if name in theories:
        continue
    uo = locate(base, '.uo')
    implementations = [line for line in uo.read_text().splitlines()
                       if line.endswith('/' + name + 'Theory.sml')]
    assert len(implementations) == 1, (name, implementations)
    base = expand(implementations[0]).with_suffix('')
    assert locate(base, '.uo') == uo
    files = {ext: locate(base, ext) for ext in ('.uo', '.ui', '.sml', '.sig', '.dat')}
    source = base.parent / (name + 'Script.sml')
    if source.exists():
        files['source'] = source.resolve()
    theories[name] = {key: {'path': str(path), 'sha256': sha(path)}
                      for key, path in files.items()}
    for line in uo.read_text().splitlines():
        if not line.endswith('Theory'):
            continue
        todo.append(expand(line))
loaded = {line.split(' ', 1)[1].split(':', 1)[0]
          for line in (out / 'closure-audit.log').read_text().splitlines()
          if line.startswith('FORGE_PARENT ')}
missing = loaded - set(theories)
assert missing <= {'min'}, sorted(missing)
core = [tc / 'HOL/bin/hol', tc / 'cakeml/misc/cakeml-heap']
result = dict(actual_exit=0, loaded_theory_nodes=len(loaded), theories=theories,
              kernel_seed_theories=sorted(missing),
              core_files={str(p): sha(p) for p in core},
              caveat='Byte identities of loader-named proof data. No authenticated producer claim or new upstream-source replay.')
(out / 'dependency-snapshot.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'actual_exit': 0, 'loaded_nodes': len(loaded),
                  'theory_filesets': len(theories), 'kernel_seed_theories': sorted(missing)}))
