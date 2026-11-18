"""Index every recorded case of the U345-U409 packets. Read-only on packets. Planning tool, no HOL run.

Usage: python3 -I -B phase2_index.py            (writes phase2-index.json, prints a summary)
"""
from pathlib import Path
import hashlib, json, os, re

ROOT = Path('<HOME>/forge')
OUT = Path(__file__).resolve().parent.parent
PK = ROOT / 'proposals/refund-executable-feasibility'
H = str(ROOT) + '/'
PACKETS = [  # chain order, with the unsure.md entry numbers named by the memory file
    ('generic-read-local-20261112', 'U345'), ('local-context-20261112', 'U342-U345'), ('initial-stack-code-local-20261112', 'U347'),
    ('arm8-step-local-20261112', 'U348'), ('arm8-compose-local-20261112', 'U348'), ('initializer-machine-local-20261112', 'U349'),
    ('m1-closure-20261112', 'U350-U351'), ('m1-replay-closure-20261112', 'U352-U356'), ('m1-installed-closure-20261112', 'U357-U359'),
    ('m1-exclusion-profile-20261113', 'U360-U363'), ('m1-n1-reachability-20261113', 'U364-U366'), ('m1-p1-lab-closure-20261113', 'U367-U370'),
    ('m1-p2-lab-invariant-20261113', 'U371-U373'), ('m1-lab-exclusion-20261113', 'U374-U376'), ('m1-p3-prefix-20261113', 'U377-U379'),
    ('m1-p3-zero-case-20261113', 'U380'), ('m1-p3-layout-20261113', 'U381'), ('m1-p3-root-20261113', 'U382'), ('m1-p3-replay-20261113', 'U383'),
    ('m1-exact-exclusion-20261114', 'U384'), ('m1-compile-facts-20261114', 'U385'), ('m1-compile-correct-20261114', 'U386'),
    ('m1-source-nonfail-20261115', 'U387'), ('m1-reject-startup-20261115', 'U388'), ('m1-loader-memory-20261115', 'U389'),
    ('m1-memory-domain-20261115', 'U390'), ('m1-residual-20261115', 'U391'), ('m1-env-model-20261116', 'U392'),
    ('m1-fficlose-stub-20261116', 'U393'), ('m1-fficlose-compose-20261116', 'U394'), ('m1-callsite-20261116', 'U395'),
    ('m1-signed-len-20261116', 'U396'), ('m1-ffiwrite-20261116', 'U397'), ('m1-ffiwrite-success-20261116', 'U398'),
    ('m1-write-reach-20261116', 'U399'), ('m1-write-args-20261116', 'U400'), ('m1-closure-audit-20261116', 'U401'),
    ('m1-profile-a-slide0-20261117', 'U404'), ('m1-slide-s1-s2-20261117', 'U405'), ('m1-slide-s3-20261117', 'U407'),
    ('m1-slide-s4-s6-20261117', 'U409'),
]
TAG = re.compile(r'^(?:[A-Z][A-Z0-9_]{3,}\b|Exception|.*\bUncaught exception\b|.*HOL_ERR|.*\bFail\b)')


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def marker_lines(path):
    if not path.is_file():
        return None
    out = []
    for line in path.read_text(errors='replace').splitlines():
        line = re.sub(r'\x1b\[[0-9;]*m', '', line)
        if TAG.match(line) and not re.search(r'took .* to build', line):
            out.append(line[:240])
    return out


phase1 = json.loads((OUT / 'plan.json').read_text())
p1_dirs = {}
for s in phase1['steps']:
    if s['kind'] != 'holmake':
        p1_dirs[s['recorded']['record']] = s['id']
cases = []
for packet, entries in PACKETS:
    for cj in sorted((PK / packet).rglob('command.json')):
        try:
            d = json.loads(cj.read_text())
        except Exception:
            continue
        if not isinstance(d, dict) or not d.get('argv'):
            continue
        argv = [a.replace(H, '') if isinstance(a, str) else a for a in d['argv']]
        rd = cj.parent
        objs = d.get('objects') or {}
        theories = sorted({Path(k).name[:-len('Theory.dat')] for k in objs if k.endswith('Theory.dat')})
        src_argv = argv[-1] if isinstance(argv[-1], str) else ''
        heap = next((a.split('refund-cakeml-20261104/')[-1] for a in argv if isinstance(a, str) and a.startswith('--holstate=')), None)
        case = d.get('case') or rd.name
        markers = d.get('markers')
        if markers is None and 'completion_marker' in d:
            markers = ['completion_marker=' + str(d['completion_marker'])]
        cases.append({
            'packet': packet, 'entries': entries, 'folder': str(rd.parent.relative_to(PK / packet)), 'case': case, 'record': str(cj.relative_to(ROOT)),
            'casedir': str(Path(src_argv).parent) if src_argv.startswith('results/') else None,
            'source': d.get('source'), 'source_sha256': d.get('source_sha256'), 'argv': argv, 'cwd': (d.get('cwd') or '').replace(H, ''),
            'heap': heap, 'actual_exit': d.get('actual_exit'), 'wall_seconds': d.get('wall_seconds'), 'markers': markers,
            'wall_timeout': d.get('wall_timeout'), 'cpu_seconds_limit': d.get('cpu_seconds_limit') or d.get('cpu_seconds_per_process'),
            'theories': theories, 'objects': {Path(k).name: v for k, v in objs.items() if 'Theory.' in k},
            'has_stdout': (rd / 'stdout.log').is_file(), 'has_stderr': (rd / 'stderr.log').is_file(), 'has_proof_sml': (rd / 'proof.sml').is_file(),
            'stdout_marker_lines': marker_lines(rd / 'stdout.log'), 'stderr_tail': (rd / 'stderr.log').read_text(errors='replace').splitlines()[-4:] if (rd / 'stderr.log').is_file() else None,
            'phase1_step': p1_dirs.get(str(cj.relative_to(ROOT))),
            'mtime': cj.stat().st_mtime,
        })
tmp = OUT / 'phase2-index.json.tmp'
tmp.write_text(json.dumps(cases, indent=1) + '\n')
os.replace(tmp, OUT / 'phase2-index.json')
print('cases', len(cases))
by = {}
for c in cases:
    by.setdefault(c['packet'], []).append(c)
for packet, _ in PACKETS:
    cs = by.get(packet, [])
    th = sorted({t for c in cs for t in c['theories']})
    print('%-36s cases %3d  exit0 %3d  phase1 %2d  theories %s' % (packet, len(cs), sum(1 for c in cs if c['actual_exit'] == 0),
                                                              sum(1 for c in cs if c['phase1_step']), th))
