# Refund exception source semantics — U284

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.

`forge_refundRejectSemanticsTheory.refund_error_stdio_semantics` is **PROVED**.
It connects the existing `refund_main_error` contract to the nonempty set of
source-program behaviors. Every behavior has the full final modeled FFI event
list, the modeled FFI transition relation, an exception satisfying `Fail_exn err`,
and the `STDIO (fastForwardFD fs 0)` postcondition. All pointer-equality oracles
are covered. The approved specification, input domain and required trace were
not changed. This is a conditional source theorem, not a native-execution theorem.

## Exact theorem and premises

```sml
Decls env1 st1 prog env2 st2 ==>
lookup_var «refund_main» env2 = SOME refund_main_v ==>
stdin_content fs = SOME text /\
refund_run_wire (implode text) = INL err ==>
SPLIT (st2heap p st2) (h1,h2) /\ STDIO fs h1 ==>
sem_satisfies
  (semantics_dec_list st1 env1
    (SNOC (Dlet NoLocs (Pcon NONE [])
      (App Opapp [Var (Short «refund_main»); Con NONE []])) prog))
  (λbehavior. ∃st3 exn.
    behavior = Terminate Success st3.ffi.io_events /\
    (∃h3 h4. SPLIT3 (st2heap p st3) (h3,h2,h4) /\
      (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) /\
    RTC call_FFI_rel st1.ffi st3.ffi)
```

The six conjunctive premises are substantive. `Decls` must bind the actual
declaration prefix and states. Lookup must select the verified main value.
The supplied stdin must exist, and the existing wire evaluator must return the
stated error. The initial heap must split as stated and satisfy `STDIO fs`.
Zero explicit theorem hypotheses does **not** mean these implication premises
have been discharged for the native executable.

The theorem covers arbitrary modeled input text satisfying those premises.
It does not restrict IDs, Unicode, amounts, reasons or callers to test fixtures.
It does not cover the separate unavailable-stdin branch through this premise.
The exact `ffi.io_events` is retained; no event is removed or replaced with an
empty trace. This does not yet provide a closed event-replay equation for the
initialized concrete `refund_prog`.

`Success` is the source semantics' logical outcome constructor. The checked
`refund_raise_determ` theorem derives it from `Rerr (Rraise exn)` using the
pinned `semantics_dec_list_determ_def`. It is neither normal ML return nor an
OS exit-code guarantee. No claim about POSIX exit0 follows from these proofs.

## Checked chain

| Theorem | Checked role |
| --- | --- |
| U282 `refund_call_main_exception` | Exceptional application to appended declaration evaluation and heap postcondition |
| `refund_raise_determ` | Exact exceptional evaluation to deterministic behavior and modeled FFI relation |
| `refund_exception_determ` | Conditional declaration/application composition |
| `refund_evaluate_dec_list_clock_result` | Equal non-timeout results across sufficient clocks |
| `refund_semantics_dec_list_determ_terminate_unique` | One terminating deterministic behavior fixes that oracle's behavior |
| `refund_semantics_dec_list_all_terminate` | Nonempty behavior set and property for every pointer oracle |
| `refund_exception_semantics` | Generic exceptional application to all source behaviors |
| `refund_error_stdio_semantics` | Existing refund error contract to the complete modeled behavior and heap claim |

Three generic local lemmas are replayed in this new proposal theory because
their equivalents in the existing `cfMain` theory are not exported. Their
source origin and hash are recorded. No upstream theory or proof machinery
was modified. Their actual proofs run through the same existing kernel.

## Actual commands and preserved failures

`R` below is `records/run.py`. Full invocations, source snapshots, stdout,
stderr, completion markers and exports are retained under `records/`.

| Command/check | Actual exit | Observation |
| --- | --- | --- |
| `R determ-0001` | 0 | First two deterministic lemmas exported |
| `R stdio-0001` | 1 | Clock helper cannot derive equality of final FFI states |
| First clock diagnostic | 1 | Wrong quotation form for diagnostic interface; preserved |
| Corrected clock diagnostic | 0 | Exact hypotheses and shadowed state theorem printed |
| `R stdio-0002` | 1 | Generic all-oracle lemma checks; final rule application asserts |
| Stdio diagnostic | 0 | Exact error app contract is available; final rule step isolated |
| `R stdio-0003` | 0 | All seven new theorems checked and exported |
| `R stdio-repeat` | 0 | Same source; all four exports byte-identical |
| `R wrong-empty-trace wrong-empty-trace.sml` | 1 | Wrong event-list substitution refused at required theorem |
| `import_audit.py` | 0 | Fresh import; unchanged final statement and seven theorem tags checked |
| `readback.py` | 0 |245-node closure,1458 parent files,50 protected paths and native identity checked |

The first residual had equality of clock-adjusted execution states. An opened
`semanticsTheory.state_component_equality` described a different state record.
Explicit `semanticPrimitivesTheory.state_component_equality` closes the exact
unchanged clock lemma. The next diagnostic constructs the required error app
fact successfully. The final `drule_all` application still asserts. Explicit
instantiation of only `P` and `Q`, followed by `metis_tac`, proves the unchanged
target. Its internal assertion cause remains unestablished; the logs are kept.
The saved `Context.snapshot` warning also remains in the original proof logs.

The wrong-trace control changes only the final target from the actual
`st3.ffi.io_events` to `[]`. The proof reports `no solution found` for
`refund_error_stdio_semantics`, exports nothing and has no completion marker.
This tests binding of the proof claim. It is not a universal refutation theorem.
U274's five failures, U278's builder refusal and U282's diagnostics remain intact.

## Exact artifact identities

| Artifact | SHA256 |
| --- | --- |
| Final source and replay source | `68c4f9bbf6537d1ea9f5afcd8980e1302779e3adcddd542e5f1eea96228e7655` |
| Theory data | `cfb0f1aa475e4c08a4f490cef6b0d187c7ac274f06e6cf9e6925da2615f215d0` |
| Generated structure | `19e68b4422dc28994331894a75d7af3b9019275467ad906a3c7aa7b193a25469` |
| Generated signature | `85226f6846fd26b21d7c0433b6de8074335d67ebd65650a9682728f9f6b5c738` |
| Generated HTML | `5b76253e4d0950fe43eb9c5a256ad5649c932cbb3df042114cb18c69bb051c52` |
| Parent declaration theory data | `e6a9062d763b0f049f75633e61633554e6e35a7b9e7e376d9cc6efd42d673760` |
| Standard CakeML heap | `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247` |
| Existing native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

The fresh import checks all seven theorems: zero explicit hypotheses, zero
explicitly tagged axioms and only `DISK_THM` import tags. The closure has245
nodes and the existing `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX` and
`bool.BOOL_CASES_AX` axioms. The1458 input files match U282's accepted snapshot.
The declaration source, stdio source, approved protected files, frozen mission
and native executable are unchanged. Dependency lists and full file hashes are
in `records/dependency-snapshot.json`.

This audit makes the dependencies visible. It does not remove trust in HOL's
logic or kernel, Poly/ML, the loader, the host, or cached parent proof data.
Fresh source replay and import on this host are not clean independent replay
of the complete chain.

## Assurance matrix and next check

| Claim | Status | Limit |
| --- | --- | --- |
| Conditional error contract to all modeled source behaviors | PROVED | Exact six premises above |
| Exception value, consumed stdin and complete modeled event list | PROVED | Heap/FFI model; no physical OS correspondence |
| Nonempty behavior set and all pointer oracles | PROVED | Source semantics |
| Export reproduction, dependency hashes and wrong-trace control | TESTED | Actual exits0/0/1; same host |
| Logic, kernel, loader, host and imported proof data | ASSUMED | Four axioms are explicit; independent clean replay remains open |
| Initialized concrete-program error event-replay equation | NOT_ESTABLISHED | Concrete initial state, prefix/lookup/heap and extraction composition remain |
| Complete unavailable-stdin and physical process-exit contract | NOT_ESTABLISHED | Not implied by logical Success |
| Universal native runtime/FFI/resources and source/model binding | NOT_ESTABLISHED | Prior U276/U277/U283 boundaries remain |
| Complete independent M1 assurance | NOT_ESTABLISHED | `end_to_end=false` |

The [next exact obligation](records/NEXT-OBLIGATION.md) states the basis FFI event
extraction lemma and the concrete initialization work. It is clearly NOT RUN.
It must retain this theorem's full trace and exceptional postcondition.
No native rebuild, test rerun, signing, protected change, deployment or Stage12
occurred in this proof work. The separate compiler proof retains its existing owner.
