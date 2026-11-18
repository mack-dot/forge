"""Listing of built theory files in the pinned tool tree. Read-only on the tool tree.

Usage:
  python3 -I -B listing.py save <out.json>
  python3 -I -B listing.py compare <before.json> <out.json>

save: path, size, mtime_ns and SHA-256 of every *Theory.sig, *Theory.sml and *Theory.dat
      under cakeml/ and HOL/ of the tool tree (Forge folders included if present).
compare: re-reads every file of <before.json>; reports changed or missing files.
         New files are listed separately. This is a file comparison, not a proof check.
"""
from pathlib import Path
import hashlib, json, os, sys

TC = Path('<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104')
SUFFIXES = ('Theory.sig', 'Theory.sml', 'Theory.dat')


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def scan():
    out = {}
    for base in ('cakeml', 'HOL'):
        for root, dirs, files in os.walk(TC / base):
            if '.git' in dirs:
                dirs.remove('.git')
            for name in files:
                if name.endswith(SUFFIXES):
                    p = Path(root) / name
                    st = p.stat()
                    out[str(p.relative_to(TC))] = {'size': st.st_size, 'mtime_ns': st.st_mtime_ns, 'sha256': sha(p)}
    return out


def write(path, data):
    tmp = Path(str(path) + '.tmp')
    tmp.write_text(json.dumps(data, indent=1, sort_keys=True) + '\n')
    os.replace(tmp, path)


mode = sys.argv[1]
if mode == 'save':
    files = scan()
    write(sys.argv[2], {'tool_tree': '<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104',
                        'suffixes': list(SUFFIXES), 'count': len(files), 'files': files})
    print('listed', len(files))
elif mode == 'compare':
    before = json.loads(Path(sys.argv[2]).read_text())['files']
    now = scan()
    changed = sorted(p for p, v in before.items() if p in now and now[p]['sha256'] != v['sha256'])
    touched = sorted(p for p, v in before.items() if p in now and now[p]['sha256'] == v['sha256'] and now[p]['mtime_ns'] != v['mtime_ns'])
    missing = sorted(p for p in before if p not in now)
    new = sorted(p for p in now if p not in before)
    result = {'before_count': len(before), 'now_count': len(now), 'existing_changed': changed,
              'existing_missing': missing, 'existing_same_content_new_mtime': touched, 'new_files': new,
              'statement': ('0 existing theory files changed' if not changed and not missing
                            else str(len(changed) + len(missing)) + ' existing theory files changed or missing')}
    write(sys.argv[3], result)
    print(result['statement'], '| new files', len(new), '| same content, new mtime', len(touched))
    raise SystemExit(0 if not changed and not missing else 1)
