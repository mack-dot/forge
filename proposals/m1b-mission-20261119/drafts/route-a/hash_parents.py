"""Dependency hashes for one HOL case (Route A, worker X7 draft; not run).

Usage:
  python3 -I -B hash_parents.py <deps.txt> <case-folder> [<extra .sig/.sml path> ...] > <case-folder>.hashes.json

<deps.txt> has one path per line, in the style of deps-e4.txt / deps-imp4.txt (a preload .sml file, then
<dir>/<Name>Theory.sig and <dir>/<Name>Theory.sml pairs). HOL resolves <dir>/<file> to <dir>/.hol/objs/<file>
when <dir>/<file> does not exist (run_case.py line 51). For every theory it hashes the .sig, the .sml AND the .dat
(the .dat holds the stored terms; run_case.py does not hash it). It also hashes the theory objects the case
produced (<case-folder>/.hol/objs/*), the heap and the hol binary named in <case-folder>/invocation.json.
It only reads files. It prints JSON. Exit 0 if every listed file exists, 2 otherwise.
"""
from pathlib import Path
import hashlib, json, sys


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


def resolve(p):
    p = Path(p)
    if p.is_file():
        return p
    alt = p.parent / '.hol/objs' / p.name
    return alt if alt.is_file() else None


def theory_files(p):
    """For <dir>/<Name>Theory.sig or .sml give the .sig, .sml and .dat that HOL actually reads."""
    name = Path(p).name
    for ext in ('.sig', '.sml'):
        if name.endswith('Theory' + ext):
            stem = name[: -len(ext)]
            out = []
            for e in ('.sig', '.sml', '.dat'):
                r = resolve(Path(p).parent / (stem + e))
                out.append((stem + e, r))
            return stem, out
    return None, [(name, resolve(p))]


def main():
    deps = [l.strip() for l in Path(sys.argv[1]).read_text().splitlines() if l.strip()]
    deps += sys.argv[3:]
    case = Path(sys.argv[2])
    seen, parents, missing = set(), [], []
    for d in deps:
        stem, files = theory_files(d)
        key = stem or d
        if key in seen:
            continue
        seen.add(key)
        entry = {'listed': d, 'theory': stem, 'files': {}}
        for name, r in files:
            if r is None:
                missing.append(str(Path(d).parent / name))
                entry['files'][name] = None
            else:
                entry['files'][name] = {'path': str(r), 'sha256': sha(r)}
        parents.append(entry)
    produced = {}
    objs = case / '.hol/objs'
    if objs.is_dir():
        produced = {str(p.relative_to(case)): sha(p) for p in sorted(objs.iterdir()) if p.is_file()}
    tools = {}
    inv = case / 'invocation.json'
    if inv.is_file():
        record = json.loads(inv.read_text())
        argv = record.get('argv', [])
        if argv:
            tools['hol'] = {'path': argv[0], 'sha256': sha(argv[0]) if Path(argv[0]).is_file() else None}
        for a in argv:
            if a.startswith('--holstate='):
                h = a.split('=', 1)[1]
                tools['heap'] = {'path': h, 'sha256': sha(h) if Path(h).is_file() else None}
    for name in ('stdout.log', 'stderr.log', 'proof.sml', 'command.json'):
        if (case / name).is_file():
            tools[name] = sha(case / name)
    # Statements exactly as HOL printed them: the lines after "CHECKED <name>" that start with the turnstile
    # or with white space (thm_to_string continuation lines). Also the definition lines and every marker line.
    checked, markers = {}, []
    log = case / 'stdout.log'
    if log.is_file():
        lines = log.read_text(errors='replace').splitlines()
        i = 0
        while i < len(lines):
            line = lines[i]
            if line.startswith(('LEMMA_FAILED', 'CONTROL_OK', 'UNEXPECTED_CONTROL_ACCEPTANCE', 'TEXT_CHECK', 'CLOSURE_AXIOM',
                                'STORED_', 'EXACT_COMPLETE', 'IMPORTED', 'IMPORT_MISMATCH', 'PREMISE_FOUND')):
                markers.append(line)
            if line.startswith('CHECKED ') or line.startswith('DEFINITION '):
                name = line.split(' ', 1)[1] if line.startswith('CHECKED ') else 'DEFINITION@' + str(i + 1)
                body = [] if line.startswith('CHECKED ') else [line[len('DEFINITION '):]]
                j = i + 1
                while j < len(lines) and (lines[j].startswith('⊢') or lines[j][:1] in (' ', '\t')):
                    body.append(lines[j])
                    j += 1
                checked[name] = '\n'.join(body)
                i = j
                continue
            i += 1
    print(json.dumps({'case': str(case), 'parent_theories': len([p for p in parents if p['theory']]),
                      'parents': parents, 'produced_objects': produced, 'tools_and_logs': tools,
                      'statements': checked, 'markers': markers, 'missing': missing}, indent=1, ensure_ascii=False))
    raise SystemExit(0 if not missing else 2)


if __name__ == '__main__':
    main()
