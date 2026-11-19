#!/usr/bin/env python3
"""Y7 dispatch: copies byte-equal?, main verify, negative controls, audit. Decides no proof by itself.
Runs ONE Dafny process at a time (dafny_one.sh waits for any other Dafny/z3 process first)."""
import hashlib, json, shutil, subprocess, sys
from pathlib import Path

Y = Path(__file__).resolve().parent
ROOT = Path('<HOME>/forge')
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
INPUTS = Y / 'inputs'
COPIES = {'model/FinalityProtocol.dfy': 'proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy',
          'impl/RefundFinality.dfy': 'impl/RefundFinality.dfy', 'impl/Refund.dfy': 'impl/Refund.dfy',
          'spec/refund/RefundSpec.dfy': 'spec/refund/RefundSpec.dfy'}
STEP_COMMIT = 'else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)'
EXTRA_LEMMA = '''  lemma CommitAlwaysChangesState(s: System, c: Claim, t: Tag)
    requires SinkAccepts(s, c, t) && SpecRel(c.pre, c.req, c.post, c.eff)
    ensures Commit(s, c, t).store != s.store
  {
  }

  // ---- a finding stated as a proved fact'''
# name -> (old text, new text); each old text must occur exactly once in SinkCore.dfy
MUTANTS = {
    'N1-drop-fresh-id-check': ('    else if tok.requestId in core.settled then StepResult(core, Rejected(RequestSettled))\n', ''),
    'N2-drop-pre-state-check': ('    else if core.charge != tok.pre then StepResult(core, Rejected(PreStateMismatch))\n', ''),
    'N3a-wrong-arithmetic-double-deduct': (STEP_COMMIT, STEP_COMMIT.replace(
        'Core(tok.post,', 'Core(tok.pre.(remaining := tok.pre.remaining - 2 * tok.intent.amount),')),
    'N3b-wrong-arithmetic-add': (STEP_COMMIT, STEP_COMMIT.replace(
        'Core(tok.post,', 'Core(tok.pre.(remaining := tok.pre.remaining + tok.intent.amount),')),
    'N4-commit-on-invalid-signature': ('    else if !sigOk then StepResult(core, Rejected(SignatureInvalid))\n', ''),
    'N5-drop-pinned-ids-check': ('if tok.specId != PINNED_SPEC || tok.checkerId != PINNED_CHK then', 'if false then'),
    'N6-non-injective-id-encoding': ('(s[0] as int + 1) + B * Enc(s[1..])', '(s[0] as int + 1) + Enc(s[1..])'),
    'N7-claim-every-commit-changes-state': ('  // ---- a finding stated as a proved fact', EXTRA_LEMMA),
    'N8-two-effects-per-commit': (STEP_COMMIT, STEP_COMMIT.replace('[tok.intent]', '[tok.intent, tok.intent]')),
}

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def verify(folder, log):
    r = subprocess.run([str(Y / 'dafny_one.sh'), str(folder / 'sink'), 'SinkCore.dfy', str(log)])
    lines = [l for l in log.read_text().splitlines() if l.strip()]
    summary = next((l for l in reversed(lines) if l.startswith('Dafny program verifier')), lines[-2] if len(lines) > 1 else '')
    errors = [l for l in lines if ': Error' in l][:3]
    return r.returncode, summary, errors

def main():
    only = sys.argv[1:]
    logs = Y / 'logs'; logs.mkdir(exist_ok=True)
    rows = []
    for copy, src in COPIES.items():
        rows.append({'check': 'copy ' + copy, 'repo_sha256': sha(ROOT / src), 'copy_sha256': sha(INPUTS / copy),
                     'equal': sha(ROOT / src) == sha(INPUTS / copy)})
    rows.append({'check': 'SinkCore.dfy sha256', 'value': sha(INPUTS / 'sink/SinkCore.dfy')})
    if not only or 'main' in only:
        code, summ, errs = verify(INPUTS, logs / 'main.log')
        rows.append({'check': 'verify SinkCore.dfy', 'expected_exit': 0, 'exit': code, 'summary': summ, 'errors': errs})
    src = (INPUTS / 'sink/SinkCore.dfy').read_text()
    for name, (old, new) in MUTANTS.items():
        if only and name not in only:
            continue
        assert src.count(old) == 1, name
        folder = Y / 'mutants' / name
        if folder.exists():
            shutil.rmtree(folder)
        shutil.copytree(INPUTS, folder)
        (folder / 'sink/SinkCore.dfy').write_text(src.replace(old, new))
        code, summ, errs = verify(folder, logs / (name + '.log'))
        rows.append({'check': 'control ' + name, 'expected_exit': 4, 'exit': code, 'summary': summ, 'errors': errs})
    if not only or 'audit' in only:
        files = sorted(str(p.relative_to(INPUTS)) for p in INPUTS.rglob('*.dfy'))
        rep = logs / 'audit.md'
        a = subprocess.run([str(DAFNY), 'audit', *files, '--report-format', 'md', '--report-file', str(rep)],
                           cwd=INPUTS, capture_output=True, text=True)
        (logs / 'audit.stdout.log').write_text(a.stdout + a.stderr)
        found = [l for l in rep.read_text().splitlines() if l.startswith('|') and not l.startswith(('|Name', '|----'))] if rep.exists() else ['NO REPORT']
        rows.append({'check': 'audit of %d files' % len(files), 'files': files, 'exit': a.returncode, 'findings': found,
                     'stdout_last': (a.stdout.strip().splitlines() or [''])[-1]})
        g = subprocess.run(['grep', '-n', '-E', r'\bassume\b|\{:axiom\}|@Axiom|\bexpect\b|\{:verify false\}|\{:extern\}',
                            'sink/SinkCore.dfy'], cwd=INPUTS, capture_output=True, text=True)
        rows.append({'check': 'forbidden words in SinkCore.dfy', 'grep_exit': g.returncode, 'hits': g.stdout.strip()})
    out = logs / ('result-%s.json' % ('-'.join(only) if only else 'all'))
    out.write_text(json.dumps(rows, indent=1) + '\n')
    for r in rows:
        print(json.dumps(r))

if __name__ == '__main__':
    main()
