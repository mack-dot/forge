#!/usr/bin/env python3
"""X4 DRAFT (2026-11-19): compare a closure export (from closure_export.sml) with a pinned manifest.

Standard library only. No network. Reads files only. Fails closed.
Exit 0: export equals the manifest element by element, and every listed .dat file has the pinned hashes.
Exit 1: refused (reasons printed, one per line, prefix REFUSE).
Exit 2: crash or unusable input.

Export format "forge.closure-export/1": one record per line, fields separated by a single TAB.
  FORMAT     forge.closure-export/1
  TARGET     <thy> <thm>
  STATEMENT  <canonical term>            (canonical s-expression; bound variables as de Bruijn indices)
  STATEMENT_TEXT <escaped printed text>  (String.toString of Parse.thm_to_string; for people, also compared)
  THM_TAG    <thy.name> <oracles,sorted,comma> <hypothesis count>
  CONST      <thy$name> <canonical type> <DEF thy.defname | STOP | NODEF>
  TYPE       <thy$tyop> <DEF thy.defname | STOP | NODEF>
  DEF        <thy.defname> <canonical conclusion>
  ANCESTOR   <thy> <sha1 recorded in the HOL theory graph> <parents,sorted,comma>
  AXIOM      <thy.name> <canonical conclusion>
  LOADED_DAT <thy> <sha1 recomputed at load by the guard hook> <path>
  END        <number of records before END>
Manifest (JSON): {"format": "forge.closure-manifest/1", "target": [thy, thm], "records": [<lines without LOADED_DAT>],
  "dat": {thy: {"sha256": hex64, "sha1": hex40}}, "allowed_oracles": [...], "allowed_axioms": [...],
  "reference": {"computed_by": str, "machine": str, "independent": bool, "record": str}}
"""
import argparse, hashlib, json, re, sys
from collections import Counter
from pathlib import Path

FMT_EXPORT = 'forge.closure-export/1'
FMT_MANIFEST = 'forge.closure-manifest/1'
KINDS = {'FORMAT': 1, 'TARGET': 2, 'STATEMENT': 1, 'STATEMENT_TEXT': 1, 'THM_TAG': 3, 'CONST': 3, 'TYPE': 2,
         'DEF': 2, 'ANCESTOR': 3, 'AXIOM': 2, 'LOADED_DAT': 3, 'END': 1}
HEX40 = re.compile(r'^[0-9a-f]{40}$')
HEX64 = re.compile(r'^[0-9a-f]{64}$')


class Refuse(Exception):
    pass


def digest(path, algo):
    h = hashlib.new(algo)
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def parse_export(text):
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    recs = []
    for i, line in enumerate(lines, 1):
        parts = line.split('\t')
        kind = parts[0]
        if kind not in KINDS or len(parts) != KINDS[kind] + 1:
            raise Refuse('malformed export line %d: %r' % (i, line[:120]))
        recs.append((kind, tuple(parts[1:]), line))
    if not recs or recs[0][:2] != ('FORMAT', (FMT_EXPORT,)):
        raise Refuse('export FORMAT line missing or wrong')
    if recs[-1][0] != 'END' or recs[-1][1][0] != str(len(recs) - 1):
        raise Refuse('export END line missing or count wrong (truncated export?)')
    if [r for r in recs[:-1] if r[0] == 'END']:
        raise Refuse('END record before the last line')
    return recs


def check(export_path, manifest_path, dat_paths, require_independent):
    reasons = []
    m = json.loads(Path(manifest_path).read_text())
    if m.get('format') != FMT_MANIFEST:
        raise Refuse('manifest format is not %s' % FMT_MANIFEST)
    for key in ('target', 'records', 'dat', 'allowed_oracles', 'allowed_axioms', 'reference'):
        if key not in m:
            raise Refuse('manifest key missing: %s' % key)
    recs = parse_export(Path(export_path).read_text())

    # 1. Exact equality of every content record. Not compared here: FORMAT and END (checked by
    #    parse_export) and LOADED_DAT (its path is machine-local; checked in step 4). Multiset compare.
    got = Counter(r[2] for r in recs if r[0] not in ('LOADED_DAT', 'FORMAT', 'END'))
    want = Counter(m['records'])
    for line in sorted((want - got).elements()):
        reasons.append('MISSING ' + line[:200])
    for line in sorted((got - want).elements()):
        reasons.append('EXTRA ' + line[:200])

    # 2. Target, statement, tags: policy checks that hold even if the manifest were wrong.
    tgt = [r[1] for r in recs if r[0] == 'TARGET']
    if tgt != [tuple(m['target'])]:
        reasons.append('TARGET differs or repeated: %r' % (tgt,))
    if sum(1 for r in recs if r[0] == 'STATEMENT') != 1:
        reasons.append('exactly one STATEMENT required')
    allowed_or = set(m['allowed_oracles'])
    for kind, f, _ in recs:
        if kind == 'THM_TAG':
            ors = set(x for x in f[1].split(',') if x)
            if not ors <= allowed_or:
                reasons.append('ORACLE not allowed on %s: %s' % (f[0], ','.join(sorted(ors - allowed_or))))
            if f[2] != '0':
                reasons.append('HYPOTHESES on %s: %s' % (f[0], f[2]))
    axs = sorted(f[0] for k, f, _ in recs if k == 'AXIOM')
    if axs != sorted(m['allowed_axioms']):
        reasons.append('AXIOM set differs: got %s' % ','.join(axs))

    # 3. Ancestry: every ANCESTOR has a pinned .dat entry and the reverse; hashes agree.
    anc = {f[0]: f[1] for k, f, _ in recs if k == 'ANCESTOR'}
    if len(anc) != sum(1 for r in recs if r[0] == 'ANCESTOR'):
        reasons.append('ANCESTOR listed twice')
    pinned = m['dat']
    for t in sorted(set(anc) - set(pinned)):
        reasons.append('ANCESTOR without pinned .dat: ' + t)
    for t in sorted(set(pinned) - set(anc)):
        reasons.append('pinned .dat not in ancestry: ' + t)
    for t in sorted(set(anc) & set(pinned)):
        p = pinned[t]
        if not (HEX40.match(p.get('sha1', '')) and HEX64.match(p.get('sha256', ''))):
            reasons.append('pinned hash malformed for ' + t)
        elif p['sha1'] != anc[t]:
            reasons.append('graph SHA-1 differs from pinned SHA-1 for %s' % t)

    # 4. The .dat files that HOL actually read (LOADED_DAT, from the load guard) and the files given on the
    #    command line: hash them here, outside HOL, and compare with the pins.
    loaded = {}
    for k, f, _ in recs:
        if k == 'LOADED_DAT':
            if f[0] in loaded:
                reasons.append('LOADED_DAT twice for ' + f[0])
            loaded[f[0]] = (f[1], f[2])
            if f[0] not in anc:
                reasons.append('LOADED_DAT for a theory outside the ancestry: ' + f[0])
            elif f[1] != anc[f[0]]:
                reasons.append('LOADED_DAT SHA-1 differs from graph SHA-1 for ' + f[0])
    files = {}
    for spec in dat_paths:
        if '=' not in spec:
            raise Refuse('--dat needs THEORY=PATH')
        t, path = spec.split('=', 1)
        files[t] = path
    for t in sorted(set(loaded) - set(files)):
        reasons.append('LOADED_DAT %s has no file given with --dat (cannot hash it)' % t)
    for t, path in sorted(files.items()):
        if t not in pinned:
            reasons.append('--dat for an unpinned theory: ' + t)
            continue
        try:
            s1, s256 = digest(path, 'sha1'), digest(path, 'sha256')
        except OSError as e:
            reasons.append('cannot read .dat for %s: %s' % (t, e))
            continue
        if s256 != pinned[t].get('sha256'):
            reasons.append('.dat SHA-256 differs for %s' % t)
        if s1 != pinned[t].get('sha1'):
            reasons.append('.dat SHA-1 differs for %s' % t)

    # 5. Provenance of the reference values.
    ref = m['reference']
    if require_independent and ref.get('independent') is not True:
        reasons.append('reference values are not independently computed (computed_by=%r, machine=%r)'
                       % (ref.get('computed_by'), ref.get('machine')))
    return reasons, ref


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('export')
    ap.add_argument('manifest')
    ap.add_argument('--dat', action='append', default=[], help='THEORY=PATH of a .dat file to hash')
    ap.add_argument('--require-independent', action='store_true')
    a = ap.parse_args()
    try:
        reasons, ref = check(a.export, a.manifest, a.dat, a.require_independent)
    except Refuse as e:
        print('REFUSE ' + str(e))
        return 1
    except Exception as e:  # noqa: BLE001
        print('CRASH %s: %s' % (type(e).__name__, e))
        return 2
    for r in reasons:
        print('REFUSE ' + r)
    if reasons:
        return 1
    print('CLOSURE_EQUAL reference_independent=%s computed_by=%s' % (ref.get('independent'), ref.get('computed_by')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
