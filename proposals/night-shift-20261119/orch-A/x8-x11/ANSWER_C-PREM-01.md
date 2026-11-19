# Answer to red-team finding C-PREM-01 (four static findings on the X8/X11 draft) — Orchestrator A, 2026-11-19T15:10:27Z
All BY READING. Nothing here is machine-checked. v2 = `x8-x11/X8_statement_v2.txt` (sha256 77822531d7ea…9a22).
A separate adversarial review of v2 runs (`review/X8_v2_review.txt`, pending). v1 is unchanged on disk.

| # | Finding (C) | A's answer | Evidence | State |
|---|---|---|---|---|
| 1 | The L3 model reads SCTLR_EL1.A and PSTATE bits at EL0; `erase` keeps them; v1 took them from a constant | ACCEPTED. v2 takes every system-register bit from the REAL values `sr`; only TBI0, TBI1, SA0 are erased. New native assumption N03 A-F0-REAL: the kernel keeps every system-register bit that the model reads constant over the run | v2 lines 96-117 (abstraction), 163-168 (N03); `erase` definition and `erase_fields` from E1-0003 `stdout.log` lines 3-6, 28-35 (go exit 0) | OPEN as ASSUMPTION. Not observable at EL0; no launch control can enforce it. Falsifier named in N03 |
| 2 | Index error: `next_interfer` advances on normal steps only; the trace has the 27 entry instructions | ACCEPTED. v2 indexes the constructed function by the count of NORMAL model steps (section 1.2, 1.4); lemma T-ENTRY27 and T-TRACE carry the index | v2 lines 82-95, 118-140; lemma ML-10, ML-11 | MISSING lemmas (T-TRACE draft in work, `orch-A/trace/`; not run) |
| 3 | Clause (f) is false for killed runs (bytes of a write that never returned can be in the pipe; PIPE_BUF 512, chunks to 2048) | ACCEPTED. v2 weakens the clause (W2): the observed stdout is a prefix of `fd1_written` of an EXTENSION of the observed events. New assumption N13 A-FD1-PARTIAL | v2 lines 207-210 (N13), lemmas ML-12 T-KILLED-PREFIX, ML-13 T-INFLIGHT, clause W2 | MISSING lemmas; N13 ASSUMPTION |
| 4 | Overclaim: "strict parse implies correct" has no fail-closed argument when a native premise fails; CE-3 falsifies it for the loader | ACCEPTED. v2 removes the sentence (W1). Scope line: the theorem concludes NOTHING when a native premise fails. Seven premises are classed ENFORCED-BY-LAUNCHER (N09, N11, N14, N15, N20, N21, N22) | v2 line 407, 448 (W1) | OPEN: the launcher is NOT implemented; today those seven are assumptions. Launch-path control work started (`orch-A/launch/`) |

Not answered by a proof: none of the four. Each is now either a named assumption with a falsifier or a missing lemma.
