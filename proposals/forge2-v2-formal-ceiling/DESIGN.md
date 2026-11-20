# Formal Ceiling v2: design and estimate for R6 FFI (T9), TBI0/SA0 (T11) and the WAL fold (F2.7)

Status: DESIGN and ESTIMATE only, 2026-11-20. NOT STARTED. `end_to_end=false`. M1-B OPEN.
CURRENT none. Stage 9 deferred. Stage 12 unauthorized. Base: `origin/main` = `b2249ea2`.
This record approves nothing, decides nothing and starts nothing. It waits for the owner's
budget word.

No HOL process, no `Holmake`, no `cake_compile`, no Dafny run and no build ran for this record.
No file other than this one changed. Method: reading of committed files, and static commands
(`git show`, `grep`, `wc`, `awk`) by the orchestrator and two read-only workers. One
fresh-context adversarial review; its 21 findings and the repairs are in section 9.

## 0. The request, and the short answer

Owner's request (as the launcher gave it to this session): "Formal Ceiling (v2 — ~3–4 Weeks if
You Want end_to_end=true on Refund): Fix M1's true user-space premises (R6 FFI + TBI0/SA0) and
fold the 64-byte WAL check into CakeML (F2.7) so sink.rs isn't needed in the Refund path at all."

Short answer, in four points. Each point has its evidence in the sections below.

1. **The three items do NOT give `end_to_end=true`.** After all three, 17 transitions are still
   neither MACHINE-CHECKED nor a signed assumption; up to 20 by a stricter reading (section 3).
   The rule is in section 1.
2. **R6 and T11 each have a native part that no proof in this repository closes.** R6 closes
   only the model part of T9. The T11 run lift closes only the model part of T11. Each then
   needs a NEW owner signature (draft lines A7 and A8, section 5). The signed P6 excludes the
   processor bits.
3. **The WAL fold closes no transition of the present graph.** `sink.rs` is not in the graph. A
   folded binary is a NEW program image. For that image the machine chain of M1 must be made
   again (section 4.3). Unproved system-call code stays in the path; it has fewer checks in it.
4. **Order matters.** R6 and T11 work is partly bound to one image. If the fold is wanted, the
   image should be fixed first. Otherwise a part of the R6 and T11 work is done twice (4.3).

Evidence classes: MC = MACHINE-CHECKED, AS = ASSUMPTION, TU = TESTED-UNPROVED, MI = MISSING,
EP = enforced by an unverified prototype launcher.
"ESTIMATE (this record)" marks a number that I derived. It has no committed source. Its inputs
have sources, and the arithmetic is shown.

Names in this record. "Q-1" to "Q-8" are the questions of section 7. They are not the owner
decisions D-1 to D-6 of the night shift. "A7" to "A12" are DRAFT assumption lines; none is
signed. "R1 premise 8" is the FFI premise of theorem R1; A2README calls it P8.

Short names for sources:

- GRAPH = [TOP_LEVEL_GRAPH_REFRESH_20261119.md](../m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md)
- APEX2 = [TOP_LEVEL_GRAPH_REFRESH_20261119_APEX2.md](../apex2-contract-link-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119_APEX2.md)
- GAPS = [END_TO_END_GAPS_v2.md](../night-shift-20261119/orch-A/END_TO_END_GAPS_v2.md)
- FINAL = [orch-A/FINAL.md](../night-shift-20261119/orch-A/FINAL.md)
- OR = [OWNER_REQUIRED.md](../night-shift-20261119/OWNER_REQUIRED.md)
- F27 = [F27_ARCHITECTURE.md](../m1b-mission-20261119/drafts/F27_ARCHITECTURE.md)
- X8v3 = [X8_statement_v3.txt](../night-shift-20261119/orch-A/x8-x11/X8_statement_v3.txt)
- A2README = [apex2 README.md](../apex2-contract-link-20261119/README.md)
- G19 = [Goal 19 REPORT.md](../forge2-native-silicon-sink/REPORT.md)
- TEXT7 = [OWNER_TEXTS.md](../forge2-native-silicon-sink/OWNER_TEXTS.md), Text 7
- REPLAY = [M1 chain replay REPORT.md](../refund-executable-feasibility/m1-chain-replay-20261118/REPORT.md)
- D11 = [D11-processor-state-bits.md](../m1b-mission-20261119/reports/D11-processor-state-bits.md)
- G2 = [G2-processor-erasure-lemma.md](../m1b-mission-20261119/reports/G2-processor-erasure-lemma.md)
- AA = `proposals/forge2-finish-line/ACCEPTED_ASSUMPTIONS.md` on branch `docs/finish-line-directive`
  (`45c21aa1`). It is not on `main`, so it has no link here.
- BRIEF = `proposals/forge2-finish-line/APEX3_STEP3A_BRIEF.md`, same branch.
- U-numbers are entries of `unsure.md` on `main`.

## 1. The rule for `end_to_end=true`

AA, section "The rule this list serves": `end_to_end=true` may be stated for the refund slice
ONLY when every transition of GRAPH section 3 is MACHINE-CHECKED or a signed assumption of AA.
A transition that is MISSING, TESTED-UNPROVED or FUTURE WORK keeps `end_to_end=false`.

Signed lines (AA, owner's words of 2026-11-19T23:08Z): P1 covers T12k. P2 covers T14o. P3
covers T20. P4 covers T21. P5 covers T22. P6 covers "the CPU part of T11 and T13 only"; its
mitigation cell says: "the processor bits (TBI0, TBI1, SA0, EL0, E0E) remain a SEPARATE
transition (T11), not covered here."

A prior owner decision that this request touches. AA lines 32 to 33: "With the owner's time-box
(item 5), T9 (R6 FFI) and the APEX-3 WAL fold are recorded as FUTURE WORK. They keep
`end_to_end=false`." The request of section 0 would move both out of FUTURE WORK. That is the
owner's word to give (Q-1).

One note on P1. Its text says "on the sink's descriptors". The refund process reads descriptor 0
and writes descriptor 1. Whether P1 as written covers these is a question for the owner (Q-7).
I do not decide it.

## 2. What each of the three items is, mapped to the graph

| Item of the request | Graph object | What the item can close | What it cannot close |
| --- | --- | --- | --- |
| R6 FFI | T9 (links X6, X7) | the MODEL premise "every FFI event of every run is a valid read or write" for one image | the NATIVE contract of the real C code at valid calls (AS, unsigned) |
| TBI0/SA0 | T11 (link X11, X11e) | the MODEL run lift: the real-bit run and the erased-bit run agree (lemmas ML-05, ML-07, ML-08, ML-09) | the NATIVE rows N02, N03, N04 (real register values; AS, unsigned; never observed) |
| WAL fold (F2.7) | none today | a new HOL-level theorem about a new program | any present transition; kernel, drive, loader |

Sources: row X7 of GRAPH (line 60) and row T9 of GRAPH section 3 (line 134); T11 rows of GAPS
sections 2 and 2.1. "Neither graph file mentions sink.rs, silicon or Goal 19": command
`grep -c -i -E "sink\.rs|silicon|goal 19"` on GRAPH and on APEX2, 0 hits each (worker's run and
the reviewer's re-run, 2026-11-20).

## 3. Table (a): every transition that is not MACHINE-CHECKED and not signed

The launcher's list after the sign-off (AA, last note): MISSING are T4i, T9, T10, T11, T12, T13,
T16, T17, T18, T23, T24; T14a is TU; T19 is in progress. By the rule of section 1 the unsigned
ASSUMPTION rows block too: T2b, T3 (with T3p), T4, T15. AA itself lists them under "What this
list does NOT cover". They are in the table.

Column "3 items": does R6, the T11 lift or the WAL fold touch the row. Sizes "small", "medium",
"large" are quoted from GAPS section 7; that file gives no days for them.

| # | Transition | Class now | What closes it | 3 items | Estimate and its source |
| --- | --- | --- | --- | --- | --- |
| T2b | reader of the export bytes | AS; off the path of the contract link (APEX2 sec. 2) | owner signature, or a verified reader | no | NO SOURCE FOUND |
| T3, T3p | Dafny meaning = HOL meaning | AS, narrowed to BETA-PLAIN; its check is TU (APEX2) | owner signature of BETA-PLAIN (4 parts, A2README sec. 4) | no | signature only |
| T4 | exporter fidelity | AS; off the path (APEX2) | owner signature, or a rebuilt exporter | no | NO SOURCE FOUND |
| T4i | stdin bytes = `refund_request` of the nine values | MI | a HOL lemma on the input encoding, plus a caller-side check | fold makes it LARGER (stdin then also carries the WAL) | NO SOURCE FOUND |
| T9 | FFI premise | MI | model part: R6. Native part: a signature (A7), or the C patch plus a signature | R6: model part only | 7 to 12 working days for R6 (OR, A-3 addendum 2; U497). See 4.1 |
| T10 | entry state at `cml_main` | MI (ML-10 MI; N16 AS) | ML-10 (shares the T11 lift) plus a signature for N16 | T11 lift helps; does not close | "medium" (GAPS sec. 7 step 6) |
| T11 | processor bits | MI (one step MC; run lift MI) | model part: ML-05, ML-07, ML-08, ML-09. Native part: a signature (A8) | T11 item: model part only | see 4.2 |
| T12 | descriptors 0 and 1 | MI (parts EP) | ML-04 ("small", GAPS) plus a signed line for the EP rows (the launcher is unverified; owner item A-5) | no | "small" plus an owner decision |
| T13 | X8: the real process refines the model | MI: the smallest missing refinement boundary | 15 model lemmas ML-01 to ML-15 (0 stored) plus 23 native rows (17 AS, 6 EP; GAPS 2.2) | R6 and T11 give inputs (ML-05, 07, 08, 09; ML-15 is "R6-like") | 10 sized steps, small to large, and 1 owner step; no day number (GAPS sec. 7) |
| T14a | Python `frame.strict_parse` = HOL parser | TU | a verified or HOL-extracted parser | no | NO SOURCE FOUND |
| T15 | launch environment | AS (parts EP); C-1 permanently NOT RUN (D-6) | a signature that also covers the EP parts | no | owner decision |
| T16 | native result to issuer decision | MI in the deployed path | an issuer bridge in the deployed code (drafts x-bridge2, x-bridge3 are TU), then proof or signature | no (see section 5 for a re-scope) | NO SOURCE FOUND |
| T17 | issuer, token, sink, committed state, DEPLOYED code | MI | proof about deployed TypeScript and SQLite ("nothing is proved about any TypeScript", GRAPH row U5b), or a re-scope by the owner | no; `sink.rs` is not this sink | NO SOURCE FOUND |
| T18 | trust base; clean and independent replay | MI | a clean replay and a replay on an independent machine | no | NO SOURCE FOUND |
| T19 | hardened sink, minter, dispatcher on `main` | in progress (AA) | the owner's merge of its PR | no | not an item of this record |
| T23 | an admitted module terminates within a bound | MI: no sound static rule (GRAPH row E1) | a sound rule, or a signed limit | no | NO SOURCE FOUND |
| T24 | approval the agent cannot forge; enforced merge rule; separate trust domains | MI (GRAPH rows S1, E2, E4) | repository settings and a second trust domain: owner actions, not proofs | no | owner action |

**Count: 17 rows, or up to 20.** The 17 takes three rows as not blocking. Each is a choice that
the owner may read the other way:

- T7 is "MC earlier; UNCONFIRMED tonight" (GRAPH line 131). I count it MC because of the replay
  71 of 71 (M1R-1). GRAPH's own rule is "the class of a row is the class of its WEAKEST part".
- T8v is "MC for the shape antecedent only; none for MT1; no Success-with-frame witness" (GRAPH
  line 133). By the weakest-part rule it is not fully MC.
- T12k is counted as signed by P1. That depends on Q-7.

T8 is MC only under premises T9 to T13. T7, T8 and T8v are about image `b8ed5ec2…7bb8`. A new
image needs them again (4.3).

The three items touch 2 of the rows directly (T9, T11), each in its model part only. They give
inputs to 2 more (T10, T13).

## 4. Designs and estimates

### 4.1 R6 / T9 (c)

**Statement.** R6 is the premise `REMAINING_PREMISE_R6` of theorem
`refund_profile_a_sl_events` (case L2c-0001): every I/O event of every run of the machine model
from the entry state satisfies `refund_valid_event`. Source: FINAL lines 126 and 311;
`hol-runs/routeA-attempt-0001/L2c-0001/stdout.log` lines 402 to 413 (worker's read; the
reviewer confirmed it).

**Two routes for T9** (OR lines 90 to 96; FINAL line 126):

- Route (i), shape form. The latest Route A theorem, APEX-2 R1
  `refund_route_a_flat_plain_shape`, has no R6 premise. Its one FFI premise (R1 premise 8) is
  the contract at shape-valid calls. It is an ASSUMPTION, and the review found that no
  environment that describes the present C meets it (A2README lines 162 to 170). So route (i)
  is not open for the present image, with or without a signature.
- Route (ii), R6 plus the contract at `VokY3`-valid calls. The second part is native and is
  "TESTED-UNPROVED" (FINAL line 126).

**Proved toward R6** (FINAL lines 357 to 427; each exit 0; same machine; stored parents):
`forge_refundR6Base` (R6base-0001), `forge_refundR6Ffi` (R6ffi-0002), `forge_refundR6Write`
(R6w-0004, write side up to `print`), `forge_refundR6Read` (R6r-0004, bottom layer only),
`forge_refundR6Top` (R6t-0004, source-level `io_events` under hypotheses). R6r-0004 and R6t-0004
have no reproduction (FINAL lines 45 to 46).

**Design: what remains.**

1. Nine read-side specifications with the event invariant: openStdIn,
   refillBuffer_with_read_guard, inputBuff, inputAll_aux, inputAll, input1, consume_rest,
   open_option, inputAllFrom; with `IOFS_V_init` and the eval-state bridge that the same review
   names (`orch-A/review-R6r/REPORT.md` lines 6 to 10).
2. The specification of the refund main function, success path and exception path
   (`orch-A/review-R6w/REPORT.md`, item (b)).
3. The hypotheses that R6t-0004 leaves: declaration lookup, state facts, `wfFS`, `STD_streams`
   (`orch-A/review-TR/REPORT.md` lines 10 to 12).
4. No event of another FFI part; no close and no open_in on the path (GRAPH row X7).
5. The transfer from source-level events to the machine `io_events`. R6 is a machine-level
   statement, so this step is required (U498).
6. Negative controls, one fresh review, a reproduction of all R6 cases.

**Estimate.** 7 to 12 working days "in all" for statement R6 (U497; OR, A-3 addendum 2: about
1,500 to 1,800 lines, about 20 specifications, 1 to 3 runs each in the single HOL slot). An
earlier estimate was 4 to 7 days (OR lines 97 to 100); it was revised upward. The 7 to 12
number was made BEFORE cases R6w-0004, R6r-0004 and R6t-0004 closed. No record re-bases it: NO
SOURCE FOUND. I keep 7 to 12 as the planning number. I do not lower it for the work done, for
two recorded reasons: the estimate already rose once, and two R6 explorations hung until
SIGTERM (R6rx-0001 at 2,388.691 s and R6tx-0001 at 500.851 s, field `wall_seconds` of their
`.run.json` files in `hol-runs/routeA-attempt-0001/`; FINAL lines 578 to 579). That choice is
mine. Recorded wall time of the five stored R6 proof runs: 78.1 s to 503.4 s each (FINAL lines
357 to 427).

**What stays after R6.** The native contract at valid calls: AS, unsigned (GRAPH row X7: "native
contract at valid calls is an ASSUMPTION"). The known differences between the C and the model
(`orch-A/ffi-hardening/REPORT.md` lines 4 to 7): abort against error byte; descriptor truncated
to 32 bits; close of descriptors 0, 1, 2. So T9 becomes "model part MC, native part AS". It is
closed for the rule only with a new signed line (draft A7, section 5).

**Alternative: the model-total C patch** (OR lines 66 to 82; patch SHA-256 `ea344ad0…f357`;
UNAPPLIED). It makes the shape premise "plausible" (TU), not proved. It gives a new image
(`ba89fef3…c89`), so: a new digest in the M1 records, a second extraction, the binding manifest,
the runner's assert, conformance, and a re-examination of every theorem that quotes stub or C
words (U393 to U401). It needs the owner's approval text of OR lines 80 to 82. The night-shift
decision D-6 says: no new work planned for A-3. Q-2 asks whether that still holds.

**A fact the owner should know.** The X8 route does not need R6: "R6 is NOT needed for the
real-process claim" (`orch-A/STATE.md` line 244); T9 is "Off the shortest path since the X8
route" (GAPS, row T9). R6 is the route to an all-states claim. But T9 stays a row of GRAPH
section 3. On the X8 route its model part closes only by R6, or by ML-15 with native row N07,
or by the owner's re-scope of the row.

### 4.2 TBI0/SA0 / T11 (c)

**The problem, stated exactly.** APEX-2 R2 `refund_entry_forces_plain_user_state`: the entry
premise forces TBI0 = TBI1 = SA0 = E0E = F at EL0. R3 `refund_entry_refuses_tagged_user_state`:
a state with TBI0 or SA0 set does not meet the premise (A2README lines 80 to 81). The records
say the real values are TBI0 = 1 and SA0 = 1, from the Linux and XNU sources (D11 item 4). They
were never observed on this machine (U804). So R1 "speaks of the ERASED state only" (A2README
lines 154 to 159). R2 and R3 discharge nothing; they make the premise explicit.

**Design: the erasure run lift.** Do not change the entry premise. Prove that a run from the real
state (bits set) and the run from its erased copy (bits clear) agree on every observed field.

1. ML-07 (no write to SP in the code slice) and ML-06 (decode facts): a decoder lemma over the
   130,436 code bytes. "medium" (GAPS sec. 7 step 4).
2. ML-05 L-GHOST: fields outside the observed set are not read at EL0. "large"; FALSE without
   the EL0 premise (X8v3 lines 252 to 259).
3. ML-08 L-UNTAGGED-RUN: every next program counter of the 27 entry steps and of the run is
   untagged. Proved today in slide-0 form only (EE-0001); slide forms MISSING. No stored
   theorem keeps the program counter in the code region (U496). "medium".
4. ML-09 L-ERASE-RUN: the per-step result `NextStateARM8_erase` (EE-0001, 4 premises) lifted
   over the run; both interference functions must commute with erasure. "medium".
5. A non-vacuity witness with the bits SET (today none: GRAPH row X11).
6. Negative controls (a tagged branch target; a misaligned SP access), one fresh review.

Two limits from the records. The model has no top-byte-ignore for data addresses, so untagged
data addresses are a separate condition (G2 item 8). On macOS, TBID0 = 1 "probably" makes real
branches keep the tag, which is the erased model's behaviour; D11 item 5 marks this as part
GUESS.

**Estimate.** The records give sizes, not days, for ML-05 to ML-09 (GAPS sec. 7). The only day
numbers are in G2 item 10, marked GUESS there: 2 to 5 days for the frame and step lemmas (done
since: EF-0001, EE-0001) and 1 to 3 days for the lift.
ESTIMATE (this record): 10 to 19 working days. Derivation, with one value per size everywhere:
"large" = 3 to 5 days, "medium" = 2 to 4 days; both values are mine, no record sets them. Then
ML-05 (large) 3 to 5; ML-06 with ML-07 (medium) 2 to 4; ML-08 (medium) 2 to 4; ML-09 (medium)
2 to 4; design steps 5 and 6, 1 to 2. Sum 10 to 19. G2's guess for the lift alone (1 to 3 days)
is lower than my 4 to 8 for ML-08 and ML-09; I use the higher number because GAPS, the later
record, sizes them "medium each". Risk: high for ML-05 and for the program-counter invariant; a
failure there leaves T11 where it is.

**What stays after the lift.** Native rows N02 (EL0, AArch64, E0E = 0, no pending exception),
N03 (five bits A, E0E, SA0, TBI0, TBI1 are constant during the run and equal the recorded
values), N04 (SP alignment): AS (X8v3 lines 176 to 186). "No row can be closed by HOL"
(`orch-A/x8-x11/X11_statement.txt` lines 103 to 105). User space cannot read these registers.
D11 item 6 describes five indirect tests (tagged load, tagged branch, odd SP load, unaligned
load, endianness probe): "described only, not built, not run". They would give TU evidence for
a signature, not a proof. So T11 becomes "model part MC, native part AS". It needs a new signed
line (draft A8).

### 4.3 The WAL fold, APEX-3 step 3A (b)

**Facts first.**

- `sink.rs` on `main` has 248 lines (`wc -l`). Pure parts: `crc32` 43–50, `fnv128` 52–54,
  `canonical_id` 56, `money` 58–61, `frame` 63, `encode` 64–74, `scan` 82–100, request parse
  129–145: 64 lines, plus the pure checks inside `open_ledger` (114–119) and `commit`
  (163–172). BRIEF's ranges are correct (worker's inventory; the reviewer confirmed all eight
  ranges).
- Effect code today, by the worker's inventory: `push` 4 lines, `open_ledger` effects about 15,
  `ask_binary` 14, `commit` effects about 17, `handle` 6, `answer` 9, `serve` 13, `init` 13,
  `main` 16. My sum: about 107 of the 248 lines.
- Today the sink starts the M1 binary once per request and sends at most 154 bytes (G19 lines
  148 to 149, 252; U701). It accepts only exit 0, empty stderr and the exact frame (`sink.rs`
  lines 146 to 159).
- F2.7 in `FORGE_MASTER_IDEA.md` (line 200) and in F27 is the ISSUER: "input bytes to token
  bytes". F27 keeps the sink OUTSIDE the theorem (lines 425 to 431) and its estimate excludes
  "any sink proof" (line 476). TEXT7 uses the name F2.7 for "WAL-fold + policy". This is a
  scope change. It needs the owner's word (Q-4).
- The approved refund spec has no stored state (F27 fact D12). Conservation, one commit per
  request id and the epoch ratchet are NEW intent. They need an approved spec before a theorem
  about them means anything (F27 precondition P-2).
- The sink uses more system calls than TEXT7 names: open of two files, read of the WAL, the
  ratchet and the request, `ftruncate`, close, exit (U709 finding 4(d)).
- The basis file model has open_in, open_out, read, write, close. It has no lock, no sync, no
  truncation, no append, and no crash (worker's grep of the pinned `fsFFIScript.sml`, not
  re-checked; U709 findings 4(d), 4(e)). The stock `basis_ffi.c` has 890 lines (U709).
- A new program is a new image. Of the 71 theories of the M1 chain, 57 have a `forge_refund`
  name and 14 have a generic name; replay wall times sum to 4,175.9 s and 634.1 s (my `awk`
  over REPLAY lines 139 to 209; the split is by NAME only). F27 lines 378 to 384 list what must
  be redone: the compile instance, installed state and entry, FFI contract and environment
  predicate, the exclusion theorem, the slide chain, joint premises, Profile A.
- M1-B is OPEN for the present, smaller binary (U709 finding 4(f)).

**The 12-line design** (12 items, one long line each).

```text
 1. Program: one CakeML binary `refund_wal`, a PURE FILTER (shape S1 of BRIEF): bytes in, bytes out, no file access.
 2. stdin: one frame = lengths, ratchet bytes, WAL bytes, one request line; a stated maximum length, a longer input is refused.
 3. stdout: one exact text frame, printed after the decision: verdict code; WAL length to keep; ratchet entry to write; the new 64-byte record (hex) or none.
 4. FFI of the program: `read` (fd 0) and `write` (fd 1) only, the path Route A models; no new oracle, no new C. Shape S2 (TEXT7's C stub) is NOT RECOMMENDED; the owner decides (Q-5).
 5. HOL definitions: `wal_crc32`, `wal_fnv128`, `wal_decode`, `wal_scan`, `wal_recover` (torn tail, ratchet floor), `wal_commit_check` (reason, fresh id, CAS, amount <= remaining), `wal_encode`; decision = `eligible_def` (R1–R5).
 6. Theorems T-A, on every accepted transition: sum(committed) <= original; one record per request id; epoch' = epoch + 1; R1–R5; output = `wal_encode` of the checked fields; a refusal carries no record. T-B: round trip and prefix-freeness of both frames.
 7. Spec first: a proposal for the WAL state and rule as approved intent (owner approval; F27 P-2).
 8. CakeML: translate; `main` with a bounded read; CF proof; whole-program semantics; in-logic compile (`cake_compile_heap`); compose with `compile_correct`.
 9. Machine chain for the new bytes: entry, installed state, exclusion, slide chain (the M1 chain again), then the Route A layer again. Largest part, largest risk.
10. Unproved shim that REMAINS (new files; `sink.rs` and bundle `1f569fcf…` stay byte-identical): open x2, flock, read x2, build the frame, start the binary, pipes, wait, check exit and frame, ftruncate to the kept length, append, F_FULLFSYNC, undo by ftruncate on failure, ratchet write and sync, close, answer.
11. Tests: the Goal 19 suite against binary plus shim; the 120 kills at points need a new mechanism (the Rust seam is gone); cases `frames` and `trace` lose a part of their object (U709 4(a), 4(b)).
12. Limits after 3B: kernel, drive, loader, entry state, processor bits, X8, the shim, T4i for the larger input, rollback of both files. `end_to_end=false`.
```

**Why S1 is the recommendation.** S1 keeps the proved program on read and write of descriptors
0 and 1. The Route A theorem accepts only such events (`VokY3_rejects_close_and_open_in`, FINAL
line 125). S1 adds nothing to owner item A-3. S2 adds four or more new FFI names, each with the
A-3 problem, and a "proved" sync in a model with no crash proves nothing about durability (U709
4(e)). Cost of S1: the WAL goes through stdin, so memory grows with the WAL. F27 rule M-2 asks
for a bounded read (lines 77 to 78). Item 2 keeps a bound. The maximum WAL size is an owner
number (Q-5). At `CML_HEAP_SIZE=256` the present binary stopped a flood at 132,120,576 bytes
(U701).

**Honest limit on the request's words.** "sink.rs isn't needed in the Refund path at all": true
for the file `sink.rs`. NOT true for unproved code. Under S1 the shim of item 10 is unproved,
and it holds most of today's effect code (about 107 lines today) plus a parser for the output
frame. A shim that ignores the frame, or appends other bytes, breaks every theorem of item 6
for the real ledger. Under S2 the C stub is unproved. The fold moves the CHECKS into the proved
program. The system calls and their order stay outside every proof (P1, P5).

**Reuse of existing HOL results (BRIEF item 3).** Generic and reusable: the trace theories
TR1-0001 and TR2-0001 (FINAL lines 430 to 457); the generic lemmas of LO-0006 on `fd1_written`
(FINAL lines 231 to 244); `eligible_def` and APEX-2's FC0 to FC6 (A2README lines 58 to 66).
Bound to the present program or image, to be made again: PF-0004 (it is about the refund
renderer), MF-0002, L2d-0001, the instance part of LO-0006, and R1 (A2README lines 79 to 81).
Gaps that stay: X8, and T14 part a.

**Wall time per stage, from recorded runs on this machine.** The numbers are for the PRESENT
program. They are a floor for one clean pass, not an estimate of development.

| Stage | Recorded wall time | HOL jobs recorded | Source |
| --- | --- | --- | --- |
| In-logic compile, first run with dependency builds | 2,674.44 s | 1 | U275 |
| In-logic compile, repeat | 137.66 s | 1 | U275 |
| Source theories and compile, replay (theories 1 to 9) | 521.7 s | 9 | my `awk` over REPLAY lines 139 to 147 |
| Machine chain, replay (theories 10 to 71) | 4,288.3 s | 62 | my `awk` over REPLAY lines 148 to 209 |
| Whole chain replay, elapsed | 7,034 s; peak 4,768 MiB | 92 commands, 16 upstream theories built first | REPLAY lines 25 to 27; M1R-1 |
| Phase 2 (24 more theories) | 1,389 s; peak 2,839 MiB | 25 | REPLAY lines 86 to 88 |
| Both phases | 8,423 s | 95 theories | REPLAY line 89; F27 fact D14 |
| Route A layer, one case | 13.2 s to 503.4 s | 1 each | FINAL (worker's read of lines 39 to 40, 118, 345, 418) |
| Toolchain rebuild | 6,238 s | — | `ROADMAP.md`, Round 4 table |

The per-theory sum (4,810 s) is lower than the elapsed 7,034 s because the elapsed time holds
92 commands and the upstream builds. So one clean pass of a program of M1's size is about 2.3
hours of HOL wall time (8,423 s), in at least 95 jobs, one at a time. The number of development
jobs for a new program: NO SOURCE FOUND. One recorded sign of the ratio: the stored R6 cases
R6w-0004, R6r-0004 and R6t-0004 are each the fourth staged script of their name (FINAL lines
617 to 620).

**Estimate.**

- Unit: M1 = 152 `unsure.md` entries, 2026-11-04 to 2026-11-17 (F27 fact D14). That is 14
  calendar days by my count of the dates.
- F27's own estimate for the stateless F2.7: 84 to 168 entries, about 0.55 to 1.1 × M1; step 5
  (the machine chain) is 40 to 80 of them (F27 lines 463 to 476). F27 marks these as its
  author's estimates, not measurements. They exclude the closing of M1-B and any sink proof.
  F27 step 5 does not list the Route A layer of the night shift.
- A day or line estimate for the WAL fold itself: NO SOURCE FOUND.
- ESTIMATE (this record): 100 to 200 entries, about 9 to 18 calendar days at the M1 rate,
  WITHOUT the Route A layer of item 9. Derivation: F27's 84 to 168; plus 15 to 30 entries for
  design items 5 and 6 (seven definitions, two theorem groups; my number, no source). Then
  (100 / 152) × 14 = 9.2 and (200 / 152) × 14 = 18.4. The Route A layer for a new image has no
  estimate: NO SOURCE FOUND, and I give none. The M1 rate may not hold: M1 had the single HOL
  slot to itself.
- Resources: one HOL or `cake_compile` process at a time, AC power for long runs (TEXT7 hard
  rule 4); 16 GiB of memory (U350); the swap rule of
  [PROTOCOL.md](../night-shift-20261119/PROTOCOL.md) lines 37 to 48.
- Dependency on APEX-2: FC0 to FC6 carry over if the new program reuses `eligible_def`. R1 does
  not carry over.

**Order (point 4 of section 0).** R6's library-level specifications (write side, read side)
are about basis functions and should carry over to a new program that reads with the same
functions; the main-function specification and the machine transfer are per program. The T11
steps ML-06, ML-07 and ML-08 are facts about one code slice. This is my reading of the theory
contents; no record states it, and item 2 of the design (a bounded read) may use other basis
functions than the present `inputAllFrom`. Consequence: if the fold is approved, the cheaper
order is the fold's source-level part first, then the image, then R6's program-specific part
and the T11 lift ONCE, on that image. If the fold is not approved, R6 and T11 go on image
`b8ed5ec2…7bb8`. The owner decides (Q-6).

### 4.4 Total

One unit: calendar days. Working days × 7 / 5 = calendar days.

| Item | Estimate | In calendar days | Class of the number |
| --- | --- | --- | --- |
| R6 (T9 model part) | 7 to 12 working days | 10 to 17 | recorded (OR A-3 addendum 2; U497); not re-based |
| T11 run lift (model part) | 10 to 19 working days | 14 to 27 | ESTIMATE (this record), from GAPS sizes with my day values |
| WAL fold, 3B, without the Route A layer | 9 to 18 calendar days | 9 to 18 | ESTIMATE (this record), from F27's estimate and D14 |
| Sum, one HOL slot, in sequence | | 33 to 62 | arithmetic |

33 to 62 calendar days is about 5 to 9 weeks. "3–4 weeks" (21 to 28 days) is below the low end
of the sum. Three weeks covers R6 alone, or the fold alone at its low end. Every item has a
real chance to stop without its theorem. The Route A layer for a new image is not in the sum.
And the sum buys `end_to_end=false` (section 5). X8, the larger debt, is not in the sum.

## 5. The honest answer (d)

**Status after R6, the T11 lift and the WAL fold, if all three succeed: `end_to_end=false`.**

What changes:

- T9: MI becomes "model part MC; native part AS, unsigned".
- T11: MI becomes "model part MC; native part AS, unsigned".
- A new machine-checked statement exists about the WAL checks of a new binary, at model level,
  under the Route A premises. It is not a row of the present graph.
- With the fold, T7, T8 and T8v must hold for the NEW image, or the fold's binary is outside
  the graph and the graph still speaks of `b8ed5ec2…7bb8`.

What stays open, by the rule of section 1 (the 17 rows of table (a)):

- MISSING, untouched: T4i, T10, T12, T13 (X8), T16, T17, T18, T23, T24.
- TESTED-UNPROVED: T14a. In progress: T19.
- ASSUMPTION without a signature: T2b, T3 with T3p (BETA-PLAIN), T4, T15, and the two new
  native parts of T9 and T11.

**What more `end_to_end=true` needs.** Three kinds of work. I give no total: most rows have no
recorded estimate.

1. Proof work: R6 or its replacement for the model part of T9 (4.1, last paragraph); the X8
   model part ML-01 to ML-15 (GAPS sec. 7, steps 1 to 10; ML-05, ML-11 and ML-15 "large"); the
   T4i input lemma; a verified or extracted parser for T14a; ML-04 and ML-10; a clean replay and
   an independent-machine replay (T18).
2. Owner signatures for NEW assumptions. The lines below are DRAFTS for the owner to write,
   change or reject. None is signed. Native rows are those of GAPS section 2.2.
   - A7 (T9 native; rows N07, N08): the linked C FFI code gives, at every call the program
     makes, the result and the memory effect of the HOL basis oracle, and changes nothing else.
   - A8 (T11 native; rows N02, N03, N04): during the run the process is at EL0 in AArch64 state
     with no pending exception; the five bits A, E0E, SA0, TBI0, TBI1 keep their recorded
     values; SP is 16-byte aligned at each SP-based access. A8 has a meaning only WITH the run
     lift of 4.2: the records say the literal entry premise is false for the real registers.
   - A9 (T3, T3p): BETA-PLAIN, the four parts of A2README section 4.
   - A10 (T2b, T4): the exporter and the reader of the export bytes.
   - A11 (the other native rows of T10, T12, T13, T15): AS rows N05, N06, N16, N17, N18, N19,
     N23, and the six EP rows N09, N11, N14, N15, N20, N21. An EP row is enforced by an
     unverified launcher that is not deployed; under the rule it is neither MC nor signed, so
     it needs a signed line too, with the launcher adopted (owner item A-5).
   - Already under signed lines, no new line: N01 (P6); N10, N12, N13 (T12k, P1, subject to
     Q-7); N22 (T14o, P2). Check of the count: 3 + 2 + 7 + 5 = 17 AS rows.
   A signature moves a row out of "blocking". It does not make the row true.
3. Things that are not proofs and not signatures: T16 and T17 need either proofs about the
   deployed TypeScript path (none exists) or the owner's re-scope of "deployed path" to the
   native path (then the graph needs new rows, and T16 has no issuer or token to speak of: G19
   line 149). T19 needs the owner's merge. T23 needs a sound rule or a signed limit. T24 needs
   repository protection and a second trust domain.

So `end_to_end=true` on the refund slice is not a 3 to 4 week result by any reading of the
records. The shortest route that meets the rule has ALL of these: the X8 model part; the model
part of T9; T4i; T14a; T18; the merge of T19; signatures A7 to A11; and the re-scope or closure
of T16, T17, T23, T24.

## 6. Fallback (e)

In order of cost, each one useful alone. None sets `end_to_end=true`.

1. **Signatures first (no HOL; no time estimate from me).** The owner reads and signs or rejects
   A7, A9, A10. If D11's five indirect processor tests are built and run (TU evidence), A8 has a
   factual base.
2. **Fold at source level only.** Design items 5 to 7 and the CakeML part of item 8 without the
   compile: HOL definitions, theorems T-A and T-B, the translation and CF proof. No machine
   chain, no new image in the path. The HOL function serves as a differential oracle against
   `sink.rs` in the Goal 19 suite. Result class: MC at HOL source level; `sink.rs` stays in the
   path as TU. Size: F27 steps 2 and 3 (10 to 20 plus 15 to 30 = 25 to 50 entries, F27 table)
   plus my 15 to 30: 40 to 80 entries, about 4 to 7 calendar days at the M1 rate (ESTIMATE,
   this record).
3. **R6 with a time-box.** Stop at working day 12. If the read side or the machine transfer does
   not close, the stored theories stay and T9 stays MISSING. I do NOT offer "sign the shape
   premise" as a fallback: the review found that the present C does not meet it (4.1, route
   (i)). The only other recorded route is the C patch with a new image, then a signature (Q-2).
4. **T11 with a time-box.** Stop at working day 19. If ML-05 or the program-counter invariant
   does not close, T11 stays MISSING. D11 item 5 has a named assumption for that case, A-PROC:
   each real step has the effect of one model step from the ERASED state, under two unproved
   conditions (branch targets with bits 63:55 = 0; no SP-based access while SP is misaligned).
   As a draft line it is A12, separate from A8. It is weaker than A8 with the lift: the owner
   would sign the two conditions that the lift would have proved.
5. **Do none of the three now.** Put the HOL slot on X8 (T13), the smallest missing refinement
   boundary by the graph's own words.

## 7. Questions for the owner

- Q-1. Budget word: which of R6, the T11 lift and the fold may start, with which time-box. This
  moves T9 and the fold out of FUTURE WORK (AA lines 32 to 33).
- Q-2. R6 route: prove R6 on the present image, or approve the C patch (new image), or neither.
  The night-shift decision D-6 planned no new work for A-3.
- Q-3. Accept that the three items leave `end_to_end=false`, or change the aim to a named,
  narrower claim that the owner defines.
- Q-4. Scope of the name F2.7: issuer (master idea, F27) or WAL fold plus policy (TEXT7). And
  approval of a spec for the WAL state and rule (new intent).
- Q-5. Boundary shape: S1 (this record's recommendation) or S2 (TEXT7's text); the maximum WAL
  size; whether the shim is Rust or C.
- Q-6. Order: fold first and fix the image, then R6 and T11; or R6 and T11 on `b8ed5ec2…7bb8`.
- Q-7. Wording of P1: does it cover descriptors 0 and 1 of the refund process?
- Q-8. Whether the native path may replace the TypeScript path as the "deployed path" of T16
  and T17 (a graph change); the draft lines A7 to A12; whether T7 and T8v count as blocking.

## 8. Limits of this record

- Nothing here was run in HOL. Every design step can fail in the prover.
- Four numbers are mine and have no committed source: the day values for "medium" and "large",
  the T11 total, the 15 to 30 entries for the fold's HOL part, and the choice not to lower R6's
  7 to 12. The reuse of R6 across images is my reading. All are marked where they stand.
- Two workers read the sources. I checked these of their citations myself: the T-table of GRAPH
  and APEX2; AA; OR items A-3, A-5 and D-6; U497; U709; F27 lines 33 to 49, 74 to 82, 376 to
  386, 455 to 476; GAPS sections 1, 2, 2.1, 2.2 and 7; A2README lines 80 to 81 and 150 to 172;
  D11 items 4 to 6; G2 item 10; FINAL lines 610 to 622; REPLAY lines 25 to 27, 86 to 89 and the
  theory table; the two `.run.json` wall times. The reviewer verified more (section 9). Not
  re-checked by anyone but the worker: the `fsFFIScript.sml` FFI names; the Route A wall-time
  range; `review-R6w` item (b) beyond its first line.
- The owner's request in section 0 is the text the launcher gave me. It is not in the repository.

## 9. The one review and the repairs

One fresh-context reviewer got the first draft (local commit `2b13f3f3`, squashed before the push) and not my
conclusions. Result: 0 FAIL-OPEN, 3 HIGH, 13 MEDIUM, 4 LOW, 1 NOTE. All 21 are repaired in this
text. The repairs were NOT reviewed again.

| # | Severity | Finding | Repair |
| --- | --- | --- | --- |
| 1 | HIGH | the "shortest route" left out T4i, T14a, T19 and the model part of T9 | section 5, last paragraph; 4.1, last paragraph |
| 2 | HIGH | a fallback offered to sign the shape premise, which the present C does not meet | fallback 3 no longer offers it; 4.1 route (i) says so |
| 3 | HIGH | the output frame gave the shim no truncation length and no ratchet value; shim actions not all listed | design items 3 and 10; "Honest limit" paragraph |
| 4 | MEDIUM | T11 estimate used unequal day values and left steps out (was 6 to 12) | 10 to 19 working days, one value per size |
| 5 | MEDIUM | "F27 steps 2 and 3 = 30 to 60 entries" was wrong | 25 to 50 |
| 6 | MEDIUM | "2 to 5 exploration rounds" had no source | deleted; replaced by the recorded case numbers |
| 7 | MEDIUM | mixed units; "six weeks" too low | 4.4 in calendar days: 33 to 62 |
| 8 | MEDIUM | the count 17 hid three choices (T7, T8v, T12k) | section 3, "17 rows, or up to 20" |
| 9 | MEDIUM | AA's FUTURE WORK line was not cited | section 1; Q-1 |
| 10 | MEDIUM | no wall time per stage, no job count, no reuse list | 4.3, two new parts |
| 11 | MEDIUM | the Route A layer was in the design and not in the estimate | stated as not estimated |
| 12 | MEDIUM | draft lines overlapped and missed bits and EP rows | exact N rows per draft line |
| 13 | MEDIUM | A-PROC was offered "as P8" against the text of section 5 | separate draft A12 |
| 14 | MEDIUM | an unsupported reason for keeping 7 to 12 | reason replaced by two recorded facts; marked as my choice |
| 15 | MEDIUM | "S2 rejected" overstepped | "NOT RECOMMENDED; the owner decides" |
| 16 | MEDIUM | name clashes (P8; D-1 to D-8) | A7 to A12; Q-1 to Q-8; "R1 premise 8" |
| 17 | LOW | the 12-line design had 25 physical lines | 12 items, one line each |
| 18 | LOW | five wrong or loose line references | corrected |
| 19 | LOW | 56 and 15 theories; should be 57 and 14 | recounted by me with `awk`; the 4,810 s against 7,034 s difference explained |
| 20 | LOW | "no proof can close"; an unmarked "days"; a duplicate stop rule; two R6 items missing | reworded; removed; added |
| 21 | NOTE | TBID0 and data-address limits missing in 4.2 | added |
