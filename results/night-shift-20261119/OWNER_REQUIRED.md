# OWNER_REQUIRED (append only; A- and B- items). Nothing here is executed by an agent.

## B-1 (2026-11-19T08:02Z) — request-ID check in the merged sink and dispatcher (Goal D)
- Fact: `ts/refund-finality/sink.ts` commits a signed token whose body request id differs from its intent's request id; an honest token for the intent's id commits after it; the dispatcher then sends two refunds for one request id. Needs a trusted but faulty signer; the real issuer refuses such transitions. Proved as a Dafny counterexample on the unchanged core (worker run; B's re-run pending) and shown by Node runs on copies with test keys.
- Proposed (UNAPPLIED; `git apply --check` exit 0, run by B at 985f5eaf): `orch-B/d-reqid/diffs/sink-reqid.diff.orig-copy` SHA-256 0f111954bcfa05c8d99a35cd003d4f2ac16a422a818b036c51c757da5035a45e; `dispatcher-reqid.diff` 49704aa171fc4a621dd5e84deb5357e1e6e139ce1db6309d775522844bd525dc.
- Decision needed: approve the exact diffs. `ts/` is not a protected path, but the change alters the recorded Slice 1 and Slice 3 bundle digests; their records must be made again.
## B-2 — charge-ID binding in the sink (Goal D; a POLICY decision)
- Fact: intent.chargeId and post.chargeId are not bound to the stored charge in sink.ts or in the Dafny core (lemma ChargeIdNotBound, worker run). A faulty signer could release an effect for another charge.
- Proposed (UNAPPLIED, check exit 0): `sink-reqid-and-chargeid.diff` 3ce2a48c988cbf44b8ca830a980a120018a867f498d662a783236f0fbd6f9d54 (or `sink-chargeid-on-top-of-reqid.diff` 340f85cbc94970bac60a1f55bd53ab3184c386eacbf734fa95ebfdd9d7d5f489 after B-1). The sink would then hold an identity rule; the core needs the same check (not written).
## B-3 — admission authority (Goal G). Full text: `orch-B/g-admission/OWNER_ACTIONS.md` (steps O1 to O12, each with a negative test and a rollback)
- Facts read tonight by GET: `main` is unprotected; ruleset endpoints return HTTP 403 (plan limit); pull request 58 has a FAILURE check and can be merged; this machine's agent sessions can act as the owner account (admin).
- No ruleset can be applied before O1 (plan). O3 to O5 remove the owner's credential from the agent. O8: `orch-B/g-admission/proposal-B2/admission-option-B2.diff` SHA-256 4e02fddbbeade631c58bf9189469c0e9fc34c0d602a2b271f0170dbcf5f34056 (protected path gate/; check exit 0 by B; NOT applied).
- Two open design points even after the rulesets: (a) the required check is pinned to the GitHub Actions app id, not to a workflow; (b) an approval record is accepted when it is on `main`, without an owner signature (two-PR route). O11 (a hardware approval key) addresses (b).
## B-4 (08:50Z) — additions to B-1 and B-2 from the adversarial review (orch-B/r-reqid)
- B-1 needs a start-up step: before a patched sink serves an EXISTING database, run the patched audit and refuse to start on any "request id" problem. Without it, a store written by the unpatched sink can still yield two effects for one request id (proved in Dafny; shown by a Node run on copies).
- B-2 is more than hardening: without the charge-id check, a faulty signer can cause two refunds for one charge and one request id through another charge's store (proved in Dafny on the model). Recommended: approve B-1 and B-2 together.
- Digests that change if applied: proposals/forge2-slice1-refund-finality/records/evidence.json (sink, dispatcher), links-final.json, regression.json; the binding manifest draft. No protected path.

## A-1 (Orchestrator A, 2026-11-19T08:47Z): the swap rule of PROTOCOL.md was broken by A; a rule decision is needed
- Fact: PROTOCOL.md says "Swap free < 1 GB: start no heavy step". A's wrapper checked battery and other HOL processes only.
  Ten HOL cases started between 08:31Z and 08:45Z with 503 to 759 MiB swap free (start state in each `<case>.go.log`,
  folder `results/m1b-routeA-20261119/attempt-0001`): PF-0001, E1-0001, E1-0002, E1-0003, E1neg-0001, L2-0002, L2-0003,
  L2b-0001, LO-0002, LO-0003, PF-0002. None of them ended with the Poly/ML "Run out of store" message. Their exit codes
  are real. Two passing results fall in this group: E1-0003 and L2-0003.
- Correction made: the wrapper `nightshift-run.sh` now refuses a start below 1024 MiB swap free (exit 96).
- Effect: at 08:47Z swap free is 799 MiB (total 7168 MiB; memory free 65 %; AC power). The HOL queue waits.
- Decision for the owner (not taken by A): keep the 1 GB swap rule as written, or replace it for HOL runs by the recorded
  runner guard (`memory_pressure` free ≥ 25 % and no other HOL process). macOS changes the swap total by itself
  (11264, 9216, 8192, 7168 MiB were seen tonight), so "swap free" is not a fixed capacity. A does not change the rule.
- Optional owner action to confirm the two passing results: run E1-0003 and L2-0003 again when swap free is above 1 GB
  (A will do this by itself when the condition holds).
## B-5 (10:15Z) — gate admission: the `expect` rule, run-time halts without `expect`, and resource supervision (Goal E). All diffs UNAPPLIED; `git apply --check` exit 0 each (B's run at 985f5eaf). Evidence: orch-B/e-expect.
- (a) The `expect` rule of report G1 (gate/refund.py, protected): diff SHA-256 70910e2ec3f3139f5f0ea7635a0bba4cc2b571e3f4bbb9b0baf94be6811c9ce3. Reproduced: 75 of 75 stored verdicts; 0 false refusals of 19 correct implementations; no lexer bypass found in an attack round. Known fail-closed costs: an identifier like x'expect, a form feed or a Latin-1 byte in a comment are refused.
- (b) NOT covered by the rule, admitted by every tier today: a submission that halts at run time on one keyed amount with no `expect` (H04: `seq(4294967296, …)` throws RangeError in the JavaScript runtime; H01b: a `:|` search of about 10^18 steps). A rule for this class is a POLICY decision: a restricted subset for refund submissions, or the HOL/CakeML route. A subset checker draft is in work (e-totality).
- (c) Supervision: no timeout, no process-group kill and no output cap in gate/refund.py run(), backends/dafny.py, booking.py, backends/typescript.py, scripts/javascript_env.py, incremental.py and pr_check.py (the last two FROZEN: they need a ratification record). Diffs: refund-supervision 62cd51e6…, combined refund-expect-and-supervision 613309b7e2c236dfd3070be621802346dff4825b57f49add8fc55d6644418470, dafny db8468ce…, booking f5874df4…, typescript 4cdffe56…, javascript_env 1b59e0e3…, incremental acc82339…, pr_check a57c0796…, m1_fail_closed 091d875a…. One verdict change: a step killed by a signal becomes RESOURCE_LIMIT (exit 1). The timeout values are guesses. Memory is NOT bounded (macOS does not enforce RLIMIT_AS).
- Also: the `implementation.lock` entry for gate/refund.py is already stale (9d91b754 against bafc1b72, per the worker).
- B, correction (09:04Z by `date -u`): the times in the headings of B-1, B-4 and B-5 ("08:02Z", "08:50Z", "10:15Z") were estimates and run ahead of the clock. The items were written between 07:59Z and 09:00Z. Their content is unchanged.
