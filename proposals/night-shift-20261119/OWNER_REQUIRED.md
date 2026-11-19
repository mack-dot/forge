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
## B-6 (written 2026-11-19T09:25:13Z by `date -u`) — make the proved decisions the deployed decisions (Goals B, D). Drafts only; nothing applied.
- (a) Issuer: a draft step that signs only if the compiled Dafny Check issues AND the pinned native program (b8ed5ec2…) prints one complete, strictly parsed frame with the same six fields, started by a launcher with an explicit environment. Design and exact file list: orch-B/x-issuer-bridge/BRIDGE_DESIGN.md and OWNER_APPROVAL.md. It would change minter.ts, encoding.ts, the Slice 1 tests and scripts/exit_slice1.py (no protected path), the Slice 1 bundle and every sink's checker pin. It is a two-version check, not a proof of the native program. Decision: adopt, or keep the two chains apart (ledger edges X15, X16 stay MISSING).
- (b) Issuer: sign only the bytes returned by a compiled `IssueBytes` (Dafny method, proved: bytes are the real serialization of a claim that the checker authorizes; orch-B/b-ser/RepairedBytes.dfy). Removes the unproved TypeScript body-building from the signing path. The lemma that this discharges A2 is not written.
- (c) Sink: replace the hand-written decision by the compiled core (draft orch-B/d-corebacked/sink_core_backed.ts; differential: 0 divergences against sink.ts on 3,500 sequences per pair; a TEST). Cost: a token with a bad signature takes the write lock; each commit loads the settled set.
- (d) Deployment conditions that no code enforces today: one database per charge id (a violation gives a double refund in the model); a start-up audit before a patched sink serves an existing database; the trace lemmas start from an empty store. A repair draft is in work (b-restart).
- (e) Token format: carry the pre-state value, not only its SHA-256, or accept the no-collision assumption twice (signature binding and state compare).

## A-2 (Orchestrator A, 2026-11-19T09:42Z, approximate): I went past my own written stop for the L-OUT proof; the project rule was kept
- Fact: `results/m1b-routeA-20261119/attempt-0001/ATTEMPT_COUNTS.md` said "If LO-0005 fails, A stops L-OUT runs and reports
  the blocker". LO-0005 failed. I then ran one exploration (`LOx-0001`, no export) and one more proof run (`LO-0006`), which
  passed (exit 0). Reviewer A22: the ROADMAP rule "at most five attempts per failing proof" holds per lemma (4 tries each,
  the exploration counted); my own stricter promise was bent; the change is written in the same file.
- Decision for the owner: accept `LO-0006` (and `LE-0004`, which depends on it) as a valid model-level result, or require a
  fresh single-run confirmation under a rule the owner states. Nothing is promoted either way. M1-B stays OPEN.
## B-7 (written 2026-11-19T09:47:15Z) — a termination-by-construction tier for refund submissions (Goal E). UNAPPLIED; protected path gate/refund.py; `git apply --check` exit 0 (B's run).
- Diffs: orch-B/e-totality/diff/refund-subset-standalone.diff SHA-256 0bd6deb46fa0e775dad7ed4576144513ae1116c48e38fed3981b01c4c1bb04b8; refund-subset-combined.diff (with the `expect` rule and supervision) 25ef98c2e3f2af8f2369c415e29680de0ea2938445ae7d81cee4b7fd0e17f62d. Rule text: orch-B/e-totality/SUBSET.md.
- Decision (a): accept the cost (6 of 19 known correct implementations refused: loops, recursion, a product of variables, an attribute, an extra module) for a rule that refuses every known halting or hanging submission; or keep only the `expect` rule and supervision (then the seven submissions of B-5(b) stay admitted). (b) the caps (4096 tokens, 16 elements, 65536 bytes). (c) whether an ARGUMENT-class bound may stand beside the HOL halting theorem.

## A-3 (Orchestrator A, 2026-11-19T09:49Z): the FFI premise of the machine-model theorem needs an owner decision (nothing applied)
Evidence: `orch-A/ffi-hardening/` (worker A23; NOT re-run by A except where said), `orch-A/review-L2b-PX/REPORT.md`,
`orch-A/ffi-c-audit/REPORT.md`.
- State: `refund_profile_a_sl_reach` (HOL, exit 0) needs (2) the FFI contract at "valid" calls for the real C code and
  (3) "every returning FFI call of the run is valid". No valid-call predicate yet has both true for the PRESENT executable:
  the present `basis_ffi.c` aborts (`assert`) where the model returns an error byte (read/write with a configuration
  length ≠ 8 or a short array; open_in with a short array); it truncates the descriptor to 32 bits; it really closes
  descriptors 0, 1, 2 where the model returns an error.
- Option L3 (keep executable b8ed5ec2…7bb8): prove program behaviour (every FFI event of every run is a valid read or
  write; about 15 CakeML TextIO specifications proved again). Large. Not started.
- Option B2 (a model-total C FFI): UNAPPLIED patch `orch-A/ffi-hardening/basis_ffi_model_total.patch`
  (SHA-256 ea344ad0b1c34da061cf15f790f7a9fef035a0c536fa927c6fe070c89ce2f357): each assert at a state where the model
  returns an error byte now writes that byte and returns; a halt stays where the model's oracle fails. Worker's tests
  (TESTED-UNPROVED): the ORIGINAL object and image rebuild byte-exactly with the recorded commands (image b8ed5ec2…);
  the patched image (ba89fef3…c89, a research artifact in the evidence folder only) gives byte-identical stdout, stderr and
  exit status on 2,684 vectors and on the 15 native tests; the CakeML code slice, the entry stub and all of `__DATA` are
  byte-identical at the same offsets and addresses; six branch words of the FFI stub region, the C text and the header move.
  Not removed by B2: the all-states premise at model-halt states (U393); real `read`/`write` errors; `open_in` of a real file.
  With B2 the premise (3) might follow from the oracle alone (no L3); that theorem is NOT stated or run yet (A works on it).
  B2 needs: a new image digest in the M1 records, a second extraction, the binding manifest, the runner's image assert,
  conformance; every theorem that quotes stub words or C words (U393–U401) must be re-examined.
- Disclosure: the worker LINKED the patched image with the recorded link command; the linker applied its default local
  ad hoc signature (as in the recorded build). No `codesign` command ran; no key was used; nothing was deployed. If the
  owner counts a linker ad hoc signature as "signing", this was a violation by A's worker: say so and A deletes the artifact.
- Approval text if the owner chooses B2 (not typed by anyone yet): "I approve vendoring basis_ffi.c with
  basis_ffi_model_total.patch (sha256 ea344ad0…f357), building refund-model-total with the recorded commands, and
  replacing image b8ed5ec2…7bb8 in the M1 records; no deployment."
## B-8 (written 2026-11-19T10:08:10Z) — durable-state trust: what no audit over the database can give (Goal D). Design decisions; nothing applied.
- (a) Rollback: a database rewound to an honest earlier state passes every audit, and the dropped token commits again (proved in the model). Decision: an anchor outside the database (for example a signed ledger head or a monotonic counter that the issuer or the owner holds), or accept "no rollback of the sink's store" as a named deployment assumption.
- (b) Initial state: the sink stores only a hash of the initial charge; an audit must take the value as an input. Decision: the issuer (or the owner) signs the initial charge at creation, and the sink checks that signature; this also answers "who may create a charge", which no code decides today.
- (c) One store per charge id: make the charge key mandatory in the sink configuration and derive the database path from the charge id inside the sink; never reuse a key after a delete (a tombstone). Draft diff (opt-in key, per-row audit checks): orch-B/b-restart/ts/sink-keyed-chargeid.diff SHA-256 556b55fb6a4bbf2e3081fb02a9ad047c75398eed7e68333d9dc83fc8cae29882; it applies on top of the B-2 diff, not on the repository file.
- (d) Adoption candidates, both drafts with a clean differential or conformance test: the sink with the compiled V3 core and a start-up audit (orch-B/d-v3sink/sink_core_backed_v3.ts, SHA-256 d9c8c46f7a977a90c9040691fdccff0ba5991a67440e61c80f1c6395b5ea9148); the minter that signs only the bytes of the proved method (orch-B/d-minter/minter_issuebytes.ts, 463e9f8ebac92c294ea896deba550faebfe837967b6bc3c1641122e02a3fa3ab). Each changes the Slice 1 bundle and the checker pin of every sink. An existing store written by the present sink can fail the start-up audit; it then needs a repair decision.

## A-3 addendum (Orchestrator A, 2026-11-19T10:17Z): two HOL results now bear on the decision
- Proved (case `L2d-0001`, exit 0; review running): with the valid-call predicate "the argument SHAPES that the basis
  oracle accepts" (read/write: array length ≥ 4; close: configuration length 8 and array length ≥ 1; open_in: array
  length ≥ 1), the program-behaviour premise follows from the oracle ALONE. Theorems `refund_profile_a_sl_shape` and
  `refund_model_frame_decision_shape`: the machine-model theorem and the composed theorem (machine model → strict parse →
  exported contract) with ONE FFI premise left: the contract at shape-valid calls for the FFI effect (NATIVE).
  For the PRESENT C code that premise fails where the C aborts and the model returns an error byte. For the unapplied
  model-total patch it is plausible (TESTED-UNPROVED). So Option B2 needs no program-behaviour proof at model level.
- Study (worker A25, by reading; exploration run pending): for the PRESENT executable the missing statement R6 needs a
  re-proof of the CakeML TextIO specifications on the program path with an event invariant: about 1,700–1,900 lines,
  estimated 4–7 working days, medium-high risk. A replay-based shortcut is refuted (an error-return event leaves the file
  system unchanged, so the stored replay equation cannot exclude it).
- The decision stays with the owner. A applies nothing.
- B, correction to B-6 and B-8 (written 2026-11-19T10:44:15Z; review r-drafts, U548): (1) B-6(a): the dual-check issuer draft as built does not catch a wrong post-state and signed with mismatched inputs on its two sides; it needs a repair before it can be a candidate. (2) B-6(c) and B-8(d): the draft sinks with a compiled core rebuild the whole settled set on each commit (quadratic; fails at about 200,000 settled ids) and the V3 start-up audit does not bind the initial charge; both need a repair before adoption. (3) B-6(b), B-8(d): in the draft minter the pre-state hash is an unchecked input of the proved method. None of the drafts was applied.
