# Refund exception declaration theorem — U282

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.

`forge_refundRejectDirectTheory.refund_call_main_exception` is **PROVED** by the
existing HOL kernel. The unchanged conditional statement connects an exceptional
`app` result to evaluation of the appended `refund_main ()` declaration. It also
preserves the stated separated heap and exceptional postcondition. It does not
yet prove initialized whole-program error semantics or physical native I/O.

## Diagnosis

The exact residual goal supplies `SOME (env,exp) = do_opapp [...]`. Adding the
reverse equation with `assume_tac o SYM`, then calling `fs []`, lets simplification
orient it back. The case expression remains. The saved diagnostic shows this
before any further correction. Using `SUBST1_TAC o SYM` substitutes into that
goal directly. Both the declaration branch and heap branch then close.

This establishes cause2 in the owner's four-way diagnosis: the simplification
context did not use the available equation in the required direction. No new
semantic premise or environment invariant was added. No semantic counterexample
was found. This conditional theorem does not establish that every later runtime
premise holds for the native executable.

U274's five failed checks and U278's denied Holmake invocation remain preserved.
The denied syscall/path is still unknown. U272 already records successful direct
HOL checks in this restricted task. This work uses that existing documented
interface, unchanged pinned tools and the same permissions. It does not retry
the denied Holmake command or reroute it through another task. The source
records each changed approach; attempt counts have not been reset.

## Actual results

Paths below are relative to `records/`. Full commands, sources, stdout, stderr,
hashes and completion markers are preserved there.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Holmake `--no_action` inspection | 0 | Planned commands only; no proof |
| `run_direct.py direct-0001` | 1 | Missing batch namespace; preserved |
| `run_direct.py direct-0002` | 1 | Full theorem reached; first branch remains |
| `diagnostic-rewrite/run.py` | 0 | Exact simplification residual inspected |
| `run_direct.py direct-0003` | 0 | Unchanged full declaration theorem proved |
| `run_export.py export-0001` | 1 | Missing qualified constants; preserved |
| `run_export.py export-0002` | 0 | Fresh standard-heap proof and export |
| `run_export.py wrong-result-0001 wrong-result.sml` | 1 | Normal-result substitution fails at required branch |
| `run_export.py export-repeat` | 0 | Four exported files byte-identical |
| First exported-theory import | 1 | Duplicate `.hol/objs` virtual path; preserved |
| Corrected exported-theory import | 0 | Exact conclusion, zero hypotheses, allowed tags |
| `readback.py` | 0 | Dependency, archive, native and protected-input identities |

The two import invocations use standard HOL generated theory loading. The
correction supplies its virtual artifact paths. It changes no proof data.
An exploratory `hol help run` call also returned1 because this CLI interpreted
`help` as an input file. It provided no proof evidence.

## Exact identities

| Artifact | SHA256 |
| --- | --- |
| Passing direct proof source | `eca8a571f14f73828d25eb1dae14d0fa18833dcd6e6997dcbddc4774ebc5523e` |
| Fresh export/repeat source | `94f931b6e6ac0d14c5b27b86a887b8f9059dc5c1e9e602cca09a7d3f6433435e` |
| Theory data | `e6a9062d763b0f049f75633e61633554e6e35a7b9e7e376d9cc6efd42d673760` |
| Generated theory structure | `c0a61aa7f51760e1df827a7177b316eb6a6139e370b958f6a1604317e94e207f` |
| Generated theory signature | `dd93638d953e8bc925322acad77b53d7d0df01830ef5df5c2b39d4bee07426a3` |
| Generated theory HTML | `ef74dabd4d7980e31063aeb67ea4899200dc9481d2700fc09cb3ccd9a402908b` |
| Pinned standard CakeML heap | `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247` |
| HOL launcher | `736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd` |
| Existing native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

The fresh import checks the expected original statement with `aconv`, zero
explicit hypotheses and zero explicitly tagged axioms. Its only theorem oracle
tag is `DISK_THM`, for imported theory data. Its full closure has244 nodes and
the existing `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX` and
`bool.BOOL_CASES_AX` foundation axioms. The readback verifies1454 old dependency
files against U271's snapshot. It also checks both failed heaps,50 protected
files, the frozen mission and the existing executable. No new axiom was added.

## Assurance limits and next obligation

| Claim | Classification | Evidence or gap |
| --- | --- | --- |
| Conditional exception declaration and heap relation | PROVED | Exact named theorem; fresh proof, repeat and import |
| Wrong normal-result proof control | TESTED | Exit1 at required declaration branch; no accepted export |
| Four-file export reproducibility | TESTED | Exact same-host byte comparison |
| Imported closure identity | TESTED |244 nodes;1454 prior files checked |
| HOL kernel, Poly/ML, loader and prior proof-data validity | ASSUMED | Existing trust base; no independent full-source replay here |
| Initialized whole-program exceptional trace | NOT_ESTABLISHED | Declaration result is not yet lifted through all source semantics premises |
| Real native input/output, installed state and process exit | NOT_ESTABLISHED | U276/U277/U279 retain the open runtime boundaries |
| Clean independent complete-chain replay | NOT_ESTABLISHED | Fresh processes still use this host and cached parent theories |
| Complete M1 assurance | NOT_ESTABLISHED | `end_to_end=false` |

The next smallest experiment is a separate kernel lemma: a clocked
`evaluate_dec_list` result of `Rerr (Rraise exn)` implies
`semantics_dec_list_determ ... (Terminate Success st.ffi.io_events)` and the
existing `RTC call_FFI_rel` relation. Use the pinned definitions and
`evaluate_dec_list_call_FFI_rel_imp`. Then compose it with the accepted
declaration theorem. After that, establish all pointer oracles, initialization
and the concrete `refund_main_error` stdio postcondition. These are planned
proofs, not passing results. Logical `Success` does not prove POSIX exit0.

No native recompilation, signing, protected change, deployment or Stage12 ran.
The separate compiler behavior build retains its existing owner.
