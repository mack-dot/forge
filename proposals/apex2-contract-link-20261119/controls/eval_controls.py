#!/usr/bin/env python3
"""APEX-2: judge the negative controls. Usage:
  eval_controls.py <controls-dir with CONTROLS.json> <build-root with ctl-<ID> folders> <dafny> <z3> <out.json>
A HOL control counts ONLY when Holmake's actual exit is non-zero AND the build
output holds the EXACT expected failure text (the named theorem, or the pin
refusal). A printer control counts only when Holmake's exit is 0, the generated
file differs from the pinned one, check_link.py refuses it at the pin (exit 1),
and Dafny refuses it too (exit 4, with --skip-pins). A Dafny control counts only
when check_link.py exits 1 at the pin AND, with --skip-pins, exits 4 with an
error "a postcondition could not be proved" located in HolLink.dfy and no
error located anywhere else.
Exit 0 only when every control counts. Standard library only."""
import json, pathlib, subprocess, sys

ctl, build, dafny, z3, outp = [pathlib.Path(x) for x in sys.argv[1:6]]
here = pathlib.Path(__file__).resolve().parent.parent
check = here / 'check_link.py'
rows, bad = [], 0

def run_check(extra):
    r = subprocess.run([sys.executable, '-I', '-B', str(check), '--dafny', str(dafny), '--z3', str(z3)] + extra,
                       capture_output=True, text=True, timeout=1800)
    return r.returncode, r.stdout + r.stderr

for c in json.loads((ctl / 'CONTROLS.json').read_text()):
    cid, kind = c['control'], c['kind']
    row = {'control': cid, 'kind': kind, 'what': c['what']}
    if kind in ('hol-statement', 'export', 'printer'):
        b = build / ('ctl-' + cid)
        rc = int((b / 'holmake.exit.txt').read_text())
        text = ''.join(p.read_text(errors='replace') for p in
                       [b / 'holmake.stdout.log', b / 'holmake.stderr.log'] + sorted((b / '.hol/logs').glob('*')))
        row.update(holmake_exit=rc, expect_text=c['expect_text'], text_found=c['expect_text'] in text)
        if kind == 'printer':
            gen = b / 'HolFlatGenerated.dfy'
            row['generated_differs'] = gen.read_bytes() != (here / 'dafny/HolFlatGenerated.dfy').read_bytes()
            row['check_pin_exit'], _ = run_check(['--generated', str(gen)])
            row['check_dafny_exit'], o = run_check(['--generated', str(gen), '--skip-pins'])
            row['postcondition_errors_in_HolLink'] = sum('HolLink.dfy' in l and 'postcondition could not be proved' in l
                                                         for l in o.splitlines())
            row['counts'] = (rc == 0 and row['text_found'] and row['generated_differs']
                             and row['check_pin_exit'] == 1 and row['check_dafny_exit'] == 4
                             and row['postcondition_errors_in_HolLink'] >= 1)
        else:
            others = [l for l in text.splitlines() if 'Tactic failure proving' in l and c['expect_text'] not in l]
            row['other_failures'] = len(others)
            row['counts'] = rc != 0 and row['text_found'] and not others
    else:
        f = next(p for p in (ctl / cid).iterdir())
        opt = {'dafny-flatcore': '--flatcore', 'dafny-generated': '--generated', 'dafny-hollink': '--hollink'}[kind]
        row['check_pin_exit'], _ = run_check([opt, str(f)])
        row['check_dafny_exit'], o = run_check([opt, str(f), '--skip-pins'])
        errs = [l for l in o.splitlines() if ': Error' in l or 'Error:' in l]
        row['errors_in_HolLink'] = sum('HolLink.dfy' in l for l in errs)
        row['errors_in_FlatCore'] = sum('FlatCore.dfy' in l for l in errs)
        row['errors_elsewhere'] = len(errs) - row['errors_in_HolLink'] - row['errors_in_FlatCore']
        row['postcondition_errors_in_HolLink'] = sum('HolLink.dfy' in l and 'postcondition could not be proved' in l for l in errs)
        row['counts'] = (row['check_pin_exit'] == 1 and row['check_dafny_exit'] == 4
                         and row['postcondition_errors_in_HolLink'] >= 1 and row['errors_in_FlatCore'] == 0
                         and row['errors_elsewhere'] == 0)
    bad += 0 if row['counts'] else 1
    rows.append(row)
    print(cid, 'COUNTS' if row['counts'] else 'DOES NOT COUNT', {k: v for k, v in row.items() if k not in ('what', 'control')})
outp.write_text(json.dumps({'controls': rows, 'total': len(rows), 'not_counting': bad}, indent=1) + '\n')
print('total', len(rows), 'not counting', bad)
sys.exit(0 if bad == 0 else 1)
