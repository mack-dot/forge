"""Per-change tables (orchestrator item 4). For each gate variant, each file gets the verdict of the stages that
were RUN: source scope (tools/scope_check.py on the variant's text, MACHINE) and, for variants with the JS tier,
the JS checker on the file's translation (results/check-none.jsonl, MACHINE). Dafny verification and the test
tier are NOT RUN here (heavy/gate_jsbound.sh). Writes PER_CHANGE.md."""
import json, subprocess, os
H = '<REPO>/results/night-shift-20261119/orch-B/h-gate'
NS = '<REPO>/results/night-shift-20261119'
L3 = [l.split() for l in open(NS + '/orch-B/e-subset3/heavy/list3.txt')]
correct67 = [p for c, p in L3 if c.startswith('correct')]
fr10 = sorted(NS + '/orch-C/c5-gate/fr/' + f for f in os.listdir(NS + '/orch-C/c5-gate/fr') if f.endswith('.dfy')) + [H + '/subs/c13/G11-digit-separator-cap.dfy']
halting = [p for c, p in L3 if c == 'hostile-halting']
review = [p for c, p in L3 if c == 'hostile-REVIEW']
SETS = [('B correct (67)', correct67, True), ('C correct (10 + G11)', fr10, True),
        ('halting (24; includes the seven)', halting, False), ('rule-2 review bypasses (23)', review, False),
        ('ghost axioms C-GATE-05 (7): NOT RUN here = `dafny translate` itself fails (exit 3 warnings x6, exit 2 x1; logs/A*.translate.7.log), so verify, build and audit refuse them',
         sorted(H + '/subs/c13/' + f for f in os.listdir(H + '/subs/c13') if f.startswith('A')), False)]
JS = {}
for l in open(H + '/results/check-none.jsonl'):
    r = json.loads(l); JS[r['file'][:-3]] = r
VARIANTS = [
    ('V0 pristine 985f5eaf', H + '/gate-new/a-refund.py', False),
    ('V1 + scope-minimal (diff i)', H + '/work/v1-refund.py', False),
    ('V2 + expect rule, `@` lexer, `abstract`, size/nesting bounds (source part of diff ii)', H + '/gate-new/b/gate/refund.py', False),
    ('V3 + JS bound tier (diff ii, complete)', H + '/gate-new/b/gate/refund.py', True),
]
def scope(gate, files):
    out = subprocess.run(['/usr/local/bin/python3.10', '-I', H + '/tools/scope_check.py', gate] + files,
                         capture_output=True, text=True, timeout=120).stdout.splitlines()
    return {l.split(' | ')[0][:-4]: l.split(' | ', 1)[1] for l in out}
doc = ['# Per-change tables (h-gate). Stages RUN: source scope (MACHINE) and JS check (MACHINE, translated files only).',
       'Dafny verify, build and tests: NOT RUN (prepared: heavy/gate_jsbound.sh). For V0-V2 an "admitted" file still',
       'goes to Dafny; the halting files verify (earlier runs), so V0-V2 admit them in the real gate.',
       'Halting NOT RUN in V3 = A16-decreases-star: `dafny translate` exits 2 (resolution error), so the gate refuses it at verify.', '']
for name, gate, js in VARIANTS:
    doc += ['## ' + name, '', '| set | admitted | refused (cause: count) | NOT RUN (no translation) |', '|---|---|---|---|']
    for sname, files, good in SETS:
        sc = scope(gate, files); adm = 0; ref = {}; nr = 0
        for f in files:
            n = os.path.basename(f)[:-4]; v = sc.get(n, 'missing')
            if v != 'PASS':
                k = v.split(':')[0] + ':' + v.split(':')[1][:40] if ':' in v else v; ref[k] = ref.get(k, 0) + 1; continue
            if js:
                j = JS.get(n)
                if not j: nr += 1; continue
                if j['verdict'] != 'ACCEPT': k = 'JS_' + j['code']; ref[k] = ref.get(k, 0) + 1; continue
            adm += 1
        tag = '' if good or not adm else (' (bounded rule-2 bypasses A01s, A04, A05b, A06, X02, X06, X38: each ran in <= 29 ms, logs/drive_bounded.out)' if js and 'review' in sname else ' (UNSAFE ADMITTED by the stages run)')
        doc.append('| %s | %d%s | %s | %d |' % (sname, adm, tag, '; '.join('%s: %d' % kv for kv in sorted(ref.items())) or '-', nr))
    doc.append('')
open(H + '/PER_CHANGE.md', 'w').write('\n'.join(doc) + '\n')
print('\n'.join(doc))
