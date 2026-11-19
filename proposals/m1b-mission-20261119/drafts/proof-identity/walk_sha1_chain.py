#!/usr/bin/env python3
"""X4 read-only probe (2026-11-19). Standard library only. Writes only to the path given by --out.

Walks the HOL parent chain recorded INSIDE .dat files, from a root .dat, and checks
on real files on this machine:
  SHA-1(parent .dat file) == hash that the child .dat records for that parent
  SHA-1(parent .dat file) == hash string in the parent Theory.sml next to it (if present)
HOL itself does not recompute SHA-1 at load time (TheoryReader.sml:27-37, Theory.sml:703-723);
this probe does it outside HOL. It finds candidate files by name under the given search roots.
A parent with no candidate whose SHA-1 matches is reported UNRESOLVED (not a failure of HOL;
it means this machine has no file with that content in the searched roots, e.g. heap-only theories).
"""
import argparse, hashlib, json, os, re, sys
from pathlib import Path

HDR = re.compile(r'\(theory\s*\(\s*"([^"]+)"((?:\s*\("[^"]+"\s*\.\s*"[0-9a-f]*"\))*)\s*\)', re.S)
PAR = re.compile(r'\("([^"]+)"\s*\.\s*"([0-9a-f]*)"\)')
SMLH = re.compile(r'hash = "([0-9a-f]+)"')


def sha(path, algo):
    h = hashlib.new(algo)
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def header(path):
    with open(path, 'r', errors='replace') as f:
        head = f.read(200000)
    m = HDR.match(head.lstrip())
    if not m:
        raise ValueError('no theory header in %s' % path)
    return m.group(1), PAR.findall(m.group(2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root_dat')
    ap.add_argument('--search', action='append', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    index = {}
    for r in a.search:
        for dp, dn, fn in os.walk(r):
            for f in fn:
                if f.endswith('Theory.dat'):
                    index.setdefault(f[:-len('Theory.dat')], []).append(os.path.join(dp, f))
    name, parents = header(a.root_dat)
    root_sha1 = sha(a.root_dat, 'sha1')
    seen = {}
    todo = [(name, root_sha1, a.root_dat)]
    nodes = []
    unresolved = []
    mismatch = []
    sha1cache = {}
    while todo:
        thy, want, known = todo.pop()
        if (thy, want) in seen:
            continue
        path = known
        if path is None:
            cands = index.get(thy, [])
            hits = []
            for c in cands:
                if c not in sha1cache:
                    sha1cache[c] = sha(c, 'sha1')
                if sha1cache[c] == want:
                    hits.append(c)
            if not hits:
                unresolved.append({'theory': thy, 'recorded_sha1': want, 'candidates_by_name': len(cands)})
                seen[(thy, want)] = None
                continue
            path = sorted(hits)[0]
        n2, ps = header(path)
        if n2 != thy:
            mismatch.append({'theory': thy, 'path': path, 'stored_name': n2})
        smlp = path[:-4] + '.sml'
        smlhash = None
        if os.path.exists(smlp):
            m = SMLH.search(Path(smlp).read_text(errors='replace'))
            smlhash = m.group(1) if m else None
        if smlhash is not None and smlhash != want:
            mismatch.append({'theory': thy, 'path': smlp, 'sml_hash': smlhash, 'want': want})
        seen[(thy, want)] = path
        nodes.append({'theory': thy, 'sha1': want, 'sha256': sha(path, 'sha256'), 'path': path,
                      'sml_hash_equal': None if smlhash is None else smlhash == want,
                      'parents': [p for p, _ in ps]})
        for p, h in ps:
            if p == 'min' and h == '':
                continue
            todo.append((p, h, None))
    names = {}
    for (t, h) in seen:
        names.setdefault(t, set()).add(h)
    dup = {t: sorted(hs) for t, hs in names.items() if len(hs) > 1}
    res = {'root': a.root_dat, 'root_theory': name, 'root_sha1': root_sha1,
           'resolved_nodes': len(nodes), 'unresolved': unresolved, 'mismatch': mismatch,
           'theories_with_two_hashes': dup, 'nodes': sorted(nodes, key=lambda x: x['theory'])}
    Path(a.out).write_text(json.dumps(res, indent=1) + '\n')
    print(json.dumps({'root_theory': name, 'resolved_nodes': len(nodes), 'unresolved': len(unresolved),
                      'mismatch': len(mismatch), 'theories_with_two_hashes': len(dup)}))
    return 0 if not mismatch and not dup else 1


if __name__ == '__main__':
    sys.exit(main())
