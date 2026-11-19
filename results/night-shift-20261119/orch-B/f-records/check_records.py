#!/usr/bin/env python3
"""Check PROOF_RECORDS.json against a checkout (Python 3 standard library only).

WITHOUT --rerun this checks IDENTITY ONLY: it recomputes every closure digest, every copy-against-original
comparison and every stored log/CSV/report digest, and compares them with the record. It does NOT run Dafny
and it does NOT check that any theorem is correct.

WITH --rerun it also calls reproduce_dafny_proofs.py (which runs Dafny through the lock script) into a new
output folder and compares status, exit code and obligation count per proof.

  python3 -I check_records.py [--records PROOF_RECORDS.json] [--checkout DIR]
  python3 -I check_records.py --rerun --dafny D --z3 Z --lock L [--rerun-out DIR]
  python3 -I check_records.py --self-test     (the identity check must refuse a one-byte change)
"""
import argparse, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reproduce_dafny_proofs as rp  # noqa: E402

BANNER = ('IDENTITY CHECK ONLY: same bytes as recorded. It does NOT check that any theorem is correct, '
          'and no proof is re-run (use --rerun for that).')


def check(records_path, checkout):
    recdir = records_path.parent
    db = json.loads(records_path.read_text())
    problems, lines = [], []
    tmp = Path(tempfile.mkdtemp(prefix='check-records-'))
    try:
        for name, rec in sorted(db.get('proofs', {}).items()):
            spec = rp.PROOFS[name]
            work = tmp / name
            rp.stage_tree(checkout, spec, work)
            closure, missing = rp.include_closure(work, spec['entry'])
            want = {c['path']: c['sha256'] for c in rec['closure']}
            bad = sorted(set(want) ^ set(closure)) + [p for p in want if p in closure and want[p] != closure[p]]
            if missing:
                bad.append('missing: %s' % missing)
            if rp.set_digest(closure.items()) != rec['closure_digest']:
                bad.append('closure_digest')
            for c in rec['copies']:
                o = c.get('original')
                if c.get('equal') is not None and o:
                    now = (checkout / o).is_file() and rp.sha(checkout / o) == closure.get(c['copy'])
                    if now != c['equal'] or not now:
                        bad.append('copy %s vs %s' % (c['copy'], o))
            for key, field in (('verify', 'log'), ('verify', 'csv'), ('audit', 'report')):
                part = rec.get(key) or {}
                p, h = part.get(field), part.get(field + '_sha256')
                if p and h and (not (recdir / p).is_file() or rp.sha(recdir / p) != h):
                    bad.append('stored %s %s' % (key, field))
            state = 'OK' if not bad else 'MISMATCH %s' % bad[:6]
            lines.append('%-24s closure %3d files  %s  [%s; recorded status %s]' % (
                name, len(closure), state, rec.get('establishes'), rec.get('status')))
            if bad:
                problems.append(name)
        for name, rows in sorted(db.get('controls', {}).items()):
            for row in rows:
                src = checkout / row['source']
                if not src.exists() or rp.src_digest(src) != row['source_sha256']:
                    problems.append('%s/%s' % (name, row['control']))
                    lines.append('control %s/%s source MISMATCH' % (name, row['control']))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return problems, lines


def self_test(records_path, checkout):
    """Build a small checkout with only the needed paths; it must pass; one changed byte must be refused."""
    tmp = Path(tempfile.mkdtemp(prefix='check-records-selftest-'))
    out = []
    try:
        mini = tmp / 'mini'
        need = [rp.PROPOSAL + '/linked-refund', rp.PROPOSAL + '/sink-core', rp.PROPOSAL + '/slice-theorem',
                rp.ORIG_SPEC, rp.ORIG_REFUND, rp.ORIG_FINALITY, rp.ORIG_EXACT, rp.ORIG_DETERMINISM, rp.ORIG_PROTOCOL]
        for n in need:
            s, d = checkout / n, mini / n
            d.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(s, d) if s.is_dir() else shutil.copyfile(s, d)
        for case, path in [('baseline', None), ('one byte in impl/Refund.dfy', rp.ORIG_REFUND),
                           ('one byte in a Std copy of slice-theorem', rp.ST + '/library/Std/Wrappers.dfy'),
                           ('one byte in a sink-core mutant', rp.PROPOSAL + '/sink-core/mutants/N1-drop-fresh-id-check/sink/SinkCore.dfy')]:
            c = tmp / ('c-%d' % len(out))
            shutil.copytree(mini, c)
            if path:
                b = bytearray((c / path).read_bytes()); b[len(b) // 2] ^= 0x01; (c / path).write_bytes(bytes(b))
            problems, _ = check(records_path, c)
            refused = bool(problems)
            out.append({'case': case, 'refused': refused, 'as_expected': refused == bool(path), 'problems': problems})
            shutil.rmtree(c)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--records', default=str(HERE / 'PROOF_RECORDS.json'))
    ap.add_argument('--checkout', default=None)
    ap.add_argument('--rerun', action='store_true')
    ap.add_argument('--rerun-out', default=None)
    ap.add_argument('--dafny', default=os.environ.get('DAFNY'))
    ap.add_argument('--z3', default=os.environ.get('Z3'))
    ap.add_argument('--lock', default=os.environ.get('DAFNY_LOCK'))
    ap.add_argument('--self-test', action='store_true')
    a = ap.parse_args()
    records = Path(a.records).resolve()
    db = json.loads(records.read_text())
    checkout = Path(a.checkout).resolve() if a.checkout else (records.parent / db['checkout']).resolve()
    if a.self_test:
        res = self_test(records, checkout)
        for r in res:
            print(json.dumps(r))
        ok = all(r['as_expected'] for r in res)
        print('SELF-TEST %s' % ('as expected' if ok else 'NOT as expected'))
        return 0 if ok else 1
    print(BANNER if not a.rerun else 'IDENTITY CHECK, then --rerun: the verifier runs again (theorem meaning is still not checked).')
    problems, lines = check(records, checkout)
    for l in lines:
        print(l)
    rc = 0 if not problems else 1
    if a.rerun:
        if not (a.dafny and a.z3 and a.lock):
            ap.error('--rerun needs --dafny, --z3 and --lock (or DAFNY, Z3, DAFNY_LOCK)')
        out = Path(a.rerun_out or tempfile.mkdtemp(prefix='rerun-', dir=str(records.parent))).resolve()
        names = sorted(db.get('proofs', {}))
        cmd = [sys.executable, '-I', str(HERE / 'reproduce_dafny_proofs.py'), '--checkout', str(checkout), '--out', str(out),
               '--dafny', a.dafny, '--z3', a.z3, '--lock', a.lock, '--proofs'] + names
        subprocess.run(cmd)
        new = json.loads((out / 'PROOF_RECORDS.json').read_text())
        for n in names:
            o, r = db['proofs'][n], new['proofs'].get(n, {})
            same = (o.get('status'), (o.get('verify') or {}).get('verified'), o['closure_digest']) == \
                   (r.get('status'), (r.get('verify') or {}).get('verified'), r.get('closure_digest'))
            print('rerun %-24s %s: status %s, verified %s, exit %s' % (n, 'SAME' if same else 'DIFFERENT', r.get('status'),
                  (r.get('verify') or {}).get('verified'), (r.get('verify') or {}).get('exit')))
            if not same or r.get('status') != 'PASS':
                rc = 1
        print('re-ran the verifier into %s' % os.path.relpath(out, records.parent))
    print(('identity verified' if not problems else 'REFUSED: %s' % problems) +
          ('; theorem correctness NOT checked; proofs NOT re-run' if not a.rerun else '; theorem meaning NOT checked'))
    return rc


if __name__ == '__main__':
    sys.exit(main())
