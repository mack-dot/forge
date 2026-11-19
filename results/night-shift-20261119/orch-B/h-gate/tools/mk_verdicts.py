"""Builds VERDICTS.md: the JS checker verdict per file and per mutant (results/check-*.jsonl, MACHINE)."""
import json
H = '/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-gate'
M = ['none', 'no-loop', 'no-recursion', 'no-load', 'no-shape', 'no-cost']
R = {m: {json.loads(l)['file'][:-3]: json.loads(l) for l in open('%s/results/check-%s.jsonl' % (H, m))} for m in M}
UNSAFE = ['E06-stack-overflow-keyed', 'E07-oom-keyed', 'E08-time-keyed', 'H01b-such-that-modulus-hang',
          'H02-exponential-recursion-hang', 'H03-seq-comprehension-alloc', 'H04-seq-length-2pow32-throws',
          'Z24-expect-halt-amount-1000', 'A01-dag-equality-2x40', 'A01m-dag-equality-2x22-measure',
          'A03-extra-module-require', 'A03-extra-module-BigNumber', 'A08-param-shadows-const-display',
          'A09-local-shadows-const-display', 'A10-recursion-shadowed-const-display', 'P03-js-proto-hasown',
          'A05-hex-multiplier-loop',
          'HV06-call-tower-exponential', 'HV07-repeated-squaring', 'HV08-string-doubling', 'HV10-tuple-dag-equality',
          'Y06-helper-fanout-2x12', 'Y46-seq-concat-doubling']
REFUSED21 = [l.strip() for l in open(H + '/refused21.txt')]
FILES = ['F%02d' % i for i in range(1, 11)]
ACCEPTED = ['Refund', 'C01-early-return', 'C02-match-tuple', 'C03-set-literal-reasons', 'C07-tuple-destructure',
            'C13-match-expression-arms', 'CV05-local-constants']
def row(n):
    r = R['none'].get(n)
    if not r:
        return '| %s | NOT RUN (no translation) | | %s |' % (n, ' | '.join('' for _ in M[1:]))
    muts = ' | '.join(('ACCEPT' if R[m][n]['verdict'] == 'ACCEPT' else 'refuse') if n in R[m] else '-' for m in M[1:])
    return '| %s | %s | %s %s | %s |' % (n, r['verdict'], r['code'], r['detail'][:60].replace('|', '/'), muts)
out = ['# JS checker verdicts (MACHINE: results/check-*.jsonl; js_bound_check.cjs; light single Node runs)', '',
       'Inputs: `dafny translate js --no-verify` outputs in js/ (this task, through dafny_locked.sh) and reused builds in',
       'js-reuse/ (r-subset2, e-subset3, r-subset3). Columns 4-8: verdict of each mutant of the checker.', '']
hdr = '| file | verdict | code / detail | ' + ' | '.join(M[1:]) + ' |\n|---|---|---|' + '---|' * 5
def section(title, names):
    out.append('## ' + title); out.append(''); out.append(hdr)
    for n in names: out.append(row(n))
    out.append('')
F = [k for k in R['none'] if k[:3] in set(FILES)]
section('Unsafe (must be refused)', UNSAFE)
GHOST = ['A01-bodiless-lemma-brace-end', 'A02-bodiless-ghost-pred-brace-end', 'A13-ghost-method-bodiless-brace',
         'A14-lemma-ensures-set-literal-end', 'A15-forall-ensures-in-lemma', 'A16-induction-false-lemma', 'A17-isolate-on-bodiless']
section('Unsafe GHOST axioms (C-GATE-05): the JS tier cannot see ghost code; owner = Dafny verify (non-zero exit) and audit (red-team logs orch-C/c13-gate-js/logs: A01 verify exit 2, audit exit 2; A02 verify exit 2)', GHOST)
section('Correct, refused by rule 3 (21)', REFUSED21)
section('Reviewer files F01-F10 (correct, verified)', sorted(F))
section('Correct, accepted by rule 3 (sample)', ACCEPTED)
rest = sorted(k for k in R['none'] if k not in set(UNSAFE) | set(REFUSED21) | set(F) | set(ACCEPTED) | set(GHOST))
ADM = ['A04-seq-of-seq-growth', 'A05b-hex-multiplier-loop-100', 'A06-minus-doubling-loop', 'Y48-method-out-tree-growth']
section('Review bypasses of the RULE-2 cost argument that this checker ADMITS with a stated bound (one Assess call measured: logs/drive_bounded.out, 0-29 ms)', ADM)
rest = [n for n in rest if n not in ADM]
section('Other files with JavaScript (argued-bounded hostile, lexer probes, JS-name probes)', rest)
def count(names, want):
    have = [n for n in names if n in R['none']]
    return sum(1 for n in have if (R['none'][n]['verdict'] == 'ACCEPT') == want), len(have)
u = count(UNSAFE, False); c = count(REFUSED21 + F, True); a = count(ACCEPTED, True)
out += ['## Totals', '', '- unsafe refused: %d of %d with JavaScript (of %d named)' % (u[0], u[1], len(UNSAFE)),
        '- refused-correct (rule 3 + F01-F10) now accepted: %d of %d with JavaScript' % c,
        '- accepted-correct sample still accepted: %d of %d' % a, '']
for m in M[1:]:
    adm = [n for n in UNSAFE if n in R[m] and R[m][n]['verdict'] == 'ACCEPT' and R['none'][n]['verdict'] != 'ACCEPT']
    out.append('- mutant %s admits unsafe: %s' % (m, ', '.join(adm) or 'NONE'))
admitted = [n for n in UNSAFE if n in R['none'] and R['none'][n]['verdict'] == 'ACCEPT']
out.append('- unsafe files the checker ADMITS: ' + (', '.join(admitted) or 'none'))
open(H + '/VERDICTS.md', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out[-9:]))
