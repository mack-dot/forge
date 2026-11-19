#!/usr/bin/env python3
"""X4: synthetic controls for check_closure.py. Writes only under ./synthetic/. All inputs are FAKE.
Records the real exit code of each check_closure.py run in synthetic/results.json."""
import hashlib, json, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / 'synthetic'
CHECK = HERE / 'check_closure.py'

STMT = '(a (a (c bool$==> (bool$fun bool$bool (bool$fun bool$bool bool$bool))) (c forge_refundImage$refund_entry_pre (bool$bool))) (c forge_refundCertifiedProg$refund_fields (num$num)))'
DEF_OK = '(a (a (c min$= ...) (c forge_refundCertifiedProg$refund_fields (num$num))) (amount))'
DEF_BAD = '(a (a (c min$= ...) (c forge_refundCertifiedProg$refund_fields (num$num))) (amount + 1))'
DEF_IMG = '(a (a (c min$= ...) (c forge_refundImage$refund_entry_pre (bool$bool))) (bytes_in_memory refund_file))'


def sha(b, a):
    return hashlib.new(a, b).hexdigest()


def write_case(name, dats, records, loaded):
    d = OUT / name
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    paths = {}
    for t, content in dats.items():
        p = d / (t + 'Theory.dat')
        p.write_bytes(content)
        paths[t] = p
    lines = list(records)
    for t in loaded:
        lines.append('LOADED_DAT\t%s\t%s\t%s' % (t, sha(dats[t], 'sha1'), paths[t]))
    lines = ['FORMAT\tforge.closure-export/1'] + lines
    lines.append('END\t%d' % len(lines))
    (d / 'export.txt').write_text('\n'.join(lines) + '\n')
    return d, paths


def records_for(dats, def_text=DEF_OK, oracles='DISK_THM', extra_anc=None, drop_anc=None):
    r = ['TARGET\tforge_final\trefund_profile_a_sl',
         'STATEMENT\t' + STMT,
         'STATEMENT_TEXT\t\\226\\138\\162 refund_entry_pre \\226\\135\\146 refund_fields',
         'THM_TAG\tforge_final.refund_profile_a_sl\t%s\t0' % oracles,
         'CONST\tforge_refundCertifiedProg$refund_fields\t(num$num)\tDEF forge_refundCertifiedProg.refund_fields_def',
         'CONST\tforge_refundImage$refund_entry_pre\t(bool$bool)\tDEF forge_refundImage.refund_entry_pre_def',
         'CONST\tbool$==>\t(bool$fun bool$bool (bool$fun bool$bool bool$bool))\tSTOP',
         'TYPE\tnum$num\tSTOP',
         'DEF\tforge_refundCertifiedProg.refund_fields_def\t' + def_text,
         'DEF\tforge_refundImage.refund_entry_pre_def\t' + DEF_IMG,
         'THM_TAG\tforge_refundCertifiedProg.refund_fields_def\tDISK_THM\t0',
         'THM_TAG\tforge_refundImage.refund_entry_pre_def\tDISK_THM\t0',
         'AXIOM\tbool.BOOL_CASES_AX\t(...)', 'AXIOM\tbool.ETA_AX\t(...)',
         'AXIOM\tbool.INFINITY_AX\t(...)', 'AXIOM\tbool.SELECT_AX\t(...)']
    parents = {'bool': '', 'forge_refundCertifiedProg': 'bool', 'forge_refundImage': 'bool',
               'forge_final': 'forge_refundCertifiedProg,forge_refundImage'}
    if extra_anc:
        parents[extra_anc] = 'bool'
    for t, ps in parents.items():
        if t == drop_anc:
            continue
        r.append('ANCESTOR\t%s\t%s\t%s' % (t, sha(dats[t], 'sha1'), ps))
    return r


def manifest(dats, records, independent, who):
    return {'format': 'forge.closure-manifest/1', 'target': ['forge_final', 'refund_profile_a_sl'],
            'records': records,
            'dat': {t: {'sha1': sha(b, 'sha1'), 'sha256': sha(b, 'sha256')} for t, b in dats.items()},
            'allowed_oracles': ['DISK_THM'],
            'allowed_axioms': ['bool.BOOL_CASES_AX', 'bool.ETA_AX', 'bool.INFINITY_AX', 'bool.SELECT_AX'],
            'reference': {'computed_by': who, 'machine': 'synthetic', 'independent': independent,
                          'record': 'synthetic'}}


def run(case_dir, mpath, paths, flags=()):
    argv = [sys.executable, '-I', '-B', str(CHECK), str(case_dir / 'export.txt'), str(mpath)]
    for t, p in sorted(paths.items()):
        argv += ['--dat', '%s=%s' % (t, p)]
    argv += list(flags)
    p = subprocess.run(argv, capture_output=True, text=True)
    return p.returncode, p.stdout.strip().splitlines()


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    base_dats = {'bool': b'(theory ("bool" ("min" . "")))\n',
                 'forge_refundCertifiedProg': b'(theory ("forge_refundCertifiedProg" ("bool" . "x"))) refund_fields = amount\n',
                 'forge_refundImage': b'(theory ("forge_refundImage" ("bool" . "x"))) refund_entry_pre\n'}
    base_dats['forge_final'] = (b'(theory ("forge_final" ("forge_refundCertifiedProg" . "%s") ("forge_refundImage" . "%s")))\n'
                                % (sha(base_dats['forge_refundCertifiedProg'], 'sha1').encode(),
                                   sha(base_dats['forge_refundImage'], 'sha1').encode()))
    loaded = ['forge_refundCertifiedProg', 'forge_refundImage', 'forge_final']
    base_rec = records_for(base_dats)
    pinned = manifest(base_dats, base_rec, True, 'second operator (synthetic)')
    mpath = OUT / 'manifest.json'
    mpath.write_text(json.dumps(pinned, indent=1) + '\n')

    # The H2 attack: same name, altered definition, rebuilt dependants, SAME final statement.
    h2 = dict(base_dats)
    h2['forge_refundCertifiedProg'] = base_dats['forge_refundCertifiedProg'].replace(b'amount\n', b'amount + 1\n')
    h2['forge_final'] = (b'(theory ("forge_final" ("forge_refundCertifiedProg" . "%s") ("forge_refundImage" . "%s")))\n'
                         % (sha(h2['forge_refundCertifiedProg'], 'sha1').encode(),
                            sha(h2['forge_refundImage'], 'sha1').encode()))
    changed = dict(base_dats)
    changed['forge_refundImage'] = base_dats['forge_refundImage'] + b' '
    extra = dict(base_dats)
    extra['forge_evil'] = b'(theory ("forge_evil" ("bool" . "x")))\n'

    cases = []
    # (name, dats, records, loaded, manifest path, expected exit, flags, what)
    d, p = write_case('c0-baseline', base_dats, base_rec, loaded)
    cases.append(('c0-baseline', d, mpath, p, 0, (), 'unchanged export and files'))
    d, p = write_case('c1a-h2-definition-text-only', base_dats, records_for(base_dats, def_text=DEF_BAD), loaded)
    cases.append(('c1a-h2-definition-text-only', d, mpath, p, 1, (), 'refund_fields_def text altered (amount + 1), same name, same STATEMENT; .dat unchanged'))
    d, p = write_case('c1b-h2-rebuilt-chain', h2, records_for(h2, def_text=DEF_BAD), loaded)
    cases.append(('c1b-h2-rebuilt-chain', d, mpath, p, 1, (), 'H2 as an attacker would do it: altered parent and rebuilt dependants, same STATEMENT, consistent SHA-1 chain'))
    d, p = write_case('c2-missing-ancestor', base_dats, records_for(base_dats, drop_anc='forge_refundImage'), loaded)
    cases.append(('c2-missing-ancestor', d, mpath, p, 1, (), 'ANCESTOR forge_refundImage removed'))
    d, p = write_case('c3-extra-ancestor', extra, records_for(extra, extra_anc='forge_evil'), loaded)
    cases.append(('c3-extra-ancestor', d, mpath, p, 1, (), 'ANCESTOR forge_evil added'))
    d, p = write_case('c4-changed-dat', changed, base_rec, loaded)
    cases.append(('c4-changed-dat', d, mpath, p, 1, (), 'forge_refundImage .dat has one extra byte; export records unchanged'))
    d, p = write_case('c5-extra-oracle', base_dats, records_for(base_dats, oracles='DISK_THM,cheat'), loaded)
    cases.append(('c5-extra-oracle', d, mpath, p, 1, (), 'final theorem tag has oracle cheat'))
    # c6: the H2 chain, but the reference values were re-pinned by the same producer (not independent).
    m6 = OUT / 'manifest-repinned-same-producer.json'
    m6.write_text(json.dumps(manifest(h2, records_for(h2, def_text=DEF_BAD), False, 'same agent family, same machine'), indent=1) + '\n')
    d, p = write_case('c6-h2-repinned-same-producer', h2, records_for(h2, def_text=DEF_BAD), loaded)
    cases.append(('c6a-h2-repinned-no-provenance-rule', d, m6, p, 0, (), 'H2 chain against a manifest re-pinned by the same producer: the check alone cannot see it'))
    cases.append(('c6b-h2-repinned-require-independent', d, m6, p, 1, ('--require-independent',), 'same, with --require-independent'))
    d, p = write_case('c7-truncated-export', base_dats, base_rec, loaded)
    txt = (d / 'export.txt').read_text().splitlines()
    (d / 'export.txt').write_text('\n'.join(txt[:-3] + txt[-1:]) + '\n')
    cases.append(('c7-truncated-export', d, mpath, p, 1, (), 'two records cut, END line kept'))
    d, p = write_case('c8-loaded-dat-swapped', base_dats, base_rec, loaded)
    (d / 'forge_refundImageTheory.dat').write_bytes(changed['forge_refundImage'])
    cases.append(('c8-loaded-dat-swapped', d, mpath, p, 1, (), '.dat file swapped on disk after the export; .sml hash string unchanged'))

    results = []
    for name, d, m, p, expect, flags, what in cases:
        code, out = run(d, m, p, flags)
        results.append({'case': name, 'what': what, 'expected_exit': expect, 'actual_exit': code,
                        'as_expected': code == expect, 'output': out[:8]})
        print('%-40s expected %d actual %d %s' % (name, expect, code, 'OK' if code == expect else 'UNEXPECTED'))
    (OUT / 'results.json').write_text(json.dumps(results, indent=1) + '\n')
    return 0 if all(r['as_expected'] for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
