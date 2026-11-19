# Step B1: the exact M1 claim and the missing native-process relation (X1, Opus, read-only; nothing proved or run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

X1 (claim-statement), step B1. I worked read-only. I changed no file in the repository and ran no HOL, Dafny or Docker. The full draft is in <session scratch folder>/m1b/X1/M1_EXACT_CLAIM.md. It has 8 sections: the stored statements quoted with file and line, a 33-row assumption table, the two labels, the overclaim list, the relation in both forms, the next obligation, the effort estimate and the graph links.

**Stored statements.**
- `refund_profile_a_sl` and `_every_machine_run` are quoted from `R/final-cases/e4-0001/stdout.log`, lines 240–265 and 298–331.
- The abstract-environment variant exists: `refund_profile_a_sl_abstract_env`, lines 266–294. It has 10 premises, without `refund_env_ok_sl`, and its machine is `refund_mc … (refund_abs_env envmc)`. It is derived from `refund_abs_env_is_ok_sl` (line 212).
- `refund_ffi_contract_at` is quoted at lines 63–80, and `refund_env_ok_sl` at lines 151–156.
- FFI index order: 0 read, 1 write, 2 close, 3 open_in. The stub for index i is at `b − 16(3+i)`. `halt_pc` (`cake_exit`) is at `b − 16`.

**Labels (exact words).**
- (a) Verified machine-model behaviour: the HOL4 kernel has checked (closure axioms: the four of bool) the following. Take every `sl` with `slide_ok sl`. Take every L3 state `s` with `refund_entry_pre_sl` and the heap premises. Take every `envmc` with `prog_addresses = refund_mem_dm_sl sl h e` and `refund_env_ok_sl sl envmc`. Take every `basis_ffi` file-system model `fs` with `wfFS`, `STD_streams` and the canonical nine-field stdin text. Then the target-semantics machine `refund_mc (sl+0x1000040D0w) envmc` behaves as follows from the state 27 L3 steps after `s`:
  - it has a behaviour;
  - it never Fails;
  - it never reaches `install_pc`;
  - every behaviour is `Terminate Success io` or `Terminate Resource_limit_hit io'` with `io'` a prefix of such an `io`;
  - replaying such an `io` on the fs model appends `refund_render_fields (refund_fields …)` to the stdout inode and fast-forwards stdin.

  This is a statement about a mathematical machine. Its only real-world input is the content of `refund_file`.
- (b) Verified native execution: a theorem about runs of the real process `b8ed5ec2…`, under named assumptions E. It would say: if the process exits, then either the exit status is 0 and the bytes the kernel accepted on fd 1 equal the rendering, or the exit status is not 0 and those bytes are a prefix of it. No record reaches (b). If the relation below is only a premise, the claim is "(a) plus a named native-simulation assumption", which is M1-A at most.

**Smallest counterexample (U393 finding; U394 `zero_alen_reaches_assert_block`).**
- Function: `fficlose`, index 2. Call state: PC `b−80`, `x1 = 0w`, `x3 = 0w`.
- Both arrays read 0 bytes, so `bytes = bytes2 = new_bytes = []`, and the contract premises hold for every domain.
- The contract demands: `arm8_ok`, PC = x30, dm memory unchanged, x19–x25, x27, x28 kept.
- The real C (`basis_ffi.c` 191–197) does `assert(alen >= 1)`, then `abort()`, and never returns. In the L3 model, 6 steps reach 0x1000252A4, a call into the assertion block that is not modelled.
- Second class (my analysis, not in U393): the contract holds for every `new_bytes`. A faithful C model that ignores the oracle's bytes fails it. So OS conformance must be its own part of the native assumption.

**Missing relation, Option A (CANDIDATE, not proved).**
- New types: `ncall` and `nrun = <|ncalls; nexit : num option; nstdout|>`.
- New definitions: `ncall_event`, `stdout_of` (successful fd-1 write events, `TAKE nw (DROP (4+off) buffer)`), `native_matches`, and `native_refines sl envmc (cl,fs) s p ⇔ ∀ms. arm8_run 27 s = SOME ms ⇒ ∃b ext. machine_sem (refund_mc (sl+0x1000040D0w) envmc) (basis_ffi ext cl fs) ms b ∧ native_matches b p`.
- In `native_matches`, Success requires `nexit = SOME 0`, Resource_limit_hit requires a non-zero exit, and every other behaviour gives F.
- Candidate theorem: the 11 premises ∧ `native_refines` ⇒ (exit 0 ∧ stdout = rendering) ∨ (exit ≠ 0 ∧ stdout ≼ rendering).
- It needs two missing lemmas:
  - L-OUT: the extract_fs equation implies `stdout_of io = out`.
  - L-EXIT: exit status = low 8 bits of x0, and x0 ∈ {0,1,2} at `halt_pc`. That x0 set is my reading of `stack_removeScript` 57 and 330–331; there is no theorem. Without it, x0 = 256 is Resource_limit_hit in the model but exit status 0 in the process.
- What the relation must contain:
  - write (index 1), reachable: `x1 = 8`, fd 1, `n+off+4 ≤ alen`. This holds only at successful events in the model (U400).
  - Real write errors: the model has none on fd 1, and no owner decision covers them.
  - read (index 0), reachable: `x1 = 8`, fd 0, `alen ≥ n+4`. Its call-site facts are not in the chain. Read errors are excluded by Q2.
  - close and open_in: unreachable by inspection only (U396).
  - Entry path: dyld → `main` → `cml_init_memory` → `cml_init_eval` → `cml_main` gives `refund_entry_pre_sl`.
  - Exit path: `b cml_exit` → `exit((int)x0)`.
  - The C stack and libSystem stay outside `prog_addresses`.

**Option B (CANDIDATE replacement for `refund_env_ok_sl`).**
- `refund_ffi_contract_on b dm V f`: the stored contract with an extra hypothesis `V index new_bytes ms2`.
- `refund_ffi_tot V f`: use `f` where V holds, else `refund_abs_ffi`.
- `refund_env_ok_reach`: `interference_ok` ∧ contract_on ∧ V at every reachable call of the totalised machine.
- The stored all-states consumers stay unchanged and are applied to the totalised record: `ffi_interfer_ok_iff_contract_sl` → `refund_env_ok_sl_iff_installed_residual` → `refund_installed_rest2` / `no_handler` → U387 `refund_behavior_valid_request_no_handler` and `refund_u298_exclusion_valid_request` (via `installed` in `compile_correct'`).
- New work: U405 L1, L2 (clock-wise agreement), L3 (V per name), and faithful C models for write (U397/U398) and read (not started).

**Still not said, even then:** the physical CPU, the kernel, dyld and GOT binds, `libSystem`, the C run-time, `__DATA`/`__LINKEDIT`.

**Overclaiming sentences on `main` (8e772b55); corrected text is in §2.1 of the draft.**
- `README.md:102` "HOL4 model theorems connect the exact ARM64 code to the decision definition under explicit premises". The native link is not a premise, so a clause about the informal A3 is needed.
- `REVIEW_PACKET.md:20–22`: Dafny provenance (H4). It is corrected in the working tree only.
- `REVIEW_PACKET.md:22–24`: needs a clause saying the real executable is linked to the model only by an assumption with no HOL statement.
- `REVIEW_PACKET.md:29–31`: "a program with a stated, approved and replayed claim" should say "a machine-model theorem about the code bytes".
- `REVIEW_PACKET.md:46`: row 6 says "satisfies `installed`". That is stale: `installed` is derived.
- Conformance `REPORT.md:126`: "The M1 theorems cover canonical inputs."
- `REPORT.md:217–220`: calls the model theorems a link to the physical executable.
- `REPORT.md:258`: "one simulation assumption (Profile A, NOT approved)". The theorem actually assumes `refund_env_ok_sl`.
- `REPORT.md:259`: "part of the proved program". It is proved only for the canonical text.
- `FORGE_MASTER_IDEA.md`: no sentence claiming (b) found.

**Next obligation (CANDIDATE, not run; minutes).**
- Statement: `refund_ffi_contract_on_totalises: ∀b dm V f. refund_ffi_contract_on b dm V f ⇒ refund_ffi_contract_at b dm (refund_ffi_tot V f)`.
- Corollary: `refund_env_ok_sl sl (envmc with ffi_interfer := refund_ffi_tot V envmc.ffi_interfer)`.
- Parents: `forge_refundSlideProfileA` and `forge_refundEnvModel`. The proof follows the stored `stub_guard_ffi_satisfies_contract_at_its_base`.
- Sanity check: V = T gives an equivalence with the stored contract.
- Negative control: prove `¬(∀b dm V f. contract_on ⇒ contract_at b dm f)` with V = F, `f = refund_bad_return_ffi` and the witness state at `0x1000040A0w`.
- Counterexample control: V_close excludes the §3.0 state.
- L1 alone says nothing new about the real process; L2 is the next step.

**Effort.** About 27–71 entries, that is 0.4–1.1 units; with my uncertainty, 0.3–2 units. Breakdown: L1 1; L2 3–8; L3 write 10–25; read 6–12; close/open_in 2–6; L-OUT 2–4; L-EXIT 3–15. Even at the end, `native_refines` stays an ASSUMPTION: HOL work alone cannot reach (b).

**Could not determine:** read call-site facts; the `iobuff` size; whether real slides meet `slide_ok`; the build flags of `basis_ffi.o` (stderr printing); C stack placement; that x0 ∈ {0,1,2} at every halt; whether the heap is large enough for Success.

**Links for the top-level graph (table in §8 of the draft):**
| from | to | class |
|---|---|---|
| contract | HOL functions | TESTED-UNPROVED (Wave Gate 1; not my area) |
| HOL functions | CakeML code | MACHINE-CHECKED (translator; M1R-1) |
| CakeML code | model code bytes | MACHINE-CHECKED (`compile_correct'`, C32/C34 exit 0) |
| file | `refund_file` | ASSUMPTION (Q3c conditional) |
| model at `cml_main` | model output | MACHINE-CHECKED (e4 lines 240–331) |
| real C | `refund_env_ok_sl` | ASSUMPTION (not approved in this form; probably false) |
| process | entry state | ASSUMPTION (Q3a) |
| process | machine model (`native_refines`, A3) | MISSING |
| CPU/OS between steps | L3 + `interference_ok` | ASSUMPTION (Q1) |
| libSystem/kernel | oracle answers | ASSUMPTION (Q3b, Q2; write errors not approved) |
| model events | stdout bytes (L-OUT) | MISSING |
| Halt | exit status (L-EXIT) | MISSING |
| process | observed bytes | TESTED-UNPROVED (Wave Gate 1) |
| output | caller/sink | MISSING |

First MISSING link in my area, nearest the approved contract: native process → machine model (`native_refines` / A3).

| step | status | evidence or blocker |
|---|---|---|
| B1 (exact claim statement, X1) | REPORTED | <session scratch folder>/m1b/X1/M1_EXACT_CLAIM.md; sources: e4-0001 stdout.log lines 63–80, 151–156, 240–331, proof.sml; unsure.md U392–U409; BK M1_PROFILE_A_RESTRICTED.md A3; CK targetSemScript 118–234, 317–366, basis_ffi.c 138–202, 721–742, 883–890, fsFFIScript 187–362, export_arm8Script 82–115. Nothing proved or run |
