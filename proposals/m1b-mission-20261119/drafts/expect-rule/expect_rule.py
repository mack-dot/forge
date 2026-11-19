#!/usr/bin/env python3
"""Standalone implementation of the PROPOSED refund rule (Z1). Not the gate. Applies nothing to the repository.

Rule NO_RUNTIME_HALT_STATEMENT (proposed for gate/refund.py prepare(), after the existing byte rules):
  impl/Refund.dfy must lex (fail closed) and must contain no token `expect` outside comments and literals.
  The token covers `expect E;`, `expect E, msg;` and `:- expect` (all forms of the keyword). `expect` is a
  reserved keyword in Dafny 4.11, so it cannot be renamed, imported under another name, or spelled differently.

Usage: expect_rule.py [--rprint]   (--rprint: also lex Dafny's resolved-program printout as a cross-check)
Writes rule_results.json and rule_table.md beside this file.
"""
import hashlib, json, re, shutil, subprocess, sys
from pathlib import Path
sys.dont_write_bytecode = True
from dafny_tokens import identifiers, LexError

HERE = Path(__file__).resolve().parent
REPO = Path('<HOME>/forge')
Y5 = REPO / 'proposals/m1b-mission-20261119/drafts/zero-review'
LOCKED = HERE.parent / 'dafny_locked.sh'
BANNED = {'expect'}

# Ideal verdicts of the Z1 submissions (True = a correct submission that should be admitted).
Z1_IDEAL = {
    'Z24-expect-halt-amount-61': False, 'Z24-expect-halt-amount-1000': False,
    'Z24-expect-halt-amount-123456789': False, 'Z24-expect-halt-amount-9223372036854775805': False,
    'E01-colon-dash-expect': False, 'E02-array-oob': False, 'E03-div-zero': False, 'E04-assert-by': False,
    'E05-test-attr': False, 'E06-stack-overflow-keyed': False, 'E07-oom-keyed': False,
    'E08-time-keyed': False, 'E12-expect-in-by-method': False,
    'C13-comment-expect': True, 'C14-string-char-expect': True, 'C15-ident-expected': True,
    'N1a-nested-comment-closed': True, 'N1b-nested-comment-reopen': False,
    'S1-cr-ends-line-comment': False, 'S2-cr-comment-hides-keyed-expect': False, 'S3-u2028-in-line-comment': False, 'S4-formfeed-in-line-comment': False,
}


def rule(data):
    """Return None if the proposed rule admits; else the refusal reason."""
    try:
        for offset, token in identifiers(data):
            if BANNED & set(re.split(r"[?']", token)):
                return 'NO_RUNTIME_HALT_STATEMENT: `expect` at offset %d' % offset
    except LexError as error:
        return 'NO_RUNTIME_HALT_STATEMENT: source does not lex (%s)' % error
    return None


def load_proposed():
    """Extract LINE_END, CHAR and code_words VERBATIM from the proposed gate file (proposal/gate/refund.py)."""
    import ast
    src = (HERE / 'proposal/gate/refund.py').read_text()
    tree = ast.parse(src)
    keep = [node for node in tree.body if (isinstance(node, ast.Assign) and getattr(node.targets[0], 'id', None) in ('LINE_END', 'CHAR'))
            or (isinstance(node, ast.FunctionDef) and node.name == 'code_words')]
    assert len(keep) == 3
    class Rejected(Exception):
        pass
    env = {'re': re, 'Rejected': Rejected}
    exec(compile(ast.Module(body=keep, type_ignores=[]), 'proposal/gate/refund.py', 'exec'), env)
    def proposed(data):
        try:
            return 'REFUSE: run-time halt statement expect' if 'expect' in env['code_words'](data) else None
        except Rejected as error:
            return 'REFUSE: ' + str(error)
    return proposed


def rprint_scan(name, data):
    w = HERE / 'rprint' / name
    shutil.rmtree(w, ignore_errors=True)
    for rel in ('spec/refund/RefundSpec.dfy', 'gate/refund/Bindings.dfy'):
        (w / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / rel, w / rel)
    (w / 'impl').mkdir()
    (w / 'impl/Refund.dfy').write_bytes(data)
    out = w / 'resolved.dfy'
    c = subprocess.run(['sh', str(LOCKED), 'resolve', 'impl/Refund.dfy', 'gate/refund/Bindings.dfy',
                        '--rprint', str(out)], cwd=w, capture_output=True)
    if c.returncode or not out.exists():
        return 'resolve exit %d' % c.returncode
    try:
        hits = [t for _, t in identifiers(out.read_bytes()) if BANNED & set(re.split(r"[?']", t))]
    except LexError as error:
        return 'printout does not lex: %s' % error
    return 'expect x%d' % len(hits) if hits else 'clean'


def main():
    do_rprint = '--rprint' in sys.argv
    y5 = json.loads((Y5 / 'results.json').read_text())
    manifest = json.loads((Y5 / 'manifest.json').read_text())
    # Ideal = behaviour: every CORRECT program (also C9-C12, which the OLD byte rules refuse) should be admitted.
    entries = [(n, Y5 / 'subs' / (n + '.dfy'), manifest[n]['expected_admitted'] or manifest[n]['kind'] == 'CORRECT',
                y5[n]['actual']) for n in manifest]
    entries += [(n, HERE / 'subs' / (n + '.dfy'), ideal, None) for n, ideal in Z1_IDEAL.items()]
    proposed = load_proposed()
    rows = []
    for name, path, ideal, critical in entries:
        data = path.read_bytes()
        full = HERE / 'tree' / name / 'logs/result.json'
        full = json.loads(full.read_text()) if full.exists() else None
        # "before": the present gate. The full-gate mirror result when it ran; else the critical-tier result
        # (a critical-tier refusal is final, since the hostile tier runs the critical tier first).
        before = full['verdict'] if full else (critical if critical == 'REFUSED' else 'NOT-RUN(critical %s)' % critical)
        reason = rule(data)
        gate_reason = proposed(data)
        assert (reason is None) == (gate_reason is None), (name, reason, gate_reason)
        after = 'REFUSED' if reason else before
        row = {'name': name, 'ideal': 'ADMITTED' if ideal else 'REFUSED', 'critical_tier_Y5': critical,
               'before_full_gate': before, 'before_why': full['why'] if full else '', 'new_rule': reason or 'pass',
               'after': after, 'sha256': hashlib.sha256(data).hexdigest()}
        if do_rprint:
            row['rprint_scan'] = rprint_scan(name, data)
        rows.append(row)
        print('%-44s ideal=%-8s before=%-10s rule=%-5s after=%-8s %s' % (
            name, row['ideal'], before[:10], 'REFUSE' if reason else 'pass', after, row.get('rprint_scan', '')),
            flush=True)
    (HERE / 'rule_results.json').write_text(json.dumps(rows, indent=1) + '\n')
    lines = ['| submission | ideal | before (present gate, all tiers) | new rule alone | after | rprint scan |',
             '|---|---|---|---|---|---|']
    for r in rows:
        lines.append('| %s | %s | %s | %s | %s | %s |' % (r['name'], r['ideal'], r['before_full_gate'],
                     'pass' if r['new_rule'] == 'pass' else 'REFUSE', r['after'], r.get('rprint_scan', '')))
    (HERE / 'rule_table.md').write_text('\n'.join(lines) + '\n')
    bad_correct = [r['name'] for r in rows if r['ideal'] == 'ADMITTED' and r['new_rule'] != 'pass']
    print('correct submissions refused AFTER (all rules):', [r['name'] for r in rows if r['ideal'] == 'ADMITTED' and r['after'] != 'ADMITTED'])
    must = ['A24-expect-halt-one-input', 'A25-expect-as-assume-wrong-value', 'A38-expect-always-halt',
            'A39-expect-in-helper-method']
    missed = [m for m in must if next(r for r in rows if r['name'] == m)['new_rule'] == 'pass']
    print('correct submissions refused by the new rule alone:', bad_correct)
    print('required refusals missed:', missed)
    print('wrong submissions still admitted after:', [r['name'] for r in rows
                                                       if r['ideal'] == 'REFUSED' and r['after'] == 'ADMITTED'])
    return 1 if bad_correct or missed else 0


if __name__ == '__main__':
    sys.exit(main())
