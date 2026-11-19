# Step G7: what progress statement each layer of the refund slice can support (Z7, Opus; reading, small Dafny experiments; no HOL)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z7 report: what progress statement each layer of the refund slice can support (links P1 to P16)

**Findings, by layer**

1. **Dafny.** A passing `dafny verify` with no `decreases *` proves one thing: every loop and every recursion in verified code terminates in Dafny's semantics. The postconditions are still partial: they hold only *if* the method returns.
   - `expect`, a body that is not verified, and resource exhaustion are not excluded. Dafny has no notion of memory: `int` and `seq` are unbounded.
   - No Dafny option or audit row flags `expect`.
   - A plain compiled `function` cannot contain `expect`, so it returns a value for every input in Dafny's logic.
   - A `function … by method` CAN contain `expect false`. It verifies and its audit is clean, so it gives no such guarantee.
   - Run time (JavaScript `BigInteger`, heap, stack) is always an assumption.
   - By grep, the current closures (Refund, RefundFinality, AssessFlat, LinkedRefund, SinkCore) have no `expect`, `while` or `decreases *`. The bodies are straight-line, or functions with checked `decreases`.

2. **HOL/CakeML.**
   - **Source level.** `refund_semantics` gives `Terminate Success` with the full output, but ONLY for canonical stdin (`refund_request …`, any typed values, so input size has no bound).
   - For every decodable text, `refund_whole_prog_spec` (a CF `app` spec) holds. It is not lifted to `semantics_prog`.
   - For a decode error, `refund_main_error` holds: an uncaught `Fail` exception. There is no semantics theorem for it. In CakeML's `semantics_determ` an uncaught exception is classed `Terminate Success`.
   - Absent stdin has no theorem (Q5).
   - **Machine model.** `refund_profile_a_sl_every_machine_run` proves that the model halts in every run: no `Diverge`, no `Fail`, at least one behaviour. The result is Success with the full output, or `Resource_limit_hit` with a prefix of it.
   - Nothing bounds heap or stack enough to exclude the resource stop. The only size premise is `8192w ≤₊ e − h`.
   - **Hidden progress assumption.** `wfFS` contains `liveFS`: the stream `numchars` is infinite, and "always eventually" each read or write moves at least one byte. Stdin is a complete file in the model, so a read cannot block.
   - **Space mechanism.** It EXISTS at the pinned commit `cd915569` and is stored in `backendProofTheory.sig`:
     - `compile_correct_is_safe_for_space` (gives `machine_sem ⊆ semantics_prog`, so no resource stop);
     - `IMP_is_safe_for_space`;
     - `dataSem.data_lang_safe_for_space`;
     - `read_limits`, which reads the limits from registers 2 to 4 at the install state.
   - Using it needs `data_lang_safe_for_space` proved for the WHOLE refund dataLang program: basis, TextIO, the S-expression parser and bignums. It also needs `gc_kind ≠ None`; arm8 has `Simple`, by reading.
   - The worked examples (`examples/cost`: yes, cyes, pureLoop, sum, reverse, lcgLoop) used a mini basis. They were 200 to 2,800 lines each. They were REMOVED in commit `32a02d3fe` (2024-11-13, "Remove non-working example"). My estimate for this program: weeks to months (low confidence).
   - No time or step bound exists anywhere: `machine_sem` uses an existential clock.

3. **Native layer.** These are assumptions only:
   - N1: everything before `cml_main` terminates (X5).
   - N2: the kernel keeps scheduling the process (no SIGSTOP, no freezer).
   - N3: stdin holds the complete request and is then closed, and each `read` returns.
   - N4: stdout is drained, there is no SIGPIPE, and each `write` eventually moves a byte. This is the native form of `liveFS`.
   - N5: the heap and stack regions are granted and backed; there is no OOM or jetsam kill.
   - N6: no signal or rlimit (`RLIMIT_CPU`, `AS`, `STACK`) stops the process.
   - N7: the exit path returns its status (X10).
   - N8: a supervisor time limit exists, and a run that hits it is REFUSED.

4. **Sink.**
   - `sink.ts` sets `busy_timeout = 30000` and uses `BEGIN IMMEDIATE`, which avoids the deadlock where two readers both try to become writers. `commit()` has no loop.
   - A busy timeout returns `rejected: "transaction failed: database is locked"`. That is the same status as a final refusal: a progress defect.
   - In D6 there was no busy failure in 20 race rounds (K ≤ 50) or in 486 kills. A contender committed after the lock holder was killed. Wait times were not measured, and K = 100 did not run.
   - "A valid token eventually commits" is FALSE under contention: a concurrent commit makes the pre-state stale for good.
   - In the model, SinkCore proves `Committed ⟺ SinkAccepts`, and `Step` is a total function.

**Progress table**

| Obligation | Layer | Status | Exact statement | Effort |
|---|---|---|---|---|
| P1 loops and recursion terminate | Dafny | provable now (part of verify) | no `decreases *`; termination checked | — |
| P2 no halting construct | Dafny | provable with work | closure has no `expect`, by-method, extern, compiled `:|` | gate rule (Z1) |
| P3 `Assess` returns the approved value for every input | Dafny | provable now | Assess = compiled `function` (exp T6: exit 0; control exit 4) | minutes; spec change |
| P4 compiled code returns | JS | assumption only | A-T2 | — |
| P5 canonical stdin terminates | HOL source | proved (M1R-1) | `refund_semantics` | — |
| P6 every present stdin terminates | HOL source | provable with work | lift `refund_whole_prog_spec` and `refund_main_error` | hours |
| P7 absent stdin | — | assumption (Q5) | excluded | — |
| P8 model halts | HOL machine | proved | `…_every_machine_run` | — |
| P9 no resource stop for input ≤ N, limits ≥ (S, H) | HOL machine | provable with large work | `data_lang_safe_for_space` for refund | weeks to months |
| P9a conditional on A-SPACE | HOL machine | provable with work | draft below | hours to a day |
| P10 step or time bound | HOL | missing; no framework | — | — |
| P11 native progress | native | assumption only | N1 to N8 | — |
| P12 exit path | native | assumption only | X10 | — |
| P13 `commit()` returns | sink | tested only | D6 | — |
| P14 model: accepted means committed | sink model | proved (U5a run) | SinkCore | — |
| P15 eventual commit | sink | assumption only (false in general) | A-S3 | — |
| P16 valid request reaches a commit | end to end | missing | needs X8, X16 | — |

**Wording for the owner's approved assumptions** (each one can be shown false)
- **A-T1.** The verified closure of `Assess`, `Check` and `SinkCore` contains no `expect`, `decreases *`, extern, by-method or compiled `:|`. False if a scan finds one.
- **A-T2.** Compiled `Check` returns within 1 s and 256 MB for any token text of at most 8,192 bytes. False if a test exceeds this.
- **A-R1.** For a canonical request of at most N bytes, with heap e − h ≥ H and stack S, M1 ends with Success and the full frame. The owner fixes N, H and S. False if such a run hits the resource exit or prints a prefix.
- **A-N1.** The caller writes the whole request and closes stdin. It reads stdout to EOF. No signal except the supervisor's.
- **A-N2.** A run that passes T seconds is killed and REFUSED. False if a killed run authorizes.
- **A-S1.** Every holder of the sink's write lock ends within 30 s, and the OS releases the lock when a holder dies. False if `commit` returns "database is locked".
- **A-S3.** Only one issuer per charge is active at a time.

**Smallest progress theorem to prove first: P9a.** It uses `compile_correct_is_safe_for_space` in place of `compile_correct`. It keeps the 11 premises and adds ONE premise, A-SPACE (`∀ms po. is_safe_for_space … (read_limits … ms)`). The conclusion is `machine_sem … = {Terminate Success io}` with the full output, so the resource stop is excluded. Controls:
- N1: the same proof without A-SPACE must fail.
- N2: EVAL `gc_kind ≠ None`.
- N3 (optional): A-SPACE is false at limits (0, 0).

P9a gives no space bound by itself. It turns the resource stop from an allowed outcome into one named, precise premise.

**Commands run** (pinned Dafny via `dafny_locked.sh`, gate options):

| Experiment | Exit |
|---|---|
| T1 loop with no measure | 4 |
| T2 refining `Assess` with a `decreases *` loop | 2 ("possibly infinite loop … only if … `decreases *`") |
| T3 recursion with no measure | 4 |
| T4 `expect` in a function | 2 |
| T5 by-method with `expect false` | 0 (audit exit 0, 0 findings) |
| T5n control (wrong by-method, no `expect`) | 4 |
| T6 total function shape | 0 (5 verified) |
| T6n control | 4 |
| T7 function with no measure | 4 |

The spec copy is byte-equal to the approved file (SHA-256 `90a21c71…`). No HOL ran, nothing was built, and no repository file changed.

**Could not determine:** whether `data_lang_safe_for_space` is feasible with the full basis; the bytes-to-words relation of H; the exit status for an uncaught exception on the machine; real sink wait times.

| step | status | evidence or blocker |
|---|---|---|
| (1) Dafny | DONE | T1 to T7 |
| (2) HOL | DONE by reading | log lines 240 to 331; `.sig`; git history |
| (3) native | DONE (list) | reading |
| (4) sink | DONE | `sink.ts:35,90`; D6 results |
| (5) table and wording | DONE | above |

| link id | proposed class | evidence |
|---|---|---|
| P1, P5, P8, P14 | MACHINE-CHECKED | verify; M1R-1; U5a |
| P3 | MACHINE-CHECKED (an experiment copy only, not approved) | T6/T6n |
| P2, P13 | TESTED-UNPROVED | grep; D6 |
| P4, P7, P11, P12, P15 | ASSUMPTION (P7 approved by Q5; the others not approved) | — |
| P6, P9, P9a, P10, P16 | MISSING | — |

M1-B stays OPEN; `end_to_end=false`.

Files are in <session scratch folder>/m1b/Z7/:
- P9a_space_conditional_DRAFT.sml (the P9a draft; not run)
- exp/ (the experiments T*.dfy, their *.log files, and exits.txt)
