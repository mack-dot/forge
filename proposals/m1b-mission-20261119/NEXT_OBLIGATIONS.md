# Next obligations after wave 4 (owner text 15)

Written 2026-11-19T06:35Z. CURRENT none. **M1-B OPEN.** `end_to_end=false`. Stage 9
deferred. Stage 12 unauthorized. No protected change, no Linux probe,
no new worker, no new system: the existing checker, token flow and
SQLite sink stay.

Four kinds of evidence are kept apart in every row below:
MODEL (a HOL theorem about the machine model), NATIVE (an assumption
about the real process, kernel or processor), TEST (a finite run),
ENFORCED (a control that the agent cannot bypass). Today nothing is
ENFORCED.

## 1. The smallest independently checkable next theorem

**L1, `refund_ffi_contract_on_totalises`** (kind: MODEL):

    !b dm Vok f. refund_ffi_contract_on b dm Vok f ==>
                 refund_ffi_contract_at b dm (refund_ffi_tot Vok f)

Script `drafts/route-a/routeA-L1.sml` (SHA-256 `9ddf6746…8830`), an
import check and two negative controls (N1: without totalisation the
implication is false; N2: the zero-length close state). Pre-flight by
reading found no defect (report D1). Limit 600 CPU seconds; at most
five attempts; stored theories only. It is the next run of the
authorized schedule. What it gives alone is small: the content is in
L2 and L3.

For the exit-status finding the smallest theorem is the
**strict-prefix lemma** (kind: MODEL; draft
`drafts/route-a/prefix_lemma_DRAFT.sml`):

    p ≼ explode (refund_render_fields f) ∧ p ≠ explode (refund_render_fields f)
      ⇒ refund_strict_parse p = NONE

with the positive control P0 (the complete output parses to `f`),
because a parser that refuses everything also satisfies the lemma, and
three negative controls (a trailing newline, an atom that is a prefix
of another, depth 0). Safety of a consumer rests on this lemma and on
"output is a prefix of the result", not on the exit status.

## 2. Order of HOL runs (one process; when the replay has ended)

| # | Run | Kind | State of the script | Authorized by |
| --- | --- | --- | --- | --- |
| 0 | replay cases 109 to 158, then case 005 again | TEST of stored records | driver | text 1 Q6, text 15 item 7 |
| 1 | L1 with N1, N2 and the import check | MODEL | complete draft | text 9 item 2, text 15 item 7 |
| 2 | strict-prefix lemma with P0, N1 to N3 | MODEL | statement complete; key lemma `lex_aux_prefix_ISL` needs proof work in the session | text 15 item 3 |
| 3 | L-EXIT-0: a halt is `FFI_outcome`, or at the halt address with (Success and x0 = 0) or (resource stop and x0 ≠ 0) | MODEL | draft | text 15 item 3 |
| 4 | L-OUT at `no_ext` with N-O1 to N-O3 | MODEL | statement complete; the replay invariant has NO tactic yet | text 15 item 3 |
| 5 | halt-value range L-EXIT-V: x0 ∈ {0, 1, 2} at every halt | MODEL | statement only; the hard one (needs the register value through the label-to-target simulation); may fail | text 15 item 3 |
| 6 | link theorem: probe H0, then `exported_contract_on_refund_fields` with 11 controls | MODEL | complete draft | texts 2, 13 |
| 7 | L2, then the first `read` call-site theorem | MODEL | drafts | text 9 item 2 |

Rows 2, 4 and 5 are not finished as scripts. Their statements are
fixed; their tactics need the prover. I do not call them ready.

## 3. Tests required for the fail-closed consumer (kind: TEST)

Existing, in `drafts/fail-closed/`: 82 planted results refused; real
runs; 8,011 strict prefixes. Added today,
`run_exit_status_controls.py` (exit 0, 18 rows; with a caller that
authorizes on status 0 alone: exit 1):

1. status 0, empty stderr, the complete expected frame: AUTHORIZED
   (the only authorizing row).
2. status 0, empty stderr, each strict prefix and the empty output:
   REFUSED (the x0 = 2^32 shape).
3. status 0, stderr line, complete or cut output: REFUSED (the
   x0 = 256 shape).
4. status 1, 2, 3, 255 with the COMPLETE output, with and without the
   stderr line: REFUSED.
5. signal or time limit with the complete output: REFUSED.
6. status 0 with the complete frame of ANOTHER request, a frame twice,
   a frame plus a newline: REFUSED.

Still required and NOT written (they need the consumer to be connected
to the existing issuer, link X16; no code exists):

7. M1 says AUTHORIZED and `RefundFinality.Check` refuses (a stale
   `remaining`): no token.
8. `Check` accepts and the M1 result is REFUSED: no token.
9. Both accept: one token; the sink commits once; a replay is
   `replayed`.
10. The field values given to M1 and to `Check` differ in one field:
    no token.
11. The consumer is killed between the M1 run and the signing: no
    token, no commit.

## 4. Remaining links to native execution (graph ids)

| Link | What is missing | Kind when closed |
| --- | --- | --- |
| X6 → X7 | L1, L2, L3: the FFI contract only at reachable calls; L3 needs about 15 text I/O specifications proved again | MODEL |
| X5 / X11e | the processor bits: an erasure lemma, or the named assumption A-PROC | MODEL or NATIVE |
| X5 | entry state: everything before `cml_main` (`dyld`, `_main`, `malloc`) | NATIVE |
| X8 | the real process refines the model: no HOL statement | NATIVE (HOL cannot close it) |
| X9 | output bytes from events (L-OUT at `no_ext`) | MODEL |
| X10 | halt value range; the 32-bit test and 8-bit status of the real exit path | MODEL plus NATIVE |
| X11 | kernel and processor between steps | NATIVE |
| X13 | strict-prefix lemma | MODEL |
| V2 | the file outside the two slices: C run-time, 22 stubs, 23 binds, `__LINKEDIT` | none available today |
| S6, S7 | the contract on the HOL functions; 8 operator meanings | MODEL; ASSUMPTION |

## 5. Remaining links to protected effects

| Link | What is missing | Kind when closed |
| --- | --- | --- |
| X15 | the fail-closed consumer is a draft outside the product code | TEST, then MODEL |
| X16 | nothing connects an M1 result to the issuer | TEST |
| U2 | the issuer glue that builds the claim | not proved |
| U5b | the Dafny sink core is not `sink.ts`; `sink.ts` does not compare the token's request id with the intent's | MODEL for the core only |
| U7 | power loss (SQLite defaults, no full fsync) | TEST not done |
| U8 | the approved spec has no state; amount 0 commits repeatedly | owner decision |
| S2 | `expect` gives partial correctness; the fix is in `gate/` | owner decision |
| S1, E1, E2, E4, E5 | `main` is not protected; one machine holds both identities | ENFORCED: none today |
