# Step V: adversarial validation of the M1 claim (W8, Opus, fresh context)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W8 (adversary), step V: independent adversarial validation. Read-only. I changed no file in the repository. My only run: `python3 scripts/exit_m1_conformance.py --case conformance`, exit 0, 0 findings. Its output is in `build/m1-conformance/conformance/attempt-0006`; my log is `<session scratch folder>/m1b/W8/conformance.log`.

## CRITICAL

**C1. The stored M1 theorem says nothing formal about the output of the real executable.** CONFIRMED.
- **Statement** (`records/final-cases/e4-0001/stdout.log`): `refund_profile_a_sl` has these premises: entry state, heap, domain, `refund_env_ok_sl sl envmc`, `stdin_content fs = SOME (explode (sexp_to_string (refund_request …)))`, `wfcl cl`, `wfFS fs`, `STD_streams fs`.
- **Conclusion:** `machine_sem (refund_mc …) (basis_ffi ext cl fs) ms ⊆ extend_with_resource_limit {Terminate Success io_events} ∧ extract_fs … = SOME (add_stdout (fastForwardFD fs 0) (refund_render_fields (refund_fields …)))`.
- **The real-code premise is probably false.** `refund_env_ok_sl` = `interference_ok … ∧ refund_ffi_contract_at …`. The contract covers every call state, with `index < 4`. U409 says: "refund_env_ok_sl is an assumption and is probably false for the real C code at every state (U393 analysis)". U393 says: "the real fficlose returns only when clen = 8 and alen >= 1 … A faithful model of the real function cannot satisfy the clause for all call states."
- **The theorem without that premise is about another machine.** `refund_profile_a_sl_abstract_env` concerns `refund_mc … (refund_abs_env envmc)`, a total and ideal FFI.
- **The bridge is informal.** `M1_PROFILE_A_RESTRICTED.md` A3 ("FFI simulation"): "NOT formalized. No HOL statement exists". A3 covers the whole I/O path: stub, C function, `libSystem`, kernel. The stdout bytes of the real process therefore rest only on A3.
- **The witness proves only consistency.** It is `refund_profile_a_sl_all_premises_satisfiable_at_0x4000` in `forge_refundInputSat`. It uses `refund_abs_env`, a 128 KiB heap (`0x200000000w..0x200020000w`), a constructed `sat_mem_sl`, and `numchars := LREPEAT [1]`. It shows that the premises are consistent in the model. It shows nothing about a real process.
- **Settle with:** a reachable-call FFI refinement in HOL (the contract only at reachable call states, with clen = 8 etc., as proposed in U405), so that a model of the real C code can satisfy it. Or a formal A3 statement in the final theorem. Until then, every document must say that the real-executable claim is "abstract-env theorem + informal A3".

## HIGH

**H1. The output conclusion allows empty or truncated output. Nothing proves that any run succeeds. The executable signals no error.** CONFIRMED.
- **Statement:** `refund_profile_a_sl_every_machine_run` gives `b = Terminate Success io ∧ … ∨ ∃io io'. b = Terminate Resource_limit_hit io' ∧ io' ≼ io`. `io'` may be empty. Every run could be a resource stop. U398 also notes: "unconstrained existential io_events".
- **Truncated output is safe only with a strict parser.** The output has no trailing newline (my run: last byte is `)` or the output is empty). The top-level `)` is the last byte. So a strict prefix should never parse as a complete result. That is PLAUSIBLE; it is not proved.
- **The conformance classifier accepts a prefix.** `m1_class` in `scripts/exit_m1_conformance.py` labels any output that starts with `(refund-result-v1 True ` as AUTHORIZED, for example `(refund-result-v1 True 4`. The A-BYTES check catches it inside that script. A caller that copies this classifier fails open.
- **Exit 0 with no output on bad input** (my run): `R-trailing_newline`, `R-empty_input`, `R-invalid_integer`, `R-missing_fields` all gave exit 0, empty stdout and empty stderr. All 192 wire inputs exit 0, and 132 of them give no output. `refund_dispatch` does `raise Fail msg`, and the message is lost.
- **Nothing implements fail-closed.** No component consumes M1 output, so the owner's Q2/Q5 fail-closed rule exists nowhere in code.
- **Settle with:** a HOL lemma `p ≺ refund_render_fields x ⇒ ¬(parse p = INR (_, []) ∧ refund_response_fields _ = INR _)`. Also a boundary wrapper that requires exit 0 AND an exact full parse, tested with truncated and empty outputs.

**H2. Substitution: the import checks compare statement text, not definitions.** CONFIRMED.
- **What the check compares.** `imp4-0001.sml` line 11 uses `same name tm = … aconv (concl th) tm`. The terms are built in the same session from the loaded constants. The import check compares no definition the statement depends on: `eligible_def`, `refund_fields_def`, `refund_render_fields_def`, `refund_request_def`, `refund_image_mem_def`, `refund_file_def`, `code_def`. (It does compare the two definitions of its own theory, `refund_ffi_contract_at_def` and `refund_env_ok_sl_def`.)
- **Altered theories with the same name exist.** `certified-library-20261104/records/controls/altered-amount/forge_refundCertifiedProgScript.sml` defines `refund_fields` with `amount + 1` under the same theory name. Built on such a parent, the final theorem prints byte-identically and the import check passes.
- **What actually binds content:**
  - the `.dat` SHA-256 equality, against hashes recorded earlier by the same agent family;
  - `run_case.py` `assert inputs[IMAGE] == 'b8ed5ec2…'`;
  - the SHA round-trip "compared by the runner's wrapper", outside the kernel.
- **The conformance script binds only the executable.** Its identity checks are the executable SHA plus `plan-phase2.json` and `budget-phase2.json`. It checks no HOL artifact. Swapping the proofs does not change its result.
- **The U393/U398 defect class still lacks a replayed control.** Those were exit-0 theorems with contradictory premises (variable capture in ffic-0005; BigEndian in fault-0001). The final theorem has the fs satisfiability control. The intermediate theorems' controls are among the 158 cases that are NOT replayed (replay REPORT: "no negative control of the chain is replayed").
- **Settle with:** an import check that also compares the printed definitions above and the `.dat` hashes of `forge_refundImage` and `forge_refund*` parents against a pinned list. Also make the conformance script verify those hashes.

**H3. The gate does not enforce "humans approve intent".** CONFIRMED.
- **Merges bypassed the gate.** U463: "`gh pr merge 49 --squash --admin`, exit 0 … an OVERRIDE of the review rule and of the red gate status". U465 and U468 record the same for pull requests 50 to 52; U471 records it for pull request 54. The agent runs the merge itself, from the account. The "owner's word" was an option the agent offered in its own question ("Merge it for me").
- **The owner's texts are unauthenticated.** `OWNER_DECISIONS.md`: "pasted texts with no words of the owner's own … an inference (U473)". One line of it arrived cut off.
- **The code itself is sound.** `approval.py` freezes 8 `PR_GATE_FILES`. Ratification records are read only from the trusted base. I found no code path by which the gate approves its own change. The weak point is that a gate verdict (exit 3 or 1) is not a precondition of a merge.
- **Settle with:** branch protection with the gate as a required status, no administrator bypass, and owner approval from a separate account or signed commit.

**H4. REVIEW_PACKET §1 says that the program was "written in the Dafny subset that CakeML reads, compiled by the proved CakeML compiler". The binary does not contain Dafny-frontend code.** CONFIRMED.
- **Where the code comes from.** `forge_refundCertifiedProg` (real version) says "Alternative local implementation through the existing proof-producing translator". It does `translate eligible_def; translate refund_fields_def`. `forge_refundWireProg` translates `refund_render_fields` and `refund_run_wire`. The compiled code is the output of the HOL→CakeML translator for HOL functions.
- **The Dafny side is not the approved file.** The Dafny AST `refund_body` in `forge_refund` is hand-written in HOL with 9 flat variables and `mlstring`. It is not parsed from `impl/Refund.dfy`. `refund_fields_original_method` only relates results.
- **Impact:** the M1-B mechanical link must target `eligible_def` / `refund_fields` / `refund_render_fields`. A Dafny compilation route does not apply.
- **Settle with:** correct the sentence, and point the M1-B plan at those HOL definitions.

## MEDIUM

**M1. The file binding covers only `__TEXT` and the bitmaps.** CONFIRMED.
- **Definition** (image-0001): `refund_image_mem sl m ⇔ bytes_in_memory (0x100000000w+sl) (TAKE 163840 refund_file) … ∧ bytes_in_memory (0x10002C018w+sl) (TAKE 20248 (DROP 180248 refund_file)) …`.
- **Covered by no theorem:**
  - file 163840–180248: `__DATA`/`__DATA_CONST`, including the GOT with 23 dyld binds such as `close`, `write`, `read`;
  - file 200496–238776: `__LINKEDIT`, with the chained fixups, symbols and code signature;
  - `libSystem` and the dyld shared cache, which are not pinned.
- **Bytes do not mean behaviour.** The C run-time, `basis_ffi.o` and the stubs are bytes inside `__TEXT`. Their behaviour is assumed (A2, A3).
- **The entry point is checked only in ML.** `LC_MAIN` entryoff 152900 is checked by an ML `raise Fail` and stored in `refund_macho_fields`. No final theorem uses it.
- **Offsets come from outside HOL.** The Python tool supplies them ("HOL has no Mach-O parser").
- **A different file could pass.** A file with equal `__TEXT` and bitmaps but changed GOT binds or fixups gives a theorem with the same meaning. Only the script SHA assert refuses it.
- **Settle with:** an in-HOL check of the load commands and the bind table, or an A6/A2 statement that names these ranges as unverified.

**M2. REVIEW_PACKET §4 overstates the joint-premise witness.** The O4 row says "the eleven premises of `refund_profile_a_sl` hold together for ONE constructed state at slide 0x4000". It does not say that `envmc` is `refund_abs_env` (the ideal FFI that the real code cannot match, C1) or that the heap is 128 KiB. CONFIRMED. **Fix:** add both facts to the row.

**M3. The approved spec allows behaviour a person would likely not intend. Only the unproved sink limits it.** CONFIRMED.
- **Zero amounts.** `RefundSpec.dfy`: `0 <= response.amount <= context.remaining`, so amount 0 is authorized.
- **Double authorization.** `remaining` is a caller input and `Assess` is stateless. The same refund is authorized by every call.
- **The "request open" check is empty in Slice 1.** `ContextOf(... pre.refundEnabled, true)` sets `requestOpen` to true. The proposer invents request ids. Any non-empty id passes.
- **Zero tokens repeat effects.** A 0-amount token keeps the state hash (`post == pre`). So any number of 0-amount tokens with fresh request ids each commit and each yield an outbox effect. Suite row c ("a refund of amount 0 … committed") covers one; repetition is not tested. Slice 1 REPORT limit 6 states it.
- **The guard against double spend is tested, not proved.** It is the decreasing `remaining` plus request-id uniqueness in `sink.ts` (rows b and c). The core's P1 proves only `post = pre with remaining − amount`.
- **Settle with:** an owner decision on amount > 0 and on request binding. Also a proof (or model check) of the sink's state machine.

**M4. The pinned `checkerSha256` binds nothing against whoever holds the key.** CONFIRMED.
- **It is a self-declaration.** `minter.ts` computes `checkerSha256Of(coreBytes, encoding.ts, minter.ts)` itself and writes it into the body it signs. Any key holder can write the pinned value.
- **It omits dependencies.** It does not cover `bignumber.js`, `tsx`, Node or `node:sqlite`.
- **Time-of-check gap.** The file is hashed with `readFileSync`, then loaded with `require(resolve(corePath))`.
- **The sink can only compare.** It compares the field for equality. Suite row a ("two tokens with a VALID signature of the trusted key but another spec lock or checker id") tests only that equality.
- **Settle with:** an attestation from a separate key or measured launch. Or state that it is a label, not a binding.

## LOW

- **L1.** These duplication paths are known (REVIEW F6/F7, REPORT limits 4 and 13): two databases for one charge, a restored or re-initialized database replaying old tokens, a lost dispatcher ledger re-sending everything. No suite row covers them. Durability at power loss is not checked. CONFIRMED (text).
- **L2.** Non-canonical input is outside the theorem but gives decisions. My run: 16 wire variants gave `SAME_AS_BASE_AUTHORIZED` ("040", "+40", quoted atoms). Packet row 18 states this. CONFIRMED.
- **L3.** The code term is `to_list to_word <compute value>`, made by cv computation. The kernel `compute` extension is then in the trusted base, and the DISK_THM tag check would not show it. PLAUSIBLE.
- **L4.** The README M1 row still lists "an approved profile" as open. Profile A was chosen on 2026-11-19 from a pasted text (U473). CONFIRMED stale.
- **L5.** README "three independent reviews" and "Reviews find what the author misses": the reviewers are same-model agents in the same effort, so they are independent in context only. The same applies to the Q4 reviewer of the 18 rows. PLAUSIBLE overstatement.
- **L6.** README: "Each accepted artifact carries evidence that is tied to its exact bytes, its specification…". The slices are UNSUPPORTED by the gate (exit 3). The M1 executable is tied by a SHA in scripts only. CONFIRMED overstatement.

## Checked and found sound

- **The code and bitmap slice binding is kernel-checked.** It is the APPEND layout evaluation that equals `refund_file`, with controls for a changed byte and a shifted offset. It is sound, given the trusted ML reader.
- **The final statement is as described.** It is the U387 output term. One `io_events` is shared. No premise mentions `extract_fs`, `machine_sem` or an installed-state predicate. The slide-0 instances are aconv to U404. The closure axioms are the four of bool.
- **The witness covers all 11 premises**, including `wfFS`, `STD_streams` and `stdin_content`, through `sat_fs`.
- **Sink:** the signature, pinned ids, state hash and fresh request id are checked, and the three writes are in one `BEGIN IMMEDIATE` transaction.
- **Dispatcher:** chain check, ledger-before-effect (at most once) and lock. The code matches the documented limits.
- **Gate:** no ratification path for the 8 PR-gate files. Records are read only from the trusted base.
- **Conformance run:** exit 0, 2,466 typed vectors, 0 findings.

## Not checked

- No HOL run. The 158 cases were not run. I read none of the 15 theorem statements of `forge_refundInputSat` beyond those quoted above.
- I did not read `m1-closure-audit-20261116/*.md` or `m1-slide-s4-s6-20261117/REPORT.md` in full.
- GitHub branch-protection settings were not checked (no network). Whether the owner, rather than the agent, merged pull requests 39 to 41 was not checked.
- dyld and `libSystem` behaviour on real slides, and the C stack placement, were not checked.
- I read `Bindings.dfy` only in part, and `incremental.py` beyond the manifest not at all.
- The 18 rows themselves were not reviewed.

| step | status | evidence or blocker |
| --- | --- | --- |
| V (W8 adversarial validation) | REPORTED | 1 CRITICAL, 4 HIGH, 4 MEDIUM, 6 LOW. Sources: `e4-0001/stdout.log`, `fs-r4-0001/stdout.log`, `imp4-0001.sml`, image-0001.sml (backup branch), U393/U409/U463, `M1_PROFILE_A_RESTRICTED.md` A3, `sink.ts`/`minter.ts`/`encoding.ts`, `approval.py`. Run: `exit_m1_conformance.py --case conformance` exit 0, attempt-0006 |

