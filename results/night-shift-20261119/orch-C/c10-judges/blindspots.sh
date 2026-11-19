#!/bin/bash
# blindspots.sh: runs the confirmed blind-spot mutants (c10-judges) through BOTH judges of commit 1481d818
# (tests/refund-finality/regress/run.ts and tests/refund-finality/spec-conformance/run.ts seq 200 1).
# A mutant is "passed" by the regress judge when it adds no FAIL line to the FAIL set of the plain v6 sink (the
# baseline; the v6 baseline already FAILs X6-Z1, so the regress exit code is 1 for every v6-based input), and by the
# spec judge when sequencesWithViolation holds nothing but P5-SILENT (the v6 baseline; run.ts exits 0 always).
# The spec judge does not load a dispatcher: dispatcher mutants count as passed by it.
# Exit 1 if ANY mutant is passed by both judges (a judge blind spot is present); 0 otherwise.
# Each mutant's defect is shown real by confirm.sh (exit 1 = defect) with the plain v6 as control (exit 0).
EV=<REPO>/results/night-shift-20261119/orch-C/c10-judges; V=$EV/v6/ts/refund-finality; cd $EV || exit 3
LIST="base_v6|sink|dispatcher|v6 m_accept_bad_sig|m_accept_bad_sig|dispatcher|v6 m_accept_noncanon|m_accept_noncanon|dispatcher|v6
m_skip_prestate|m_skip_prestate|dispatcher|v6 m_replay_says_rejected|m_replay_says_rejected|dispatcher|v6 m_replayed_any|m_replayed_any|dispatcher|v6
m_id_gt32_or_nonascii|m_id_gt32_or_nonascii|dispatcher|v6 m_late20|m_late20|dispatcher|v6 m_wipe_on_open|m_wipe_on_open|dispatcher|v6
md_ignore_sig|sink|md_ignore_sig|v6 md_ignore_chain|sink|md_ignore_chain|v6 md_emit_before_ledger|sink|md_emit_before_ledger|v6
enc_unsigned_body|sink|dispatcher|enc"
i=0
for e in $LIST; do IFS="|" read tag s d t <<< "$e"
  ./judge.sh $EV/$t $EV/$t/ts/refund-finality/$s.ts $EV/$t/ts/refund-finality/$d.ts bs-$tag &
  i=$((i+1)); [ $((i % 4)) -eq 0 ] && wait     # at most 4 judge pipelines at once
done; wait
python3 -I - "$EV" $(for e in $LIST; do echo "${e%%|*}"; done) <<'PY'
import json, re, sys
ev, tags = sys.argv[1], sys.argv[2:]
def reg(t):
    L = open(f"{ev}/logs/bs-{t}.regress.log").read().splitlines()
    return {l.split(":")[0].split()[1] for l in L if l.startswith("FAIL ")}, sum(1 for l in L if re.match(r"^(PASS|FAIL|KNOWN-LIMIT) ", l)), L[-1]
def spec(t):
    j = None
    for l in open(f"{ev}/logs/bs-{t}.spec.log"):
        if l.startswith("{"): j = json.loads(l)
    return None if j is None else {k: v for k, v in j["sequencesWithViolation"].items() if k != "P5-SILENT"}
base, nb, _ = reg("base_v6"); both = 0
print(f"baseline v6: regress FAIL={sorted(base)} lines={nb}; spec non-SILENT={spec('base_v6')}")
for t in tags[1:]:
    f, n, ex = reg(t); sv = spec(t); new = sorted(f - base)
    rpass = not new and n == nb; spass = (sv == {}) or (t.startswith("md_") and True)
    verdict = "PASSED BY BOTH (blind spot)" if rpass and spass else "caught"
    both += verdict.startswith("PASSED")
    print(f"{t:24s} regress newFAIL={new or '-'} lines={n} {ex} | spec={sv if not t.startswith('md_') else 'no dispatcher in spec judge'} | {verdict}")
print(f"# mutants passed by both judges: {both}")
sys.exit(1 if both else 0)
PY
