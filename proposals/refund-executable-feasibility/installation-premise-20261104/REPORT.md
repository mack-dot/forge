# Refund installation premise checkpoint — U297

CURRENT stage: none. Active milestone: M1. Stage12 unauthorized.
M1 and integration EXIT: **NOT_ESTABLISHED**. `end_to_end=false`.

The new result is conditional independence from the dynamic compiler oracle in
CakeML's data-language semantics. It does not discharge the machine's installation
contract. The exact executable and all approved input/output requirements remain
unchanged. No physical execution, hosted run, new signing or admission ran here.

## Exact checked result

`forge_refundDataOracle.refund_data_oracle_independence` specializes the existing
`dataProps.evaluate_cc_co_only_diff` theorem to `forge_refundWholeProg.refund_prog`.
The full statement is in [expected-oracle.sml](records/expected-oracle.sml).
It retains the exact `set_oracle arm8_backend_config oracle`, `to_data`, `to_word`,
computed stack frames, computed limits and `is_safe_for_space` premise.
For each modeled clock, replacing the initial data compiler and compiler oracle
preserves the evaluation result and the `cc_co_only_diff` relation on final states.
That relation preserves the data state's FFI, references, locals, code, stack,
clock, resource fields and pointer-equality oracle. It excludes the dynamic
compiler and compiler-oracle fields. The two generic helper theorems establish
the initial relation and its preservation under the explicit data space premise.

**Resource adequacy is a premise, not a result.** This theorem neither establishes
safe space for every approved physical input nor replaces `install_interfer` in
the target machine. It introduces no axiom, semantics, input restriction or policy.
The [U296 precise behavior theorem](../runtime-premises-20261104/REPORT.md)
remains conditional on its entire installed-state and runtime contract.

## Actual checks

| Check | Actual exit | Meaning |
| --- | --- | --- |
| Static native disassembly / byte readback | 0/0 | Exact emitted installer jump is present; reachability is unknown |
| Installation proof attempts1–5 | 1/1/1/1/1 | STOPPED; no complete export |
| Separate data-oracle proof first/corrected/repeat | 1/0/0 | First qualifier error retained; three theorems exported and reproduced |
| Fresh exact import | 0 | Three exact statements; no explicit hypotheses or new tagged axioms |
| Missing resource premise / substituted program | 1/1 | Expected exact-statement refusal in both cases |
| Evidence readback | 0 | 482 closure nodes,2403 hashed dependency files,19 pinned sources,50 protected paths |
| Machine installation-independence proof | NOT RUN | No such new theorem is claimed |
| Native/hosted execution, independent full-chain replay, restore, admission | NOT RUN | No execution or authority completion |

Four complete data-oracle exports match byte for byte. The closure retains only
`bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX` and `bool.BOOL_CASES_AX`.
The fresh import uses cached `DISK_THM` parents on the same host. It is not an
independent full-chain source replay or producer authentication.
The two negative cases each report
`Exact statement mismatch: refund_data_oracle_independence`.
They test exact claim binding. They are not physical counterexamples or release
admission decisions. The first oracle attempt failed on a wrong constant qualifier;
that infrastructure/source error is not counted as an adversarial rejection.

The installation path stopped after five failures. The final failed log contains
four individually saved statements, but no complete theory export or repeat.
Its final failure is `standard_stubs_require_reachability: no solution found`.
Installation negative controls and the combined import were prepared but NOT RUN.
No sixth attempt or claim of a reproduced installation proof is permitted.

## Why the static shortcut does not close the gap

The pinned compiler includes `(Install_location,3,Install_code data_conf)` in its
standard stubs. `Install_code` contains a `wordLang.Install` instruction. The
exact loaded executable also includes the branch to `cake_install`:

| Identity or offset | Observed value |
| --- | --- |
| Loaded code length | 130436 bytes |
| Native file offset of code | 16592 |
| Installation stub offset/length in code | 4580/96 |
| Branch offset in code / native file | 4660/21252 |
| Instruction bytes | `6bfbff17` |
| Static disassembly | `b cake_install` |
| Modeled displacement / destination relative to entry | -4692 / -32 |

This is a jump, not a call. The stub sets its return register separately.
Static instruction presence does not prove dynamic reachability.
The published `no_install_or_no_share_mem` condition is a disjunction. The full
compiler proof selects its no-shared-memory branch; that does not establish
`no_install`. The previous r-x buffer/no-`DEVAL` runtime concern therefore remains.
No memory-permission change, installation attempt or faulting experiment occurred.

Pinned source references, retained byte for byte in this packet:

- [Installation stub](records/upstream/compiler/backend/data_to_wordScript.sml#L720), standard stub list at line3387.
- [Disjunctive condition](records/upstream/compiler/backend/proofs/lab_to_targetProofScript.sml#L774), selected by backendProof at line4530.
- [Required machine installation contract](records/upstream/compiler/backend/semantics/targetSemScript.sml#L444), `installed` at line487.
- [Existing data relation](records/upstream/compiler/backend/semantics/dataPropsScript.sml#L3079), preservation theorem at line3220.
- [Existing interference observation](records/upstream/compiler/backend/semantics/targetPropsScript.sml#L112), including `InstallApp` and `target_cc_regs`.

The inspected published sources did not supply an immediately applicable theorem
that replaces the target installation behavior for this exact reachable execution.
This is a bounded audit finding, not a proof that no such result exists.

## Remaining assurance links

| Link | Classification | Exact limitation / next check |
| --- | --- | --- |
| Exact compiled bytes and retained entry payload | OBSERVED | Identity readback; not a full physical state relation |
| Conditional data compiler-oracle independence | PROVED | Exact three statements, same-host HOL check |
| Static installation stub present | OBSERVED | Byte identity and published source; not dynamic reachability |
| No installation in reachable target executions | NOT_ESTABLISHED | Need a checked reachability/simulation bridge |
| Universal physical `install_interfer_ok` | NOT_ESTABLISHED | r-x candidate buffer and no-EVAL runtime remain unresolved |
| Full `is_safe_for_space` applicability | NOT_ESTABLISHED | Resource premise cannot be omitted |
| ARM control fields, memory/frame/interference, FFI/OS and physical exit | NOT_ESTABLISHED | U296's complete correspondence matrix still applies |
| Source frontend and cross-system interpretation | ASSUMED / not yet reviewed | U294/U295 local proofs do not verify serialization or inter-kernel translation |
| New claim provenance and independent admission | NOT_ESTABLISHED | Historical signatures do not authorize this claim |
| Exact off-machine archive identity and restore | UNOBSERVED | Owner reports a copy; exact hash and restore evidence are absent |
| Effective branch protections | NOT VERIFIED here | No GitHub refresh or governance change in this checkpoint |

## Smallest next authorized action and approval packet

Use existing backend simulation relations to investigate whether the new
data-level result can justify independence from target `install_interfer` on
reachable states of this exact compiled refund program. State the relation and
preserve all entry, FFI, memory, interference and resource premises. The target
is a narrow checked bridge, not a universal OS or compiler proof. Do not restart
the five-attempt installation bundle or U290's stopped entry-layout route.
If no applicable bridge is available, retain the installation premise as
unsupported. A review cannot turn an unproved premise into a proved fact.

This packet is a local proposal. It requests no policy weakening and grants no
admission. Independent reviewers must check the exact three statements, dependency
closure and remaining premise profile before any accepted-claim change. The
separate U294 frontend proposal also still needs review before protected adoption.
Publication, push, merge, dispatch, protected adoption, signing, admission and
deployment retain their existing explicit authorization boundaries. Local unsigned
commits are authorized. Node, SPM, Stage12 and new infrastructure remain out of scope.

## Exact identities and reproduction

Exact local commands, numeric exits and observed wall times are in
[COMMANDS.md](COMMANDS.md). Every failed attempt is retained under `records/`.
The two executable dispatch scripts invoke the existing HOL kernel; they do not
replace it. Use fresh case directories for a reviewer-authorized reproduction.
The stopped installation route must not be resumed as an automatic retry.

| Item | Identity |
| --- | --- |
| Base local docs commit | `e940b9d5b23b5d8d1cad8e9d8bba05550ff31d88` |
| CakeML commit | `cd9155694c16831373ab695a670794f23282ed62` |
| HOL commit | `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` |
| Data-oracle proof SHA256 | `8566a4ef31034b02fc2c6b3cd2c006f2d245a455aa0ca67b7c05f922dfab2772` |
| Expected statements SHA256 | `3c9d249fbd5725374fd859ec07d77240951dc677f2d86ef1d01bc0709ad7b11f` |
| Theory data SHA256 | `f7502eeea86a4c1fdd6fe257779ed842c8b2ceb7d0ad00fcb3e007a7256d5c5f` |
| Native SHA256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Loaded code SHA256 | `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb` |
| Readback SHA256 | `e035edfa8786512bb25df50d3576f1ac7c9a919bf3b5bee3d98e3ca7703b2ffe` |

Manifest hashes bind retained bytes only. They do not authenticate their producer.
No hosted performance or cost measurement ran. Local times are observations, not
benchmarks, cache savings or evidence of physical correctness.

## Packaging checks

Full staged whitespace check: exit2. The initial narrower check also exited2
because it still included verbatim HOL failure logs. The corrected authored-file
selection exits0. Exact upstream sources, generated exports and raw logs retain
their original bytes. Diagnostics remain in `records/packaging-check.json`;
the exact authored selection is in `records/packaging-authored-check.json`.
No evidence was normalized and no Git whitespace setting was changed.
