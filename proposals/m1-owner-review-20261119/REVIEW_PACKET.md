# M1 owner-review packet (prepared 2026-11-19)

CURRENT none. Stage 9 deferred. M1 OPEN. Stage 12 unauthorized.
`end_to_end=false`. This packet approves nothing and proves nothing.
It puts the open M1 decisions in one place for the owner. Its sources
are the M1 records of 2026-11-16 to 2026-11-18; I copied their
statements and did not run a proof again. Entry: `unsure.md` U471.

Source files (on branch `backup/forge-local-2026-11-11`, under
`proposals/refund-executable-feasibility/`; not on `main`):
`m1-profile-decision-20261116/M1_PROFILE_DECISION.md` (U402),
`m1-profile-a-statement-20261116/M1_PROFILE_A_RESTRICTED.md` (U403),
`m1-profile-a-slide0-20261117/A8_CONTRACT_REVIEW_MATRIX.md` (U404),
`m1-closure-audit-20261116/` (U401). On `main`: the replay report
`proposals/refund-executable-feasibility/m1-chain-replay-20261118/REPORT.md`
and the [conformance report](../forge2-m1-conformance/REPORT.md).

## 1. What M1 is, in four sentences

One refund decision program was written in the Dafny subset that
CakeML reads, compiled by the proved CakeML compiler to ARM64 code, and
linked to the executable `b8ed5ec2…7bb8`. HOL4 theorems connect that
exact code, in a machine model and under explicit premises, to the
output `refund_render_fields (refund_fields …)`. M1 closes when that
connection reaches the APPROVED refund contract (R1 to R5) under an
APPROVED list of assumptions, and independent replays confirm the
proofs. None of the three is done.

The executable already exists and runs. Closing M1 builds no new
binary. It turns "a program with a proof chain that has open ends" into
"a program with a stated, approved and replayed claim".

## 2. Decision 1: Profile A (the list of assumptions)

A profile is the list of things the M1 claim ASSUMES. No profile is
approved. The records recommend Profile A (U402); Profile B would
change the approved contract.

| # | Under Profile A the claim ASSUMES | In plain words |
| --- | --- | --- |
| 1 | the published CakeML FFI oracle `basis_ffi` | the model of the operating system's file calls is the standard CakeML one |
| 2 | no OS read error on an open readable descriptor | a read that fails with `EIO` or `EINTR` is OUTSIDE the claim (a named exclusion) |
| 3 | no other thread, process or signal changes the descriptors | |
| 4 | `wfcl`, `wfFS`, `STD_streams`, live `numchars` | a well-formed command line and file system model |
| 5 | a canonical wire request on standard input | one spelling per value; Wave Gate 1 showed that the reader also takes `040`, `+40`, `"40"` |
| 6 | the machine state satisfies `installed` | code, data and heap are where the theorem says |
| 8 | the native C code of the CakeML basis behaves as the model | proposed as ONE simulation assumption, because the literal premise is probably false for the real C code (U393) |
| 9 | no interference between machine steps | |
| 10 | the processor is the L3 ARMv8 model; the loader gives the stated layout | |
| 13 | the HOL4 kernel, Poly/ML, the published CakeML and L3 definitions | trusted |

Not assumed: a resource bound (the theorem allows a stop at a resource
limit with a prefix of the output). Row 7 (installer exclusion) is a
conclusion, not an assumption (U386 to U392).

Questions for the owner (U402 Q1 to Q6; none is answered):

- **Q1.** Approve Profile A, Profile B, or neither?
- **Q2.** If A: approve the exclusion of OS read errors (row 2)?
- **Q3.** If A: approve three additions that the first profile text
  lacks: (a) the entry-state assumption (loader and C run-time reach
  `cml_main` with the image mapped at some slide); (b) row 8 as one
  simulation assumption; (c) the file reader and offset tool of U389 as
  trusted?
- **Q4.** May the link from the approved contract to the HOL model be a
  named, independently REVIEWED assumption (section 3), or must it be a
  machine-checked translation before M1 closes?
- **Q5.** Absent standard input: inside the claim (then it is a proof
  obligation, open since U388) or a named exclusion?
- **Q6.** Time and authorization for a clean replay and for an
  independent replay (section 5).

What Profile A does NOT give, whatever the answers: a claim about the
physical processor, the loader, `libSystem` or the kernel. Those stay
assumptions. It gives a "level B" claim in the words of U401: model
theorems under a stated, approved profile.

## 3. Decision 2: the 18 rows that link the approved contract to the HOL model

No tool relates a Dafny term to a HOL term. Each row is a claim that
two texts mean the same thing. The record asks for a reviewer who is
NOT the proof author. All 18 rows are NOT REVIEWED (U404).

The last column is new. It says what the finite conformance test of
Wave Gate 1 observed for the row (2,466 vectors, compiled Dafny against
the executable). It is test support, NOT a review, and it cannot
replace one: the test compared two programs, and its renderer uses the
same reading as the row.

| # | Dafny side (approved or boundary) | HOL side | Review status | Finite test support (Wave Gate 1) |
| --- | --- | --- | --- | --- |
| 1 | `int` | `:int` | NOT REVIEWED | integers from −2^256 to 10^100 gave equal decisions |
| 2 | `bool` | `:bool` | NOT REVIEWED | all eight flag combinations |
| 3 | `seq<nat>`, elements below 256 | `mlstring` through `MAP ORD ∘ explode` | NOT REVIEWED | texts compared as UTF-8 bytes |
| 4 | `Codes(U.Encoded(chargeId))`, `…(requestId)` | `charge`, `request` | NOT REVIEWED | 44 hostile texts as ids, Unicode limits included; byte strings that are not UTF-8 were NOT tested |
| 5 | `MaxMoney = 9223372036854775807` | the same literal in `eligible_def` | NOT REVIEWED | Max−1, Max, Max+1 |
| 6 | `ValidContext` | the conjuncts of `eligible_def` | NOT REVIEWED | every bound at its value and one below and above; five wrong variants of these conjuncts were found by the test |
| 7 | `response.Candidate?` | `candidate : bool` | NOT REVIEWED; check that R3 gives one fallback for all six other constructors | 427 vectors: all six constructors gave the bytes of the M1 rejection |
| 8 | `0 ≤ amount ≤ remaining` | the same | NOT REVIEWED | bounds at their value and one below and above |
| 9 | `AllowedReason`: three strings | three `mlstring` literals | NOT REVIEWED | 30 near-miss reasons |
| 10 | `Decision` and `plan` | the six-tuple | NOT REVIEWED | the rendering of the Dafny result equals the M1 bytes; the renderer encodes this row's reading, so this is consistency, not independent support |
| 11 | R1 | follows from `eligible` | NOT REVIEWED | — |
| 12 | R2 | follows from `eligible` | NOT REVIEWED | — |
| 13 | R3 | `¬ok ⇒ (F, 0, «», «», «», 0)` | NOT REVIEWED | 2,040 rejected vectors |
| 14 | R4 | `ok ⇒ (T, amount, reason, charge, request, 1)` | NOT REVIEWED | 426 authorized vectors |
| 15 | R5 | count is 1 iff `ok` | NOT REVIEWED | as rows 13 and 14 |
| 16 | the formula text in `Boundary.dfy` | the statement of `byte_fields_result` | NOT REVIEWED; the author did not compare them line by line | none: the test does not read these texts |
| 17 | `Boundary` is tied to the approved `Assess` | — | NOT REVIEWED; NOT RE-AUDITED | none |
| 18 | wire text: decimal integers, `True` / `False` | `refund_request_def` | NOT REVIEWED | the reader also takes other spellings of a number and quoted atoms; the producer of the wire text stays outside the claim |

What the owner decides here: who reviews the 18 rows (U403 R2), and
whether a dated review record is enough (Q4). Rows 16 and 17 need a
person to read two proof texts; no test helps there.

## 4. Compiler premises and the slide

| Item | State in the records | Open |
| --- | --- | --- |
| `backend_config_ok`, `mc_init_ok` | discharged inside the U386 proof scripts from the published `arm8_backend_config_ok` and `arm8_init_ok`; `opt_eval_config_wf` by its definition (found by reading, U402) | the final theorems do not have them as premises; they must pass again in a clean replay. Not run again since |
| Output equation in the composed theorem (O3) | proved at slide 0 for every environment record that satisfies `refund_env_ok` (U404) | — |
| Slide-generic chain (O2) | steps S1 to S6 proved in the model for every page-aligned, non-wrapping slide; `refund_profile_a_sl` (U405, U407, U409) | one run each; U409 had no repeat and no separate import check at that time |
| Joint premises (O4) | the eleven premises of `refund_profile_a_sl` hold together for ONE constructed state at slide 0x4000 (M1R-1, theory `forge_refundInputSat`) | every permitted slide; the state is constructed, not observed |
| The 95 theories of the chain | replayed with byte-equal exports on rebuilt tools, same machine (M1R-1, M1R-2) | a clean replay; an independent replay |
| The 158 recorded controls, repeats and import checks | see section 5 | |

`refund_env_ok_sl` (row 8 of section 2) is an ASSUMPTION of the final
theorem and is "probably false for the real C code at every state"
(U393, U409: an analysis, not a theorem). That is why Q3 (b) asks for
the simulation form.

## 5. Replays

| Replay | State | Size |
| --- | --- | --- |
| 158 recorded cases (55 controls, 61 repeats, 42 import checks) on this machine | STARTED 2026-11-19 04:02Z as a background job on the pasted instruction (U471): plan, restored sources and a dry-run check are done; NO case had run when this row was written (04:24Z), because the job waits for mains power. The result goes into a later entry | recorded wall times sum to 11,144 s |
| Clean replay (fresh checkout, tools rebuilt from the pins, no old cache) | NOT RUN; needs Q6 | measured parts sum to about 26,000 s (tool build 6,238 s, chain 8,423 s, the 158 cases) |
| Independent replay (another machine and operator) | NOT RUN; needs Q6 | not on this machine |

## 6. The shortest order (from U402, with today's state)

1. The owner answers Q1 to Q5.
2. The 18-row review (section 3), by the reviewer that the owner names.
3. One acceptance statement with its premises and controls (O4), for
   every permitted slide.
4. Clean replay; then independent replay (Q6).

Until Q1 is answered, no proof step changes the M1 status (U402).
