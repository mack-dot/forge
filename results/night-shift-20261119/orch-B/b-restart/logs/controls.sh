#!/bin/bash
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/b-restart; C=$D/controls; cd $C
mk(){ rm -rf $1; mkdir -p $1; cp -R ../src ../Restart.dfy ../KeyedStore.dfy $1/; }
for c in C1-audit-reject-all C2-step-reject-all C3-step-commit-all C4-drop-history C5-create-no-key-check C6-drop-A5Ledger; do mk $c; done
python3 - <<'PY'
def ed(p, old, new):
    s=open(p).read(); assert s.count(old)==1, (p, old); open(p,'w').write(s.replace(old,new))
ed('C1-audit-reject-all/Restart.dfy', "    InitOkB(init) && Replay(init, ledger).0 && Replay(init, ledger).1 == core\n", "    false // CONTROL C1: reject-all audit\n")
step="  function Step(core: Core, tok: SinkToken, sigOk: bool): StepResult\n  {\n"
end_old="    else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)\n  }"
end_new="    else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)\n    */\n  }"
ed('C2-step-reject-all/src/SinkCoreV3.dfy', step, step+"    StepResult(core, Rejected(IdsNotPinned)) // CONTROL C2: reject all\n    /*\n")
ed('C2-step-reject-all/src/SinkCoreV3.dfy', end_old, end_new)
ed('C3-step-commit-all/src/SinkCoreV3.dfy', step, step+"    StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed) // CONTROL C3: commit all\n    /*\n")
ed('C3-step-commit-all/src/SinkCoreV3.dfy', end_old, end_new)
ed('C4-drop-history/Restart.dfy', "    requires A2_MintOnlyOnCheck(a) && A5_VerifierMatchesAtEachDelivery(a) && H1Cont(a0, a)\n", "    requires A2_MintOnlyOnCheck(a) && A5_VerifierMatchesAtEachDelivery(a) // CONTROL C4: H1Cont dropped\n")
ed('C5-create-no-key-check/KeyedStore.dfy', "    key == init.chargeId && key !in st && 0 <= init.remaining <= init.original\n", "    key !in st && 0 <= init.remaining <= init.original // CONTROL C5: no key == chargeId check\n")
ed('C6-drop-A5Ledger/Restart.dfy', "    requires A5Ledger(ledger) && A2Mints(ms) && H1Ledger(ms, ledger)\n    ensures core == Exec", "    requires A2Mints(ms) && H1Ledger(ms, ledger) // CONTROL C6: A5Ledger dropped\n    ensures core == Exec")
PY
for c in C1-audit-reject-all C2-step-reject-all C3-step-commit-all C4-drop-history C5-create-no-key-check C6-drop-A5Ledger; do
  (diff -u ../Restart.dfy $c/Restart.dfy; diff -u ../KeyedStore.dfy $c/KeyedStore.dfy; diff -u ../src/SinkCoreV3.dfy $c/src/SinkCoreV3.dfy) > $c.diff; done
for x in "C1-audit-reject-all Restart" "C4-drop-history Restart" "C6-drop-A5Ledger Restart" "C2-step-reject-all Restart" "C3-step-commit-all Restart" "C5-create-no-key-check KeyedStore" "C2-step-reject-all KeyedStore" "C3-step-commit-all KeyedStore"; do
  set -- $x; $D/logs/run.sh $C/$1 $1-$2 300 $2.dfy --dev | tail -c 110; echo
  grep "): Error" $D/logs/$1-$2.log | sed -E 's/^[^(]*\(([0-9]+),.*Error: (.*)/\1 \2/' | while read ln msg; do lm=$(awk -v L=$ln 'NR<=L && /^ *(lemma|function|predicate)/ {n=$2} END{print n}' $C/$1/$2.dfy); echo "   line $ln [$lm] $msg"; done
done
