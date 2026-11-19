#!/usr/bin/env python3 -I
"""Z8: negative controls for verify_refund_bindings.py. DRAFT. Changes NO repository file.

Each control builds a fresh MIRROR (copies of only the files that the manifest names, plus the whole proof roots)
under ctl/<name>/, changes ONE thing in the mirror or in a copy of the manifest, and runs the verifier on it.
The Dafny toolchain is read in place (read only; never changed). The baseline mirror must pass (exit 0).
A control passes when the verifier exits 1 AND prints the control's own reason code.
Usage: python3 -I run_binding_controls.py <repo> <scratch-root>"""
import copy
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO, SCR = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
MAN = json.loads((HERE / 'refund_binding_manifest.json').read_text())
CTL = HERE / 'ctl'
LR = 'proposals/m1b-mission-20261119/proofs/linked-refund/inputs'
SC = 'proposals/m1b-mission-20261119/proofs/sink-core'
EXE = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def locators(obj):
    if isinstance(obj, dict):
        if set(obj) == {'locator', 'sha256'} and isinstance(obj['locator'], dict):
            yield obj['locator']
        elif len(obj) == 1 and next(iter(obj)) in ('repo', 'scratch') and isinstance(next(iter(obj.values())), str):
            yield obj
        for v in obj.values():
            yield from locators(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from locators(v)


SRC = {'repo': REPO, 'scratch': SCR}
LIVE = {'proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md', 'proposals/m1-owner-review-20261119/OWNER_DECISIONS.md', 'ROADMAP.md'}
EXTRA = [('scratch', 'm1b/W9/attempts/03/' + f) for f in ('env.txt', 'output.log', 'sha256.txt', 'command.txt')]


def snapshot():
    """One copy of every input at the start. Live documents that the orchestrator edits during the run are re-pinned
    to this snapshot (printed). Every control then copies from the snapshot, never from the live tree."""
    global SRC
    roots = mirror(MAN, 'S0-snapshot')
    for kind, rel in EXTRA:
        (roots[kind] / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SRC[kind] / rel, roots[kind] / rel)
    notes = []

    def walk(o):
        if isinstance(o, dict):
            if set(o) == {'locator', 'sha256'} and isinstance(o['locator'], dict):
                kind, rel = next(iter(o['locator'].items()))
                f = roots.get(kind, Path('/nonexistent')) / rel
                if f.is_file() and sha(f.read_bytes()) != o['sha256']:
                    if rel in LIVE:
                        o['sha256'] = sha(f.read_bytes())
                        notes.append(f'RE-PINNED live document {rel} to the snapshot')
                    else:
                        notes.append(f'NOT re-pinned (changed since the manifest was made): {rel}')
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(MAN)
    for n in sorted(set(notes)):
        print('NOTE ' + n)
    SRC = roots
    return sorted(set(notes))


def mirror(m, name):
    d = CTL / name
    if d.exists():
        shutil.rmtree(d)
    roots = {'repo': d / 'repo', 'scratch': d / 'scratch'}
    src = SRC
    for loc in locators(m):
        kind, rel = next(iter(loc.items()))
        if kind not in src:
            continue
        s, t = src[kind] / rel, roots[kind] / rel
        if s.is_dir():
            if not t.exists():
                shutil.copytree(s, t, symlinks=True)
        elif s.is_file():
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(s, t)
    for p in m['dafny_proofs']:  # whole proof roots (the folder inventory needs every file)
        kind, rel = next(iter(p['root'].items()))
        t = roots[kind] / rel
        if t.exists():
            shutil.rmtree(t)
        shutil.copytree(src[kind] / rel, t, symlinks=True)
    return roots


def flip(path, offset=None):
    b = bytearray(path.read_bytes())
    i = len(b) // 2 if offset is None else offset
    b[i] ^= 0x01
    path.write_bytes(bytes(b))
    return i


def run(m, roots, name):
    mp = CTL / name / 'manifest.json'
    mp.write_text(json.dumps(m, indent=1))
    r = subprocess.run([sys.executable, '-I', str(HERE / 'verify_refund_bindings.py'), str(mp), '--root', str(roots['repo']),
                        '--scratch-root', str(roots['scratch']), '--toolchain-root', str(REPO), '--git-tree', str(REPO)],
                       capture_output=True, text=True)
    (CTL / name / 'verdict.txt').write_text(r.stdout + r.stderr)
    head = r.stdout.split('\n\n', 1)[0]  # the reason lines come before the first blank line
    codes = sorted({l.strip().split(':')[0] for l in head.splitlines() if l.startswith('  ') and ':' in l})
    return r.returncode, codes, r.stdout


def proof(m, pid):
    return next(p for p in m['dafny_proofs'] if p['id'] == pid)


def main():
    if CTL.exists():
        shutil.rmtree(CTL)
    snap_notes = snapshot()
    results, ok = [], True

    def record(name, what, expect_exit, must, exitc, codes, out, extra_check=None):
        nonlocal ok
        good = exitc == expect_exit and all(any(c == mc for c in codes) for mc in must)
        if extra_check is not None:
            good = good and extra_check(out)
        ok = ok and good
        results.append({'control': name, 'what': what, 'expected_exit': expect_exit, 'actual_exit': exitc,
                        'required_codes': must, 'codes': codes, 'as_expected': good})
        print(f'{name:28s} exit {exitc} (expected {expect_exit})  {"OK " if good else "BAD"}  {",".join(codes) or "-"}', flush=True)

    # baseline: the unchanged manifest on the mirror
    m = copy.deepcopy(MAN)
    roots = mirror(m, 'B0-baseline')
    e, c, o = run(m, roots, 'B0-baseline')
    record('B0-baseline', 'unchanged manifest on the mirror', 0, [], e, c, o, lambda out: 'identity verified; proofs NOT re-run' in out)

    def ctl(name, what, must, change_files=None, change_manifest=None, extra_check=None):
        m = copy.deepcopy(MAN)
        if change_manifest:
            change_manifest(m)
        roots = mirror(m, name)
        if change_files:
            change_files(roots)
        e, c, o = run(m, roots, name)
        record(name, what, 1, must, e, c, o, extra_check)

    ctl('C01-linkedrefund-byte', 'one byte changed in LinkedRefund.dfy', ['DIGEST_MISMATCH'],
        lambda r: flip(r['repo'] / LR / 'LinkedRefund.dfy'),
        extra_check=lambda o: 'include_closure: LinkedRefund.dfy' in o)
    ctl('C02-flatcore-byte', 'one byte changed in FlatCore.dfy', ['DIGEST_MISMATCH'],
        lambda r: flip(r['repo'] / LR / 'transport/FlatCore.dfy'),
        extra_check=lambda o: 'include_closure: transport/FlatCore.dfy' in o and 'export.source' in o)
    ctl('C03-library-byte', 'one byte changed in an included library file (Std/Wrappers.dfy)', ['DIGEST_MISMATCH'],
        lambda r: flip(r['repo'] / LR / 'library/Std/Wrappers.dfy'),
        extra_check=lambda o: 'include_closure: library/Std/Wrappers.dfy' in o)
    ctl('C04-exe-in-code-slice', 'one byte changed in the executable at offset 17592 (inside the code slice)',
        ['SLICE_DIGEST', 'WHOLE_FILE_DIGEST'], lambda r: flip(r['repo'] / EXE, 17592))
    ctl('C05-exe-outside-slices', 'one byte changed at offset 152900 (_main C code, outside both slices)', ['WHOLE_FILE_DIGEST'],
        lambda r: flip(r['repo'] / EXE, 152900), extra_check=lambda o: 'SLICE_DIGEST' not in o and 'SYMBOL_OFFSETS' not in o)

    def swap_sink(r):
        shutil.copy2(r['repo'] / SC / 'mutants/N1-drop-fresh-id-check/sink/SinkCore.dfy', r['repo'] / SC / 'inputs/sink/SinkCore.dfy')
    ctl('C06-swapped-sinkcore', 'SinkCore.dfy replaced by the N1 mutant (a real other file)', ['DIGEST_MISMATCH'], swap_sink,
        extra_check=lambda o: 'include_closure: sink/SinkCore.dfy' in o)

    def stale(m):  # point the W9 record at attempt 03 (an older proof file) and re-pin every record file honestly
        run_ = proof(m, 'S3-linked-refund')['runs'][1]
        for k in ('env', 'output', 'sha', 'command'):
            rel = run_['files'][k]['locator']['scratch'].replace('/attempts/04/', '/attempts/03/')
            run_['files'][k] = {'locator': {'scratch': rel}, 'sha256': sha((SRC['scratch'] / rel).read_bytes())}
        del run_['files']['closure_list']
    ctl('C07-stale-log', 'the run record replaced by an older real log (W9 attempt 03), digests re-pinned', ['STALE_RECORD'],
        change_manifest=stale)
    ctl('C08-control-diff-removed', 'negative/N3a-drop-flat-ensures-1.diff deleted', ['MISSING_FILE'],
        lambda r: (r['repo'] / 'proposals/m1b-mission-20261119/proofs/linked-refund/negative/N3a-drop-flat-ensures-1.diff').unlink(),
        extra_check=lambda o: 'controls.N3a-drop-flat-ensures-1' in o)

    def drop_control(m):
        p = proof(m, 'S3-linked-refund')
        p['controls'] = [c for c in p['controls'] if c['name'] != 'N3a-drop-flat-ensures-1']
    ctl('C08b-control-entry-removed', 'the N3a control removed from the manifest list', ['CONTROL_SET'], change_manifest=drop_control)
    ctl('C09-added-file-in-folder', 'a new file transport/Extra.dfy added to the proof folder', ['EXTRA_FILE'],
        lambda r: (r['repo'] / LR / 'transport/Extra.dfy').write_text('module Extra {}\n'))

    def listed_extra(m):
        p = proof(m, 'S3-linked-refund')
        p['include_closure'].append({'path': 'Boundary.dfy', 'sha256': next(x['sha256'] for x in p['folder_files'] if x['path'] == 'Boundary.dfy')})
        p['include_closure'].sort(key=lambda x: x['path'])
        p['include_closure_digest'] = sha(''.join(f'{x["path"]}\t{x["sha256"]}\n' for x in p['include_closure']).encode())
    ctl('C09b-closure-lists-unread-file', 'the manifest closure lists Boundary.dfy, which the include walk does not reach', ['MISSING_FILE'],
        change_manifest=listed_extra, extra_check=lambda o: 'not reached' in o)

    def model_for_test(m):
        next(c for c in m['claims'] if c['link'] == 'X12')['stated_class'] = 'MODEL'
    ctl('C10-model-for-test-row', 'claims X12 (a finite test) as MODEL', ['CLASS_OVERSTATED'], change_manifest=model_for_test)

    def source_for_reported(m):
        next(c for c in m['claims'] if c['link'] == 'E3')['stated_class'] = 'TEST'
    ctl('C10b-test-for-sentence', 'claims E3 (a sentence only) as TEST', ['CLASS_OVERSTATED'], change_manifest=source_for_reported)

    ctl('C11-claim-removed', 'the claim for link S3 removed', ['MISSING_REQUIRED_ENTRY'],
        change_manifest=lambda m: m.__setitem__('claims', [c for c in m['claims'] if c['link'] != 'S3']))
    ctl('C11b-proof-entry-removed', 'the dafny_proofs entry U5a-sink-core removed', ['MISSING_REQUIRED_ENTRY', 'DANGLING_EVIDENCE'],
        change_manifest=lambda m: m.__setitem__('dafny_proofs', [p for p in m['dafny_proofs'] if p['id'] != 'U5a-sink-core']))
    ctl('C11c-unbound-item-removed', 'the unbound item sink.ts removed', ['MISSING_REQUIRED_ENTRY'],
        change_manifest=lambda m: m.__setitem__('unbound', [u for u in m['unbound'] if u['id'] != 'sink.ts']))
    ctl('C11d-executable-removed', 'the executable entry removed', ['MISSING_FIELD'], change_manifest=lambda m: m.pop('executable'))

    # C12 needs the file change before the manifest is re-pinned, so it is built by hand
    name = 'C12-change-and-repin'
    m = copy.deepcopy(MAN)
    roots = mirror(m, name)
    f = roots['repo'] / LR / 'LinkedRefund.dfy'
    flip(f, len(f.read_bytes()) - 2)
    new = sha(f.read_bytes())
    p = proof(m, 'S3-linked-refund')
    for lst in (p['include_closure'], p['folder_files'], p['pins']):
        for x in lst:
            if x['path'] == 'LinkedRefund.dfy':
                x['sha256'] = new
    for k, lst in (('include_closure_digest', 'include_closure'), ('folder_digest', 'folder_files')):
        p[k] = sha(''.join(f'{x["path"]}\t{x["sha256"]}\n' for x in p[lst]).encode())
    e, c, o = run(m, roots, name)
    record(name, 'one byte in LinkedRefund.dfy AND every manifest digest of it re-pinned', 1, ['STALE_RECORD', 'RUNNER_PIN'], e, c, o)

    def stated_level(m):
        next(c for c in m['claims'] if c['link'] == 'S3')['computed_class'] = 'SOURCE_PROOF'
    ctl('C13-producer-stated-level', 'a claim carries a computed_class key', ['PRODUCER_STATED_LEVEL'], change_manifest=stated_level)

    def bad_tool(m):
        m['toolchain']['dafny_tree_digest'] = '0' * 64
    ctl('C14-tool-digest', 'the Dafny tree digest changed in the manifest', ['TOOL_MISMATCH'], change_manifest=bad_tool)

    def bad_argv(m):
        p = proof(m, 'S3-linked-refund')
        p['argv'] = [a for a in p['argv'] if a != '--verify-included-files']
    ctl('C15-argv-weakened', 'argv without --verify-included-files', ['ARGV_MISMATCH'], change_manifest=bad_argv)

    def s3a_break(r):
        flip(r['scratch'] / 'm1b/Y10/S3a-noHex/inputs/library/Std/Strings.dfy', 100)
    ctl('C16-s3a-derivation', 'one byte in the S3a Strings.dfy (scratch)', ['DERIVATION', 'DIGEST_MISMATCH'], s3a_break)

    out = {'snapshot_notes': snap_notes, 'controls': results, 'all_as_expected': ok, 'proofs_re_run': False}
    (HERE / 'controls-result.json').write_text(json.dumps(out, indent=1) + '\n')
    print('ALL CONTROLS AS EXPECTED' if ok else 'SOME CONTROL NOT AS EXPECTED')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
