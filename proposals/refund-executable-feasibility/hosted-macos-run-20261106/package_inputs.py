from pathlib import Path
import hashlib, io, json, lzma, resource, tarfile

resource.setrlimit(resource.RLIMIT_CPU, (120, 120))
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
PREFIX = Path('.toolchain/experiments/refund-cakeml-20261104')
DIAG = Path('results/refund-native-audit-2026-11-04/attempt-0011/dependency-diagnostic')
sha = lambda b: hashlib.sha256(b).hexdigest()
old = json.loads((ROOT / 'results/refund-environment-recovery-20261106/attempt-0004/preflight.json').read_text())['pins']
files = [
 'HOL/bin/hol', 'HOL/bin/hol.state0', 'HOL/src/num/termination/numheap',
 'HOL/bin/hol.state', 'HOL/examples/l3-machine-code/l3-heap',
 'HOL/examples/l3-machine-code/arm8/step/arm8-heap',
 'HOL/src/HolSat/sat_solvers/minisat/minisat',
 'poly-install/lib/libpolyml.16.dylib',
 'HOL/holproject.toml', 'HOL/examples/l3-machine-code/arm8/step/Holmakefile',
 'HOL/COPYRIGHT', 'HOL/src/HolSat/sat_solvers/minisat/LICENSE', 'polyml/COPYING',
]
bindings = [(TC / f, PREFIX / f) for f in files]
bindings += [(ROOT / DIAG / f, DIAG / f) for f in ('preload.sml', 'proof.sml')]
bindings += [(Path('/opt/homebrew/opt/gmp/lib/libgmp.10.dylib'), PREFIX / 'transport/lib/libgmp.10.dylib')]
bindings += [(Path('/opt/homebrew/opt/gmp') / f, PREFIX / 'transport/licenses' / f) for f in ('COPYING', 'COPYING.LESSERv3')]
entries = []
buffer = io.BytesIO()
with tarfile.open(fileobj=buffer, mode='w', format=tarfile.USTAR_FORMAT) as archive:
 for source, target in bindings:
  data = source.read_bytes()
  expected = old.get(str(source))
  if source.name == 'libgmp.10.dylib': expected = old['/opt/homebrew/opt/gmp/lib/libgmp.dylib']
  if expected is not None: assert sha(data) == expected, str(source)
  mode = 0o500 if source.name in ('hol', 'minisat') or source.suffix == '.dylib' else 0o400
  info = tarfile.TarInfo(str(target)); info.size = len(data); info.mode = mode
  info.uid = info.gid = info.mtime = 0
  archive.addfile(info, io.BytesIO(data))
  entries.append({'path': str(target), 'source': str(source), 'sha256': sha(data), 'bytes': len(data), 'mode': mode,
                  'historical_U320_binding': expected is not None})
assert next(e['sha256'] for e in entries if e['path'].endswith('/proof.sml')) == 'bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108'
archive_bytes = lzma.compress(buffer.getvalue(), preset=1)
(OUT / 'inputs.tar.xz').write_bytes(archive_bytes)
parts = []
for i, offset in enumerate(range(0, len(archive_bytes), 512 * 1024)):
 data = archive_bytes[offset:offset + 512 * 1024]
 name = 'inputs.part-%03d' % i
 (OUT / name).write_bytes(data)
 parts.append({'name': name, 'bytes': len(data), 'sha256': sha(data)})
manifest = {'format': 1, 'installation_root': str(ROOT), 'archive_sha256': sha(archive_bytes),
 'archive_bytes': len(archive_bytes), 'tar_bytes': len(buffer.getvalue()), 'parts': parts, 'files': entries,
 'source_pins': {'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3', 'PolyML': '4557554077078decce4ce5f90da00a713cfc32e4'},
 'scope': 'Exact pinned HOL and parent states, original MiniSat, dependent libraries, unchanged diagnostic, startup configuration and licenses only',
 'trust_limits': ['New parent hashes identify current bytes; not independent bootstrap provenance',
                 'Hosted OS and provider isolation remain environmental assumptions',
                 'Original absolute installation root must be created without privilege; fail otherwise'],
 'end_to_end': False}
(OUT / 'INPUTS.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
print(json.dumps({'files': len(entries), 'original_bytes': sum(e['bytes'] for e in entries),
 'archive_bytes': len(archive_bytes), 'parts': len(parts), 'manifest_sha256': sha((OUT/'INPUTS.json').read_bytes()),
 'historical_hash_matches': sum(e['historical_U320_binding'] for e in entries), 'end_to_end': False}, sort_keys=True))
