#!/usr/bin/env python3
# Z10: build and run Z10's own mutants of SinkCore.dfy (copies only). Each must give exit 4 with a real error.
import hashlib, shutil, subprocess, sys
from pathlib import Path
Z = Path('<session scratch folder>/m1b/Z10')
BASE = Z / 'base'
src = (BASE / 'sink/SinkCore.dfy').read_text()
assert hashlib.sha256(src.encode()).hexdigest().startswith('198474e4')
COMMIT = 'else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)'
LOWER = '''  function Lower(s: string): string {
    seq(|s|, i requires 0 <= i < |s| => if 'A' <= s[i] <= 'Z' then (s[i] as int + 32) as char else s[i])
  }

  ghost function EncSet('''
SETTLED = '    else if tok.requestId in core.settled then StepResult(core, Rejected(RequestSettled))\n'
SPECREL = '    F.Authorizes(pre, F.Transition(req, post, eff))\n'
M = {
 # stored id is lower-cased, the check is exact: replay "R1" after "R1" commits twice
 'Z1-store-lowercased-id': [('  ghost function EncSet(', LOWER), (COMMIT, COMMIT.replace('core.settled + {tok.requestId}', 'core.settled + {Lower(tok.requestId)}'))],
 # case-insensitive freshness check (stricter than the model)
 'Z2-case-insensitive-check': [('  ghost function EncSet(', LOWER), (SETTLED, SETTLED.replace('tok.requestId in core.settled', 'exists x | x in core.settled :: Lower(x) == Lower(tok.requestId)'))],
 # relation admits amount = remaining + 1 in one extra branch
 'Z3-specrel-amount-plus-one': [(SPECREL, SPECREL.rstrip('\n') + ''' ||
    (req.amount == pre.remaining + 1 && post == pre.(remaining := -1) &&
     eff == R.Intent(pre.chargeId, req.requestId, req.amount, req.reason))
''')],
 'Z3b-specrel-plus-one-valid-pre': [(SPECREL, SPECREL.rstrip('\n') + ''' ||
    (0 <= pre.remaining <= pre.original && req.amount == pre.remaining + 1 &&
     post == pre.(remaining := -1) && eff == R.Intent(pre.chargeId, req.requestId, req.amount, req.reason))
''')],
 # the id is not settled by the commit (settle "after" the effect, lost)
 'Z4-settle-omitted': [(COMMIT, COMMIT.replace('core.settled + {tok.requestId}', 'core.settled'))],
 # pre-state check ignores the charge id (accept a token for another charge)
 'Z5-other-charge-id': [('    else if core.charge != tok.pre then', '    else if core.charge != tok.pre.(chargeId := core.charge.chargeId) then')],
 # T5 claimed strict: a non-empty outbox never refunds the whole original
 'Z6-T5-strict': [('    ensures 0 <= SumIntents(core.outbox) <= init.original\n', '    ensures 0 <= SumIntents(core.outbox) <= init.original\n    ensures |core.outbox| > 0 ==> SumIntents(core.outbox) < init.original\n')],
 # Enc not injective at one point: Enc("ab") == Enc("b")
 'Z7-enc-collision-one-point': [('    if |s| == 0 then 0 else (s[0] as int + 1) + B * Enc(s[1..])', '    if s == "ab" then Enc("b") else if |s| == 0 then 0 else (s[0] as int + 1) + B * Enc(s[1..])')],
 # signature ignored for the empty request id
 'Z8-sig-ignored-empty-id': [('    else if !sigOk then', '    else if !sigOk && tok.requestId != "" then')],
 # effect amount off by one
 'Z9-effect-amount-plus-one': [(COMMIT, COMMIT.replace('core.outbox + [tok.intent]', 'core.outbox + [tok.intent.(amount := tok.intent.amount + 1)]'))],
 # vacuity probe: the headline hypotheses imply false?
 'Z10-vacuity-probe': [('  // ---- a finding stated as a proved fact', '''  lemma HypothesesFalse(init: State, core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk) && Rel(core, s, toks) && Inv(init, s) && IdealMac(s) && InitOk(init)
    ensures false
  {
  }

  // ---- a finding stated as a proved fact''')],
 # T1 strengthened: every commit's token is unique for its claim (no second verifying tag for the same claim)
 'Z11-T1-unique-tag': [('    // T2: no token causes two commits;', '''    ensures forall i, t | 0 <= i < |toks| && VerifyTag(s.log[i], t) :: t == toks[i].sig
    // T2: no token causes two commits;''')],
}
names = sys.argv[1:] or list(M)
for n in names:
    s = src
    for old, new in M[n]:
        assert s.count(old) == 1, (n, old)
        s = s.replace(old, new)
    d = Z / 'mutants' / n
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(BASE, d)
    for f in ['sink/Attack.dfy', 'sink/WitnessCore.dfy']:
        (d / f).unlink()
    (d / 'sink/SinkCore.dfy').write_text(s)
    r = subprocess.run([str(Z / 'v.sh'), str(d / 'sink'), 'SinkCore.dfy', n], capture_output=True, text=True)
    log = (Z / 'logs' / (n + '.log')).read_text().splitlines()
    errs = [l for l in log if ': Error' in l][:4]
    print(n, 'EXIT', r.returncode, '|', r.stdout.strip().splitlines()[0] if r.stdout.strip() else '', '|', errs, flush=True)
