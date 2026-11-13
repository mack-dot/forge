# Forge: proof-gated changes

**CURRENT: none — Stage 11 EXITs passed on 2026-10-30 (Stage 11 merged at 4e4112c6; Linux readiness PR #30 merged at e7b5b52a; receipt repair PR #32 merged at edd9f9d9; booking workflow PR #33 merged at f9eb1cbc; hosted booking matrix and historical consumer controls passed; independent historical kernel579 and proposed memory-independent kernel569 passed; recorded21-state model conformance and its independent567-module kernel check passed; auxiliary kernel594 and composed process-prefix kernel595 passed; separate new local observer records FCSR0 and complete404-byte LOAD identity under explicit trust limits); integration EXIT NOT_ESTABLISHED; Stage 12 unauthorized; campaign awaits independent review and operational actions; proposal PR #37 published; fresh fixed-behavior and modeled-exit kernel597 passed; see U254**

Active mission: [FORGE_MISSION.md](FORGE_MISSION.md). Track its current M1–M4
requirements in [FORGE_MISSION_STATUS.md](FORGE_MISSION_STATUS.md). The immediate
priority is a real component's executable behavioral claim. The fixed-ELF GCD
work is supporting evidence. This introduces no new repository stage or authority.



## N1 corrected and proved for every oracle; exclusion still not established — U364–U365

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs. No profile approved. The U298 exclusion premise is not
adopted. No hosted action, protected edit or deletion.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `run_case.py explore-0001` / `0003` / `0006` / `0008`–`0010` / `0012`–`0014` / `0016` |0 each|Explorations; nothing stored. 552 functions; callers of 29 are `[31]` |
| `run_case.py explore-0002` / `0004` / `0005` / `0011` / `0015` |1 each|SCRIPT ERRORS, not counted; no `store_thm` attempt failed |
| `run_case.py explore-0007` |−15|Non-terminating tactic stopped by the agent; not counted |
| `python3 -I -B run_case.py proof-0001 proof-0001.sml` |0|`install_stubs_unreferenced` and ten supporting theorems; three exports |
| `run_case.py import` / `repeat` |0/0|Ten exact statements, 477 closure nodes; byte-identical |
| `run_case.py naive-statement` / `naive-closure` |1/1|Intended mismatch; fresh evaluation rejects `Install_location` alone |
| `python3 -I -B verify_cases_r5.py` (first version) |1|Reader error (export count); corrected |
| `python3 -I -B verify_cases_r5.py` / two altered copies |0/1/1|Byte, exit and marker binding only |
| Lab-level closure P1; lab invariant P2; target prefix lemma P3 |NOT RUN|Proposed lemmas only |
| U298 exclusion for the exact program |NOT ESTABLISHED|Needs P1, P2 and P3 |

[Report](proposals/refund-executable-feasibility/m1-n1-reachability-20261113/REPORT.md).
N1 as first stated is false: `InstallData_location` calls `Install_location`.
The corrected N1 is PROVED for every allocation oracle: no other function of
the exact word program holds a code label of either stub. This is a syntactic
fact; it does not show that the installer is never executed. None of the six
installed-state obligations becomes dischargeable. No frozen statement
changed; no axiom or `cheat`. M1 and integration EXIT NOT_ESTABLISHED.

## Exclusion suffices; exclusion not proved; clean replay of two ARM8 theorems; profiles compared — U360–U363

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs and one clean-container replay. No profile approved. No
authorization changed. No hosted action, protected edit, commit or deletion
(except two containers that the agent created).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| Host disk, swap, Docker VM and process check (read-only) |0|39.1 GiB free (target 20); swap 3.8 GiB in use; no running container; prerequisites hold |
| `docker run … sh /inputs/replay.sh` (clean replay attempt-0001) |30|Both proofs 0; imports and controls 1 by SCRIPT ERROR (theory path); not counted |
| `docker run … sh /inputs/replay.sh` (clean replay attempt-0002) |0|PolyML and HOL from upstream commits; `ffiread_error_return`, `install_call_site_step` and imports 0; two controls 1 as intended; exports byte-identical to the host |
| `run_case.py explore-0001` / `0003` / `0004` / `0006` / `0007` |1/1/1/1/1|SCRIPT ERRORS, not counted; no `store_thm` attempt failed |
| `run_case.py explore-0002` / `0005` / `0008` / `0009` / `0010` |0/0/0/0/0|Goal-manager explorations; nothing stored |
| `python3 -I -B run_case.py proof-0001 proof-0001.sml …` |0|`arm8_install_handler_ok`, `arm8_install_handler_exists`, `installed_modulo_install_handler`, `install_exclusion_suffices`; four exports |
| `run_case.py import` / `repeat` |0/0|Four exact statements, 343 closure nodes; byte-identical |
| `run_case.py missing-exclusion` / `wrong-return-register-v2` |1/1|Intended statement mismatch; bounded tactic fails for the altered handler |
| `run_case.py wrong-return-register` |−24|CPU-limit resource stop; not counted |
| `run_case.py search-install-pc` |0|Observation: no stored theorem concludes an evaluator-prefix PC inequality with `install_pc` |
| `python3 -I -B verify_cases_r4.py` / two altered copies |0/1/1|Byte, exit and marker binding only |
| Working-tree audit (read-only) |0|Tracked documents: additions only; ten ELF files: mode change only; nine packets: 0 manifest mismatches |
| U298 exclusion for the exact program |NOT ESTABLISHED|No published program-counter invariant; needs an instrumented simulation |
| Clean replay of CakeML-dependent theorems; independent replay; hosted job |NOT RUN|No from-source CakeML build on this host |

[Report](proposals/refund-executable-feasibility/m1-exclusion-profile-20261113/REPORT.md),
[profile comparison](proposals/refund-executable-feasibility/m1-exclusion-profile-20261113/PROFILES.md),
[installed-state obligations](proposals/refund-executable-feasibility/m1-exclusion-profile-20261113/INSTALLED-STATE.md).
With installer exclusion, `installed` no longer needs a correct install
handler (PROVED). The exclusion itself is not proved; it is the minimal
explicit assumption and is not adopted. Profile A is recommended, not
approved. `installed` for the physical process stays NOT_ESTABLISHED. No
frozen statement changed; no axiom or `cheat`. M1 and integration EXIT
NOT_ESTABLISHED.

## No safe cleanup; replay not run; initializer on `installed`; installer call site — U357–U359

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs, one at a time behind a resource guard. All results are
same-machine results. No deletion, pruning, clean replay, hosted action or protected edit.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| Scratch, Docker, swap and process inspection (read-only) |0|0 GiB recovered; 12.3 GiB free at the end; target 20; other-project scratch is in live use; Docker trim gains nothing |
| Clean-container replay |NOT RUN|Disk below target; Docker VM shared with a live session |
| `run_stack_case.py explore-0001` / `explore-0002` / `explore-0003` |1/1/0|Two script errors, not counted; then goal-manager proof of the heap lemma |
| `python3 -I -B run_stack_case.py installed-0001 installed-0001.sml ...` |0|`heap_region_extends`, `arm8_machine_model_instance`, `refund_initialization_installed`; four exports |
| `run_stack_case.py audit` / `repeat` |0/0|Premises are the predicate and `installed`; 487 closure nodes; byte-identical |
| `run_stack_case.py missing-installed` / `other-bitmaps` |1/1|Intended statement mismatches |
| `python3 -I -B scan_entry_branches.py` |0|Observation: one direct branch to the installer entry, code offset 4660 |
| `python3 -I -B run_arm8_case.py install-site-0001 install-site-0001.sml` |0|`install_call_site_step`; four exports |
| `run_arm8_case.py import` / `wrong-target` / `repeat` |0/1/0|Exact statement, 97 closure nodes; intended mismatch; byte-identical |
| `python3 -I -B verify_cases_r3.py` / two altered copies |0/1/1|Byte, exit and marker binding only |
| U298 exclusion theorem; `installed` for the physical process; independent replay; hosted job |NOT RUN|Separate obligations |

[Report](proposals/refund-executable-feasibility/m1-installed-closure-20261112/REPORT.md).
The initializer now has two premises: the machine-model predicate, for which
an explicit instance is proved, and the published `installed` predicate, which
stays an assumption for the physical process. The exact code holds one
installer call; U298 is a reachability claim and is not established. Profiles
A and B are unchanged and not approved. No frozen statement changed; no axiom
or `cheat`. M1 and integration EXIT NOT_ESTABLISHED.

## Replay stopped at disk deficit; basis instance, initializer 6→2, U298 lemmas — U352–U356

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs, one at a time behind a resource guard. All results are
same-machine results. No deletion, clean replay, hosted action or protected edit.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| Disk, swap, cache and process inspection (read-only) |0|6.7 GiB free; target 20; deficit 13.3 GiB; nothing already authorized for deletion; 0 GiB recovered by cleanup |
| Clean-container replay |NOT RUN|Stopped by the owner's rule at the deficit |
| `run_case.py explore-0001` / `explore-0002` (instance diagnosis) |1/0|Script error, not counted; then cause shown: two `rest` variables of different type in the old goal |
| `python3 -I -B run_case.py instance-0001 instance-0001.sml ...` |0|`read_error_basis_instance` checked; four exports |
| `run_case.py repeat` / `import` |0/0|Byte-identical; both theorems exact; 219 closure nodes |
| `run_case.py wrong-exception` / `instance-missing-read-none` / `oracle-missing-read-none` |1/1/1|Intended rejections |
| `run_case.py oracle-repeat oracle-0001.sml ...` |0|Byte-identical to U351's export |
| `run_stack_case.py no-machine-config` / `missing-memory` / `missing-memory-statement` (U349 controls) |1/−24/1|Rejection; CPU-limit resource stop, not counted; statement mismatch |
| `python3 -I -B run_stack_case.py aligned-0001 aligned-0001.sml ...` |0|`refund_initialization_aligned`; `REMAINING_ANTECEDENTS 2`; four exports |
| `run_stack_case.py audit` / `repeat` |0/0|Two premises; 486 closure nodes; byte-identical |
| `run_stack_case.py unaligned-domain` / `missing-memory-statement` |1/1|Intended statement mismatches |
| `run_case.py stub-0001` |−24|CPU limit in an optional third lemma; nothing exported; not counted |
| `python3 -I -B run_case.py stub-0002 stub-0002.sml` |0|`install_stub_has_install`, `stubs_contain_install` checked; four exports |
| `run_case.py import` / `wrong-polarity` (first versions) |1/1|SCRIPT ERROR, load order; not counted |
| `run_case.py import-0002` / `wrong-polarity-0002` |0/1|Exact statements, 243 closure nodes; intended mismatch |
| `python3 -I -B verify_cases_r2.py` / two altered copies |0/1/1|Byte, exit and marker binding only |
| U298 target-level exclusion; `memory_assumption`; independent replay; hosted job |NOT RUN|Separate obligations |

[Report with profiles, matrix and graph](proposals/refund-executable-feasibility/m1-replay-closure-20261112/REPORT.md).
The U351 instance failure was the agent's goal-construction error (U353).
Assurance Profiles A and B are written and not approved (U356). No frozen
statement changed; no axiom or `cheat`. M1 and integration EXIT NOT_ESTABLISHED.

## Continuation: ARM8 composition, initializer 14→6, oracle lemma; replay not run — U348–U351

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs with the pinned tools. All results are same-machine results.
No clean or independent replay, hosted action, native execution or protected edit.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -I -B verify_sources.py upstream-api` |0|HOL, CakeML, PolyML tracked files equal upstream commit trees |
| `run_arm8_case.py explore-0001/0002` |0/0|Explorations; no theorem |
| `python3 -I -B run_arm8_case.py compose-0001 compose-0001.sml` |0|`ffiread_error_return` checked on the exact native bytes; four exports |
| `run_arm8_case.py repeat` / `import` |0/0|Exports byte-identical; exact statement; `DISK_THM` only; 97 closure nodes |
| `run_arm8_case.py wrong-status` / `missing-separation-v2` / `untaken-branch-v2` |1/1/1|Intended rejections after the positive audit |
| `run_arm8_case.py missing-separation` / `untaken-branch` (first versions) |1/1|SCRIPT ERROR, no current theory; not counted |
| `run_stack_case.py explore-0001` (initializer) |0|Exploration; no theorem |
| `python3 -I -B run_stack_case.py machine-0001 machine-0001.sml ...` |0|`refund_initialization_machine`; `REMAINING_ANTECEDENTS 6`; four exports |
| `run_stack_case.py repeat` / `audit-0002` |0/0|Exports byte-identical; six premises; 485 closure nodes |
| `run_stack_case.py audit` (first start) |none|INTERRUPTED by the agent under memory pressure; not a result |
| Initializer controls `no-machine-config`, `missing-memory` |NOT RUN|Memory and disk guard |
| `run_case.py explore-0001/0002/0003` (FFI oracle) |1/−9/0|Script error; wall timeout under load; then goal-manager proof. No theorem stored |
| `python3 -I -B run_case.py oracle-0001 oracle-0001.sml ...` |0|`basis_read_error_oracle` checked; instance theorem FAILED once (`No match`) |
| `python3 -I -B verify_cases.py` / two altered copies |0/1/1|Byte, exit and marker binding only |
| Clean or independent replay; U298 exclusion; hosted job; oracle import/repeat/controls |NOT RUN|Disk 1–2 GiB free, swap 15–16 GiB; approval boundaries |

[Continuation report with matrix, graph, inventory and plan](proposals/refund-executable-feasibility/m1-closure-20261112/REPORT.md),
[ARM8 composition](proposals/refund-executable-feasibility/arm8-compose-local-20261112/REPORT.md),
[initializer corollary](proposals/refund-executable-feasibility/initializer-machine-local-20261112/REPORT.md).
Parallel HOL jobs raised swap and reduced free disk to about 1 GiB; the agent
stopped the batch and ran the rest one at a time under a guard (U350).
No frozen statement changed; no axiom or `cheat`. The FFI oracle equation for
native read errors on open descriptors stays ASSUMED. U298 was inspected by
source reading only. M1 and integration EXIT NOT_ESTABLISHED.

## Two local proofs checked: generic read error and initial stack code — U345, U346, U347

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner approved the local M1 actions of U342. All runs are local HOL runs
with the pinned tools. No hosted action, native execution or protected edit.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `run_case.py explore-0001/0002/0003` (goal-manager explorations) |0/0/0|No theorem; two exploration-script tracking errors preserved |
| `python3 -I -B run_case.py proof-0001 generic-read-0002.sml` |0|`read_error_generic` checked; frozen statement bytes; four exports |
| `python3 -I -B run_case.py repeat generic-read-0002.sml` |0|Four exports byte-identical |
| `python3 -I -B run_case.py import import.sml proof-0001 forge_refundGenericReadError` |0|Frozen U329 import; exact statement; `DISK_THM` only; 217 closure nodes |
| `run_case.py wrong-exception ...` / `run_case.py omitted-event ...` |1/1|Frozen U329 controls; `Exact generic read statement mismatch` |
| `python3 -I -B validate_evidence.py` / altered-copy control |0/1|Byte, exit and marker binding only |
| `python3 -I -B run_recorded.py inspect-arm8-steps-0001` (unchanged U316 source) |0|`arm8_stepLib` loads; seven step theorems for six words; U316 recorded exit1 |
| `run_stack_case.py diagnose-0001/0002/0003` (typed-goal diagnostics) |0/0/0|No export; U314 failing step is `drule specialized_labels` |
| `python3 -I -B run_stack_case.py code-0004 code-local-0004.sml` |0|Five theorems checked; `REMAINING_ANTECEDENTS 14`; four exports |
| `python3 -I -B run_stack_case.py repeat code-local-0004.sml` |0|Four exports byte-identical |
| `python3 -I -B run_stack_case.py audit expected.sml code-0004 forge_refundInitialStackCode` |0|Prepared U314 audit; 14-premise contract; 484 closure nodes |
| `run_stack_case.py wrong-lowering/duplicate-label/missing-memory ...` |1/1/1|Prepared U314 controls; each rejects after the positive audit |
| `python3 -I -B validate_stack_evidence.py` / altered-copy control |0/1|Byte, exit and marker binding only |
| Hosted job; `inputAllFrom`/`refund_main` composition; six-step ARM8 composition; U298; independent replay |NOT RUN|Separate obligations |

[Generic read report](proposals/refund-executable-feasibility/generic-read-local-20261112/REPORT.md),
[ARM8 step report](proposals/refund-executable-feasibility/arm8-step-local-20261112/REPORT.md),
[initial stack code report](proposals/refund-executable-feasibility/initial-stack-code-local-20261112/REPORT.md).
Candidates: generic read SHA90e827dc782bcfe23f0518cca18facf649d434f59421d593bc436a187f003ae3;
stack code SHA7d24953dea9a70a51db26a4ee7c6b858d692a9a5cd84fecf5a86544ff5871c6f.
Both keep every quoted statement byte-identical; tactic changes only; no axiom
or `cheat`. `read_error_generic` assumes the FFI oracle equation; it does not
discharge it for the native runtime. The initializer keeps 14 open conditions
(U313 had 15). Both results are LOCALLY_VALIDATED: same machine and agent,
cached parents, no independent replay. The U341 hosted request was not used.
M1 and integration EXIT NOT_ESTABLISHED.

## Local proof context works; candidate fails at one tactic step — U342, U343

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The EPERM of U316/U319/U320 does not occur in this session. The unchanged
candidate now reaches the theorem and fails. No hosted action or protected edit.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| Read-only `access()` query on `/var/tmp`, `/private/var/tmp` |0|Write access reported; U319 recorded EPERM; no file created |
| Unchanged SAT diagnostic `diagnose-sat.sml`, pinned HOL and ARM8 heap, U316 argv/cwd |0|`⊢ probe ∨ ¬probe`; U316 recorded exit1 |
| `python3 -I -B run_candidate.py` on unchanged `generic-read-0001.sml`, U328 argv/cwd |1|`cfLib` loads; theorem reached for the first time; `THEN1` failure; 2665 inputs unchanged; no export |
| `python3 -I -B run_candidate.py` on instrumented diagnostic copy |1|Same failure; `xffi` branch leaves five uninstantiated witnesses |
| Tactic repair / repeat / import / two controls / hosted job |NOT RUN|Expected exits are not observed exits |
| Script removal (U343) |NOT RUN|Zero files removed; 33 of 35 `scripts/` files are pinned by the protected lock |

[Report](proposals/refund-executable-feasibility/local-context-20261112/REPORT.md),
[records](proposals/refund-executable-feasibility/local-context-20261112/records).
Candidate SHA7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6.
`read_error_generic` is unestablished, not disproved. The residual is a missing
witness step by the agent's reading; no repair was run. U341's hosted workflow
runs the same candidate bytes, so the same failure is the expected result there;
that is an inference, not an observed hosted exit. Recommendation: hold the
[U341 approval request](proposals/refund-executable-feasibility/proof-loader-fix-20261109/NEXT-RUN-APPROVAL.md)
and repair the tactic locally. Same-machine and cached-parent trust limits remain.
Native frame, composition, U314, U298 and independent replay stay open.

## Loader paths fixed; real local regression passes — U341

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Two bootstrap expressions now supply virtual theory paths for parent loads and
later imports. All other driver/workflow fields and proof inputs are unchanged.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/prepare_fix.py` |0|New unpublished workflow;five generated modes checked |
| `/bin/bash --noprofile --norc -n proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/shell.sh` |0|Shell syntax only |
| Initial local loader regression |1|Non-exported API in test;source/logs preserved,not an accepted negative |
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/test_loader.py` corrected |0|Real child old path1/exact ENOENT;fixed path0,four parent byte reads,two import path resolutions |
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/check_preservation.py` |0|Only two driver expressions differ;candidate/controls,50 protected paths and mission match |
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/record_fix.py` |0|Fix,assurance and tracker recorded;journal prefix preserved |
| Candidate proof / hosted job / publication |NOT RUN|Prior one-retry grant exhausted |

[Fix and tests](proposals/refund-executable-feasibility/proof-loader-fix-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-loader-fix-20261109/ASSURANCE.md),
[separate execution scope](proposals/refund-executable-feasibility/proof-loader-fix-20261109/NEXT-RUN-APPROVAL.md).
Workflow SHA9a29e94d16033592704bfa20bd1ef06818e50458d4155a2216500ac205486629,
16363 bytes. Actual pinned HOL file APIs tested;no theory sources compiled,
cfLib/SAT loaded or theorem attempted. Future output paths resolve correctly,
but no fresh theorem import occurred. Full hosted proof remains unestablished.
Old failures preserved;no protected change,Stage12,signing or deployment.

## Frozen retry reaches HOL; parent theory path fails before candidate — U340

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
HOL_PARENT_LOAD_ENOENT. One approved retry executed; candidate theorem NOT_REACHED.

| EXIT command/action | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/preflight.py` |0|Exact approval/workflow/driver/manifests/candidate; prior attempt1,no competing runs |
| One rerun_workflow_job call |Tool success|Run42661020831,attempt2,job129430257438; unchanged commitf1e4a080 |
| Hosted sw_vers/sysctl/true/otool |0/0/0/0|Pinned ARM64 image and environment checks pass |
| Exact HOL child / workflow step |1/1|Parent QUse load duplicates .hol/objs; ENOENT; no timeout,exports or candidate invocation |
| Repeat / import / two negative HOL controls |NOT RUN|Stopped on first unexpected result |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/read_streams.py` |0|Full log and three chunked artifacts recovered; hashes match |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/validate_evidence.py` |1 then0|Initial seven-digit timestamp parse failure preserved; corrected interval parser only |
| Guessed source path / corrected source lookup |1/0|Read-only shell glob failure preserved; no extra HOL |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/finalize.py` |0|Assurance/tracker updated;50 protected paths and journal prefix preserved |

[Report](proposals/refund-executable-feasibility/hosted-proof-retry-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-proof-retry-20261109/ASSURANCE.md).
Log SHA7fea30873cceeb1b199bfa468ccb4dde56ad2a4f884b95ef902241185c7d7cca.
Required image20261104.0514.1 observed;26196042 input bytes match;1493 before/after
hash checks and private-library gate pass.31s workflow step;provider343000ms,
0 billable ms reported. Actual child CPU/peak RSS unavailable,not inferred.
Bootstrap passes a physical parent theory path to virtual QUse loader,which adds
.hol/objs again. Same convention in U282/U291; static review missed this defect.
No theorem pass or counterexample. Smallest issue:review bootstrap theory paths;
no fix or new attempt made. Single retry authority consumed; no automatic retry.

## Scheduling inspected; one unchanged retry awaits approval — U339

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The theorem remains unestablished,not disproved. No retry or HOL execution.

| EXIT command/action | Actual exit/result | Result |
| --- | --- | --- |
| Run/jobs/repository/queued/in-progress/pending approvals/frozen workflow reads |Tool success|Same cancelled job,no runner/steps; no currently queued/running work or pending approvals |
| Workflow settings metadata / public run page |400 / cache miss|Preserved; exact cancellation reason and account restrictions still unknown |
| `python3 -B proposals/refund-executable-feasibility/proof-retry-review-20261109/records/inspect_retry.py` |0|Exact frozen workflow/candidate and one-call retry scope; no proof/input audit repeated |
| `python3 -I -B proposals/refund-executable-feasibility/proof-retry-review-20261109/records/record_review.py` |0|Assurance/tracker updated; prior journal prefix preserved |
| Retry / HOL / repeat / import / negative controls |NOT RUN|Separate owner authorization required |

[Inspection](proposals/refund-executable-feasibility/proof-retry-review-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-retry-review-20261109/ASSURANCE.md),
[exact retry approval](proposals/refund-executable-feasibility/proof-retry-review-20261109/APPROVAL.md).
Concurrency group forge-m1-macos-environment-preflight,cancel-in-progress:false;
macos-15,15min,permissions{},no environment gate or dependent jobs. Current empty
queues do not establish historical absence of contention.404 BlobNotFound is
not a cancellation explanation. No settings change or proof modification.
Prepared one rerun of job129312292711 at existing commitf1e4a080,expected attempt2,
with unchanged image guard,inputs and controls. No dispatch or further retry grant.

## Authorized frozen proof attempt ends without a runner — U338

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
HOSTED_RUNNER_NOT_ASSIGNED. One authorized job triggered; no HOL execution.

| EXIT command/action | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -B -` frozen-scope/branch/trigger preflight |0|Exact approved workflow and prior evidence; other12 workflows do not trigger |
| `python3 -I -B -` pre-trigger remote workflow/commit check |0|Sole changed workflow; exact approved16385 bytes and Git blob |
| Tree/commit creation and lease-checked branch update |Tool success|One trigger,commitf1e4a080; no force or retry |
| Hosted run / sole job |failure / cancelled|Run42661020831,job129312292711,attempt1; runner_id0,no steps |
| Environment / proof / repeat / import / two negative controls |NOT RUN|No actual OS exits,theorem output or dependency closure |
| Full log / optional check-run reason reads |404 / 400 tool errors|BlobNotFound; unsupported reason endpoint; both preserved |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-run-20261109/records/validate_terminal.py` |0|Separate terminal evidence binding; validates failure report,not proof |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-run-20261109/records/finalize.py` |0|Assurance/tracker/ROADMAP updated; original journal prefix preserved |

[Report](proposals/refund-executable-feasibility/hosted-proof-run-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-proof-run-20261109/ASSURANCE.md).
Provider duration902000ms,0 billable MACOS ms; actual proof CPU/RSS unavailable.
Workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
Pinned image guard never reached. Exact scheduler cause UNKNOWN; no allocation
was recorded. Three prior integrity mutations remain in-process rejections
without separate exits.217 prior packet members and50 protected paths unchanged.
Smallest issue:assigned macOS ARM64 runner that passes frozen image guard.
The one-job authority is consumed; another attempt requires separate approval.
No native/frame/composition/replay work,Stage12,signing or deployment occurred.

## Frozen hosted proof proposal reviewed; execution not authorized — U337

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Owner recommends a separate proof-run decision and explicitly grants no execution.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -I -B proposals/refund-executable-feasibility/proof-approval-review-20261109/review.py` |0|Exact workflow,driver,1493-entry manifests,candidate/import/control hashes and prior evidence match |
| `/bin/bash --noprofile --norc -n proposals/refund-executable-feasibility/hosted-integrity-run-20261109/records/proposed-proof-shell.sh` |0|Syntax only |
| Hosted proof / repeat / import / two proof controls |NOT RUN|Expected exits0/0/0/1/1 are not observed exits |
| Native correspondence / full-chain replay |NOT RUN|Later obligations,not authorized here |

[Exact review](proposals/refund-executable-feasibility/proof-approval-review-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-approval-review-20261109/ASSURANCE.md).
Frozen workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
One15-minute macOS job,permissions{},at most five serial HOL children; each
CPU120s,wall150s,maxheap1536MiB,4MiB/file. Image availability/resource adequacy
remain untested; mismatch fails closed. No blocking static mismatch found.
Three prior hosted integrity controls remain in-process ValueError rejections,
with no separate OS exits. U335/U336 transfer result retained. No hosted action,
protected/input edit,publication,signing or deployment. Next:separate explicit
approval of the unchanged proposal; branch and trigger recheck before publication.

## Completed integrity preflight confirmed; no duplicate job — U336

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
TRANSFER_INTEGRITY_ESTABLISHED. U335 already completed the requested one-job
preflight. Fresh read-only provider evidence confirms that result; no rerun.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/confirm.py` |0|Fresh workflow/log equality; all181 prior packet members,50 protected paths and mission match |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/readback.py` (child) |0|Fresh provider evidence;1475+18 members; complete records match frozen manifests |
| Existing hosted `/usr/bin/python3 -I -B -` |0|Run42624212334,job129183679727,attempt1; log confirms shell exit |
| Existing three integrity mutations |Expected ValueError rejections|No separate OS exits |
| Six fresh GitHub reads |Tool success|Run,list,job,workflow,full log and timing |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/update_tracking.py` |0|Root tracker and append-only journal updated; prior text preserved |
| New hosted job / HOL / native /21-snapshot replay |NOT RUN|One-job request already fulfilled; HOL remains unauthorized |

[Report](proposals/refund-executable-feasibility/integrity-confirmation-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/integrity-confirmation-20261109/ASSURANCE.md).
Exact U335 workflow SHA b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9;
fresh log SHA b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
Existing use:9.004512771s wall,48684KiB peak RSS; provider16s,0 billable Ubuntu ms.
U333's redirect defect remains preserved; the executed workflow uses U334's fix
and the requested mutations/resource records. No source input or premise changed.
The existing [separate TextIO.read proof proposal](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
remains unchanged and unrun. Only root tracking updated; no local commit claimed.

## Hosted transfer integrity established; HOL remains unauthorized — U335

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
TRANSFER_INTEGRITY_ESTABLISHED for the exact frozen published inputs.

| Executed action/check | Actual exit/result | Result |
| --- | --- | --- |
| Checker preparation / local candidate / pre-trigger readback |0 / 0 / 0|Reviewed same one-job scope; no proof inputs changed |
| Hosted integrity process |0|Run42624212334,job129183679727,attempt1; exactly one job |
| Hosted integrity mutations |3 expected rejections|In-process ValueError controls; no separate OS exit |
| Separate full evidence readback |0|1475+18 members,ten files,two commits and unchanged quotation |
| Next proof proposal syntax / preservation |0 / 0|Unpublished; no HOL execution |
| Initial wrong-branch / optional full-job metadata read |404 / 400 tool errors|Both preserved; supported evidence routes succeed |
| HOL / native refund /21-snapshot replay |NOT RUN|Separate authorization and obligations remain |

[Report](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/ASSURANCE.md),
[separate proof proposal](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md).
Downloaded26196042 payload bytes plus36303 metadata bytes. Workflow commitfca212c;
log SHAb22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
Checker9.0045s wall,48684KiB peak RSS; provider16s,0 billable Ubuntu ms reported.
The approved checker retains the redirect fix and adds requested mutations and
exit/resource records. U333/U334 preserved. This is tested transfer integrity,
not the TextIO.read theorem or native correctness. No new local Git commit.

## Redirect scope corrected; revised integrity job awaits approval — U334

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner's recommendation is explicitly not authorization. No hosted job ran.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Revised workflow preparation / shell syntax |0 / 0|New orchestration only; pinned inputs unchanged |
| Original HTTP302 local control |1|Default handler attempts redirected URL |
| Revised positive / five redirect controls |0 / 1,1,1,1,1|Exact reasons and zero follow-up requests checked |
| Corrected control recorder / preservation |0 / 0|Original records and U333 retained |
| Hosted integrity / HOL /21-snapshot replay |NOT RUN|Authorization absent |

[Revised exact approval scope](proposals/refund-executable-feasibility/integrity-preflight-20261109/APPROVAL.md);
[report](proposals/refund-executable-feasibility/integrity-preflight-20261109/REPORT.md);
[assurance](proposals/refund-executable-feasibility/integrity-preflight-20261109/ASSURANCE.md).
NO-GO for U333's workflow:it checked redirects after following them. U334 refuses
them first. GO recommendation for this revised11897-byte workflow,one Ubuntu job,
5 minutes,permissions{},only after explicit approval. Remote bytes remain unchecked.
The first recorder's exit-only308 result was insufficient; both control versions
are preserved. No repeated input audit,DNS retry,proof change or Git repair.

## Remote integrity preflight prepared; authorization pending — U333

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit/result | Result |
| --- | --- | --- |
| getaddrinfo localhost / three GitHub hosts |0 / 1,1,1|Remote names fail with gaierror8 |
| scutil --dns / curl --head |1 / 6|No visible DNS configuration; resolution fails |
| Remote manifest,commit and tree reads |Tool success|Two exact manifests; commit/tree identities reconstructed |
| Offline independent-code verifier |0|1,475 new and18 base local members; original premises match |
| Changed commit / manifest / part controls |1 / 1 / 1|Expected integrity refusals |
| Workflow and shell syntax |0|No hosted execution |
| Root protected paths / mission / old packet hashes |0|50 paths and mission; U329/U332 copies match |
| Initial preservation / git rev-parse / Git diagnostic batch |1 / 128 / 129|Missing worktree metadata; no new commit |
| Hosted preflight / proof /21-snapshot replay |NOT RUN|Explicit authorization pending |

[Exact preflight approval scope](proposals/refund-executable-feasibility/integrity-preflight-20261108/APPROVAL.md);
[evidence](proposals/refund-executable-feasibility/integrity-preflight-20261108/REPORT.md);
[assurance matrix](proposals/refund-executable-feasibility/integrity-preflight-20261108/ASSURANCE.md).
GO recommendation:authorize one integrity-only Ubuntu job,5-minute cap,
permissions{},one11,609-byte workflow; no proof inputs uploaded or executed.
NO-GO for proof:full remote binary readback remains unestablished. Proof execution
needs complete integrity evidence and separate approval under the owner's rule.
Local offline checks are not remote readback or independently controlled replay.
No theorem,premise,published input or protected file changed. The new checkpoint
has no commit because review Git metadata is incomplete; evidence remains local.

## Exact hosted inputs published; proof trigger held — U332

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner first approved trying the exact prepared scope. Four inputs were
published under that authority. A later instruction requires the manifest scope
report before execution and explicit authorization; the workflow remains held.

| Executed action/check | Actual exit/result | Result |
| --- | --- | --- |
| Approved local input identities / corrected transfer reads |0|Four files;44 complete read pieces |
| Initial large buffer / first commit call |Tool errors|Truncated response,then catalog change; both preserved |
| Blob/tree/commit/branch publication |Tool success|21c4bdf; exactly four approved input paths |
| Binary remote readback routes |Tool errors/empty content|Byte readback remains unestablished |
| Direct immutable-URL read |1|DNS getaddrinfo error8; no download |
| Commit/branch/run API readback |Tool success|Workflow head unchanged; only prior U324/U326 runs |
| Protected/input preservation |0|Root50 paths plus mission match; review protected/prior packet diff0 |
| New proof / hosted job /21-snapshot replay |NOT RUN|Zero hosted runs used in this attempt |

[Exact transfer,commands,permissions,budget and expected checks](proposals/refund-executable-feasibility/hosted-cf-transfer-20261108/REPORT.md);
[assurance matrix](proposals/refund-executable-feasibility/hosted-cf-transfer-20261108/ASSURANCE.md). The uploaded and committed blob IDs
match local values. Complete remote byte readback is a distinct unmet requirement.
No pinned input,theorem,premise or event was changed. Smallest transport need:
a binary-capable reader for the published immutable commit. Execution also remains
held under the latest report-before-execution instruction. No automatic retry.

## Prepared hosted job reviewed on owner request — U331

CURRENT none; M1 open; goal remains blocked; Stage12 unauthorized; end_to_end=false.

| Executed check | Actual exit | Result |
| --- | --- | --- |
| Frozen packet/workflow/statement review |0|66 packet files,1,475 archive members and exact expected statement match |
| Embedded shell syntax |0|bash -n only; no proof or hosted command executed |
| Optional source lookup |2|Guessed PolyML osmem.cpp path absent; failure retained |
| HOL / hosted run / native run / independent replay |NOT RUN|No additional execution authority inferred |

[Review](proposals/refund-executable-feasibility/hosted-cf-review-20261107/REPORT.md); [assurance update](proposals/refund-executable-feasibility/hosted-cf-review-20261107/ASSURANCE.md).
No blocking defect was found within this offline review. Candidate buffer,state
and full event trace remain. This does not prove the candidate or native frame.
U329's prepared job is unchanged; explicit one-job/input-transfer approval remains
pending under the owner's current goal. No new assumption,axiom or protected edit.

## Goal blocked at the prepared hosted-action approval boundary — U330

CURRENT none; M1 open; goal status blocked; Stage12 unauthorized; end_to_end=false.
The same additional-run/input-transfer condition persists through U328–U330.
U329 completed useful preparation; this turn adds no proof evidence or live wait.

| Executed check | Actual exit/status | Result |
| --- | --- | --- |
| ROADMAP,approval scope,journal and worktree reads |0|Clean U329 review checkpoint4a45cb0; approval pending |
| Goal status update |Returned blocked|No authorized next execution; full objective retained |
| New proof / hosted run / independent replay |NOT RUN|No automatic retry or external publication |

[Checkpoint](proposals/refund-executable-feasibility/hosted-cf-approval-blocked-20261107/CHECKPOINT.json); [unchanged assurance claims](proposals/refund-executable-feasibility/hosted-cf-approval-blocked-20261107/ASSURANCE.md).
Minimum action remains the existing [exact one-job/input-transfer approval](proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/APPROVAL.md).
The owner's current goal explicitly requires it. U329's immutable packet and
all previous failures remain. No protected change or new software correctness claim.

## Generic FFI candidate package ready; hosted approval pending — U329

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
U328's checked replay obstruction remains. No new behavioral theorem is claimed.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Saved-state / module-path metadata |0/0|Four-state chain;549 preloaded modules |
| Input collection / packaging |0/0|1,475 new files; three archive parts |
| Relocated pinned HOL and exact term parsing |0|1,493 input identities match; no cfLib load or theorem attempt |
| Workflow validation / transport roundtrip |0/0|One bounded job; exact streams reconstructed |
| Wrong archive hash / path traversal / symlink |1/1/1|Expected transport refusals |
| First / corrected artifact readback |1/0|Cross-workspace baseline error preserved; separate historical baselines match |
| New generic proof / hosted job / independent21-snapshot replay |NOT RUN|Explicit additional-run and input-transfer approval pending |

[Results](proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/REPORT.md); [assurance matrix](proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/ASSURANCE.md).
Public loadHierarchy and path registration permit exact saved-state/module files
in private paths. The unchanged candidate statement parses. Its proof and closure
remain unchecked. No failing local loader/SAT/ARM8 route was retried.
[Concrete next action](proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/APPROVAL.md):publish10,815,103 input bytes and
run one15-minute macOS ARM64 job for the unchanged generic FFI candidate,with
conditional repeat/import/two controls. No automatic retry or native/full-chain
replay is included. The owner's current goal requires this additional approval.
No publication,protected change,signing,Stage12 or deployment occurred.

## Read-error replay obstruction checked; generic proof loader stopped — U328

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
U327 made progress. This turn checks the complete-event consequence and tests
the published generic FFI route without changing any existing theorem or model.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Four-theorem proof / repeat / fresh import |0/0/0|First attempt passes; four identical exports |
| Wrong replay result / omitted error event |1/1|Intended exact-statement refusals |
| Artifact/closure readback |0|217 nodes,1287 closure files,2668 inputs;50 protected paths plus mission match |
| CakeML pin / eight-source diff |0/0|Inspected sources match pinned revision |
| Generic TextIO error candidate |1|load cfLib fails in helperLib/numLib.DECIDE; theorem not reached |
| Generic failure readback |0|No theory export; complete failure retained |
| New native / hosted / independent21-snapshot replay |NOT RUN|No additional external authority or completed chain |

[Proof and limits](proposals/refund-executable-feasibility/read-event-gap-20261107/REPORT.md); [assurance matrix](proposals/refund-executable-feasibility/read-event-gap-20261107/ASSURANCE.md).
`basis_read_ignores_ext` closes the extension-override route. The new
`stdin_error_complete_trace_rejected` preserves arbitrary prefix/suffix and
complete byte pairs:under the guarded stdin premises,a status1 read event makes
extract_fs return NONE. U310 requires SOME. No event is dropped or premise
weakened. This is a model obstruction,not a demonstrated native counterexample.
The separate generic-FFI candidate retains an explicit transition,buffer,state
and full event append. Its load failed before its theorem. No errno was captured;
the U320 mkstemp cause is not established for this failure. No loader retry.
[Next](proposals/refund-executable-feasibility/read-event-gap-20261107/NEXT-STEP.md):prepare exact hosted inputs for unchanged cfLib load
and candidate,then obtain one-run/transfer approval before external execution.

## Software boundary: stdin model domain proved — U327

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner limits the goal to software correctness under explicit ISA,OS and
HOL trust assumptions. No silicon proof is required. No hosted run was added.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Initial runner preflight / first model proof |1/1|Missing physical signature path,then missing constructor fact; preserved |
| Residual diagnostics1–4 |1/1/1/0|Exact residual recovered; no sandbox denial |
| Corrected model / totality extension / repeat / fresh import |0/0/0/0|Four final theorems; four identical exports |
| Wrong status / missing stdin guard |1/1|Intended exact-statement refusals |
| Native errno wrapper; two native children |0;0/0|libc read returns-1/EAGAIN35 versus0/errno0; both executable streams empty |
| Artifact/dependency readback; source pin/diff checks |0;0/0/0|148 theory nodes,876 closure files,2665 inputs;50 protected paths plus mission unchanged |
| Hosted run / ARM8 frame proof / independent21-snapshot replay |NOT RUN|No new external authority; full chain remains open |

[Proof and evidence](proposals/refund-executable-feasibility/stdin-domain-20261107/REPORT.md), [assurance matrix](proposals/refund-executable-feasibility/stdin-domain-20261107/ASSURANCE.md).
`stdin_ffi_read_total` proves that wfFS,STD_streams and valid stdin buffer guards
force an existing model result with status0. `stdin_ffi_read_status_zero` covers
every returned result. The native C source uses status1 on read errors. The
smallest gap is now the admitted physical stdin relation for such error events.
No no-error assumption,descriptor restriction,event weakening or semantic edit
was introduced. OS exit0 remains distinct from logical Success and FFI events.
[Next precise paired-event check](proposals/refund-executable-feasibility/stdin-domain-20261107/NEXT-STEP.md). U310/U315 remain unchanged.

## Unchanged hosted SAT diagnostic passes without privilege — U326

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The authorized additional [run42400884739](https://github.com/mack-dot/forge/actions/runs/42400884739)
completed successfully. The scoped environment/SAT execution objective is achieved.

| Executed command/check | Actual exit/result | Result |
| --- | --- | --- |
| Local published loadHierarchy API check |0|No local SAT retry |
| Workflow/source validation |0|No sudo; unchanged runtime,states,diagnostic and solver binding |
| Hosted sw_vers,sysctl,true,otool |0 each|Pinned ARM64 macOS image; private RUNNER_TEMP root |
| Hosted access / mkstemp |0 / fd3; errno0|Read/write,memory and negative EACCES13 control pass |
| Exact HOL/SAT subprocess |0|Reports ⊢ probe ∨ ¬probe; completion marker |
| Separate API/log/stream/source readback |0|36 input hashes,18 sources,50 protected paths plus mission match |
| Native MiniSat / instruction proof / physical proof / independent replay |NOT ESTABLISHED / NOT RUN|No coverage inferred from diagnostic success |

[Exact result and trust limits](proposals/refund-executable-feasibility/hosted-macos-nosudo-20261107/REPORT.md).
Public PolyML loadHierarchy loads five unchanged states from a private writable
path. The original MiniSat path is unavailable; the unchanged library uses its
existing proof fallback. This is not native MiniSat execution evidence. GitHub
reports0 billable MACOS ms and47000ms run duration. No additional run remains
authorized. [Next exact physical-proof check](proposals/refund-executable-feasibility/hosted-macos-nosudo-20261107/NEXT-STEP.md):
load the unchanged ARM8 evaluator,inspect word39000268's complete store/frame
premises,then address the error-return composition. Full OS/FFI relation remains open.

## Goal blocked at exhausted one-run authority — U325

CURRENT none; M1 open; goal status **blocked**; Stage12 unauthorized;
end_to_end=false. Third consecutive goal turn at the same approval boundary.

| Executed check | Actual exit/status | Result |
| --- | --- | --- |
| Roadmap,journal,worktree status reads |0|Prior U324 checkpoint retained |
| GitHub job status read |Tool success; no process exit|Job128147719439 completed/failure; prior step78 |
| Goal status update |Returned blocked|No new execution authority; no live wait |
| New hosted run / SAT / proof |NOT RUN|Additional-run and scoped setup approval pending |

[Blocked checkpoint](proposals/refund-executable-feasibility/execution-approval-blocked-20261106/CHECKPOINT.json).
Next action remains the prepared [one-run/directory-setup approval](proposals/refund-executable-feasibility/hosted-macos-run-20261106/NEXT-ACTION.md).
U324 assurance matrix and evidence remain unchanged. No automatic retry or
substitute proof. The current goal is not complete.

## Hosted execution reaches a new path-permission boundary — U324

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
One authorized hosted run completed. [Run42292059389](https://github.com/mack-dot/forge/actions/runs/42292059389).

| Executed command/check | Actual exit/result | Result |
| --- | --- | --- |
| Pinned PolyML saved-state parent inspection |0/0|Five-state ancestry identified; no SAT |
| Input packaging,extraction,workflow static check |0|Exact bytes prepared; static check later found incomplete |
| Hosted sw_vers,sysctl,true |0/0/0|Pinned macOS ARM64 image; process executes |
| Hosted access / mkstemp |0 / fd3; errno0|/var/tmp works; read/write and negative EACCES13 control pass |
| Hosted Python step |78|mkdir /Users/mackianni fails EACCES13 before input download or SAT |
| API/log/source readback and preservation |0|Published identities match;50 protected paths plus mission unchanged |
| Unchanged SAT / physical proof / independent replay |NOT RUN|Original installation path unavailable |

[Exact evidence and assurance limits](proposals/refund-executable-feasibility/hosted-macos-run-20261106/REPORT.md).
GitHub reports0 billable macOS milliseconds and12000ms run duration. Metadata-read
only token; provider isolation/OS remain trusted. Readback found an unused
INPUT_8435 key bug; prepared fix is unexecuted and did not cause observed EACCES.
[Exact next action](proposals/refund-executable-feasibility/hosted-macos-run-20261106/NEXT-ACTION.md):
approve one additional run and two scoped privileged directory-setup commands.
The existing one-run authority is consumed; no automatic retry or permission
broadening. Pinned tool/runtime/SAT input bytes and proof statements unchanged.

## Hosted macOS preflight prepared — U322

CURRENT none; M1 awaiting external-preflight approval; Stage12 unauthorized;
end_to_end=false. No proof or same-sandbox diagnostic ran.

| Executed command/check | Actual exit/status | Result |
| --- | --- | --- |
| Local workflow/source validation |0|YAML parses; embedded Python compiles; mutation scope and triggers checked |
| Preparation readback,initial / corrected (U323) |1/0|Wrong cross-history comparison preserved; individual identities and journal prefixes match |
| Connected GitHub metadata reads |Tool success; no process exit|Forge public; mainf9eb1cbc; read-only access works through connector |
| Hosted publication / preflight / SAT |NOT RUN|Exact external action awaits approval |

[Review the one-job proposal](proposals/refund-executable-feasibility/hosted-macos-preflight-20261106/APPROVAL.md). Standard GitHub-hosted macos-15
ARM64 is a new candidate; provider docs list this class as free for public repos.
Unlike self-hosted inventory,it does not require a pre-registered personal Mac.
Prepared workflow is environment-only,empty token permissions,no checkout,
installs,secrets or proof/toolchain upload. It pins image20261104.0514.1 and
checks architecture,/var/tmp,memory,process and a negative permission control.
No matching push trigger exists in the12 base workflows for the proposal branch.
Remote source transfer beyond this generic workflow needs separate approval.
A preflight success would not prove M1 or preserve a VM for later jobs.

## Authorized execution target required — U321

CURRENT none; M1 blocked; Stage12 unauthorized; end_to_end=false.
**BLOCKED: AUTHORIZED_EXECUTION_TARGET_REQUIRED**

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Scoped workflow/connection discovery |0|14 Ubuntu jobs;9 SSH aliases establish no authorized macOS target |
| First GitHub recorder / corrected registry request |1/1|Recorder type error preserved; corrected request cannot connect; registry UNKNOWN |
| Target validation,transfer,SAT,proof,replay |NOT RUN|No authorized target established |

[Discovery limits and minimum user action](proposals/refund-executable-feasibility/target-required-20261106/REPORT.md).
Historical macOS runner plans are unprovisioned proposals. Reuse U320's VM
inventory; no repeated sandbox diagnostic or artifact audit. Supply one existing
authorized macOS ARM64 target and connection details with trusted host identity.
Require private writable /var/tmp,enforced isolation,exclusive proof-state access,
verifiable pinned tools/provenance and sufficient resources. Validate first;
external transfer requires separate explicit approval. No infrastructure or costs.

## Required temporary creation fails at mkstemp — U320

CURRENT none; M1 execution blocked; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `attempt-0004/run_temp_requirement.py` |1|Private read/write passes; original term CNF has1 variable,2 clauses; tmpName raises EPERM at basicio.cpp:1025 |
| `otool -tvV -p _PolyBasicIOGeneral` |0|Runtime uses /var/tmp/ plus MLTEMP template,then mkstemp; line1025 error branch confirmed |
| Targeted `log show` query |64|Cannot run while sandboxed; no denial event retrieved |
| Initial/corrected directory metadata lookup |127/0|Wrong ls executable path corrected; no target retry |
| Record/input readback |0|86 prior bindings and original SAT input unchanged;50 protected paths included |
| Unchanged SAT / physical proof / independent replay |NOT RUN|Authorized replacement context not supplied |

[Exact current failure, settings distinction and smallest unblock action](proposals/refund-executable-feasibility/temp-requirement-20261106/REPORT.md).
TMPDIR configures Poly/ML memory backing files,not this pinned tmpName path.
The current default tmpName call fails at mkstemp. This establishes today's
operation-specific failure,not the historical U316 cause. Standard disassembly
binds the directory/error branch to the unchanged runtime bytes. The managed
filesystem sandbox is the likely issuer: declared roots exclude /private/var/tmp,
U319 write-access controls deny it,and the host log tool reports sandboxing.
Exact denying rule remains unestablished. No workaround or permissions changed.
Next: obtain an existing authorized isolated macOS ARM64 execution target with
private writable /var/tmp; validate provenance,isolation,controls and resources,
then run unchanged SAT first. Owner asked for target details; dependent work waits.
No proof development,swarm,Stage12 or independent replay is authorized by a probe.

## Read-only environment execution — U319

CURRENT none; M1 open and blocked; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `attempt-0002/run_operations.py` |1|Location-format type error; no operations reached; preserved |
| `attempt-0003/run_operations.py` |0|Pinned HOL/ARM8 heap runs four probes; file read,memory allocation and system command pass |
| `attempt-0003/access_errno.py` |0|20 read-only queries; /var/tmp W_OK returns-1,EPERM; permitted controls pass; absent path gives ENOENT |
| Local record/source/input review |0|12 sources,SDK header,all recorded inputs and50 protected paths unchanged |
| Unchanged SAT,proof,native,swarm,independent replay |NOT RUN|No validated replacement context; no same-query retry |

[Actual denial, separate failure boundaries and recovery requirement](proposals/refund-executable-feasibility/environment-operations-20261106/REPORT.md).
The exact observed API denial is access("/var/tmp",W_OK), not a captured
historical SAT syscall. Both /var/tmp aliases deny write access; reads/search
pass. Pinned HOL's OS.Process.system succeeds with the read-only true command.
The installed SDK's P_tmpdir=/var/tmp matches the existing temporary-path
hypothesis. Historical SAT/Holmake causation and the denial issuer remain open;
sandbox_apply is a separate recorded boundary. No temporary file was created.
Next: an authorized isolated macOS ARM64 context with private writable /var/tmp,
validated identities,permissions,isolation and provenance; unchanged SAT first.
No sandbox weakening,temp override,proof change or full-goal resume occurred.

## Environment diagnosis only — U318

CURRENT none; M1 open and blocked; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `source_audit.py` |0|12 pinned sources,6 retained diagnostic files,relevant tool/heap identities and50 protected paths match |
| Initial read-only source lookup batch |2|Guessed source path absent; corrected source lookup retained |
| New SAT,proof,native,independent replay |NOT RUN|No same-context retry or permission change |

[Source path, error-location finding and exact recovery experiment](proposals/refund-executable-feasibility/environment-recovery-20261106/REPORT.md).
Poly/ML replaces nonzero-errno diagnostic text with the generic OS message.
The runtime source supplies an exception location, but U316 did not record it.
The denied syscall/path remains NOT_ESTABLISHED. Temporary creation and process
launch/wait are source-visible candidates; no dynamic attribution is claimed.
No replacement execution context is validated. First run the unchanged SAT
source in an explicitly authorized context with its provenance and isolation
checked. If it fails, preserve it and obtain an original exception location or
an authorized host failure record before proof work. Full replay keeps its
independent environment/provenance gate. No full-goal resume or new theorem.

## Full runtime goal blocked after prerequisite audit — U317

CURRENT none; M1 open; goal blocked; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `attempt-0012/audit.py` |0|487 packet members,21 snapshots,accepted data,native files and50 protected paths match |
| Worktree HEAD / status / protected diff |0/0/0|Clean parent6ce40d46 before tracking updates |
| Scoped replay/environment inventory |0|No validated replacement context identified |
| New proof,SAT,debugger,native,signature,replay commands |NOT RUN|Stopped routes are not retried |

[Full requirement audit,three-turn blocker and exact next check](proposals/refund-executable-feasibility/runtime-blocked-audit-20261105/REPORT.md).
The goal service confirms blocked. U315 and U316 made real progress, but the
validated independent execution/provenance prerequisite remains absent for the
third consecutive goal turn. Current available proof/observer routes cannot
close the physical correspondence. This does not count the SAT error as three
separate failures. No live job is being awaited. Full success is not established.
Smallest obligation: one ffiread call's OS result,complete buffer,filesystem effects,
return state and FFI frame must match the unchanged published model together.
Resume only with an authorized working proof/observer context and validated
independent replay prerequisites. First run the unchanged SAT diagnostic there.
No specification,premise,trace or input-domain change. Stage12 stays unauthorized.

## Native error-instruction boundary and tool restriction — U316

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Pinned LLDB static inspection / byte binding / raw-word readback | 0/0/0 |28 words match both existing native files; no launch |
| Relative / absolute / published-ARM8-heap library loads | 1/1/1 | Missing search path,then two DECIDE failures; no instruction theorem |
| Separate standard HOL SAT dependency diagnostic |1|SysErr Operation not permitted (EPERM) |
| Artifact reader first/corrected |1/0|stderr reader corrected; all failures retained |
| New instruction proof,repeat,import,controls |NOT RUN|No theory exported |
| New native execution,signing,independent full-chain replay |NOT RUN|Environment/provenance prerequisites remain open |

[Exact words,commands,tool error and assurance limits](proposals/refund-executable-feasibility/native-error-instructions-20261105/REPORT.md).
The six post-read error instructions are now bound to exact executable bytes.
Their state/frame theorem remains NOT_ESTABLISHED. The standard SAT_PROVE query
for probe OR NOT probe fails with EPERM. The denied syscall/path is unknown;
do not change solver,temp path or permissions to reroute it. Stop this proof-tool
route until an authorized context permits the operation. No machinery was edited.
2659 prior bindings,ten sources,404 prior packet members and50 protected paths
match. U315's accepted model theorems remain unchanged. Physical ffiread/OS/frame,
installation,resource and independent-replay gaps remain. Next: validate the
unchanged dependency diagnostic in an authorized working context, then inspect
the exact six instruction premises. No new stage or protected/remote action.

## Read/error boundary audited — U315

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Model bundles0001–0006; status diagnostic | 1/1/1/1/1/1;0 | Parser and residual-goal failures preserved |
| Model0007 / repeat / complete import | 0/0/0 | Four exact theorems; four identical exports |
| Wrong ready status / changed error frame | 1/1 | Intended refusals after positive audits |
| Native runners, first/repeat | 0/0 |16 processes:14 normal exit0; two SIGPIPE(-13) |
| LLDB script check / directory launch / valid launch | 1/1/1 | No new native FFI/frame capture |
| Standard checksum / signature checks / readback | 0/0/0/0 | Exact existing artifacts and protections match |
| Replay preflight / independent full-chain replay | 0 / NOT RUN |21 snapshots match; environment/provenance gate NO_GO |

[Exact claims, assurance matrix, failures and next experiment](proposals/refund-executable-feasibility/read-runtime-20261105/REPORT.md).
The ready-read and complete error-buffer model statements are proved. Actual
ffiread syscall/offset/buffer behavior and its universal return-state frame remain
NOT_ESTABLISHED. Logical Success does not imply OS exit0. No model or original
theorem changes. is_arm8_machine_config fixes static target/register mapping;
installed/good_init_state contain the runtime premises. This corrects U310 prose.
147 closure nodes/870 files; four existing Boolean foundations;2659 parent bindings
and50 protected paths match. Independent clean replay lacks validated environment
and bootstrap provenance. No denied operation was retried. Next: restore a working
authorized observer context, then capture one exact error read; retain the need
for universal refinement. Separate U314 initialization work remains open.
No stage transition, protected change, recompilation, signing or deployment.

## Initial stack-code proof checkpoint preserved — U314

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Recorded HOL code-0001/0002/0003 | 1/1/1 | Label, numeric tactic, then FIRST_ASSUM failures preserved |
| Initial byte audit / correction preparation / premature invocation | 1/1/2 | Distinct-checkout and missing-cache assumptions corrected |
| checkpoint-complete.py | 0 | 96 raw files,18 source pins,208 prior U313 members per copy match |
| New complete import, closure audit, repeat and negative controls | NOT RUN | No complete new theory exported |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Full assurance remains open |

[Exact checkpoint, commands, failures and next check](proposals/refund-executable-feasibility/initial-stack-code-checkpoint-20261105/CHECKPOINT.md).
Three helpers complete in-process before the last two bundle failures. The final
combined proof remains unproved at FIRST_ASSUM. U313 remains the latest completed
initialization validation:15 conditions, not14. This Markdown step ran byte
checks only; it did not rerun HOL or promote partial helpers to adopted evidence.
Next: print the typed goals and specialized theorems at each drule boundary.
Identify the failed match before changing the proof. Then complete the exact
statement/premise audit, reproduction and meaningful controls. Preserve U298's
every-prefix requirement and all physical/source/resource/FFI/OS conditions.
The separate histories and U290/U297 stopped routes remain intact. Owner-reported
backup still needs exact other-device hashes/restore. Protections were not
refreshed. No protected or remote operation. M1/integration EXIT NOT_ESTABLISHED.

## Initialization static conditions and full local validation — U313

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Static proof bundles1/2/3 | 1/0/0 | Parser failure;16-condition checkpoint;15-condition final claim |
| Complete imports1/2 | 1/0 | First refuses incomplete reduction; second checks all seven claims |
| Original/static proof repeats; byte comparisons | 0/0;0/0 | Eight identical exports across both theories |
| Wrong stack code / wrong lab oracle / missing memory | 1/1/1 | Intended refusals after complete positive audits |
| Missing-memory first/corrected; sequence/completion | 1/1;1/0 | Tactic error preserved; corrected premise refusal required |
| readback.py | 0 | 483 theory nodes,2406 dependency files; four Boolean foundations |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Complete M1/integration assurance remains open |

[Exact proof, commands, controls, conditions and hashes](proposals/refund-executable-feasibility/initialization-static-validation-20261105/REPORT.md).
Two conditions are discharged by existing compiler facts: every future stack
oracle program is good_code, and the register-name map is a permutation.
The original17-condition claim and reduced15-condition claim pass complete premise
equivalence audits. U312's pending local validation is complete. The proof keeps
memory/layout/alignment, initial-stack good_code and saved-register identities.
Physical applicability and final stack non-failure remain required.

A constructed abstract ARM8 configuration proves only the static oracle fact;
it does not supply physical runtime evidence or replace the actual machine state.
The initial wrong overload qualifier and incomplete normalization remain recorded.
All failures remain. U290/U297 stay stopped. No failing proof exceeds five attempts.
Next: derive good_code for the exact initial stack program using existing word
labels and word-to-stack conventions. Preserve resource and physical conditions;
then connect lower-pass transitions to U298's complete target-prefix obligation.
Fourteen source pins,50 protected paths and892 prior packet members per copy match.
Independent review/replay, new provenance/admission, other-device hashes/restore
and current protection evidence remain open. No new stage or protected/remote
operation. M1/integration EXIT NOT_ESTABLISHED; end_to_end=false.

## Successful-initialization proof checkpoint — U312

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| `inspect-0001` | 0 | Published initializer premise diagnostic |
| `success-0001` / `success-0002` | 1 / 0 | Type error preserved; corrected free variable gives three claims |
| `checkpoint-readback.py` / `checkpoint-readback-complete.py` | 1 / 0 | stderr reader corrected; exact evidence bytes match |
| Fresh complete-contract import, closure audit, repeat, new controls | NOT RUN | Required before this checkpoint is fully locally validated |
| Independent replay, native/hosted run, admission, off-machine restore | NOT RUN | Full M1/integration EXIT remains open |

[Exact statements, 17 conditions, commands and hashes](proposals/refund-executable-feasibility/initialization-success-checkpoint-20261105/CHECKPOINT.md).
The recovered HOL process proves successful modeled initialization under its
17 remaining premises, plus semantics equality conditional on stack non-failure.
Code/oracle identities and basic arithmetic are discharged. Memory layout,
alignment, saved registers, initial/future good_code and register mapping remain.
These are applicability conditions, not observed physical facts. A fallback
constructor or final-output equality cannot prove target-prefix correspondence.

The Markdown tracking step ran byte readbacks only; it did not rerun HOL.
Eleven pinned sources,50 protected paths and843 prior U311 members per copy match.
All earlier attempts and separate workspace/worktree histories remain intact.
U311 is still the latest completed pointer/word-trace validation packet.
Next: discharge available static conditions using published compiler facts, then
check exact statements/closure, reproducibility and meaningful rejection controls.
Retain physical conditions and U298's every-prefix obligation. U290/U297 stay stopped.
No new stage or protected/remote action. M1/integration EXIT NOT_ESTABLISHED.

## Exact pointer witness validated with all seven premises — U311

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Recorded composition bundles1/2/3 | 1/1/0 | Unchanged four-claim proof preserved |
| Premise diagnostic, original/corrected | 1/0 | Script error retained; get_limits state difference isolated |
| Full-contract imports1/2/3 | 1/1/0 | Final complete premise equivalence checked |
| Proof repeat / byte comparison | 0/0 | Four identical exports |
| Pointer substitution / missing prefix / missing space | 1/1/1 | Intended refusals after complete positive audits |
| readback-validation.py | 0 | 491 theory nodes,2430 dependency files; four Boolean foundations |
| Packet/history/links; full staged/authored whitespace | 0;2/0 | Exact raw bytes and separate histories preserved |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Full assurance chain remains open |

[Exact claims, commands, retained premises and hashes](proposals/refund-executable-feasibility/pointer-witness-validation-20261105/REPORT.md).
U308's pending local validation is complete. Unfolding the published get_limits
definition resolves the audit mismatch. Its state projection does not read the
differing endian field. HOL checks full premise equivalence; the theorem and
exports stay unchanged. Endian agreement and data safe-for-space remain required.
The fixed-syntax witness does not permit arbitrary pointer substitution. Seven
source/environment/resource/state conditions remain. No physical initialization
or all-prefix target installer exclusion follows from this model result alone.

Next: specialize the existing full_make_init_semantics relation with the exact
constructor and compilation. Preserve and justify its memory, alignment,
register, code/oracle and configuration premises. Then connect lower-pass
execution to U298's target-prefix condition; final-output equality is insufficient.
U290/U297 stay stopped. Composition and premise equivalence each pass on their
third proof attempt. All failures, U308's packet and separate histories remain.
Seven pinned sources,50 protected paths and4393 prior members match. Independent
review/replay, full source/physical/FFI/OS/resource applicability, new provenance,
other-device hashes/restore and current protection evidence remain open.
No new stage, protected adoption or remote action. EXIT NOT_ESTABLISHED.

## Exact ARM8 refund exception composition checked — U310

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Input inventory first/corrected | 1/0 | Manifest schema failure preserved |
| Original-theorem inspection / new proof / repeat / exact import | 0/0/0/0 | Complete error predicate retained; four identical exports |
| Wrong code / omitted space / shortened trace | 1/1/1 | Intended complete-statement refusals |
| Standard artifact checksum / both signature verifications | 0/0/0 |311 historical members and exact existing builds verified; no signing |
| Replay preparation first/corrected | 1/0 | Historical source filename corrected;21 snapshots prepared |
| readback.py | 0 |486 theory nodes,2659 parent bindings,2727 prior chain files,50 protected paths |
| Independent full-chain replay / new native execution | NOT RUN | Complete physical/native assurance remains open |

[Exact theorem, eight premise groups, commands and assurance matrix](proposals/refund-executable-feasibility/exception-compiler-20261105/REPORT.md).
refund_error_compiled_precise composes U286 with the existing exact ARM8 compiler
theorem. It preserves the outer initial heap frame, Fail_exn witness, complete
FFI events and consumed-stdin replay. Installed state, read_limits, the four
source conditions, ARM8 machine configuration and universal space safety remain.
Logical Success does not imply normal ML return or OS exit0. No specification,
original theorem, trace requirement or valid input domain changed.

Fresh same-host import checks both complete statements and the four existing
Boolean foundations. It is not independent clean full-chain replay. All failures
remain, including two preparation failures; both new proofs pass first attempt.
Next physical check: exact ffiread error/EOF/buffer behavior and ABI frame against
the published ffi_read model. Its unchanged-filesystem error branch has an
explicit source warning about real file-position behavior; no Darwin counterexample
is claimed. Independent replay sources and acceptance plan are prepared only.
Separate initializer/pointer/target-event work remains unchanged. U290/U297 stay
stopped. No native rebuild, signing, protected change, deployment or Stage12.


## Pointer-witness proof captured; complete premise audit open — U308

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
[Current checklist](FORGE_MISSION_STATUS.md#current-execution-checklist) and
[exact checkpoint, commands and hashes](proposals/refund-executable-feasibility/pointer-witness-checkpoint-20261105/CHECKPOINT.md).
U307 remains the latest completed local validation packet.

| Executed command/check | Actual exit / status | Result |
| --- | --- | --- |
| Recorded pointer bundles1/2/3 | 1/1/0 | Final run exports four claims; seven conditions reported |
| Recorded normalization diagnostic | 0 | Diagnostic only; no accepted complete contract |
| Recorded fresh imports1/2 | 1/1 | Resource-premise equivalence remains unproved |
| Recorded premise diagnostic | 1 | Undeclared map_index; argument comparison did not execute |
| checkpoint.py byte capture | 0 | 539 raw files,264 imported copies,684 prior members per copy |
| Documentation/history/links; full staged/authored whitespace | 0;2/0 | Old histories and exact evidence bytes preserved |
| Initial/corrected precommit identity and packet check | 1/0 | Transcription corrected;547 packet members checked; U309 preserves error |
| Repeat, complete closure audit and new rejection controls | NOT RUN | Pending full-contract audit |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Complete assurance chain remains open |

The proof constructs a pointer witness for a fixed but arbitrary syntax oracle.
The generic helper retains causal prefix conditions. It does not permit an
arbitrary pointer substitution. The reported seven conditions retain canonical
source/environment, nonempty stack, endian agreement and data safe-for-space.
Two imports match helpers and conclusion but fail complete premise equivalence.
This checkpoint does not resolve that mismatch or prove physical initialization.

Next: repair the diagnostic's indexing helper in a new copy, compare the resource
arguments, and resolve the exact mismatch without weakening premises. Complete
the import, closure, repeat and controls before the lower-pass event bridge.
The unexecuted readback draft has stale expectations; it is not accepted evidence.
All failures and separate histories remain. No new HOL proof ran in this tracking
step. U290/U297 stay stopped; five attempts per failing proof remain the limit.
Other-device hashes/restore, independent review/replay, resources, physical/FFI/OS
relations and new provenance/admission remain open. GitHub controls were not
refreshed. No new stage or protected/remote action. EXIT NOT_ESTABLISHED.

## Exact stack-constructor premises validated — U307

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Fresh full-contract import | 0 | Four claims; all eight premises checked |
| Proof repeat / exported-byte comparison | 0/0 | Four identical exports |
| Compiler substitution / unsupported initialization / omitted space | 1/1/1 | Intended claim/premise refusals after positive audits |
| readback.py | 0 | 490 theory nodes, 2427 dependency files, four Boolean foundations |
| Packet/history/links; full staged/authored whitespace | 0;2/0 | Exact evidence and append-only histories retained |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Complete assurance chain remains open |

[Exact claims, commands, failures and hashes](proposals/refund-executable-feasibility/stack-initialization-validation-20261105/REPORT.md).
U306's pending local validation is complete. GC, store and compiler-function
conditions are discharged for the exact modeled constructor. Eight source,
resource, pointer and state conditions remain. The fallback constructor does not
prove successful or physical initialization. One epoch is not target installer
exclusion. Same-host cached imports are not independent full-chain replay.

Next: specialize the existing pointer fixed-point and constructor-oracle
congruence lemmas. Preserve prefix conditions. Then use the existing successful-
initialization relation before lower-pass event composition. U290/U297 stay stopped.
Eleven pinned sources,50 protected paths and3162 prior packet members match.
Full source review, physical/FFI/OS relations, resources, independent checking,
new provenance/admission, other-device hashes/restore and protection evidence
remain open. No new stage, protected adoption or remote action. EXIT NOT_ESTABLISHED.

## Stack-initialization result preserved in Markdown — U306

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
[Current checklist](FORGE_MISSION_STATUS.md#current-execution-checklist) and
[exact checkpoint](proposals/refund-executable-feasibility/stack-initialization-checkpoint-20261105/CHECKPOINT.md). U305 remains the latest fully validated local packet.

| Executed check | Actual exit / status | Result |
| --- | --- | --- |
| Previously launched HOL bundles1–7 | 1/1/1/1/1/1/0 | Four final claims; eight conditions remain |
| Bitmap diagnostic | 0 | Existing conversion equality recovered without simplifying it to true |
| Tracking byte audit, initial/corrected | 1/0 | Audit-path error fixed; original proof/evidence untouched |
| Documentation history/links; full staged/authored whitespace | 0;2/0 | Old histories and exact evidence bytes preserved |
| Repeat, fresh exact import, new rejection controls | NOT RUN | New checkpoint validation pending |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Full assurance chain remains open |

GC, store and compiler-function facts hold for the modeled initializer. Its
fallback state does not establish successful or physical initialization.
This tracking step reads completed results; no new HOL proof runs. It preserves
all failures,456 raw files,534 U305 members per copy and distinct document histories.
Next: audit all four exact claims/eight premises, repeat, compare exports and run
meaningful rejection controls. Then continue the lower-pass event bridge to U298.
Resource, pointer, source, physical-state/FFI/OS and independent-review gaps remain.
Other-device hashes/restore and effective protection evidence remain unverified.
M1/integration EXIT NOT_ESTABLISHED. No new authority or remote action.

## Exact compiler oracle premises discharged — U305

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Normalization / diagnostic / corrected composition | 1/0/0 | Oracle and label premises discharged; 11 conditions remain |
| Repeat / byte comparison | 0/0 | Four identical exports |
| Fresh imports 1–3 | 1/1/0 | Unchanged-term helper failures preserved; final complete claim accepted |
| Substituted compiler information / omitted pointer premise | 1/1 | Intended exact-claim and premise refusals |
| readback.py | 0 | 489 theory nodes, 2424 dependency files, four existing Boolean foundations |
| Packaging/history/links; full staged/authored whitespace | 0;2/0 | Exact raw/upstream/generated bytes preserved |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Full assurance chain remains open |

[Proof packet and exact commands](proposals/refund-executable-feasibility/word-oracle-validation-20261105/REPORT.md).
The original U304 13-premise run remains historical. Exact oracle/label lemmas
now remove two additional conditions. Definition instantiation is distinguished
from proof discharge. Resource adequacy, memory/state, source inputs, lower-pass
compiler relation and pointer behavior remain explicit. The theorem does not
establish target InstallApp exclusion or physical applicability. All failures
remain; no proof exceeds five attempts. U290/U297 stay stopped.

Next: use the published full_make_init_compile and IMP_init_store_ok lemmas
with the exact compiler definition. Preserve their premises, then continue the
lower-pass event bridge to U298. Nine CakeML sources, one HOL source, 50 protected
files and 2164 prior packet members match. Toolchain tracked trees are unchanged.
M1/integration EXIT NOT_ESTABLISHED. Independent review/replay, new provenance,
other-device archive hashes/restore and effective protection evidence remain open.
No new stage, protected adoption or remote action.

## Markdown checkpoint and pending oracle validation — U304

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
[Current task checklist](FORGE_MISSION_STATUS.md#current-execution-checklist) and
[exact checkpoint](proposals/refund-executable-feasibility/word-oracle-20261105/CHECKPOINT.md).

| Executed command/check | Actual exit / status | Result |
| --- | --- | --- |
| Previously launched HOL oracle-0001 | 0 | Three exports; combined statement retains 13 antecedents |
| Documentation checkpoint byte readback | 0 | 535 U303 members in each copy; four new exports and 28 imported files match |
| Markdown history, links and authored whitespace | 0 | Separate histories and append-only uncertainty preserved |
| Full staged whitespace | 2 | Original HOL-generated whitespace retained; no evidence bytes altered |
| New proof repeat, exact import and negative controls | NOT RUN | Pending; no completed oracle-validation claim |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Existing assurance boundaries remain |

The oracle equality and future-label bound still occur in the combined theorem.
Their separate exported lemmas must be normalized and applied, then audited.
The lower antecedent count alone does not prove physical assumptions. Next: close
that local composition gap and run its acceptance checks before the lower-pass
bridge. This update preserves the completed run and updates Markdown tracking.
It does not change protected files, acceptance policy or remote state. The full
refund claim, all unresolved runtime premises and approval limits remain.

## Exact refund word code and initializer composed — U303

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Code bundles1–3; repeat | 1/1/0;0 | Six code/initializer claims; qualifier errors retained |
| Epoch first/corrected/repeat | 1/0/0 | Exact configuration and composed conditional trace |
| Import attempts1–5 | 1/1/1/1/0 | Type, reduction, memory-load and normalization failures retained |
| Premise diagnostic | 0 | Complete antecedent sets each contain16 conditions |
| Wrong return / empty stack / substituted code / omitted space | 1/1/1/1 | Intended model/claim refusals |
| readback.py | 0 |488 theory nodes,2421 dependency files; eight identical new exports |
| Copied records/links; full staged/authored whitespace | 0/0;2/0 | Original evidence bytes preserved |
| Native/hosted execution, independent full-chain replay/admission/restore | NOT RUN | Complete assurance chain remains open |

[Exact claims, commands, failures, hashes and next action](proposals/refund-executable-feasibility/word-initialization-20261105/REPORT.md).
The exact refund data-to-word relation and code domains are established. The
published make_init supplies fixed word fields. Their composition removes code-
relation and static-initializer assumptions from U302;16 conditions remain.
They include source inputs, memory/store, resources, compiler/oracle relations,
GC/endian agreement, frame accounting and pointer-oracle representation.
This is a modeled initializer, not a physical loader or runtime witness.

The final import checks seven exact statements plus a kernel-normalized conclusion
and complete premise equivalence. Four existing Boolean foundations remain.
One import ran out of store before claim checking. All owned handles became
terminal before serial replay; no theorem or toolchain setting changed. The
memory cause is unproved. Full-chain independent replay/authentication remains open.

Next: bind the word oracle to exact cake_orac using the existing compilation
and data_to_word_orac_eq_std theorem, then instantiate lower-pass compiler/state
conditions. Preserve resource adequacy and all physical/runtime assumptions.
U290/U297 stay stopped. Nineteen pinned sources,50 protected files and1612 prior
packet members match. No native/remote/protected action. M1/integration EXIT
NOT_ESTABLISHED; other-device hashes/restore and independent review remain open.

## Exact refund data behavior and word trace composed — U302

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Data proof attempts1–4; repeat | 1/1/1/0;0 | Exact source-to-data behavior checked |
| Word proof setup/corrected; repeat | 1/0;0 | Conditional non-error and one-epoch results |
| Refund composition bundles1–7; repeat | 1/1/1/1/1/1/0;0 | Main composition passes its fourth proof attempt |
| Word/data imports; refund imports1–5 | 0/0;1/1/1/1/0 | Nine complete statements checked |
| Omitted data non-failure / omitted space / substituted program | 1/1/1 | Intended claim-binding refusals |
| Omitted canonical input, four audit versions | 1/1/1/1 | Exact stdin condition remains unproved |
| Source/type diagnostics | 0/0 | Existing theorem and type inspection |
| readback.py | 0 |486 theory nodes,2415 hashed files;12 identical new exports |
| Copied records/links; full staged/authored whitespace | 0;2/0 | Exact evidence bytes retained |
| Native/hosted execution, independent full-chain replay/admission/restore | NOT RUN | Complete assurance chain remains open |

[Exact claims, commands, failure reasons and hashes](proposals/refund-executable-feasibility/word-applicability-20261105/REPORT.md).
The exact data program's non-failure follows from its source behavior. It now
supplies the compiler-word theorem's non-failure premise. The source contract,
word initial-state/code/oracle relations and space conditions remain explicit.
Physical applicability and lower-pass event correspondence are not established.
The word result excludes successful modeled Install events in its trace only.
Same-host cached imports are not independent full-chain replay or provenance.

Next: instantiate the retained relations with the existing make_init and exact
refund to_word output. Preserve resource adequacy and every runtime premise.
Then connect word events to U298's target-prefix condition. U290/U297 stay stopped;
no proof exceeded five attempts. All setup, proof and import failures remain.
Fourteen pinned sources,50 protected paths and926 prior packet members match.
M1/integration EXIT NOT_ESTABLISHED. Other-device hashes/restore and independent
review remain open. No protected or remote action. U301 is the separate substrate
record; this result uses U302. Earlier checkpoints remain historical.

## Initialized refund exception semantics checked — U286

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
U286 is the reserved source-proof checkpoint. U300's compiler/runtime work and
U301's separate substrate result remain unchanged.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Extraction attempts1/2/3 | 1/1/0 | Missing helper and library-load failure preserved; exact replay lemma checked |
| Basis composition first/diagnostic/corrected/repeat/import | 1/0/0/0/0 | Three-theorem intermediate variant reproduces |
| Initial declaration inspection / three heap diagnostics / projection lemma | 0/0/0/0/0 | Exact residual facts isolated |
| Initial heap attempts1–5 | 1/1/1/1/0 | Same heap claim passes on fifth attempt |
| Concrete initialized proof / repeat / fresh import | 0/0/0 | Exact refund_prog, nine theorems, four identical exports |
| Wrong final filesystem / wrong main / omitted filesystem premise | 1/1/1 | Intended proof-claim refusals |
| readback.py | 0 |246 theory nodes,1462 parent files,50 protected paths and212 prior packet members |
| Native build/test, independent full-chain replay, signing/deployment | NOT RUN | Physical/native correspondence remains open |

[Exact theorem, premises, commands, failures and hashes](proposals/refund-executable-feasibility/exception-initialization-20261105/REPORT.md).
The new refund_error_initialized_semantics discharges declaration, main lookup,
initial FFI/reference-store and STDIO-heap obligations for the existing refund_prog.
It retains the exception witness, complete modeled event list, FFI relation and
extract_fs replay to fastForwardFD fs0. Four input/environment conjuncts remain:
wfFS, STD_streams, available stdin and the stated wire-evaluation error.
Logical Success is not normal ML return or OS exit0. No event requirement changed.

All nine imported theorems have no explicit hypotheses/new tagged axioms; the
four existing Boolean foundation axioms remain. Same-host replay with cached
parents is not independent clean full-chain replay. Both old failed heaps match.
Next for this branch: compose the exact error behavior with the existing ARM8
compiler theorem, preserving full events and every runtime/resource premise.
Reuse the existing compiled artifact. U300's space/non-error and target event
obligations remain open; U290/U297 stay stopped. No protected or remote action.


## Local execution-substrate checkpoint — 2026-11-05 (U301)

**NO-GO remains.** Benchmark protocol unchanged. CURRENT none; M1 open;
Stage12 unauthorized; end_to_end=false. Target: two isolated workers plus an
independent admission authority. No worker, gateway or pilot launched.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `/usr/local/bin/docker version --format '{{json .}}'` | 1 | Local engine socket connect denied with operation not permitted |
| Environment recording wrapper | 0 | Preserves the child failure; not successful engine access |
| `python3 -B proposals/untrusted-swarm-20261104/benchmark.py validate --run preflight-0001` | 0 | Original freeze/results and44 protected paths unchanged |
| `python3 -B results/untrusted-swarm-readiness-20261104/verify_packet.py` | 0 |187 packet members and1165 pinned inputs unchanged |

[Exact failure, resource scopes and next action](results/swarm-substrate-20261105/REPORT.md).
Three CPU-hours is the proposed3-cell aggregate allowance.16GiB is per-cell
peak, not per-agent and not an enforced experiment-wide cap. Model prices,
authoritative token accounting and a dollar-budget gateway remain unbound.
Next: an authorized local execution context with engine access, followed by
real worker/checker isolation and aggregate-budget controls. No socket permission,
sandbox protection, service, model request or benchmark protocol changed.

## Markdown execution tracking — documentation only

The [current execution checklist](FORGE_MISSION_STATUS.md#current-execution-checklist)
records the next proof obligation, completion evidence and approval limits.
Baseline: local commit `9765329277117a111a88860be26c9cf76a6f00e3`.

| Executed check | Actual exit | Result |
| --- | --- | --- |
| Local mission and U300 manifest readback | 0 | 386 packet members match in workspace and Git worktree |
| Markdown history, link and whitespace check | 0 | Two documentation files changed; uncertainty logs unchanged |
| Initial / corrected precommit guard | 1/0 | Removed an invalid equality check between distinct preserved histories; no evidence changed |
| New proof, native/hosted run, independent replay or restore | NOT RUN | Documentation update only |

Record: `results/mission-tracking-checklist/attempt-0001/baseline.json`.
The U300 proof results below remain historical executions. No stronger claim is
made. CURRENT none; M1 open; Stage12 unauthorized; `end_to_end=false`.

## Refund configuration and word installation trace checked — U300

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual child exit | Result |
| --- | --- | --- |
| Configuration proof/repeat | 0/0 | Exact closure property survives every allocation oracle |
| Space proof first/corrected/repeat | 1/0/0 | Three conditional installation-space lemmas |
| Trace bundle first five attempts | 1/1/1/1/1 | Main theorem saves on fifth; separate corollary first fails there |
| Corollary follow-ups/repeat | 1/1/0;0 | Corollary passes on its fourth attempt; complete exports reproduce |
| Initial main import and initial controls | 1 each | Missing wordPropsTheory preload; infrastructure failures |
| Corrected main import / trace import | 0/0 | Nine exact statements, including the historical parent |
| Wrong program / omitted space / changed bound / omitted non-error / omitted trace space | 1/1/1/1/1 | Intended claim-binding refusals |
| readback.py | 0 | 386 closure nodes, 1917 files; three new theories each reproduce four exports |
| Full staged / authored whitespace | 2/0 | Exact upstream, generated and log bytes retained |
| Target event preservation, native/hosted run, independent replay/admission/restore | NOT RUN | Complete assurance chain remains open |

[Exact statements, commands, accounting and remaining gap](proposals/refund-executable-feasibility/config-install-20261105/REPORT.md).
The new word theorem proves one ptr_eq_trace epoch under a recorded stack bound
and a non-error result. The entry corollary keeps these conditions at every clock.
One epoch excludes successful modeled Install events in this published trace;
it does not establish target InstallApp exclusion or physical no-install behavior.
The non-error premise matters because MustTerminate can restore the original
state when its inner run times out and returns Error. All failed claims remain.
The early bundle-level stop count was corrected against the actual per-failing-proof
rule: main trace theorem passes on attempt5; its separate corollary on attempt4.
Successful-prefix bytes remain identical. No proof exceeded its limit. U290/U297
remain stopped. Same-host imports are not independent full-chain source replay.
Next: specialize the word premises to the exact compiled refund state and connect
existing word epochs to lower-pass and target installation events. Preserve every
resource, error, runtime, provenance and review condition. Twelve pinned sources,
50 protected paths and 540 prior packet members match. No protected or remote action.
M1/integration EXIT NOT_ESTABLISHED. Exact other-device hashes/restore remain open.


## Exact refund closure installation check — U299

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| run_hol.py closure-0001 / closure-0002 / closure-repeat | 1/0/0 | Setup corrected; no Install in exact closure syntax; four identical exports |
| run_import.py exact-import | 0 | Exact statement and existing assumption closure |
| run_hol.py injected-install | 1 | Predicate true; absence claim rejected by EQF_ELIM |
| run_import.py wrong-program | 1 | Exact source-statement mismatch |
| readback.py initial/corrected | 1/0 | Log-name matcher corrected; 379 closure nodes, 1888 files |
| Full staged / authored whitespace | 2/0 | Original upstream/generated/log bytes preserved |
| Exact target exclusion, native/hosted run, independent replay/admission/restore | NOT RUN | Remaining assurance chain stays open |

[Full claim, commands, hashes and next action](proposals/refund-executable-feasibility/closure-install-20261105/REPORT.md).
The theorem checks the exact refund program after backend.to_clos with the default
ARM8 configuration. It does not prove target installer exclusion or physical
applicability. The new negative control adds Install while retaining the program;
wrong-program import separately checks claim identity. Initial setup/readback
failures are preserved and do not count as adversarial rejections.
Next: bind the result to the actual compiler configuration and carry installer-event
exclusion through existing simulations to U298's target-prefix condition.
Keep every live-value, resource and runtime premise. Same-host cached imports
are not independent full-chain replay. Four Boolean foundations remain; 14 pinned
sources, 50 protected paths and 456 prior packet members match their identities.
U290/U297 stopped routes stay closed. Independent review, new provenance/admission,
full physical correspondence and exact other-device archive hashes/restore remain
open. No remote or protected action. M1/integration EXIT NOT_ESTABLISHED.


## Conditional target installer bridge checked — U298

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual child exit | Result |
| --- | --- | --- |
| Target bridge attempts1–5; repeat | 1/-2/1/1/0;0 | Two conditional target theorems; four identical exports |
| Model counterexample attempts1–4; repeat | 1/-2/1/0;0 | Handler replacement can change success to error |
| Complete-prefix corollary attempts1–4; repeat | 1/1/1/0;0 | Formal halt plus earlier exclusion suffices |
| Exact imports, three/four statements | 0/0 | Claims and existing assumption closure checked |
| Wrong success / missing exclusion / finite-only exclusion / missing halt | 1/1/1/1 | Intended false-goal or exact-claim refusal |
| readback.py | 0 |131 closure nodes,644 files,10 pinned sources,50 protected paths |
| Full staged / authored whitespace | 2/0 |Exact raw and generated bytes retained |
| Exact refund exclusion, physical/hosted execution, independent replay/admission/restore | NOT RUN | Application and assurance chain remain open |

[Exact proofs, commands, failures and next obligation](proposals/refund-executable-feasibility/target-install-bridge-20261105/REPORT.md).
Child -2 is SIGINT, wrapper254. Interrupted rewrites are not theorem rejections.
The new bridge preserves the full machine_sem set when all formal TimeOut prefixes
avoid install_pc. A checked halt permits a finite complete-prefix condition.
Only install_interfer may change; all other configuration fields and initial
states remain identical. No exact refund exclusion or physical relation is proved.
The generic model counterexample is not the refund executable or a new semantics.
Same-host imports are not independent full-chain replay. U296's runtime/resource
premises remain. Next: connect the exact refund program through the existing
backend simulation to this exclusion condition. Retain all approved inputs.
U290/U297 stopped routes remain closed. No policy, protected adoption, native
permissions, acceptance claim, publication, push, merge, signing or dispatch changed.
M1/integration EXIT NOT_ESTABLISHED; independent review/admission and exact
other-device archive hashes/restore remain open.


## Installation premise and data-oracle independence — U297

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Static disassembly / exact byte readback | 0/0 | Installer branch present; reachability unknown |
| Installation proof attempts1–5 | 1/1/1/1/1 | STOPPED; no complete export or sixth attempt |
| Data-oracle proof initial/corrected/repeat | 1/0/0 | Three conditional theorems; four identical exports |
| Fresh exact import | 0 | All three statements match |
| Missing resource premise / substituted program | 1/1 | Intended exact-statement refusal |
| readback.py | 0 |482 closure nodes,2403 files,19 pinned sources,50 protected paths |
| Full / initial narrow / authored whitespace check | 2/2/0 |Raw tool output and generated bytes retained |
| Machine-level bridge, new native/hosted run, independent replay/admission/restore | NOT RUN | No stronger runtime or authority claim |

[Tracked proof, commands, failures and remaining installation gap](proposals/refund-executable-feasibility/installation-premise-20261104/REPORT.md).
The new theorem proves data-level compiler-oracle independence under the exact
space premise. It does not discharge target install_interfer_ok. The compiler's
no_install_or_no_share_mem disjunction does not prove installation absence;
standard stubs and exact emitted bytes include an installer jump. Presence is
not reachability. Same-host import is not independent full-chain replay.
Next: inspect the existing simulation relations for a narrow reachable-state
bridge. Keep resource adequacy and physical installation unsupported until checked.
Do not retry this stopped bundle or U290's five-attempt entry path. No runtime
permission, theorem premise, policy, protected path or accepted claim was changed.
Full physical correspondence, source interpretation/review, new provenance and
admission, exact other-device hashes/restore and operational controls remain open.
M1/integration EXIT NOT_ESTABLISHED. No publication, push, merge or dispatch.


## Runtime applicability and precise conditional behavior — 2026-11-04 (U296)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Existing stronger backend specialization diagnostic | 0 | Exact premises inspected |
| Precise behavior proof attempts1/2/3; repeat | 1/1/0;0 | Three theorems; four byte-identical exports |
| Fresh exact import | 0 | Three exact statements; no new hypotheses/axioms |
| Missing space premise / changed heap limit | 1/1 | Expected exact-statement refusals |
| runtime_readback.py | 0 |16 pinned sources,12 capture members,43 prior packet members |
| readback.py | 0 |482-node closure,2403 dependency files,50 protected paths,515 prior packet members |
| Full staged whitespace / authored-file whitespace | 2/0 |Exact generated and upstream bytes retained; diagnostics preserved |
| New native/hosted execution, independent replay/admission/restore | NOT RUN | No physical-runtime or authority completion |

[Exact theorem, complete premise matrix, commands, hashes and failures](proposals/refund-executable-feasibility/runtime-premises-20261104/REPORT.md).
The new theorem yields complete modeled success only under its explicit full
is_safe_for_space and runtime premises. Resource sufficiency remains unproved.
The existing resource-extended theorem permits an empty resource-limit prefix;
this is now checked explicitly. Same-host imports are not independent replay.
The observed code buffer is r-x and the runtime build has no -DEVAL flag;
universal install_interfer_ok remains unjustified. Next: inspect existing
no-install/reachability proofs for this exact program and their simulation use.
Do not alter runtime permissions or remove a premise. U290 stays stopped at five
attempts. Full physical state/FFI/OS, frontend review, new provenance/admission
and exact independent-device restore remain open. Integration EXIT
NOT_ESTABLISHED. No protected adoption, publication, push, merge or dispatch.


## Unicode/model byte boundary checked — 2026-11-04 (U295)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Source boundary attempt1 / corrected / repeat | 4/0/0 | Projection fact and resource failure retained;1458 batches pass |
| Same extraction frontend verifies the complete source boundary | 0 | Same1458 source outcomes; exact proposed driver |
| Dafny audit | 0 | Zero findings; separate from proof verification |
| HOL boundary attempts1/2/3; repeat | 1/1/0;0 | Seven theorems; four byte-identical exports |
| Fresh exact import initial/corrected | 1/0 | Universal-quantifier comparison corrected; nine exact statements |
| Source lossy projection / caller-ID swap | 4/4 | Intended assertion/postcondition failures |
| HOL lossy projection / caller-ID swap | 1/1 | Intended inverse/result theorem refusal |
| readback.py | 0 |231-node closure,1146 files,30 unchanged source inputs,50 protected paths |
| New native/hosted run, independent full-chain replay/admission | NOT RUN | No physical-runtime or authority result |

[Exact shared interface, commands, failures, hashes and trust limits](proposals/refund-executable-feasibility/byte-boundary-20261104/REPORT.md).
The source proof has no input precondition. Existing UTF-8 evidence discharges
the model byte bounds without restricting the approved Unicode/integer domain.
All nine inputs and six outputs remain bound to the existing refund_fields and
wire format. The shared mathematical interface is checked in both systems;
it is not a verified inter-kernel translation or proof of the C# serializer.
Same-host import is not independent full-chain replay. Next: audit exact runtime
applicability and prepare its bounded assumption profile from existing entry/FFI
observations. U290 stays stopped at five attempts. Resource-limit prefixes,
physical exit, independent review, new admission and exact other-device restore
remain open. Integration EXIT NOT_ESTABLISHED. No protected or remote change.

## Exact exported method bound to existing model — 2026-11-04 (U294)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Frontend build attempts 1/2/3 | 0/0/0 | One-file compatibility proposal builds |
| Exact-source export attempts 1/2/3; repeat | 1/1/0; 0 | String/frame limits retained; final exact export reproduces |
| Published/named examples; six unsupported-form controls | 0/0; 1 each | Prior example bytes unchanged; controls refuse export |
| Source HOL attempts 1/2/3/4; repeat/import | 1/1/1/0; 0/0 | Five theorems; four identical exports; exact statements checked |
| Model relation proof/repeat/import | 0/0/0 | Return status, heap and all six outputs agree |
| Compiled-function binding proof/repeat/import | 0/0/0 | Exact refund_fields function bound to parsed method |
| Wrong amount/field swap/input swap/missing contract/trailing bytes | 1/1/1/1/1 | Intended theorem/binding refusal; no complete export |
| readback.py | 0 |195 closure nodes,964 files,50 protected paths; prior packets intact |
| New native/hosted execution, independent full-chain replay/admission | NOT RUN | No stronger runtime or authority claim |

[Exact commands, proofs, patch, hashes, failures and approval packet](proposals/refund-executable-feasibility/source-model-binding-20261104/REPORT.md).
The new checks bind the actual exported AST to the existing model and compiled
function. They do not verify the C# frontend or establish physical execution.
All three source contracts and all input/output fields remain present. Typed
byte-string/integer model behavior is proved under the explicit initializer;
full source Unicode/frontend composition remains a separate gap. Only the four
existing HOL Boolean foundation axioms occur. Same-host imports are not clean
independent full-chain replay. The original source/native and protected paths
remain unchanged. U290 stays stopped after five attempts; compiler jobs stay
terminal. Next: bind U262's UTF-8 transport to the byte-string model using existing
library theorems; obtain independent review before protected frontend adoption.
Runtime/resources/exit, authenticated new admission and exact other-device restore
remain open. Integration EXIT NOT_ESTABLISHED. No new stage or publication.

## Exact source export experiment — 2026-11-04 (U293)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run.py source` / `sdk` / `build` | 0/0/0 | Exact upstream source; isolated pinned SDK; unchanged frontend build |
| `run.py export` / `export-with-solver` | 4/4 | Z3 lookup failure; neither is a proof rejection |
| `run.py export-with-path` / `source-repeat` | 1/1 | Exact source rejected at module-count guard; no AST |
| `run.py example` / `module-control` | 0/1 | Published example works; named-module wrapper isolates limitation |
| `run.py module-free-diagnostic` | 1 | Complete method/contracts retained; unsupported Iff |
| `readback.py` / `readback_0002.py` | 1/0 | Incorrect hash comparison preserved; corrected identity-only audit |
| Prior frontend snapshot comparison / diagnosis | 1/0 | One extra final LF in historical API snapshot; Git source exact |
| Refund HOL parser/equivalence/native/hosted checks | NOT RUN | No exported refund AST |

Commands are rooted at `results/refund-source-binding-2026-11-04/attempt-0001/`.
[Exact commands, failures, hashes and bounded result](proposals/refund-executable-feasibility/source-export-feasibility-20261104/REPORT.md).
The direct export route is UNSUPPORTED. Prepare a local compatibility proposal
for the existing frontend, retaining all source contracts and input/output fields.
No new parser or accepted tool replacement. The subsequent HOL semantic relation
remains required. All prior proofs and failures stay preserved. Integration EXIT
NOT_ESTABLISHED; exact other-device restore and assurance-chain review stay open.

## Source-binding tracking checkpoint — 2026-11-04 (U292)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The current next action and completion conditions are recorded in
[FORGE_MISSION_STATUS.md](FORGE_MISSION_STATUS.md#resume-here--source-to-model-binding-u292).

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Inline Python identity/readback check | 0 | 140 packet files match; source/mission identities and prior local bundle hash checked |
| Initial Git status in workspace root | 128 | Root has no Git metadata; documentation worktree is clean at 2a5706d |
| Documentation worktree status and HEAD readback | 0 | Exact local commit identified; no remote-state claim |
| New source/frontend/model experiment | NOT RUN | Next task; source-to-AST relation remains unestablished |
| Proof, native, hosted or independent-device restore rerun | NOT RUN | Prior results remain prior executions |

[Readback evidence](proposals/refund-executable-feasibility/source-binding-checkpoint-20261104/identity-readback.json).
The source proof calls AssessFlat; the HOL compiler proof starts from a constructed
Refund AST. Source-to-model equivalence remains open. Inspect the pinned published
frontend and use the existing CakeML parser next; a successful parse alone will
not prove the relation. Completed compiler jobs stay terminal. U290 stays stopped
at five attempts. Local recovery does not confirm the owner-reported other-device
copy. Full runtime applicability, independent review and new admission remain
open. This documentation checkpoint completes no proof or integration EXIT.

## Conditional compiler behavior established — 2026-11-04 (U291)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run_behavior.py 0001 repeat` / `0002 repeat` | 0/0 | Original job finished; six exports reproduce exactly |
| Behavior import / corrected isolated-layout import | 1/0 | Initial loader failure retained; exact full conditional claim checked |
| Substituted code / changed result bindings | 1/1 | Exact-statement mismatch; no native counterexample claim |
| Behavior readback.py | 0 |481-node closure,2400 files, exact artifacts and50 protected paths |
| Resource positive initial/corrected/repeat/import | 1/0/0/0 | Initial rendering error retained; three exact statements and four equal exports |
| Wrong resource limit / stale midpoint | 1/1 | Intended false equations; residual F |
| Resource readback.py | 0 |338-node closure,1683 files, exact captured pointer inputs |

[Actual theorem, commands, hashes, assumptions and approval packet](proposals/refund-executable-feasibility/compiled-behavior-20261104/REPORT.md).
The compiled model behavior permits resource-limit I/O prefixes. Full input-domain
Unicode/source/model binding, applicable installed state, physical runtime and
resource sufficiency, native exit, independent replay/review and new admission
remain open. Exact other-device restore remains unverified. Compiler jobs are
terminal; do not restart them. U290's entry-layout proof stays stopped at five
attempts. No new stage or protected adoption. Integration EXIT NOT_ESTABLISHED.


## Tracking and entry-layout checkpoint — 2026-11-04 (U290)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Entry-layout positive attempts1–5 | 1/1/1/1/1 | Final attempt stops on unresolved lemma application; no complete export |
| Exact compiled-FFI definition diagnostic | 0 | Encoded definition inspected; no layout proof |
| checkpoint.py | 0 |12 capture members,50 protected paths and exact mission/native/recovery identities |
| Local bundle create/verify/clone/rev-parse/fsck | 0/0/0/0/0 |12865 tracked files match restored commit f39849d |
| Entry negative controls / reproduction / import | NOT RUN | No accepted positive layout export |
| Original compiler behavior proof | IN_PROGRESS | Original runner47209/Holmake47239; no duplicate or terminal result |

[Exact commands, failures, candidate-domain assumptions and next actions](proposals/refund-executable-feasibility/entry-layout-checkpoint-20261104/REPORT.md).
The entry proof path stops at the five-attempt limit. The compiler remains the
next active check. U289's finite FFI proof is retained. Full source/runtime,
resource/exit, independent replay/review and new admission remain open. The
owner-reported other-device backup lacks verified exact hashes and restore.
This update preserves append-only history and adds no stage or publication.
Integration EXIT remains NOT_ESTABLISHED.


## Active mission update — 2026-11-04 (U289)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Four exact captured FFI equations are now checked in the existing HOL model.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Original model positive-0002 | 1 | Three reads proved; write leaves THE(LDROP1(4096:::ns))=ns |
| Model positive-0004 / identical-source repeat | 0/0 | Existing LDROP_1 lemma closes unchanged equation; four equal exports |
| Altered-read / wrong-write-descriptor controls before and after fix | 1/1;1/1 | Exact intended false equations, residual F; no complete export |
| Fresh standard-heap model import | 0 | Four exact statements, zero explicit hypotheses/tagged axioms; DISK_THM only |
| Initial file audit / corrected readback_model_complete_0002.py | 1/0 | Built-in min root recorded explicitly;215 nodes,1068 files and24 buffer comparisons |
| Protected-input and process readback | 0 |50 protected paths and mission unchanged; original compiler job live |
| Compiler behavior proof | IN_PROGRESS | No terminal conclusion; no duplicate invocation |

[Commands, hashes, assumptions and exact negative cases](proposals/refund-executable-feasibility/ffi-model-conformance-20261104/REPORT.md).
The previous goal turn made tracking progress. This turn proves finite model
conformance and checks rejection/reproduction/import. Full actual filesystem,
physical state, memory frames, source/runtime/resource/exit correspondence,
independent complete-chain review, new provenance/admission and exact backup
restore remain open. No native rebuild, signing, publication, merge, dispatch
or Stage12 occurred. Integration EXIT remains NOT_ESTABLISHED.

## Local launch-readiness audit — 2026-11-04 (U288)

**NO-GO.** Audit complete; no pilot authorized. CURRENT none; M1 separate/open;
Stage12 unauthorized; end_to_end=false. Fresh execution supersedes assumptions
about the old sandbox failure: it remains present.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `audit.py prepare` / `audit.py preflight` / `audit.py hol` | 0/0/0 | Recorders ran; child failures below retained |
| Frozen input readback / task reproduction | 0/0 | Original freeze intact;34 generated files identical |
| Fresh sandbox launcher | 71 | sandbox_apply EPERM; probe body NOT RUN |
| Ambient role write/process/artifact controls | 0; peer-15 | Cross-role operations allowed; security boundary FAIL |
| CPU work / exhaustion / process-tree control | 0/-24/0 | Measured local work; SIGXCPU; aggregate limit not enforced by per-process caps |
| Actual budgeted launch-interface request | 2 | CLI has no run command; not budget-exhaustion success |
| Fresh HOL proof / repeat | 0/0 | Four identical exports for exact original-method relation |
| Altered proof / altered result | 1/1 | Required HOL theorem fails; no accepted export |
| Intact / corrupt / stale / unsupported-scope / extra-path helper | 0/1/1/1/1 | Existing identity/policy helper; no complete admission claim |
| Fresh proof artifact original / mutant SHA | 0/1 | Exact artifact identity control; mutant never loaded |
| Invalid packet controls / audit readback / report builder | 0/0/0 | Preserved failures,1165 input identities and explicit readiness matrix |

Exact commands, logs, telemetry, identities and scope:
[readiness report](results/untrusted-swarm-readiness-20261104/REPORT.md).
The experiment lacks enforced role/checker domains, a metered model broker and
complete independent admission. Token/cost exhaustion, same-candidate nonce
freshness and actual arm budget comparability remain NOT RUN. No paid model
request or experimental arm ran. Smallest external blocker is sandbox_apply
EPERM; the report gives the next command after an authorized context change.
The proposed3-cell planning ceiling is720000 tokens,240 calls,3 CPU-hours,
16GiB peak and12GiB new outputs; cost and sufficiency remain unestablished.
No protected changes, signing, publication, merge, deployment or Stage12 ran.
U285/U287 and all prior journal entries remain unchanged.

## Tracking checkpoint — 2026-11-04 (U287)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner requested a durable Markdown tracker. Current actions and completion
conditions are in [FORGE_MISSION_STATUS.md](FORGE_MISSION_STATUS.md).

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -B results/refund-ffi-observation-2026-11-04/checkpoint-U287.py` | 0 | Saved records, source/native identity and live process checkpoint |
| Constructor diagnostics (prior executions; read back here) | 1/1/0 | API error; environment-key error; complete term construction only |
| Complete original-equation reconstruction (prior execution) | 0 | Input identity; no semantic proof claim |
| Proposed replacement guard | 1 | First proof marker present; no signal or replacement executed |
| Original model check / original compiler proof | IN_PROGRESS / IN_PROGRESS | Model saved first two equations; neither has a terminal result |
| Model controls / reproduction / fresh import | NOT RUN | Wait for complete positive export |

[Exact records and smallest next actions](proposals/refund-executable-feasibility/ffi-model-checkpoint-20261104/REPORT.md).
Both original jobs continue without duplication. Two saved equations do not
establish the four-equation check or full runtime correspondence. Complete-chain
review, source/runtime premises, new admission and independent backup restore
remain open. Historical evidence is unchanged. Integration EXIT NOT_ESTABLISHED.
No new stage, protected adoption, publication, signing, merge or dispatch ran.

## Active mission update — 2026-11-04 (U285)

Two native captures now record full FFI buffers and call returns for the same
exact refund executable. CURRENT none; M1 open; Stage12 unauthorized;
end_to_end=false. Finite observations do not prove universal runtime behavior.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| FFI discovery / complete capture / identical-source repeat | 0/0/0 | Three reads, one write, cml_exit(0); actual process exits0 |
| validate_observations.py | 0 |38 byte comparisons0; exact return PCs, x19–x28 and SP preserved per call |
| First HOL model check | 1 | Record annotation parse error; no accepted theorem |
| Focused parser diagnostic | 0 | Reproduces error; exact spacing correction parses |
| Corrected HOL model check | IN_PROGRESS | Original child91810 live; no terminal result |
| Model tampering controls / proof reproduction | NOT RUN | Positive model result required first |
| Six pinned source identity/diff checks | 0 | Existing semantics and runtime sources unchanged |
| U284 committed packet import | 0 |115 file hashes checked; no source-proof rerun |
| Original compiler behavior proof | IN_PROGRESS | Runner47209/Holmake47239 remain live |

[Exact observations, commands, pending model checks and limits](proposals/refund-executable-feasibility/ffi-observation-20261104/REPORT.md).
The loaded code matches before native exit as well as at entry. Full buffers
agree between captures; ASLR addresses differ. Return breakpoints are hardware.
Full memory frames, physical state, universal FFI/OS/interference/resources/exit,
source/model binding, clean independent replay/review and new admission stay open.
Poll the existing checks; do not duplicate them. Keep U284 source work separate.
Independent-copy hashes and restore remain unverified. Integration EXIT remains
NOT_ESTABLISHED. No protected change, publication, signing, merge or dispatch ran.

## Active mission update — 2026-11-04 (U284)

The refund exception contract now has a checked all-oracle source-behavior
theorem with the full modeled event trace and exceptional heap postcondition.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Deterministic exception/FFI lift | 0 | Exact final events and modeled FFI relation |
| Source semantics builds | 1/1/0 | State-theorem namespace; rule application; then complete export |
| Clock diagnostics / stdio diagnostic | 1/0;0 | Interface error preserved; exact residuals inspected |
| Positive source replay | 0 | Four byte-identical exports |
| Wrong empty-trace substitution | 1 | Required theorem refused; no accepted export |
| Fresh theory import / readback.py | 0/0 | Seven theorems;245-node closure;1458 parent files and50 protected paths checked |
| Local unsigned packet commit / Git blob readback | 0/0 | acadb09945cda234d79fe1911df0f7d86541d620;115 exact files; no publication |

[Theorem, premises, failures, identities and assurance matrix](proposals/refund-executable-feasibility/exception-semantics-20261104/REPORT.md).
The theorem retains declaration, lookup, input/error and initial heap premises.
Logical Success is not OS exit0. Four existing foundation axioms are visible;
logic/kernel/loader/host and imported proof-data trust remain. Same-host proof
and import do not establish clean independent complete-chain replay.
Next: basis event extraction and exact refund_prog initialization composition.
The precise planned lemma is NOT RUN. Physical native I/O/resources/exit remain
open. No native rebuild, signing, protected change, deployment or Stage12 ran.

## Active mission update — 2026-11-04 (U282)

The unchanged exception declaration theorem is now PROVED, replayed and imported.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Direct exact theorem checks | 1/1/0 | Namespace failure; residual branch; then both branches proved |
| Residual simplification diagnostic | 0 | fs reorients equation; direct substitution resolves it |
| Fresh standard-heap export / repeat | 1/0/0 | Qualified constants after first failure; four identical exports |
| Wrong normal-result control | 1 | Required declaration proof fails; no accepted export |
| Exported-theory import | 1/0 | Virtual-path correction; exact statement and244-node closure checked |
| readback.py | 0 |1454 prior files, two failed heaps,50 protected paths and native identity unchanged |

[Exact theorem, failures, hashes and assurance matrix](proposals/refund-executable-feasibility/exception-declaration-20261104/REPORT.md).
The existing direct HOL interface works with unchanged tools and permissions.
The earlier Holmake EPERM remains preserved and unexplained. The theorem adds no
new premise or axiom. Fresh replay still trusts this host and cached parents.
Next: exceptional evaluation to deterministic source semantics and FFI relation,
then all pointer oracles and initialized stdio. Logical Success does not establish
OS exit0. Physical native correspondence and clean independent replay stay open.
No native rebuild, signing, protected change, deployment or Stage12 occurred.

## Active mission update — 2026-11-04 (U283)

Exact loaded refund code and bitmaps now match the HOL-derived payloads in
three accepted local captures. CURRENT none; M1 open; Stage12 unauthorized;
end_to_end=false. These observations do not establish a universal native theorem.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Installed debugger file-only / dependency diagnostics | 0 / child -10 | File parses; dependency-symbol loading crashes; failures retained |
| Official observer archive/bundle download | 0/0 | Exact release hashes; isolated local tool directory |
| Upstream gh attestation verification / wrong-source control | 0/1 | Exact tag, source and signer; intended identity refusal |
| Initial decompressor/listing / corrected listing and extraction | 1/0;0/0;0/0 | Explicit1GiB decoder window; first failure retained |
| New debugger target-open diagnostic | 0 | Exact native file and dependencies load |
| Attempt0004 debugger / bitmap comparison | 0/1 | Native exits0; wrong temporary-pointer capture refused |
| Corrected capture / identical-source repeat / full-map supplement | 0/0/0 | Each native process exits0 with exact fixture stdout |
| validate_captures.py / full-map readback | 0/0 | Nine positive byte comparisons0; code/bitmap identities and scalar observations |
| Corrupted captured-code comparison | 1 | Intended difference; mutant never executed |
| Frozen-input and compiler-process readback | 0 |30 inputs unchanged; original proof remains live, no terminal result |

[Exact commands, provenance, observations and remaining premises](proposals/refund-executable-feasibility/entry-capture-20261104/REPORT.md).
The accepted captures use resolved hardware breakpoints. Loaded code130436 bytes
and bitmaps2531 words match. Full-map observation covers512MiB heap/stack in four
rw- regions and rechecks all34 named registers unchanged before resume. Different
ASLR addresses do not change payload bytes. No executable rebuild/signing occurs.
Upstream observer provenance does not authenticate local Forge evidence.

Next: finish original run_behavior.py0001repeat; inspect its actual theorem, then
require binding controls/reproduction. Keep source/model, physical control state,
universal runtime/FFI/resources/exit, independent replay/review, new admission and
off-machine restore open. Separate tasks retain their own records and authority.
No Stage12, protected change, publication, merge, dispatch or deployment ran.
Integration EXIT remains NOT_ESTABLISHED.

## Local research blocking audit — 2026-11-04 (U281)

Swarm goal status: **blocked**, confirmed by the goal service after three
consecutive turns with the same isolation/metering blocker. CURRENT none;
M1 open; Stage12 unauthorized; end_to_end=false. This does not complete the goal.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `python3 -B proposals/untrusted-swarm-20261104/benchmark.py validate --run preflight-0001` | 0 | Fresh saved-evidence readback only;20 result files and44 protected paths |

[Blocking audit](results/untrusted-swarm-20261104/blocked-audit-0003.json).
Previous continuation and this continuation are no progress. No sandbox retry,
new proof/compiler check or experimental trial ran. Need authorized enforced
local worker/checker isolation and authoritative compute metering before the
remaining execution implementation and full comparison can proceed. U280's
frozen protocol, actual failure and incomplete-work report remain unchanged.

## Local research update — 2026-11-04 (U280)

Continuation audit2: previous turn made progress; this turn found no new execution
capability. Fresh `python3 -B proposals/untrusted-swarm-20261104/benchmark.py
validate --run preflight-0001` returns0 for saved evidence only. The same isolation
and metering blocker remains. No sandbox retry or trial ran. Goal remains active.
[Audit record](results/untrusted-swarm-20261104/blocked-audit-0002.json).


**Twenty Untrusted Agents, One Trusted Specification:** prerequisite protocol
frozen; full experiment remains incomplete. CURRENT none; M1 open; Stage12
unauthorized; end_to_end=false. Twenty setup reviewers are not trial subjects.

Let `P=proposals/untrusted-swarm-20261104`. These are research command results,
not repository-stage EXIT completion. No stage transition occurred.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `python3 -B $P/prepare.py` / two setup reproductions | 0/0/0 | Two tasks;20 role slots;18 planned cells |
| Packet syntax, path and roster checks | 0 | Preparation only |
| `python3 -B $P/benchmark.py freeze` | 0 |100 frozen file identities plus four execution-tool entries |
| `python3 -B $P/benchmark.py preflight --run preflight-0001` | 2 | Required isolation/metering/checker prerequisites unavailable |
| System shasum original / substituted native copy | 0/1 | File identity control only; neither copy executed |
| Benign `sandbox-exec` canary launcher | 71 | sandbox_apply: Operation not permitted; probe body NOT RUN |
| `python3 -B $P/benchmark.py report --run preflight-0001` | 0 | Three arms NOT_RUN; metrics null |
| `python3 -B $P/readback_controls.py --run preflight-0001 --output results/untrusted-swarm-20261104/readback-controls-0001.json` | 0 | Six local packet-integrity/launch-record controls |
| `python3 -B $P/benchmark.py validate --run preflight-0001` | 0 |20 result files, reports and44 protected paths checked |

[Comparison, exact results and remaining implementation](results/untrusted-swarm-20261104/REPORT.md).
[Frozen protocol](proposals/untrusted-swarm-20261104/PROTOCOL.md).
Freeze24611850b642a61d144a36eade0837146d23b36ded2a451ef378aad88c4da94b.
Zero trials is not zero false acceptance. No fresh kernel/compiler trial ran.
Need enforced role domains, authoritative compute broker, independent refund
admission renderer/checker and hidden-corpus execution binding before trials.
No escalation or alternate route followed the sandbox refusal. No protected
modification, signing, publication, merge, deployment or Stage12 occurred.
U278/U279 and the separate proof work remain preserved. Full native M1 remains open.

## Active mission update — 2026-11-04 (U279)

The Markdown tracker now gives the ordered next actions and their completion
evidence. CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The native entry observation remains NOT_ESTABLISHED after three debugger
crashes. The existing compiler behavior invocation remains live.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Entry observation run.py attempts0001/0002/0003 | child -10/-10/-10; launcher246 each | SIGBUS inside LLDB; no accepted entry or target-exit record |
| Target-open diagnostic | 0 | Exact file opens with eager symbols disabled; no native execution |
| Initial readback.py / corrected readback_0002.py | 1/0 | First log has no symbols; existing OS diagnostic supplies them; all failures retained |
| Exact-target process query | 0 | No matching target remains; native exit status NOT_RECORDED |
| Existing compiler runner/Holmake query | 0 | Both live; no terminal proof exit; no duplicate invocation |

[Exact observer failures and identities](proposals/refund-executable-feasibility/entry-observation-20261104/REPORT.md).
The correction changes only saved-record inspection. It executes no proof or
native program. Executableb8ed5ec2, mission and30 frozen inputs are unchanged.
Raw OS diagnostics stay private; their hashes and diagnostic summary remain.
No universal loaded-state, FFI, resource or exit guarantee follows from these
checks. Complete the live proof, then inspect its actual conclusion and controls.
Isolate the debugger failure before another launch. U278's denied exception
builder remains on its separate branch; no reroute occurred. Independent replay,
review, new provenance/admission and exact off-machine restore remain open.
No rebuild, signing, protected adoption, publication, merge or dispatch ran here.
Integration EXIT remains NOT_ESTABLISHED. All prior evidence is retained.

## Active mission update — 2026-11-04 (U278)

The exception diagnosis identifies a remaining do_opapp case whose result is
already in the hypotheses with the reverse equality orientation. A standalone
HOL lemma proves the needed rewrite. The full repaired theorem remains unproved:
Holmake exits1 with EPERM before checking it. CURRENT none; M1 open;
Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Focused branch diagnostic | 0 | Existing rewrites leave the exact lookup case unresolved |
| Standalone lookup_result lemma | 0 | Universal HOL lemma; DISK_THM; no explicit hypotheses or tagged axioms |
| `run_focused.py 0001` | 1 | Operation not permitted after builder-link message; no theorem export |
| Saved-record/protected-input readback | 0 | Statement, two old heaps, native executable and50 protected files unchanged |
| Local unsigned packet commit / blob readback | 0/0 | d0445513afae513bfd1fbbe830adde4f65419331;33 exact files; no publication |

[Exact residual goal, checked lemma, repair and error](proposals/refund-executable-feasibility/exception-focused-20261104/REPORT.md).
The full invocation is attempt6 under the owner's separately justified changed
approach permission. All five earlier failures remain. No retry or reroute
followed EPERM. Its denied syscall/path remain NOT_ESTABLISHED.
Next: resolve that operation within an authorized environment, then check the
same frozen repaired source. The existing compiler behavior run stays separate.
Whole-program error, runtime/FFI/OS/resource and independent replay gaps remain.
No native rebuild, signing, protected change, deployment or Stage12 ran.

## Active mission update — 2026-11-04 (U277)

The compiler closure audit now passes. The complete runtime premise matrix
preserves every unresolved relation. CURRENT none; M1 open; Stage12 unauthorized;
end_to_end=false. The previous goal turn made progress.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Initial closure audit | child−15; launcher241 | Interrupted expanded-term display; incomplete diagnostic |
| `run_closure_0002.py` | 0 |10 own tags, four foundation axioms, no explicit hypotheses |
| `dependency_snapshot_0002.py` / closure readback | 0/0 |378 nodes;377 theory file sets; imported DISK_THM remains explicit |
| Dependency byte readback | 0 |2265 files unchanged; not a full source replay |
| Initial source collector / `collect_sources.py` | 1/0 | Record basename collision preserved;13 pinned sources checked after correction |
| HOL / CakeML tracked source diffs | 0/0 | Unchanged |
| Native identity readback | 0 | Both file slices match HOL-derived code/data; saved mutation refusals1/1 |
| Live behavior runner / Holmake process query | 0 | Original run remains live; no terminal proof exit |

[Exact results and assumption-to-evidence matrix](proposals/refund-executable-feasibility/arm8-assurance-audit-20261104/REPORT.md).
Changing audit output did not alter proofs, assumptions or acceptance rules.
The published ARM state predicate requires EL0,E0E=false,SA0=false,TBI0=false,
TBI1=false,NoException and aligned PC. Physical system-register evidence is
absent. Successful file comparisons and finite native tests do not supply it.
The generic compiler theorem permits Resource_limit_hit with output prefixes.
The full-domain is_safe_for_space/read_limits obligations remain open.

Next: finish the existing run_behavior.py0001repeat invocation, inspect its actual
conclusion and premises, then check bindings and reproduction. U276's separate
native/exception work and all prior failures remain preserved. Loaded-state,
source/Unicode/model, FFI/OS/resource/exit relations, clean independent replay,
exact review, new provenance/admission and off-machine restore remain open.
No protected adoption, publication, merge, dispatch, release signing, new native
execution or deployment ran here. Strict integration EXIT is NOT_ESTABLISHED.
M2–M4 remain later priorities.

## Active mission update — 2026-11-04 (U276)

Two exact native builds and both28-case execution runs pass. All56 processes
exit0. Both files contain the130436 code bytes and2531 bitmap words extracted
through HOL. These checks establish finite observations and file identities.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `link_native.py` | 0 | Two local builds; same executableb8ed5ec2; signatures verified |
| `run_native.py` first / repeat | 0/0 |22 typed outputs each match; six malformed cases each exit0 with no output |
| HOL extraction first / corrected | 130/0 | Interrupted expanded-term formatting preserved; corrected named-term extraction passes |
| `compare_native_identity.py` | 0 | Exact code/bitmap slices in both files;311 system hash checks |
| Fresh copied-file signatures / one-byte mutant digest and signature | 0/0;1/1 | Intended mutation refusal; mutant never executed |
| Inspection-only exception trace | 0 | Two residual goals recorded; no theorem export or new full build |
| `check_chain_inputs.py` | 0 |2727 identities;2262 closure files;108 runtime dependencies;50 protected files unchanged |
| Full packet / authored-file whitespace checks | 2/0 | Copied upstream/log trailing blank lines preserved; authored files pass |
| Local unsigned packet commit / Git blob readback | 0/0 | bab1bbe06b40c674f543f792219ad0bd7d292626;421 exact files; no publication |

[Assurance matrix, exact hashes, premise audit and smallest next experiment](proposals/refund-executable-feasibility/native-execution-20261104/REPORT.md).
The new trace isolates the final declaration-call and heap obligations. It does
not identify the exact failing tactic inside the declaration branch. A focused
rewrite trace is prepared NOT RUN; do not repeat the full failed strategy.
Compiler behavior composition remains IN_PROGRESS in its existing task.

Load-time library identity, concrete installed memory, FFI/OS transport,
resource sufficiency, native error/exit behavior and full source-to-HOL binding
remain NOT_ESTABLISHED. Clean independent final-chain replay is NOT RUN.
No protected change, release signing, deployment, publication or Stage12 ran.
The earlier U269 local ad hoc signing approval covers these native files only.

## Active mission update — 2026-11-04 (U275)

The exact ARM64 compilation and repeat pass. Six exported theory files and
assembly reproduce byte for byte. CURRENT none; M1 open; Stage12 unauthorized;
end_to_end=false. This establishes a compiler equation, not native correctness.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Compiler `run.py 0001` / `run.py repeat` | 0/0 | Exact refund_prog compilation; code length130436 and data length2531 |
| `validate_compile.py` | 0 | Saved results, six exports, assembly, mission and30 frozen inputs checked |
| Separate native build / repeated build, inspected here | 0/0 | Same exact executableb8ed5ec2; no new root signing or native run |
| Separate native fixture runs, inspected here | 0/0 |22 typed results match; six malformed inputs exit0 with no output |
| Native stream readback | 0 |84 streams identical across runs; error contract remains unproved |

[Exact theorem, commands, hashes and boundaries](proposals/refund-executable-feasibility/arm8-compile-20261104/REPORT.md).
Compiler sourceb7e12fcf; data30076203; assembly4c750e4f. First compile
2674.4407615409873 local seconds includes dependencies; repeat137.65932195901405
seconds uses those dependencies. No speedup or hosted measurement is claimed.

The following checks actually started but have no terminal exit at this checkpoint:
`run_closure.py` and `run_behavior.py 0001 repeat`, in
results/refund-arm8-compile-2026-11-04/attempt-0001/.
They remain IN_PROGRESS. Fresh import is not a full upstream source replay.
The prepared dependency snapshot is NOT RUN. Next: finish these existing runs,
inspect the behavioral conclusion and all premises, then require binding controls
and reproduction. Do not infer preservation from successful compilation.

U274's five failed exception checks remain unchanged; no further retry on that
lemma. Canonical source behavior remains checked. Full Unicode/source/model,
installation, FFI, runtime/resource and malformed-input whole-program relations
remain open. Native observations do not discharge universal claims. Independent
review, new provenance/admission and exact off-machine restore remain open.
No publication, protected adoption, merge, dispatch, release signing, admission
or deployment ran here. M2–M4 remain later priorities. Strict integration EXIT
is NOT_ESTABLISHED. The previous live-compiler checkpoints remain historical.

## Active mission update — 2026-11-04 (U274)

The attempted exception-to-main lemma remains NOT_ESTABLISHED. Five checks
failed: three source builds and two saved-goal diagnostics. No theorem export
was accepted. Stop retries on this lemma under the existing limit. The earlier
whole-program theorem for canonical requests remains unchanged. CURRENT none;
M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Exception `run.py 0001` | 1 | Missing direct theorem imports |
| Exception `run.py 0002` | 1 | Required lemma unproved; failed heap preserved |
| Saved-goal diagnostics0001/0002 | 1/1 | Renaming fails; exact exception and heap hypotheses retained |
| Exception `run.py 0003` | 1 | Required lemma still unproved after using the observed variable |
| Saved-failure and parent readback | 0 | Five failures, two heaps, exact whole-program exports and30 frozen inputs checked |

[Exact failed commands, sources and remaining relationship](proposals/refund-executable-feasibility/exception-bridge-20261104/REPORT.md).
These are failed positive attempts, not successful security controls. New
negative controls and reproduction are NOT RUN. The last batch log does not
identify its final failing tactic. Both diagnostic heaps remain preserved.
No implementation, semantics, axiom, input domain or required result changed.

The independent compiler run remains live in session60920. Published compiler
dependencies and cake_compile_heap have passed; the actual refund compile has
started. Its terminal result is not yet established at this checkpoint. Next:
finish that exact run, inspect its theorem/artifact identities, and execute the
prepared correctness composition when its preconditions hold. Preserve the
separate rejection gap. No native behavior, authenticated admission, hosted
refund measurement or integration EXIT is established by this checkpoint.
Review, full Unicode/source/model binding, runtime/resource premises and exact
off-machine restore remain open. No publication, signing, merge or dispatch ran.

## Active mission update — 2026-11-04 (U273)

The ARM64 compiler invocation is still live. Fresh exec-session60920 polls and
process queries confirm runner94706 and Holmake94707. No terminal compile record
or successful refund artifact is available. Published dependencies continue to
build; to_data_cvTheory is active. No restart occurred. CURRENT none; M1 open;
Stage12 unauthorized; end_to_end=false.

| Executed check | Actual exit | Observation |
| --- | --- | --- |
| Live runner / Holmake process query | 0 | Both confirmed live; compiler terminal exit unavailable |
| Nine pinned compiler/proof source comparisons | 0 | Exact pinned source bytes |
| Tracked HOL / CakeML source diffs | 0/0 | Unchanged |
| Four boundary-source comparisons | 0 | Resource, installation and exception-premise limits retained |
| Prepared behavior runner syntax | 0 | Python parser only; proof composition NOT RUN |
| Local recovery create / verify / restore / fsck | 0/0/0/0 | Exact865b4239 and356 files restored locally; not independent backup |

[Exact live-build checkpoint and next proof command](proposals/refund-executable-feasibility/arm8-compiler-preparation-20261104/REPORT.md).
The source theorem remains the U271 result. Its compiler-correctness composition
is prepared but NOT RUN. First finish the existing compile, inspect actual
code/data/configuration identities, then execute that composition and reproduce
the results. Do not infer success from dependency builds.

The published compiler permits resource-limit trace prefixes. Concrete memory
installation and FFI/runtime conditions remain explicit. Normal whole-program
helpers require POSTv; refund_main_error provides POSTe. The separate exception
bridge remains open. No modeled label establishes a native process exit code.
Native execution, hosted refund measurements and new admission remain NOT RUN.
Independent claim/profile review and off-machine archive hash/restore remain
unresolved. No signing, protected adoption, publication, merge or dispatch ran.
M2–M4 stay later work. This is progress plus a verified wait, not a failed proof.

## Active mission update — 2026-11-04 (U271; includes U272 fixtures)

The proposed refund program now has a checked whole-program source theorem.
Its exact main binding and initialized library state are checked through the
published CakeML bridge. Canonical requests produce all six modeled result
fields under explicit stdin, command-line and filesystem premises. This is not
a native executable claim. CURRENT none; M1 open; Stage12 unauthorized;
end_to_end=false. The original method and wrapper remain unchanged.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `run_whole.py whole-0001` | 0 | Three own theorems; 12 published dependencies built |
| Substituted main entry | 1 | Required namespace-binding refusal; no accepted export |
| `run_whole.py whole-repeat` / `run_whole_controls.py` | 0/0 | Six identical exports; intended refusal checked |
| `run_closure.py` / `dependency_snapshot.py` / `readback_whole.py` | 0/0/0 | 243 nodes, 242 theory file sets, 42 exported tags; four foundation axioms |
| Fixture packet import readback | 0 | 300 files match local commit32e3613d; no native run |
| I/O recovery bundle create / verify / restore / fsck | 0/0/0/0 | cb68edf7 and 116 files restored locally; not off-machine evidence |

[Whole-program theorem and exact evidence](proposals/refund-executable-feasibility/whole-program-20261104/REPORT.md).
[Separate checked native fixtures](proposals/refund-executable-feasibility/native-fixtures-20261104/REPORT.md).
Whole source37d623cc; repeated data52b94fa4. The first build took
737.2824473340006 local seconds, including dependencies. This is not a hosted
benchmark. The wrong-entry proof fails on
`SOME refund_dispatch_v = SOME refund_main_v`. Prior failures remain preserved.

Next: finish the existing unsigned ARM64 compiler invocation on refund_prog_def.
Record: `results/refund-arm8-compile-2026-11-04/attempt-0001/compile-0001/`.
At this checkpoint it is IN_PROGRESS; no numeric terminal exit exists. Require
exact code/data/configuration identities, reproduction and compiler-correctness
composition. Then bind the assembled artifact and runtime to modeled premises.
Do not infer a passing refund compilation from successful dependency builds.

Unicode/source/model binding, malformed-input whole-program behavior, resource
limits, installation and physical I/O remain open. Imported DISK_THM hashes do
not authenticate a producer or replace a full upstream replay. Modeled Success
and proof-checker exits are not native process-status guarantees. Native refund
execution, hosted measurements and new admission remain NOT RUN. Independent
review and off-machine archive hash/restore remain open. U269 local signing
authority stays with its separate audit task. No signing, publication, merge,
dispatch, protected adoption or deployment ran here. M2–M4 remain later work.

## Active mission update — 2026-11-04 (U270)

Modeled stdin/stdout and error contracts now pass for the proposed refund
wrapper. Wire and I/O exports reproduce exactly. Five targeted mutations fail
at their required theorems. CURRENT none; M1 open; Stage12 unauthorized;
end_to_end=false. The original generated method and wrapper remain unchanged.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Saved-goal diagnostics0005/0006/0007/0008 | 1/1/0/0 | Witness and constructor computation localized; diagnostic results are not theory exports |
| `run_stdio.py stdio-0004` | 0 | Complete modeled output and exception contracts checked |
| Wire swapped IDs / accepted trailing error / suppressed exception | 1/1/1 | Intended theorem failures; no accepted export |
| `run_wire_controls.py` / wire repeat | 0/0 | Three refusal reasons and six identical exports |
| I/O suppressed output / substituted input | 1/1 | Intended failures at refund_main_valid |
| `run_stdio_controls.py` / I/O repeat | 0/0 | Two refusal reasons and six identical exports |
| `readback_io.py` | 0 | Five reasons, exact identities and30 frozen inputs checked |
| Fresh I/O closure / dependency snapshot / closure readback | 0/0/0 |230 nodes,229 theory file sets,39 exported tags without hypotheses; four foundation axioms |
| Existing native-audit packet import | 0 |14 exact files from3c5bb8ca; no proof/signing/native run |

[Exact claims, commands and boundaries](proposals/refund-executable-feasibility/stdio-contract-20261104/REPORT.md).
Raw: `results/refund-stdio-composition-2026-11-04/attempt-0001/`.
I/O source6f7aa17a; repeated data8971cd15. Prior failures remain preserved.
Imported DISK_THM, Unicode/model binding and physical I/O remain explicit limits.
Checker refusal1 is not a native process exit1; modeled exceptions do not prove
POSIX exit status. Independent-copy archive hash/restore and exact review remain open.

Next: complete the separately running `run_whole.py whole-0001` source-semantics
build. At this checkpoint it is IN_PROGRESS, with no final exit code. It first
builds published library dependencies. Then require entry-substitution refusal
and positive reproduction before compiling the exact program through arm8.
No native compiler result, native execution, hosted refund measurements or new
admission is established. U269's local signing approval stays with its audit
thread. No signing, publication, merge, dispatch or protected adoption ran here.

## Active mission update — 2026-11-04 (U268)

The Markdown tracker now includes the completed wire proof and the unfinished
I/O composition. CURRENT none; M1 open; Stage 12 unauthorized; end_to_end=false.
This checkpoint validates saved execution records. It does not rerun the proofs.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `run.py wire-0001` | 0 | Seven strict wire/dispatcher theorems; six exports |
| `run_stdio.py stdio-0001/0002/0003` | 1/1/1 | All fail at refund_main_valid; no accepted I/O theory |
| Saved HOL diagnostics 1/2/3/4 | 1/1/1/0 | Last diagnostic inspects goals only; not a proof pass |
| `readback.py` | 0 | Saved exits, sources, exports, 30 frozen inputs and unchanged upstream sources checked |
| `validate_checkpoint.py` | 0 | 45 packet members, 28 local links and the unchanged 538930-byte journal prefix checked |
| Effective rules / ruleset list / ruleset details | 0/0/0 | Read-only exports obtained; review controls visible |
| Classic branch-protection endpoint | 1 | HTTP 404; active ruleset remains applicable |

[Exact claims, commands and open checks](proposals/refund-executable-feasibility/wire-library-20261104/REPORT.md).
Raw records: `results/refund-wire-library-2026-11-04/attempt-0001/`.
Wire source417b69d4; theory data17482ed9; latest failed I/O source17813e63.
The new wire repeat, adversarial controls and closure audit are NOT RUN.
The successful diagnostic does not establish stdin/stdout behavior.

Next authorized check: inspect the saved third I/O goal. Identify the remaining
premise before another build. Then finish I/O, controls and reproduction before
whole-program/compiler composition. Native refund execution, hosted refund
measurements and new admission remain NOT RUN. No claim or policy was weakened.

Saved GitHub mainf9eb1cbc; PRs34/36/37 open and unmerged. Review objects were not
fetched. Effective rules require independent review controls; no required check
or workflow rule appears in that returned set. No bypass or settings change ran.
Independent-copy archive hash/restore remains unverified. No protected adoption,
publication, merge, dispatch, signing, admission or deployment ran. M2–M4 stay later.

## Active mission update — 2026-11-04 (U267)

A separate full-contract library implementation now has a checked relation to
the unchanged generated method and a CF application theorem. It uses the
existing CakeML translator. It preserves all nine model inputs and all six
result fields. The old wrapper is unchanged; the new implementation is not
adopted. CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Method inspection / `run.py construct-0003` | 0/1 | Annotation removal completed; normalization manually interrupted, child signal2 |
| `run.py library-0001` through `library-0004` | 1/1/1/1 | Missing imports, Boolean representation and wrong theory qualifier failures preserved |
| `run.py library-0005` | 0 | Full result relation and library application contract checked |
| Altered-amount / swapped-wrapper-ID controls | 1/1 | Required refusal at the intended theorems; no accepted exports |
| `run.py repeat` / `run_controls.py` | 0/0 | Six identical exports; explicit acceptance matrix passes |
| Fresh HOL closure inspection / `readback.py` | 0/0 | 192 theory nodes, seven own theorem tags, four foundation axioms;30 frozen inputs unchanged |
| Dependency snapshot attempts1/2/final | 1/1/0 | Loader-path and kernel-module classification fixed;191 theory file sets and kernel/heap hashes captured |

[Exact claims, commands, failures and identities](proposals/refund-executable-feasibility/certified-library-20261104/REPORT.md).
Raw records: `results/refund-certified-library-2026-11-04/attempt-0001/` and
`results/refund-normalised-method-2026-11-04/attempt-0002/`.
The positive theorem source is2ef6fd80; repeated theory data is5ffd9d6f.
Imported DISK_THM remains explicit. The fresh closure inspection is not a replay
of every upstream source or independent human review. No new axiom was added.

Next authorized check, NOT RUN: compose this library contract with the existing
strict wire schema and published I/O proofs. Prove the proposed wrapper's
complete accepted output and malformed/trailing-input refusal. The old raw CF
and normalization failures remain preserved. Do not assume arbitrary contextual
equivalence or silently replace the old wrapper's calling convention.
Native compilation, execution, hosted refund measurements and new admission
remain NOT RUN. Unicode/model binding, compiler/runtime premises, exact claim
review and off-machine archive hash/restore remain open. GitHub was not refreshed.
No protected adoption, publication, merge, dispatch, signing or deployment ran.
M2–M4 remain subsequent work.

## Active mission update — 2026-11-04 (U266)

The Markdown tracker now records the incomplete candidate preparation and the
next check. No new behavioral proof or native artifact is established. CURRENT
none; M1 open; Stage12 unauthorized; end_to_end=false. The full mission and all
prior evidence remain preserved.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `run.py construct` / `run.py construct-0002` | 1/1 | Manual SIGINT, child signal2 each; no accepted candidate or theory |
| Diagnostic `/usr/bin/sample 56629 1 1 -file ...` | 0 | Stack sample preserved; precise normalizer cause unresolved |
| Initial / corrected `validate_records.py` | 1/0 | Manifest filename corrected;30 protected inputs and329 prior packet members checked |

Exact commands, identities and limits:
[candidate preparation record](proposals/refund-executable-feasibility/normalisation-20261104/REPORT.md).
Raw records: `results/refund-normalised-method-2026-11-04/attempt-0001/`.
The second attempt reaches exact input preparation but not the marker after
`cfNormaliseLib.normalise_decl`. Manual interruption is not a behavioral
rejection or evidence of impossibility. Two construction attempts are preserved.
No prior failure or journal entry was rewritten. Pinned HOL/CakeML tracked
sources and the actual wrapper remain unchanged. GitHub was not refreshed.

Next authorized check, NOT RUN: localize the incomplete normalizer call using
existing operations. Then independently prove any completed candidate's full
result and its observable-result relation to the original method. Library
heap/frame, complete I/O, exact native artifact and runtime correspondence
remain open. New provenance/admission and hosted refund measurements are NOT RUN.
Independent claim/profile review and off-machine archive hash/restore remain
open. M2–M4 remain subsequent work. Local records do not authorize publication,
protected adoption, merge, dispatch, signing or deployment.

## Active mission update — 2026-11-04 (U265)

The actual wrapper guard now has a conditional rejection theorem, bound to its
actual main-call prefix and namespace. Both guard removal and remainder-binding
substitution fail as required. Prefix stream execution, library method behavior,
accepted output and native compilation remain open. CURRENT none; M1 open;
Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Initial declaration / exact lookup inspection | 1/0 | Wrong predicate qualifier preserved; actual equality/error binding checked |
| `run.py 0001` / `0002` / `0003` | 1/1/1 | Two manual interruptions, then wrong theory qualifier; no accepted theory |
| `run.py 0004` / `run.py repeat` | 0/0 | Guard rejection theorem; six identical exports |
| Mutated parent / guard against unchanged mutation | 0/1 | Old partial proof still passes; new guard obligation fails |
| Parent restoration / `run_controls.py` | 0/0 | Exact original exports restored; four child expectations match |
| `run_entry.py entry-0001` / `entry-0002` | 1/0 | Closure expansion interrupted; generic call lemma and actual prefix checked |
| Remainder-binding substitution / entry repeat | 1/0 | Intended `rest = empty` proof failure; six identical positive exports |
| `run_entry_controls.py` | 0 | Both required outcomes checked |
| `run_gap.py cf-gap` / `cf-gap-repeat` | 0/0 | Exact raw match expression cannot satisfy the CF value premise |
| Fresh HOL closure / record and source postflight | 0/0 |231 nodes, eight own theorems, four foundation axioms;30 inputs unchanged |

[Exact claims, source identities and commands](proposals/refund-executable-feasibility/tail-guard-20261104/REPORT.md).
Raw records: `results/refund-tail-guard-2026-11-04/attempt-0001/`.
The U264 uncaught mutation and all earlier failures remain unchanged. The new
result is conditional model behavior, not actual stdin or native execution.

The direct CF route has a checked applicability obstacle beyond its earlier
Boolean-allocation failure. The published normalizer is explicitly unverified;
its output cannot inherit the old theorem. Next authorized experiment, NOT RUN:
produce a candidate with that existing transform, then independently prove its
complete refund result and relation to the original method. Preserve the full
contract; no assumed normalization correctness. The actual method is unchanged.
No native compiler/run, hosted refund measurement, publication, signing or new
admission occurred. Independent review and off-machine hash/restore remain open.

## Active mission update — 2026-11-04 (U264)

Published SexpProg source replay completed. The exact wrapper's tuple patterns
now have checked matching proofs. Its control-flow coverage remains incomplete:
removing the actual trailing-input guard still passes. The required refusal
remains1; the wrapper matrix fails1. No native refund executable or whole-program
claim is established. CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `Holmake --no-cache -j 2 SexpProgTheory.uo` | 0 |62 theories rebuilt;2267.0141792919894 local proof-build seconds |
| Initial/corrected Sexp identity readback | 1/0 | Ambiguous basename resolved using actual built object and source directory |
| `run_program.py program-0001` / `program-0002` | 1/0 | Translation setup fixed; second attempt constructs declarations only |
| `run_program.py program-0003` / `program-0004` | 0/0 | Nested pattern fixed; actual input/output pattern theorems checked |
| Flat-input / swapped-output wrapper mutations | 1/1 | Intended theorem failures |
| Removed-tail-check wrapper mutation | **0; required1** | **Coverage gap; not a successful negative control** |
| `run_program.py program-repeat` | 0 | Six byte-identical exports |
| `run_program_controls.py` | **1** | Matrix correctly retains the unmet refusal requirement |
| `run_heap.py heap-0003` / `heap-0004` / `heap-0005` | 1/1/1 | Helper failures, then interrupted broad evaluation; five attempts total, route stopped |
| `run_method.py method-0003` / `method-0004` | 1/1 | Boolean reference/frame obligation unresolved; four attempts total |
| Saved-record/identity validation | 0 |30 protected inputs unchanged; failed matrix and repeat identities confirmed |
| Separate runtime-object builds | 0/0 | Identical C objects; no linked refund executable |
| Separate fixture proof attempts | 1/1 | Permission errors before proof; no rerouted execution or accepted fixture result |

[Exact wrapper commands, hashes and failure records](proposals/refund-executable-feasibility/native-io-20261104/REPORT.md).
[Separate native audit](proposals/refund-executable-feasibility/native-audit-20261104/REPORT.md).
Raw records remain in `results/refund-native-io-2026-11-04/attempt-0001/`.
This checkpoint validates saved results and updates Markdown. It does not rerun
the listed proof commands or refresh GitHub. Prior results and failed attempts
remain preserved. SexpProg IN_PROGRESS below is the earlier U263 observation.

Next authorized check, NOT RUN: prove that the actual wrapper continuation
rejects a nonempty remainder. Require the same tail-guard mutation to fail for
that theorem. Then complete library framing and whole-program I/O. No native
compiler or application execution, hosted refund run, signing or admission ran.
Independent claim/profile review and off-machine archive hash/restore remain open.

Documentation preservation checks for U264: stored-record validation0;19 local
links and the520368-byte prior journal prefix checked0. Staged whole-packet
whitespace check2 reports original raw logs and proof-source whitespace. Those
bytes remain unchanged. The authored Markdown whitespace check returns0.
Exact records: `native-checkpoint-docs-validation.json` and
`native-docs-commit-commands.json` in the raw directory above.

## Active mission update — 2026-11-04 (U263)

Refund wire inputs now have a checked full-domain parsing/field relation to the
same generated method's model result. Output fields also round-trip. Trailing
input is explicitly refused; no refund precondition was added. This is not a
native I/O or executable theorem. CURRENT none; M1 open; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `run.py 0001` / `0002` | 1/0 | Proof-file syntax corrected; input/model relation checked |
| `run.py full-0001` / `full-0002` | 1/0 | HOL name collision corrected;12 own theorems checked |
| Four schema alteration checks | 1 each | Swapped fields, ignored suffix and domain narrowing refused for intended reasons |
| `run.py repeat` / acceptance readback | 0/0 | Six identical exports; all refusal reasons checked |
| Fresh HOL closure inspection | 0 |159 nodes; four existing foundation axioms explicit |
| `run_heap.py heap-0001` / `heap-0002` | 1/1 | Manual SIGINT; child signal2 each; no heap theorem accepted |
| `run_method.py method-0001` / `method-0002` | 1/1 | AST-list type error, then unsupported automatic ref tactic; preserved |
| Original-input postflight / archive validation | 0/0 |30 unchanged inputs;173 archived members checked |

[Schema proof and exact commands](proposals/refund-executable-feasibility/io-schema-20261104/REPORT.md).
Raw records: `results/refund-native-io-2026-11-04/attempt-0001/`.
Published SexpProg replay is IN_PROGRESS at this checkpoint; no final exit yet.
Next: explicit CF reference/frame proof, whole-program I/O and pinned arm8
native compilation. Native execution/admission and hosted measurements NOT RUN.
Independent review and off-machine hash/restore remain open. Stage12 unauthorized.

## Active mission update — 2026-11-04 (U262)

The complete approved Unicode input domain now has a checked source-level
UTF-8 representation for refund. Published encoding/decoding, empty strings,
exact reasons and caller-ID round trips are checked without the upstream
character wrapper's axiom. The same approved refund decisions and represented
outputs are preserved. This does not prove native I/O or an exact executable.
CURRENT none; M1 open; Stage12 unauthorized; `end_to_end=false`.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `run.py 0001` / `0002` / `0003` / `0004` | 4/4/4/4 | Resource failures preserved; no partial run accepted |
| `run.py 0005` | 0 | Character conversion and scalar round-trip checked; all included library sources verified |
| `run.py sequence-0001` / `sequence-0002` | 4/0 | Inferred subset/projection failures fixed without changing the claim |
| `run.py transport-0001` / `transport-0002` | 4/0 | Reason proof split; full string relation and source transport checked |
| `run.py final` / `repeat` | 0/0 |1426 assertion batches each;30 exact input files and symbol outcomes match |
| `run.py substituted-id ...` | 4 | Unconditional attack violates rejected empty-charge output; retained |
| `run.py accepted-id ...` | 4 | Targeted attack violates accepted caller-charge identity |
| `run.py over-limit ...` / `truncation ...` | 4/4 | False authorization and original U+0100 truncation claim refused |
| Pinned Dafny audit / acceptance readback | 0/0 | Zero audit findings; exact refusal reasons checked |
| Original-input postflight | 0 |30 frozen owner-workspace files unchanged |
| Local archive validation | 0 |848 file members checked; independent copy still unverified |

Exact commands, source/library identities, failed attempts and trust limits:
[UTF-8 source report](proposals/refund-executable-feasibility/unicode-20261104/REPORT.md).
The independently prepared conditional transport record is local commit
`73728c2efa94b452637dfd10f36546f6f8a08d23`; this run also reverified its source.
Raw results: `results/refund-unicode-2026-11-04/attempt-0001/`.

Next: bind the same method to whole-program native compilation and checked I/O.
Inspect existing `mlsexp`/`SexpProg` parsing and I/O proofs for full byte strings
and integers. Preserve compiler entry, resource-limit and environment premises.
Refund native execution, hosted measurements and new admission are NOT RUN.
Independent claim/profile review and off-machine hash/restore remain open.

## Tracking update — 2026-11-04 (U261)

The owner requested a durable Markdown record. The full mission remains in
[FORGE_MISSION.md](FORGE_MISSION.md). The compact assurance-link checklist is
at the start of [FORGE_MISSION_STATUS.md](FORGE_MISSION_STATUS.md). It names
the evidence, completion conditions, open gaps and approval boundaries.
CURRENT none; M1 open; Stage12 unauthorized; `end_to_end=false`.

| Executed documentation check | Actual exit | Observation |
| --- | --- | --- |
| `python3 -B -` mission/worktree preflight | 0 | Mission matches the original attachment; four records match the clean docs worktree at96bea846 |
| `python3 -B -` evidence/link readback | 0 |72 caller-packet manifest entries and12 local links checked; recorded positive/negative exits agree |

Records: `results/mission-tracking-2026-11-04/attempt-0001/`.
These are document and identity checks. No proof or hosted experiment reran.
Remote repository state was not refreshed. Prior results below remain recorded
executions. The next proof gap is full Unicode representation, followed by
native input/output, exact executable/runtime correspondence and new admission.
Independent backup hash/restore and review requirements remain open.

## Active mission update — 2026-11-04 (U260)

The exact generated refund method now has a universal result theorem for a
fixed model caller. The caller constructs primitive state/constructors and
typed input bindings, invokes the method and returns all six required values.
This does not establish a native ABI, input decoder or exact executable.
CURRENT none; Stage12 unauthorized; M1 remains open; `end_to_end=false`.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `python3 -B run.py 0001` | 1 | Universal proof incomplete; failed conditional-Boolean case retained |
| Concrete valid-call diagnostic through HOL EVAL | 0 | Exact tuple returned for one example; not universal acceptance |
| `python3 -B run.py 0002` | 1 | Manual SIGINT of broad rewrite; child signal2; no proof accepted |
| `python3 -B run.py 0003` | 0 | Universal caller/result theorem; narrow Boolean equalities proved in HOL |
| `python3 -B run.py swapped-ids negative-swapped-ids/forge_refund_callScript.sml` | 1 | Expected refusal: request/charge identity equality unproved |
| `python3 -B run.py missing-argument negative-missing-argument/forge_refund_callScript.sml` | 1 | Expected refusal: missing argument makes return claim false |
| `python3 -B run.py repeat` / acceptance comparison | 0/0 | Fresh source execution; six identical exports; negative reasons checked |
| Fresh HOL closure inspection | 0 |156 theory nodes; three own theorems; four foundation axioms explicit |
| Original-input postflight | 0 |30 frozen owner-workspace inputs unchanged |
| Local raw-archive member hash validation | 0 |70 members checked; off-machine validation remains open |

Exact commands and claim limits:
[model caller report](proposals/refund-executable-feasibility/caller-20261104/REPORT.md).
Raw records: `results/refund-caller-2026-11-04/attempt-0001/`.

Next authorized check: establish the full Unicode/byte representation and
input/output relation without restricting the approved domain. Preserve empty
strings, exact ASCII reason equality and caller-ID round trips. The U+0100
control still forbids low-byte truncation. Then connect the same method to the
existing native compiler and calling/I/O infrastructure. No new generic tooling.
No hosted refund execution, signing or admission has run. Off-machine backup
hash/restore validation and independent claim/profile review remain separate.

## Prior mission update — 2026-11-04 (U259)

The exact refund body now has a checked conditional behavioral relation to its
generated CakeML expression. This is not a native executable theorem. CURRENT
none; Stage12 unauthorized; M1 open; `end_to_end=false`.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| `python3 -B run.py 0001` | 1 | Static proof left a quantified trivial goal; preserved |
| `python3 -B run.py 0002` | 0 | Exact compiler relation and static premises checked |
| `python3 -B run.py 0003` / `0004` | 1/1 | Projection name error and unresolved value substitution; retained |
| `python3 -B run.py 0005` / `final` | 0/0 | Six CakeML output fields established under explicit entry premises |
| `python3 -B run.py substitution negative-compiled-substitution/forge_refund_compileScript.sml` | 1 | Expected refusal at exact compilation equality |
| `python3 -B run.py repeat` / acceptance comparison | 0/0 | Fresh source execution; six byte-identical exports; negative reason checked |
| Fresh HOL closure/theorem inspection | 0 |139 theory nodes; nine own theorems; four foundation axioms retained |
| Initial original-input postflight | 1 | Wrong comparison worktree; preserved bookkeeping failure |
| Postflight using original owner workspace | 0 |30 frozen source/input hashes unchanged |
| Parent model/report local commit and124-file readback | 0/0 | Commitd0269c05; no publication |

Exact commands and limits:
[compiler relation report](proposals/refund-executable-feasibility/compiler-relation-20261104/REPORT.md).
Raw results: `results/refund-compiler-relation-2026-11-04/attempt-0001/`.

Next authorized check: construct the checked method entry/calling environment
and caller-visible returned tuple using the existing published proof. The
current theorem retains `state_rel` and `env_rel` as premises. Full Unicode
transfer, observable interface, native artifact and new admission remain open.
No hosted refund execution or performance measurement has run. Off-machine
archive identity/restore and independent acceptance review remain separate.

## Prior mission update — 2026-11-04 (U258)

The full refund contract remains the M1 target. This new local experiment
checks refund behavior in the published HOL4 Dafny model. It does not yet
connect the approved Unicode source domain to a native refund executable.
CURRENT none; Stage12 unauthorized; `end_to_end=false`.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Pinned Poly/ML configure/build/compiler/install | 0/0/0/0 | Isolated experiment prefix; no production pin changed |
| Pinned HOL4 smart-configure / `bin/build` | 0/0 | Real local tool build |
| Initial Unicode witness/control | 2/2 | Invalid escape syntax; failures preserved |
| Corrected Dafny Unicode witness / low-byte equality control | 0/4 | Legitimate U+0100 input retained; false truncation equality refused |
| `python3 run_kernel.py 0001` / `0002` | 1/1 | Full-result proof incomplete; failed proof states retained |
| `python3 run_kernel.py 0003` | 0 | Guard, all six output fields, normal modeled return and unchanged heap |
| `python3 run_kernel.py negative-bound ...` / `negative-reject ...` | 1/1 | Expected proof failures; reasons and absent accepted output checked |
| Negative-control result check | 0 | Both violations refused for the intended reason |
| `python3 run_kernel.py repeat-0001` / object comparison | 0/0 | Fresh proof execution; all six exports byte-identical |
| HOL theorem and imported-closure audit | 0 |112 theory nodes; four HOL foundation axioms explicitly retained |
| `Holmake --no-cache -j 2 dafny_to_cakemlProofTheory.uo` | 0 | Actual published compiler-proof replay;267.9495331249782 local seconds |
| Original-input postflight | 0 |30 frozen inputs unchanged |
| Local raw-archive member hash validation | 0 |118 members checked; not off-machine verification |

Exact commands, source hashes, full logs, failed attempts and trust limits:
[verified-backend report](proposals/refund-executable-feasibility/verified-backend-20261104/REPORT.md).
Raw records: `results/refund-verified-backend-2026-11-04/attempt-0001/`.

Next authorized check: instantiate the published compiler relation for the
checked refund body and exact generated CakeML expression. Discharge its
freshness, no-shadowing and no-assertion premises. Preserve the remaining full
Unicode representation, calling/I/O, native-artifact and admission obligations.
No compiled-refund theorem, hosted refund run or new admission has completed.
Owner-reported off-machine backup still needs exact hash and restore validation.

## Prior mission update — 2026-11-04 (U257)

The complete owner mission is preserved byte for byte in FORGE_MISSION.md.
The linked tracker owns current M1–M4 status. The older stage and milestone
records below remain historical. CURRENT none; Stage12 unauthorized.

Selected feasibility target: the existing full refund R1–R5 contract, with no
new precondition or restricted input domain. Actual local source equivalence
passes. Exact compiled-refund behavior remains BLOCKED_BY_CORRESPONDENCE.
No new protected acceptance profile, publication or release is authorized here.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Full mission byte/hash comparison | 0 | 32046bytes; SHA2567bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c |
| `python3 -B scripts/exit_stage_8.py --case wrapper-proof` | 0 | Fresh approved source check; source0; over-limit/reject-all gate1 and verifier4; assumption-escape gate1; protected inputs unchanged |
| Pinned Dafny `verify Bridge.dfy --solver-path .../z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | 0 | New universal primitive-field source relation;7verified,0errors |
| Same verification in fresh directory | 0 | Same sources and byte-identical positive verifier output |
| Body mutation: remove amount upper bound | 4 | Expected unproved postcondition |
| Body mutation: always reject | 4 | Expected unproved postcondition |
| `python3 -B results/mission-m1-feasibility-2026-11-04/attempt-0001/flat-bridge/run_controls.py` | 0 | Three child outcomes and reasons checked explicitly |
| Initial new audit command | 2 | Missing expected report; harness failure preserved |
| Audit with existing zero-findings baseline | 0 | Zero findings; source and rules unchanged |

Raw commands, hashes, source snapshots, failure output and repeat records:
[refund feasibility packet](proposals/refund-executable-feasibility/README.md).
Canonical working records: results/mission-m1-feasibility-2026-11-04/attempt-0001/.
Original wrapper report: results/stage8/wrapper-proof/attempt-0005/report.json.

Live main remainsf9eb1cbc; PR34/36/37 remain open/unmerged. The actual held
booking artifact matches the current GitHub digest. Historical hosted
cold/warm/invalidation exits0/0/0, verifier launches1/0/1;13/13 expected outcomes.
This is a fresh inspection of the November2 run, not a new hosted execution.
No billed runner-minute measurement or performance improvement is inferred.

Next authorized check: inspect and reproduce an established verified compilation
path for the full refund representations. No compiled-refund proof, new hosted
run or new admission has run. M1–M4 remain open; end_to_end=false.

This is the execution plan and decision record. Stages 0–10 are DONE. Stage 6
verified the approved booking matcher and its cancellation/retry trace. The
three-condition benchmark completed 75 baseline/candidate pairs. Both real
EXIT commands returned 0. The source evidence and report reproduced byte for
byte. Stage 7's upstream replay, negative control, and own-binary EXIT each
returned 0. The exact 1,240-byte C self-test has a normal-termination proof and
a valid-entry witness. Independent checking covered 579 modules; all 86 closure
assumptions are permitted. Final source and ELF identities match. Stage 8's
wrapper-proof, hostile-outputs and evidence-separation EXITs each returned 0.
The exact approved snapshot repair retains field and prototype mutation
rejection. Source and property-test evidence each reproduced byte for byte
through fresh checks. All failures remain archived. Stage 9's six official
EXITs each returned 0 under one release request (`8a6ba7f4…`) and one
implementation lock (`5f78da21…`, v3.6, main `624c9faf`), with real Cosign
verification of GitHub OIDC-signed bundles recorded in the public Rekor log.
UID 1000 read the exact ELF (`8ced2ab6…`) in the running container of the
accepted package (`d9e9fb40…`); a substituted file was rejected and the
consumed request could not be admitted again. Residual findings F1–F4 stay
open with stated threat-model limits (U166, U169). Stage 10 ran a frozen, internally
authored benchmark of 51 cases (owner-approved manifest `98df0272…`): 47 matched;
the 4 `unsupported` cases were false accepts (the ledger PR gate accepts PRs that
change only unclaimed files); 0 false rejects; 51/51 identical decisions in the
repeat pass (U176). `end_to_end=false`.
Uncertainties and measurement limits remain in append-only [unsure.md](unsure.md).

The long-term horizon and irreducible limits live in [VISION.md](VISION.md).

## Mission

Build an open-source system for general software engineering in which
non-deterministic LLM agents propose code and established, deterministic
checkers decide what is accepted.

Every accepted artifact must carry reproducible evidence. The evidence must
state exactly what was established, about which artifact, under which
assumptions, and by which method.

**LLMs propose, checkers dispose. Humans approve intent (specs), not code.**

## Operating mode — read every run

1. Read this file. If it is missing, recreate it from the stages below and set
   Stage 0 to CURRENT.
2. Work only on the CURRENT stage. Do not start a later stage, even partially.
3. A stage is complete only when every EXIT command has actually run and
   produced its required behavior. Record each exact command, real numeric exit
   code, and result here. Then mark that stage DONE, set the next stage CURRENT,
   and stop. Stage 10 has no successor.
4. Keep the final response to at most 20 lines: stage, EXIT command table with
   real exit codes, and blockers. No narrative.
5. A documentation task does not complete an implementation stage. Keep
   unexecuted checks marked NOT RUN. Never substitute expected codes for actual
   codes.
6. Append uncertain findings to `unsure.md`. Never edit, delete, reorder, or
   overwrite an existing entry. Resolve an entry by appending a new entry that
   refers to its ID. Distinguish observations, inferences, and open questions.

## Hard rules

- Use established tools: Dafny, Rocq, Lean, TLA+/TLC, Verus, Kani, Theorem's
  published pipeline, and sigstore/in-toto. Select the backend needed by the
  current stage; do not install all backends in advance.
- Never write a custom verifier, decoder, machine semantics, proof checker,
  SMT wrapper that judges correctness, or axiom system. Gate code may dispatch
  established tools, bind their results to artifacts, and enforce policy.
- Never simulate or mock a check, or report it as passed unless the real command
  ran and exited as required. If a toolchain cannot be installed or run, STOP,
  report the exact error, and change nothing else.
- Protected files are `spec/**`, `spec.lock`, `policy/**`, and `gate/**`.
  Never modify them to make something pass. To change a spec, write
  `proposals/<name>.md` with the exact diff and a plain-English reason. STOP for
  human approval. Approval must cover the actual proposed change.
- Implementations must not contain `assume`, `{:axiom}`, `{:verify false}`,
  `Admitted`, `sorry`, axiom declarations, or bodiless lemmas. The gate rejects
  these. Deliberately invalid fixtures are rejection tests, never accepted code.
- Evidence must not overclaim. Keep `end_to_end=false` unless every link from
  spec to deployed artifact is covered by a checked method. Tested does not mean
  proved. Bounded model checking does not establish an unbounded proof.
- Pin every tool version. Use resource limits rather than time limits for
  acceptance checks. Include no timestamps in evidence. The same fully specified
  inputs must produce byte-identical evidence.
- Do not echo files or reread them without a reason. Fix only what tool output
  points to. Make at most five attempts per failing proof, then report the
  blocker in at most five lines.

## Intended users and first useful release

The initial target is a small, critical component inside an ordinary software
project. Examples include a ledger, refund rules, idempotent requests, booking
invariants, and permission decisions. Stages 0–3 establish the first useful
demonstration. They do not establish general support for arbitrary applications.

The intended workflow is: approve behavior, propose an implementation, run the
checks, and inspect a plain-English claim report. The user should not need to
write a proof merely to understand what a change establishes. Authoring and
maintaining difficult specifications may still require specialist knowledge.

Different tasks need different evidence. Tests and measurements remain useful
for integrations, performance, UI behavior, and model quality. The policy must
preserve these distinctions. Broad usefulness, acceptable cost, and ease of
adoption are hypotheses to measure in Stage 10.

## Core data model

Design for these records. Implement only what the CURRENT stage requires.

```text
Claim: {
  id, statement_plain_english, spec_ref, spec_sha
}

Artifact: {
  kind: source | module | binary | container,
  sha256, build_cmd
}

Evidence: {
  claim_id, artifact_sha, method, tool, tool_version, result,
  assumptions[], trusted_base[], reproduce_cmd, producer
}

method:
  unit_tested
  property_tested
  tested_against_proved_model
  bounded_model_checked
  eval_measured
  runtime_monitored
  source_proof
  binary_proof
  kernel_checked_proof

Policy: per code tier, required claims and their minimum acceptable methods.
Gate: backend-agnostic evidence validation against policy; no method upgrades.
```

Stage 1 should use the applicable fields directly. Stage 2 formalizes their
schema. Its bundle envelope must also carry `end_to_end`, schema and policy
versions, and the links among claims, artifacts, and evidence. Avoid creating
the later schema or adapters during Stage 0.

## Design reasoning and acceptance boundaries

### 1. The gate coordinates checks

The gate's authority comes from established checkers and protected policy.
Parsing a result, comparing a digest, or checking a required claim is gate work.
Inventing semantics or deciding whether a logical proposition is true is not.
An unknown result, crash, exhausted resource budget, or missing proof fails
acceptance. It does not demonstrate that a claim is false.

### 2. Intent needs precise boundaries

Before freezing the initial ledger spec, make these decisions explicit: account
existence, amount domain, zero amounts, balance limits, retry identifiers,
identifier reuse with different arguments, and the state included in “no effect.”
Decide whether rejected requests create retry records. These choices affect C3
and C5. They must not emerge accidentally from implementation details.

For the first ledger, scope claims to the specified state transition. Do not
claim concurrency safety, crash recovery, durable storage, or distributed
exactly-once execution unless those behaviors are specified and checked. C4 is
the success of a valid operation, not a claim about network delivery or scheduler
fairness. Include termination in its contract.

### 3. Protected inputs need an external baseline

Checking `spec.lock` against files in the same proposed change detects accidental
drift. It does not authorize an agent to change both. Stage 4 must compare with a
trusted baseline and bind approval to the spec diff and revision. Gate code,
policy, workflow configuration, and tool options must come from trusted inputs.
An untrusted PR must not replace the gate that accepts it.

Initial creation of planned files establishes a baseline. Later planned work,
such as the Stage 2 adapter refactor, must preserve existing rejection behavior.
If a change requires weaker acceptance rules or a changed spec, use a proposal
and stop. Negative tests that alter protected inputs use disposable copies;
they do not edit the approved baseline.

### 4. Evidence methods form a policy relation, not a universal ranking

A binary no-crash proof does not establish ledger conservation. A kernel-checked
theorem can concern a different property or artifact. Testing, bounded checking,
source proofs, and runtime monitoring answer different questions.

Interpret “minimum method” through explicit allowed methods for each claim,
artifact kind, scope, and assumptions. A higher-sounding label cannot satisfy an
unrelated requirement. Keep one method per evidence record. Several records can
describe different checks of the same artifact.

### 5. Artifact identity includes the relevant inputs

Hash the exact artifact bytes. For a source collection, define a canonical
manifest of paths and content digests, including the dependency closure. Bind
the result to the approved spec, toolchain, verification options, and policy.
Recompute digests; do not trust values supplied by a proposal.

A matching digest and valid JSON do not prove that a checker ran. Until Stage 9
adds signed provenance, acceptance must use a trusted local or CI checker run.
Handwritten evidence cannot grant itself authority by naming a trusted producer.

### 6. Determinism needs a complete execution contract

Lock versions, distributions, checksums, platform, relevant environment settings,
solver options, seeds, and resource budgets. Canonicalize evidence ordering and
serialization. Keep wall-clock durations, host paths, run identifiers, and raw
diagnostic logs outside canonical evidence. Record benchmarks separately.

Dafny documents stable solver resource counts for the same Z3 build and platform.
That supports resource-based limits; it is not a promise of identical behavior
across arbitrary machines. [Dafny verification optimization](https://dafny.org/dafny/VerificationOptimization/VerificationOptimization)

### 7. All proof dependencies must be covered

Verification must include the required declarations and dependencies. Reject
verification bypasses, skipped members, unapproved external assumptions, and
missing obligations. Prefer the established tool's parser and audit facilities
over inventing a language parser or relying only on keyword searches.

Dafny provides audit and verification controls. In version 4.11.0, `dafny audit`
can return zero while reporting findings. The gate must inspect the findings;
an exit code alone is insufficient. Validate this behavior with real negative
fixtures in Stage 1. [Dafny 4.11.0 reference](https://dafny.org/v4.11.0/DafnyRef/DafnyRef#13618-dafny-audit)

### 8. Deployed binary coverage requires explicit links

The planned chain is:

```text
approved intent → versioned spec → checked claim about exact binary bytes
                → evidence bound to binary SHA-256
                → release/container identity → observed deployment identity
```

Stage 7 checks a property of a particular binary through the published pipeline.
The property must match the claim being advertised. A no-crash proof cannot be
used as evidence for C1–C5. Stage 9 checks provenance and release identity, and
must compare the deployed digest with the approved release digest before
claiming that the checked artifact was deployed.

For a container, record both the container digest and the contained binary
digest. Account for linked libraries, entrypoint, configuration, runtime, and
external services within the claim's scope or list them as gaps and assumptions.
A signature authenticates evidence; it does not prove program behavior.
Rebuilding the same bytes establishes reproducibility, not compiler correctness.

Keep `end_to_end=false` when a required link is missing. Even a complete artifact
chain retains its stated model and trusted-base assumptions. No stage may infer
whole-service correctness from a proof of one component.

### 9. Incremental verification must preserve coverage

Stage 4 needs a complete dependency map. Cache keys include the member, all
relevant dependencies, the spec, toolchain, options, and policy. Dependency
uncertainty must trigger broader verification or block acceptance. Cached proof
reuse requires matching inputs and trusted origin. Count checked and reused
obligations separately. Do not equate changed lines with affected claims.

### 10. Measure results without inventing benefits

Stage 6 records all attempts, failed runs, prompts, responses, available provider
token categories, verifier time, and human interventions. Missing token data is
unknown, never zero. Fixed inputs and seeds make experiments repeatable; new
LLM runs and wall-clock measurements need not reproduce identical numbers.
Report recorded results separately from reruns and make no extrapolation.

Stage 10 requires two actual weeks of observation. Report the number and kinds
of PRs observed. A period with little activity cannot establish broad usefulness.

## Stage index

| Stage | Name | Status |
| --- | --- | --- |
| 0 | TOOLCHAIN | DONE |
| 1 | LEDGER DEMO | DONE |
| 2 | EVIDENCE SCHEMA + POLICY | DONE |
| 3 | TYPESCRIPT INTEGRATION | DONE |
| 4 | CHANGE LOOP | DONE |
| 5 | SPEC TOOLING | DONE |
| 6 | SECOND DOMAIN + REUSE MEASUREMENT | DONE |
| 7 | BINARY LAYER | DONE |
| 8 | ML BOUNDARY | DONE |
| 9 | PROVENANCE | DONE |
| 10 | GATE BENCHMARK (replaces SHADOW MODE) | DONE |
| 11 | INCREMENTAL VERIFICATION (owner-defined 2026-10-30) | DONE (EXITs passed; candidate PR awaiting review; CI shape not met) |

## EXIT command conventions

Commands for unfinished stages below are planned interfaces, not run results.
Create only the commands required by the CURRENT stage. Finalize each exact
invocation, options, and fixture before running it, and record that invocation
in the execution record. Never mark a stage DONE from this planning table.

Scenario scripts may prepare inputs, invoke established tools, and check
expected results. They must not implement a verifier. For every negative test,
record both the raw checker exit code and the scenario script exit code. A
scenario script may return zero when rejection was expected and observed.
Missing tools, syntax errors, and process crashes do not count as the intended
negative result. Record the diagnostic and claim or policy rule that caused it.

### Stage 0 — TOOLCHAIN

**Status: DONE**

Install pinned Dafny with its bundled Z3, Node, and Python. Select host-compatible
distributions and record exact versions and checksums before installation.
Use the official Dafny 4.11.0 release as the Dafny pin. Node 24.3.0 and Python
3.10.11 were already installed and are reused. Their version and executable
checksum checks passed. The Dafny archive matched its official checksum before
extraction. Bundled Z3 4.12.1 is selected explicitly. Pins and resource settings
are in `toolchain/pins.json`. Original Node/Python installer provenance remains a
disclosed trust assumption, not a verified claim; see `unsure.md` U015.
[Dafny release](https://github.com/dafny-lang/dafny/releases/tag/v4.11.0)

Create two tiny smoke fixtures: a true arithmetic lemma with a body, and a false
arithmetic lemma with a body. Use the same locked verification settings for both.
Confirm resource-limit and timeout-disable options against the pinned CLI before
the runs. No ledger, gate, policy, or later-stage scaffolding belongs here.

| EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `dafny --version` | Prints the locked Dafny version; exits 0. | 0 — `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` |
| `node --version` | Prints the selected Node version; exits 0. | 0 — `v24.3.0` |
| `python3 --version` | Prints the selected Python version; exits 0. | 0 — `Python 3.10.11` |
| `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | Trivial true lemma verifies. | 0 — 1 verified, 0 errors |
| `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | False postcondition fails verification. | 4 — 0 verified, 1 error; expected rejection |
| `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version` | Prints the selected bundled Z3 version. | 0 — `Z3 version 4.12.1 - 64 bit` |

Both verification commands wrote raw outputs to `toolchain/results/true.log` and
`toolchain/results/false.log` using shell output redirection. The false result
names the postcondition `1 + 1 == 3`; it is not an infrastructure failure.
Reproduction instructions are in [toolchain/README.md](toolchain/README.md).
The stage transition ends this run. No Stage 1 implementation was created.

### Stage 1 — LEDGER DEMO

**Status: DONE**

The user approved [the initial ledger contract](proposals/initial-ledger.md) as
written. Candidate SHA-256
`e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`
is frozen in `spec/LedgerSpec.dfy` and `spec.lock`. The real Dafny verifier
accepted the concrete refinement with 12 verified obligations and zero errors.
The final gate and all EXIT scenarios passed. The approved spec bytes are
unchanged. [Archived Stage 1 evidence](results/stage1/evidence.json) records C1–C5 as `source_proof` and keeps
`end_to_end=false`. [Actual results](results/stage1.json) record the real codes.

Create `spec/LedgerSpec.dfy` as an abstract module, `impl/Ledger.dfy` as its
refinement, `gate/gate.py`, and `spec.lock`. The lock contains the spec SHA and
Dafny version. Freeze the approved behavior before implementation repairs.

| Claim | Required behavior |
| --- | --- |
| C1 — conservation | A transfer preserves total funds. |
| C2 — non-negative | Every resulting account balance is non-negative. |
| C3 — idempotent retries | Repeating the same request does not repeat its effect. |
| C4 — progress | A valid transfer terminates and succeeds. |
| C5 — invalid → no effect | An invalid transfer is rejected and leaves the specified state unchanged. |

Self-transfers are invalid and must be rejected. Bind diagnostics to claim IDs.
Check the concrete refinement; abstract declarations alone establish no
implementation result. Audit forbidden constructs and all proof dependencies.

Plant `self_transfer` (creates money), `off_by_one` (`<` instead of `<=`),
`retry_double`, and `sneaky_assume`. Keep a fixed, deliberately incomplete unit
suite that passes these fixtures. Demonstrate each rejection through the gate.
Report `sneaky_assume` as a forbidden assumption, with the affected claim named
and unestablished; do not invent a counterexample from an audit failure.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Accepts C1–C5 and writes source-proof evidence; exits 0. | 0 — accepted C1–C5 |
| `python3 scripts/exit_stage_1.py --case reproducibility` | Runs the gate twice and byte-compares evidence; exits 0 on equality. | 0 — both gate runs and `cmp` exited 0 |
| `python3 scripts/exit_stage_1.py --case planted-bugs` | Unit suite passes each fixture; gate rejects all four and names affected claims/rules. | 0 — all four unit runs exited 0; all four gates exited 1 |
| `python3 scripts/exit_stage_1.py --case spec-lock` | A changed spec with its old lock is rejected in a disposable copy. | 0 — gate exited 1 with `SPEC_LOCK` |
| `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects a candidate without the approved refinement relationship. | 0 — gate exited 1 with `SOURCE_SCOPE` |
| `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects bodiless lemmas, axiom lemmas, and disabled verification. | 0 — each direct auditor exited 2; each gate exited 1 |

The final negative-control results were:

| Fixture | Basic unit exit | Checker exit | Gate exit | Claim or policy diagnostic |
| --- | --- | --- | --- | --- |
| `self_transfer` | 0 | 4 — verification | 1 | C1 and C5 not established |
| `off_by_one` | 0 | 4 — verification | 1 | C4 not established |
| `retry_double` | 0 | 4 — verification | 1 | C1 and C3 not established |
| `sneaky_assume` | 0 | 2 — audit comparison | 1 | Forbidden assumption; C1–C5 not established |

The basic unit suite exercises an ordinary transfer and a missing-account
rejection. It deliberately misses these bugs. Unit success is recorded as
`unit_tested`; it is not proof. A failed proof obligation means that the checker
did not establish the claim. An audit failure does not supply a counterexample.

The gate delegates proof decisions to pinned Dafny and Z3. It checks the exact
approved spec, an explicit refinement declaration, the required verified
obligations, and an empty Dafny audit report. See [gate/README.md](gate/README.md)
for commands, evidence identity, source-format restrictions, and trusted inputs.
The spec-lock test changes only a disposable copy. It does not establish
authorization for changing both the spec and lock in a proposed change.

Canonical evidence SHA-256:
`8389e88aac8526ce48dd8ef70c8e6e40f53ccf5360465b79cb8cec27b3c66df3`.
Those exact bytes and the original gate/scenario sources were preserved under
`results/stage1/` before the Stage 2 refactor. Root `evidence.json` now holds the
current policy-bound format. The archived scripts are historical source records.
Raw commands, exit codes, and diagnostics are retained locally under
`build/stage1/<case>/`; repeated runs archive prior logs under
`build/stage1-history/`. These generated directories are not publication inputs.
The portable result summary is [results/stage1.json](results/stage1.json).

This stage transition ends the run. Stage 2 is CURRENT; no Stage 2 files were
created. The user authorized continuation through the full roadmap, with binary
and deployment work deferred to their planned stages; see `unsure.md` U024.

### Stage 2 — EVIDENCE SCHEMA + POLICY

**Status: DONE**

Define JSON Schema for the core model and bundle metadata. Create
`policy/tiers.yaml`. Refactor the gate into a backend-independent policy layer
with Dafny as one adapter. Preserve Stage 1 rejection behavior. Use an established,
pinned JSON Schema validator. JSON validation establishes structure only.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_2.py --case schema` | The schema validates actual Stage 1 evidence. | 0 — exact Stage 1 archive and current evidence validate; two malformed inputs rejected with 1 |
| `python3 scripts/exit_stage_2.py --case artifact-mismatch` | Hand-edited `source_proof` evidence with a wrong artifact SHA is rejected. | 0 — three artifact-binding controls rejected with gate exit 1 |
| `python3 scripts/exit_stage_2.py --case method-policy` | A tier requiring `source_proof` rejects `unit_tested` evidence. | 0 — unit, bounded-check, and unrelated kernel-proof labels rejected with gate exit 1 |
| `python3 scripts/exit_stage_2.py --case round-trip` | Supplied valid evidence must reproduce through a fresh real checker run. | 0 — gate and byte comparison each exited 0 |
| `python3 scripts/exit_stage_2.py --case policy-controls` | Rejects altered policy, claims, trusted inputs, coverage, producer, or document keys. | 0 — all 15 negative gate calls exited 1 for the intended rule |

The refactored gate command also exited 0:
`python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json`.
It produced schema version `2.0.0` evidence bound to policy `forge-ledger` version
`1.0.0`, tier `critical`, with policy and trusted-input hashes. The five records
remain `source_proof`; `end_to_end=false`. The real Dafny run established 12
obligations. The schema also accepts archived format-1 evidence without upgrading
its authority or adding a policy binding that was absent from the original run.

Established validators: jsonschema 4.21.1 and PyYAML 6.0.1. Their installed
dependencies and file hashes are pinned in `toolchain/requirements-stage2.txt`
and `toolchain/validator-pins.json`. These preinstalled packages ran successfully;
no installation or archive authentication is claimed. See U025 for the limit.

The core checks structure, current artifact and approved-claim bindings, explicit
allowed methods, and selected policy identity. The Dafny adapter retains proof,
audit, source-scope, and result-coverage checks. Imported evidence must also match
a fresh checker result. The producer-name tampering control reached that final
comparison and was rejected. Schema-only validation prints `SCHEMA_VALID`, never
`ACCEPTED`, and writes no accepted bundle.

All Stage 1 scenario commands were rerun against the refactored gate:

| Regression command | Actual exit code | Required raw behavior retained |
| --- | --- | --- |
| `python3 scripts/exit_stage_1.py --case reproducibility` | 0 | Gate 0 twice, `cmp` 0 |
| `python3 scripts/exit_stage_1.py --case planted-bugs` | 0 | Units 0 each; three verifier exits 4; sneaky audit 2; gates 1 each |
| `python3 scripts/exit_stage_1.py --case spec-lock` | 0 | Gate 1 for stale lock in disposable copy |
| `python3 scripts/exit_stage_1.py --case contract-binding` | 0 | Gate 1 for missing approved refinement |
| `python3 scripts/exit_stage_1.py --case audit-controls` | 0 | Direct audits 2 and gates 1 for all three proof-escape controls |

`cmp evidence.json build/stage1/reproducibility/evidence.json` also exited 0.
The approved spec and `spec.lock` are unchanged. The evidence digest is
`0400b148904360eb3fde1940acaf73ba0a1342f9244da8cf1f69046a6c9d4e16`.
Actual results are in [results/stage2.json](results/stage2.json). Raw local logs
are under `build/stage2/` and `build/stage1/`; previous runs are archived.

Stage 2 is DONE. Stage 3 is CURRENT. This transition ends the run. No TypeScript
integration, later-stage adapter, binary layer, or deployment code was created.

### Stage 3 — TYPESCRIPT INTEGRATION

**Status: DONE**

Compile the Dafny ledger core to JavaScript. Import it from `app/main.ts`.
Add handwritten `ts/ledger.ts` and pinned fast-check property tests against the
Dafny model. Record fixed seeds and run counts. Cover sequences of operations,
including retries and invalid requests, and preserve the spec's numeric domain.
Record handwritten TypeScript results as `tested_against_proved_model`.
The source proof remains attached to Dafny source; generated JS is a distinct
artifact with a recorded build link and explicit compiler/runtime assumptions.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `node --import tsx app/main.ts` | Uses locked local dependencies; prints `Ok` then `Rejected`; exits 0. User-approved replacement for the original CLI invocation. | 0 — exact expected output; rerun after approval also exited 0 |
| `python3 scripts/exit_stage_3.py --case correct-typescript` | Real property tests pass on correct TypeScript. | 0 — 300 runs, 3,506 compared transitions, no skips |
| `python3 scripts/exit_stage_3.py --case self-transfer` | Real property tests fail on the planted TS self-transfer bug. | 0 — actual fast-check exit 1 and gate exit 1; real shrunk counterexample |
| `python3 scripts/exit_stage_3.py --case evidence-labels` | Source proof and TS comparison results have distinct, correct methods and digests. | 0 — source and comparison gates 0; critical-tier rejection 1 |

The pinned JS packages are installed and runnable. The original install attempt
exited 1 with `getaddrinfo ENOTFOUND registry.npmjs.org`; the user then installed
them externally. `npm ls --depth=0` exited 0 with the requested exact versions.
Their lock and observed installed content are pinned in `package-lock.json` and
`toolchain/javascript-pins.json`. Original tarball integrity was not independently
replayed here.

The compiled-model build command, `python3 scripts/build_model.py`, exited 0.
Dafny verified 12 obligations, then generated JS. The script preserves that output
and adds only a tracked CommonJS export footer. The model module digest is
`2387fcdf5fcfb6d9bc4a05e752b55549cd001ada104431a5bf1311e92ce2b567`.
The original approved spec and `spec.lock` are unchanged.

`node --import tsx app/main.ts` exited 0 and printed exactly `Ok` then `Rejected`.
This supported loader works within current permissions. The tsx CLI version
probe exited 1 with `listen EPERM` for its local socket. The user authorized IPC,
but the host refused an elevated retry because `sandbox_approval=false`.
That refused retry did not run and has no process exit code.

The original `npx tsx app/main.ts` command subsequently ran and exited 1 with
`listen EPERM`. Its `cli-demo` scenario also exited 1. The user then approved the
previously proposed replacement, `node --import tsx app/main.ts`. That exact
replacement ran again with exit 0 and the expected output. This is an approved
invocation change, not a claim that the original CLI command passed. The spec,
lock, policy, comparison corpus, and evidence methods are unchanged. See U030.

Supplemental real checks:

| Command | Actual exit code | Observed result |
| --- | --- | --- |
| `npx --no-install tsc --noEmit` | 2, then 0 | Fixed the reported example tuple type; implementation unchanged |
| `python3 scripts/exit_stage_3.py --case reproducibility` | 0 | Two real builds and gate runs; generated module and evidence byte-identical |
| `python3 scripts/exit_stage_3.py --case loader-demo` | 0 | Real loader invocation printed exactly the two expected lines |
| `python3 gate/gate.py --schema-only results/stage3/typescript-evidence.json` | 0 | Schema validation only; no proof claim |

All five Stage 1 and all five Stage 2 scenario commands were rerun and exited 0.
The real child codes, comparison counters, and preserved negative counterexample
are in [results/stage3.json](results/stage3.json) and `results/stage3/`.
Source evidence is `source_proof`; TypeScript evidence is
`tested_against_proved_model`. The critical tier rejects the latter. The compiler,
runtime, and conversion bridge remain assumptions, and `end_to_end=false`.
See [ts/README.md](ts/README.md) for the exact corpus and module-layout scope.

All Stage 3 EXITs, including the approved replacement invocation, are established.
Stage 3 is DONE; Stage 4 is CURRENT. This transition ends the run. No Stage 4
implementation or later-stage spec change was started.

### Stage 4 — CHANGE LOOP

**Status: DONE**

Investigation: `python3 scripts/probe_stage_4.py` ran with exit 0. It invokes
real Dafny commands on isolated copies. Full verification accepted the original
ledger (exit 0) and rejected a broken helper proof (exit 4). Selecting only
`Ledger.Apply` returned exit 0 in both cases. Selection therefore cannot replace
dependency coverage. The diagnostic accepts no artifacts and completes no
Stage 4 EXIT. Exact child commands and obligation counts are recorded in
`results/stage4-member-probe.json`; see `unsure.md` U033.

Local implementation: `gate/incremental.py` uses Dafny/Boogie snapshot caching,
audits both revisions, binds evidence to SHA-256 source identities, and rejects
changes to trusted inputs. `python3 scripts/check_stage_4_local.py` ran with
exit 0. A valid Apply edit checked 2 obligations and reused 10; broken helpers,
weakened helper contracts, and planted bugs were rejected. Repeated evidence
was byte-identical. The first local test driver run exited 1 because it expected
the wrong exit code for Dafny's bare-assume warning; that failure is preserved.
These local controls do not satisfy the real-PR EXITs below. See
`docs/stage4-change-loop.md`, `results/stage4-local.json`, and `unsure.md` U034–U036.

The exact saved reproduction command also ran with exit 0 and reproduced
identical evidence. Linux inventory then succeeded in
[Actions run 40397041174](https://github.com/mack-dot/forge/actions/runs/40397041174):
the inventory command exited 0, the true lemma exited 0, and the false lemma
exited 4. Exact child commands and measured pins are in
`results/stage4/ci-inventory.json`. The new Linux profile is now selected explicitly
by the PR gate. Its real-PR results are recorded below. The workflow runs
trusted checking and reporting code in separate jobs. These preparation checks
do not satisfy the real-PR EXITs.

Pre-publication regression record: `results/stage4/regressions.json` retains all
20 exact commands and real codes. The updated local controls exited 0. All five
Stage 1 scenarios exited 0. An initial Stage 2 method-policy check exited 1
because its fixture used stale evidence and reached `TRUSTED_INPUTS` first.
After the real source gate refreshed evidence (exit 0), all five Stage 2 scenarios
and all five supported Stage 3 scenarios exited 0. See U041 for the setup error;
no acceptance rule was relaxed. The actual loader demo printed `Ok` then `Rejected`.

Create a GitHub Action that computes affected claims from dependencies and
content hashes, invokes per-lemma/per-member verification, and posts a
plain-English claims table. Pin actions and dependencies. Use trusted gate and
policy inputs and isolate untrusted PR execution from credentials.

Demonstrate a fee requirement through `proposals/fees.md`. Stop for human
approval before changing the spec. After approval of that exact diff, create
spec v2, update the lock through the approved path, and reverify. Bind approval
to the revision; a later edit requires fresh approval. Block an agent attempt
to weaken C2. An approval label alone is insufficient evidence of approved text.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_4.py --case affected-claims` | A real PR without a spec change verifies only affected claims; logs checked/reused counts. | 0 |
| `python3 scripts/exit_stage_4.py --case unapproved-spec` | The real workflow rejects an unapproved spec change and the C2 weakening attempt. | 0 |
| `python3 scripts/exit_stage_4.py --case approved-spec` | After human approval, the real workflow accepts the new spec and records its new SHA. | 0 |

Record PR and workflow run references. Local scenarios cannot substitute for
the required GitHub Action runs. Keep this stage CURRENT while approval is pending.

Actual EXIT execution: [run 40403180524](https://github.com/mack-dot/forge/actions/runs/40403180524),
job 121854084912, trusted revision `b2906e2f64f9e1ecd364d2dced55a391f736c236`.
Both exact commands above exited 0. `results/stage4/exit-run.json` and
`exit-affected-claims.json` / `exit-unapproved-spec.json` retain the API bindings,
actual checker receipts, comments, statuses, and real exit codes.

PR 1 / run 40402849081 accepted the valid Apply edit: gate 0; baseline checked 12;
candidate checked 2 and reused 10; literal replay 0 and byte-identical evidence.
PR 2 / run 40402945633 rejected an unapproved spec plus matching lock with gate 1.
PR 3 / run 40402975014 rejected C2 weakening with gate 1. Both failures reported
`UNAPPROVED_PROTECTED_CHANGE`, emitted no accepted evidence, and had successful
reporting jobs. The negative workflow failures are the required observations.

Approved intent: [proposals/fees.md](proposals/fees.md) contains the exact
spec and lock diff approved by the user's yes response. Candidate spec SHA-256:
`2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940`.
It proposes one unit per fresh successful transfer, paid by the sender to fee
account 0. Retries and rejections pay no fee. The exact approved diff was applied
locally; both candidate digests match. See proposals/fees-decision.md and U044.
The trusted approval support is published separately from the fee PR, so the
real workflow can check the v1-to-v2 spec transition against an external baseline.

Local fee validation: the source proof passed on its first attempt (gate 0).
The model build, ten explicit examples, all 16 full-gate/Stage 1–3 regression
commands, and the updated local incremental controls passed (scenario codes 0).
`python3 scripts/check_stage_4_approval.py` exited 0: approved candidate checked
4 obligations and reused 8; altered spec, C2, approval metadata, and policy each
failed with gate 1. Literal replay exited 0 with identical evidence. These are
local checks; the real approved-spec EXIT is recorded below. See U045.

Final Stage 4 execution: [run 40409284514](https://github.com/mack-dot/forge/actions/runs/40409284514),
job 121875254229, commit `88057d49f9abe6cf3a701c1f388a2377108428e3`.
The three exact EXIT commands above each exited 0. The unapproved-spec case
checked three real rejection PRs, including the new post-approval C2 mutation.
Prior EXIT reports are preserved with `-before-fees` names.

PR 4 / run 40405564741 accepted the exact fee spec with gate 0: baseline 12
checked; candidate 4 checked, 8 reused. Literal replay exited 0 and reproduced
identical evidence. Its new spec SHA is the approved candidate digest above.
PR 5 / run 40405711794 changed C2 after fee approval and was rejected with gate 1,
`UNAPPROVED_PROTECTED_CHANGE`, and no accepted evidence. Both reporting jobs
succeeded. PR 4 merged at `08cae1c59f6c1b40354851b422070a1edb4dc39d`; the merged
tree exactly matched the checked PR tree. See U047 and results/stage4/exit-run.json.

Every Stage 4 EXIT requirement is established for the recorded revisions.
Stage 4 is DONE. Stage 5 is CURRENT; no Stage 5 implementation ran in this turn.

### Stage 5 — SPEC TOOLING

**Status: DONE**

Render every claim in plain English. Generate accept/reject examples. Add a
checked witness of a non-trivial successful execution. Mutate implementations
and report which mutants the spec catches. Use isolated fixtures for deliberately
vacuous specs; do not weaken the approved spec.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_5.py --case vacuity` | Flags a spec that accepts implementations which reject everything. | 0 |
| `python3 scripts/exit_stage_5.py --case mutations` | Lists killed and surviving mutants and the kill rate. | 0 |

Report invalid mutants and inconclusive checks separately from kills. A witness
rules out the demonstrated vacuity; it does not prove that the spec captures all
human intent. A kill rate is a measured diagnostic, not a completeness theorem.

Actual execution records: results/stage5/vacuity.json, mutations.json,
replay.json, and auxiliary.json. The raw log archive index binds 86 actual logs.
Both exact EXIT commands ran with exit 0 after correcting the driver issues
recorded in U048. Earlier failed driver runs remain preserved, with codes 1.
The production gate and approved spec were not changed to resolve those issues.

`python3 scripts/generate_claim_docs.py` exited 0 and generated docs/claims.md
from actual source-proof evidence and 227 model comparisons: 6 Ok, 221 Rejected.
All matched TypeScript; the comparison evidence binds both the candidate bytes
and the reference model. The explicit TypeScript compiler check exited 0.

The successful-execution witness verified with 13 obligations and Dafny exit 0.
An isolated spec with false retry/fresh-valid predicates admitted a reject-all
implementation (Dafny 0). The same successful-execution witness failed there
(Dafny 4), so the vacuity diagnostic flagged it. That fixture was never approved
for production acceptance.

Mutation results: 8 killed, 2 survived, 1 invalid, 1 audit rejected, 0 inconclusive.
Spec-proof kill rate: 8/10 (80.00%). The algebraic rewrite and print-effect
mutants survived. The labeled algebraic control stays in the denominator;
invalid programs and audit rejections do not count as spec-proof kills.
Printed output is outside the current state claims. No general defect-coverage
rate or semantic-equivalence result is inferred.

`python3 scripts/render_spec_report.py` exited 0. After the input-binding fix
in U050, two complete runs of generation, both EXITs, and rendering returned 0.
Five real cmp commands returned 0 for examples.json, source-evidence.json,
spec-quality.json, docs/claims.md, and docs/spec-quality.md. Canonical summaries
exclude raw timing/log data. See U051 for the completion scope.

Every Stage 5 requirement is established for the recorded inputs. Stage 5 is
DONE. Stage 6 is CURRENT; no Stage 6 implementation or benchmark ran in this turn.

### Stage 6 — SECOND DOMAIN + REUSE MEASUREMENT

**Status: DONE**

The user approved [the exact booking proposal](proposals/booking.md) by replying
"go ahead". The [decision record](proposals/booking-decision.md) binds the approved
public revision and spec/lock digests. Those bytes were applied without alteration.

The matcher establishes B1 no double-booking; B2 a fresh valid request gets the
lowest allowed free slot; B3 cancellation frees exactly its target slot; and B4
accepted retries replay their historical result without another state change.
It reuses the checked Ledger.TotalReplace and TotalRemove lemmas for capacity sums.
The [booking gate](gate/booking.py) uses the existing evidence schema and policy
validator, with a new source-proof-only booking policy. Existing ledger inputs
remain unchanged. [Behavior and scope](docs/booking.md).

| EXIT command | Actual behavior | Real exit code |
| --- | --- | --- |
| `python3 scripts/benchmark_reuse.py` | Completed five repetitions of five cases under three conditions: 75 pairs. Every expected acceptance/rejection occurred. | 0 |
| `python3 scripts/exit_stage_6.py --case report` | Recomputed measured totals, checked raw logs and source evidence, and reconciled all available runtime token categories in the stated interval. Generated the scoped report without extrapolation. | 0 |

The [measured report](docs/reuse-benchmark.md), [raw experiment](results/stage6/benchmark.json),
[source evidence](results/stage6/source-evidence.json), and [report EXIT receipt](results/stage6/report-exit-attempt1.json)
retain exact commands, real codes, digests, and limits. The hardware was Apple M1
Pro / MacBookPro18,1, 16 GB, with 10 reported logical CPUs and macOS 27.0.1.
The verifier used one worker, the existing pinned Dafny/Z3 builds, resource limit
1000000 per isolated assertion batch, and verification time limit 0.

| Condition | Pairs | Verifier process seconds, baseline included | Checked members, including rejected candidates | Reused members |
| --- | ---: | ---: | ---: | ---: |
| Cold flattened input | 25 | 269.713 | 1100 | 0 |
| Shared files, fresh checks | 25 | 271.067 | 1100 | 0 |
| Native dependency-graph reuse | 25 | 175.828 | 590 | 510 |

These are observations for this exact corpus and host. Audit, fixture setup,
preparation failures, and development checks are recorded separately. Cached
trace times/resource counts describe earlier work and are excluded from new
solver-work totals. Every warm-up baseline is charged. No productivity or
cross-project benefit is inferred. Fresh timing reruns can produce different
numbers; reproduction of recorded totals is a separate operation.

Additional real checks:

- Booking implementation verification attempts returned 4, 4, and 0. The last
  checked 99 assertion batches across 22 members. Trace attempts returned 4, 4,
  and 0; the last checked 238 batches across 33 members. All failures are retained.
- `python3 scripts/check_stage_6.py` first returned 1 because an audit-scope control
  did not reject at the expected audit step. Verification still rejected the
  forbidden assumption. The new gate was strengthened to audit each concrete
  implementation explicitly. The final control script returned 0.
- Final acceptance and imported-evidence replay returned 0; actual `cmp` returned
  0. Six negative gates returned 1 for artifact mismatch, wrong method, forbidden
  assumption, bodiless lemma, unapproved spec/lock, and changed witness. The two
  proof-escape auditors returned 2. No rejected case wrote accepted evidence.
- A postrun inspection matched all 450 materialized source files to the frozen
  fixture bytes. The accepted source collection has its own canonical manifest.
- A second report EXIT returned 0. Actual `cmp` commands returned 0 for both
  `results/stage6/report.json` and `docs/reuse-benchmark.md`. See [replay](results/stage6/report-replay.json).

The [usage record](results/stage6/accounting.json) includes all six available
runtime categories for 76 responses in its declared interval. Total: 10146635
tokens; input: 10041872, including 9944960 cached; output: 104763, including
53391 reasoning output. Reported cache-write input: 0. Subcategories are not
added again. Per-response sums match cumulative differences. Three human
interventions and three automatic continuations are separate. Shared authoring
is not allocated to the conditions by guess. This interval ends before report
publication; it is not a final project bill. Local transcript events are indexed
by hash; private instructions/reasoning and internal transport bodies are not
published. Earlier proposal resolution and one hardware inspection have no
isolated subprocess timing; neither was a proof run.

The original syntax-only proposal check returned 0 and remains under
[results/stage6/proposal/](results/stage6/proposal/). Preparation run-0001 returned
1 for denied sysctl inventory; run-0002 returned 1 for a report-count error;
run-0003 returned 0 for all 15 preflight pairs. Full run-0004 returned 0.
See append-only `unsure.md` U054–U061 for decisions, failures, and scope.

The PR workflow still reports the ledger claims; booking acceptance uses its
explicit gate command. No new PR-enforcement guarantee is claimed. All evidence
keeps `end_to_end=false`. Stage 7 is CURRENT; no Stage 7 command ran in this turn.

### Stage 7 — BINARY LAYER

**Status: DONE — all three real EXITs passed, including independent checking**

Use a Docker-capable host and Theorem's published Rocq/RISC-V pipeline. Pin an
upstream commit, image digest, semantics, and dependencies. Replay one published
upstream proof, then prove a no-crash property of a small C or Rust core through
that pipeline. Never replace missing upstream support with custom semantics or
a custom decoder. Record exact binary digests, theorem scope, assumptions, and
trusted components. Keep unrelated ledger claims unestablished at the binary layer.

Upstream publishes proofs about particular binaries under its Linux-process
model. These do not automatically cover another architecture or build.
[Published pipeline](https://github.com/theorem-labs/oss-verify-proofs)

The documented `oft check` path audits assumptions. Its independent `rocqchk`
pass is optional and can be expensive. Our EXIT requires that pass for the own
proof; an upstream replay alone is insufficient. “Audit clean” means no
assumptions outside the explicitly recorded upstream allowlist, not an empty
trusted base. [Upstream checking procedure](https://github.com/theorem-labs/oss-verify-proofs/blob/main/docs/checking.md)

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_7.py --case upstream-replay` | The pinned published pipeline, independent `rocqchk`, and assumption audit accept the upstream proof. | 0 — attempt 0003; earlier attempts 0001 and 0002 returned 1 before proof checking |
| `python3 scripts/exit_stage_7.py --case invalid-proof` | The real checker rejects a deliberately invalid proof for the intended reason. | 0 — attempt 0001; prepared proof rejected with 1, valid True certificate compiled with 0, published binding wrapper rejected it with 1 |
| `python3 scripts/exit_stage_7.py --case own-proof` | Own binary proof passes the pipeline, `rocqchk`, and assumption audit. | 0 — attempt 0001; termination and valid-execution witness compiled, both binding wrappers compiled, full independent kernel check returned 0, final identities match |

Record the exact container, upstream, and `rocqchk` commands and all real codes.
Use `binary_proof` and `kernel_checked_proof` only for the scopes actually checked.
If the host, tooling, resource needs, or proof blocks progress, report the exact
blocker. Leave Stage 7 CURRENT and stop. A truthful blocked report is permitted;
it is not a completed stage and does not unlock Stage 8.

Stage 7 setup record (not proof EXITs):

- The first `docker version` attempt returned 1 because the prior session could
  not access the Docker socket. After the user enabled full permissions, the
  real retry returned 0. Client and engine are 28.5.1; Docker Desktop is 4.48.0.
- The published checker image was pulled by digest with exit 0. Its AMD64
  platform manifest is pinned as well. An offline container with one CPU and
  4 GiB of memory ran `rocq --version` with exit 0 (Rocq 9.2, OCaml 4.14.3),
  and `python3 --version` with exit 0 (Python 3.12.3).
- Git fetched upstream commit `bf6a65114ed2e255098e213e183e83f63c2cabcc`
  with exit 0. The selected replay is `zlib/checksum_fuzzer/plain_halts`.
  The initial macOS checkout later failed exact source identity. Linux recovery
  and dependency installation are recorded below; proof replay remains pending.
- Exact commands, raw output, real exit codes, and output digests are in
  [results/stage7/commands](results/stage7/commands). The recorder makes no proof
  verdict. These setup results do not establish binary or deployment coverage.
- The user separated binary evidence from post-foundation abstraction-discovery
  research. The research comparison and first public product priorities are
  documented only in [VISION.md](VISION.md). They add no later-stage work here.

Recovery record:

- Attempt 0001 returned 1 before Rocq ran. The upstream tree has 110 groups of
  names that differ only by case (222 paths). The host checkout could not retain
  distinct bytes for them. Its original full diff remains in the attempt log.
- The first Linux clone also returned 1: `/work/.git: Permission denied`.
  Inspection found an ext4 volume owned by UID/GID 1000 with mode 0755, while
  that clone ran as UID/GID 501:20. The previous `chown` command reported 0, but
  its intended ownership was not present on the next mount. No cause for that
  ownership reset is asserted without a separate test.
- Recovery uses the image's existing non-root `opam` user, UID/GID 1000:1000.
  The clone and exact checkout each returned 0. No global Docker setting,
  privileged container, or broad host permission change was needed.
- In attempt 0002, real Git identity commands returned 0. All 149,053 tracked
  files (8,606,911,568 bytes) matched their upstream Git blobs. All 222 case
  paths have distinct inodes. The selected ELF matched SHA-256
  `4f04e95082d3e0baa9d55c72288945d99e64bb7503e39c0e644f4b38a7781af2`.
  The installed compiler/checker and package inventory are retained.
- Attempt 0002 returned 1 because the new recording wrapper incorrectly treated
  the upstream shell launcher as Python. Rocq proof checking did not run. The
  wrapper now invokes the same `oft` module, root, and environment as that
  launcher. It observes actual subprocess return codes without replacing any
  checker function or changing a verdict. The previous runner is archived.
- The user's recovery instruction requires independent checking for the
  upstream replay too. The real invocation now includes `--rocqchk`; success
  requires both independent passes and the upstream assumption audit. Attempts
  and command records remain separate from canonical accepted evidence.
- In attempt 0003, the statement build and its independent `rocqchk` pass
  returned 0. The proof library build, target proof compilation, and generated
  binding-wrapper compilation also returned 0. The wrapper audit reports 15
  allowed assumptions. At that checkpoint, the final independent proof check
  was still running. The completed result is recorded below.
- The image's 201 LPS source files match the source-tree hash in the pinned
  upstream Dockerfile. The actual source-hash check returned 0. Tool executable
  hashes and the wrapper's exact assumption names are retained in command
  records. These identity and intermediate checks do not complete Stage 7.

Completed upstream replay:

- Attempt 0003's complete EXIT returned 0. Both independent `rocqchk` calls
  returned 0. The full proof closure audit reports 86 allowed assumptions,
  no type-in-type dependencies, no unsafe fixpoints, and no assumed positivity.
- The target proof and its generated binding wrapper each compiled with exit
  0. Its theorem-specific audit lists 15 allowed assumptions. These differ
  from the 86 assumptions in the complete imported dependency closure.
- The selected proof library has 407 source modules. Its Dune log records
  407 actual module compilations. The first independent pass checked 469
  modules; the final independent pass checked 997, including all 407 library
  modules. Compiled-module counts are not independent-check counts.
- Both complete source-identity commands returned 0. Before and after hashes
  match for every tracked source file and the selected binary. The full raw
  commands, output, audits, and input manifests remain under
  `results/stage7/upstream-replay/attempt-0003/`.
- The negative-control runner now tests the prepared invalid proof and a valid
  True certificate against the unchanged upstream binding-wrapper template.
  Its complete EXIT returned 0 on attempt 0001. Both intended rejections were
  proof type mismatches, not infrastructure failures. Pre/post source and ELF
  identity checks returned 0 and their digests match.
- The next task is an own compiled C arithmetic self-test, with its exact ELF
  checked under the published LPS semantics. No own-binary proof or EXIT has
  run. The published compiler image was fetched by digest with exit 0.
- All earlier failed attempts remain unchanged. The public operational-record
  archive preserves the large input manifests and raw logs as standard tar/xz.
  This is an intermediate publication, not completion of Stage 7.

Completed own-binary proof:

- `python3 scripts/stage7_build_own.py` returned 0. Two actual clang 20.1.8
  compilations returned 0 and produced identical 1,240-byte RISC-V ELFs:
  `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
- `python3 scripts/exit_stage_7.py --case own-proof` returned 0 on attempt 0001.
  Its nine fresh Rocq compilation commands returned 0. These cover seven
  source modules (including the generated image) and two binding wrappers.
  The existing core Dune build returned 0 with no module compilation logged.
- The exact statement is `halts_may_fail [verdict_accept] Images.program`.
  For every valid modeled input and entry, every execution terminates normally
  with status 0. It has no memory-budget refusal exemption. The arithmetic pair
  is fixed in this ELF; no claim covers arbitrary GCD arguments.
- The separate `selftest_has_valid_execution` theorem proves that a valid input
  and entry exist and satisfy that same termination property. Image validity,
  the witness, and the universal theorem are all independently checked.
- The unchanged published wrapper template bound both proofs to their required
  propositions. Both theorem audits list 13 permitted primitive assumptions.
  Real `rocqchk -o -bytecode-compiler no` returned 0 over all 579 dependency
  modules. The official closure audit lists 86 permitted assumptions, with no
  type-in-type, unsafe fixpoints, or assumed positivity. No allowlist changed.
- Both full upstream source identity commands returned 0. Their manifest
  digests match. The own ELF, C source, proof sources, and generated image inputs
  retain their initial hashes. A separate post-check manifest hashes all 579
  compiled dependency files; it is not another kernel execution.
- Exact commands, raw output, versions, digests, and audits remain under
  `results/stage7/own-proof/attempt-0001/` and `results/stage7/commands/`.
  Canonical evidence, the complete assumption list, and the exact ELF are in
  `results/stage7/accepted/own/`. The full records are archived for publication.
- `python3 scripts/stage7_emit_evidence.py --attempt results/stage7/own-proof/attempt-0001 --output results/stage7/accepted/own` returned 0.
  Repeating with `--output build/stage7/serialization-repeat` returned 0.
  `diff -r results/stage7/accepted/own build/stage7/serialization-repeat` returned
  0. This checks serialization, not a second proof replay.
- `python3 gate/gate.py --schema-only results/stage7/accepted/own/evidence.json`
  returned 0. Structural validation is separate from the actual proof checks.
- Previous failures are preserved. No protected contract, checker semantics,
  or acceptance policy changed. Model fidelity, ELF loading/data import,
  kernel primitives, image provenance, host runtime, and hardware remain trusted.
  Compiler correctness, deployment identity, and whole-service correctness
  remain unproved. `end_to_end=false`.
- Stage 7 is DONE; Stage 8 is CURRENT. Per the latest user instruction, stop
  after recording and publishing this transition. Performance experiments and
  proof-construction research remain deferred. See append-only U068–U069.

### Stage 8 — ML BOUNDARY

**Status: DONE**

Wrap an LLM-backed refund suggester in verified code. Enforce refund ≤ charge,
allowed reasons, and a safe fallback for timeout or invalid output. Treat model
responses as untrusted inputs. Define the charge and refund numeric domains in
the approved spec, including lower bounds. Keep effects behind the checked
boundary and name the assumptions of the external timeout mechanism.

Model quality is `eval_measured`. Wrapper properties use the method actually
checked. Tests of hostile responses supply additional testing evidence.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_8.py --case wrapper-proof` | The established verifier accepts the wrapper bounds and allowed outcomes. | 0 — final attempt 4 |
| `python3 scripts/exit_stage_8.py --case hostile-outputs` | Fuzzed malicious outputs never violate bounds in the executed test corpus. | 0 — final attempt 3 |
| `python3 scripts/exit_stage_8.py --case evidence-separation` | Evidence distinguishes proved wrapper properties, fuzz testing, and measured model quality. | 0 — final attempt 2 |

Record fuzz seeds, counts, and limits. Do not turn “no violations observed” into
a universal proof. Keep application timeout behavior distinct from proof-run
resource limits.

Historical Stage 8 contract preparation (not EXIT results; resolved below):

- The user requires universal safety **and** exact acceptance of every valid
  proposal. Fallback must preserve the absence of refund side effects.
- [proposals/refund.md](proposals/refund.md) contains the complete proposed diff
  and explicit business choices. Four new protected files are proposed: the
  Dafny contract, wire/lifecycle protocol, spec lock, and separate refund policy.
  None has been applied. No implementation or refund gate has been written.
- The proposed Assess method has no validity precondition. It must handle all
  modeled contexts and responses, reject ineligible inputs with an empty plan,
  and accept every eligible candidate with its exact amount/reason. A future
  arbitrary-input binding and successful witness must prevent vacuous acceptance.
- The current gates bind ledger and booking domains. Exact approval of this
  contract does not authorize an unspecified future protected gate patch.
  Such a patch must also be reviewed before application.
- `.toolchain/dafny-4.11.0/dafny/dafny --version` returned 0 and matched the pin.
  `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/refund/RefundSpec.dfy`
  returned 0 and printed `Dafny program verifier did not attempt verification`.
  This is proposal resolution only, not source proof or a Stage 8 EXIT.
- `git apply --check proposals/refund/protected.diff` returned 0 without
  applying the patch. The proposed policy passed structural validation with
  pinned jsonschema 4.21.1 (Python process exit 0). This is not policy acceptance.
- Records are in `results/stage8/proposal/`. There are no formal guarantees,
  executed fuzz cases, model-quality scores, or Stage 8 passing EXITs yet.
  All three EXIT commands remain NOT RUN. See append-only U070.
- Stop for exact human contract approval. Stage 8 remains CURRENT;
  `end_to_end=false`. No Stage 9 work has started.

Historical Stage 8 contract adoption and gate preparation (not EXIT results):

- The user approved exactly the four additions at published revision
  `e3aa546f86dc5b43ec8c754792e3db4cb413b410`, bound to its manifest and digests.
  The approval excludes real refunds and unspecified gate changes. See
  [proposals/refund-decision.md](proposals/refund-decision.md).
- The published Git tree, candidate blob identities, manifest and patch hashes
  matched. All four target paths were absent. Their exact approved bytes are
  now installed. All existing protected files remain unchanged. Identity
  records: [contract adoption](results/stage8/contract-adoption/identity.json).
- `impl/Refund.dfy` implements the approved pure boundary. The direct checks
  below used the real pinned toolchain. The proposed binding covers arbitrary
  inputs with no preconditions and includes an eligible successful witness.
  These results do not complete the protected gate or any Stage 8 EXIT.
- [proposals/refund-gate.md](proposals/refund-gate.md) proposes exactly three
  gate additions, with their complete diff and digest manifest. None is applied.
  They preserve fresh full verification, empty audits, source identities,
  resource limits, and distinct source-proof and property-test methods.

| Development/review command | Actual exit code | Actual result |
| --- | --- | --- |
| `.toolchain/dafny-4.11.0/dafny/dafny --version` | 0 | Expected pinned build. |
| `.toolchain/dafny-4.11.0/dafny/dafny verify impl/Refund.dfy proposals/refund-gate/Bindings.dfy` plus pinned options and TRX output | 0 | All six required source, contract, universal-binding and witness obligations passed. |
| `.toolchain/dafny-4.11.0/dafny/dafny audit impl/Refund.dfy proposals/refund-gate/Bindings.dfy` with empty-report comparison | 0 | Zero reported findings. |
| `.toolchain/dafny-4.11.0/dafny/dafny build impl/Refund.dfy --target js --output build/refund-proposal/model` plus pinned options | 0 | Real generated JavaScript; four source obligations verified during build. |
| `node node_modules/typescript/bin/tsc` on the proposed hostile suite, with strict no-emit options | 2, then 0 | TS2769 tuple-type error retained; corrected type declaration passed. No hostile cases executed. |
| `git apply --check proposals/refund-gate/protected.diff` | 0 | Complete three-addition patch is applicable; not applied. |

Exact argv, input digests, before/after identities, complete outputs, TRX, generated
JavaScript, and the failed static-check source snapshot are retained in
[results/stage8/gate-proposal](results/stage8/gate-proposal/). The Python candidate
parsed successfully with the standard AST parser. Python, validator packages,
Node and installed package content matched their existing pins.

The new protected gate has not executed. The runtime adapter and EXIT harness
remain unimplemented. Negative controls, hostile cases, canonical accepted
evidence reproduction, and model evaluation have not run. The planned 9,000
generated cases are not actual coverage. Model quality is unmeasured. All three
EXIT commands above remain NOT RUN. No Stage 8 accepted bundle is published.

Stop for separate exact approval of the three proposed gate additions, as the
latest user instruction requires. See append-only U071. Stage 8 remains CURRENT;
`end_to_end=false`. Stage 9 has not started.

Historical Stage 8 approved gate execution and frozen-scope blocker:

- The user approved exactly `gate/refund.py`, `gate/refund/Bindings.dfy`, and
  `gate/refund/hostile.ts` at `d2d557e2dcd564049fbd97171b0af67659eacf81`.
  The published candidates, manifest, patch and target digests matched. The
  three files were adopted byte for byte. See
  [the decision](proposals/refund-gate-decision.md) and
  [adoption identities](results/stage8/gate-adoption/identity.json).
- `ts/refund.ts` implements the declared parser/host interface. The unprotected
  EXIT harness and supplemental integration tests are implemented. The strict
  TypeScript check returned 0. No approved contract, policy or gate was edited.
- Wrapper attempt 1 returned 1 after the actual proof and all three real
  rejections. The reporting harness did not read the auditor's `.expect`
  sidecar. Correcting that unprotected file selection allowed full attempt 2
  to return 0. Both attempts, source snapshots and complete logs remain.
- The successful wrapper EXIT checked all six required source, abstract-contract,
  universal-binding and witness obligations. Over-limit authorization failed
  actual verification with 4 at R1; reject-all failed with 4 at R4. The actual
  assumption audit rejected the escape with 2. Each negative gate returned 1.
- The hostile EXIT returned 1. Its 68 fixtures and 3,000 T1 generated cases
  passed first. T2 seed 8001 failed after two cases and six shrinks: fast-check
  generated a null-prototype record, while `structuredClone` normalized the
  snapshot's prototype. Strict equality then rejected an unchanged input.
  The compiled wrapper's expected-value assertion passed before that failure.
- The evidence-separation EXIT returned 1 at the same T2 assertion. Its two
  fresh source runs reproduced byte for byte. Those bytes also match the
  successful wrapper EXIT, for three separate fresh accepted source runs.
  Evidence SHA-256: `acafe3f90623314d4389604ffbc8d99c880091ea8a28f805b255ae1a60c753fe`.
- Supplemental tests returned 0 for 23 fixtures and 500 generated cases, seeds
  8004 and 8005. They cover stale delivery, caller/result mutation, concurrent
  terminal calls, executor reentry/failure, numeric and byte boundaries, and
  malformed/truncated bytes. These finite checks are not a Stage 8 EXIT pass.
- A minimal prototype-preserving snapshot repair was evaluated directly from
  `proposals/`, before the final freeze, and returned 0 for 9,000 generated cases
  and 68 fixtures. It was never substituted into the approved gate. It supplies
  no accepted integration bundle. Its exact diagnostic diff is in
  [proposals/refund-hostile-snapshot.md](proposals/refund-hostile-snapshot.md).
- The final user instruction freezes scope and forbids changes to approved gate
  files. The repair remains unapplied. Effect-bypass, duplicate-dispatch,
  fabricated/mislabeled-evidence and spec-tamper controls have not been reached
  by the EXIT harness. Integration evidence reproduction remains unfinished.
  No Stage 8 completion or passing eval_measured record is claimed.

The [status record](results/stage8/status.json) links every actual EXIT attempt,
code, input identity and archived operation. The [boundary report](docs/stage8-refund.md)
states proof scope, finite test counts, toolchain assumptions and reproduction
commands. See append-only U072. Stage 8 remains CURRENT — blocked;
Stage 9 remains NOT STARTED; `end_to_end=false`.

Stage 8 exact repair, final EXITs and completion:

- The user approved only the exact prototype-preserving snapshot replacement
  at `76f58de25fb5ebe305831432907e42a4210add40`. The published identities matched.
  Both `git apply --check proposals/refund-hostile-snapshot/protected.diff`
  and `git apply proposals/refund-hostile-snapshot/protected.diff` returned 0.
  Applied `gate/refund/hostile.ts` SHA-256 is
  `0e15d543f42c32b0b6c2b7aab7eb66962dc7c1facde380c44f00a8710a9c475a`.
  No other protected file changed. See
  [the exact decision](proposals/refund-hostile-snapshot-decision.md).
- The added unprotected assertion controls execute the exact approved T2
  callback with the real compiled wrapper. Four unchanged ordinary/null-prototype
  combinations passed. Sixteen genuine field/prototype mutations were rejected
  by the snapshot assertion. No replacement assertion or proof checker is used.
- Their first static check returned 2 for object-type narrowing; its correction
  returned 0. Hostile attempt 2 then returned 1 for an omitted extracted helper.
  Both errors and original source snapshots remain. Only that unprotected
  extraction was corrected; hostile attempt 3 returned 0.
- Final real EXIT attempts: wrapper 4 = 0, hostile 3 = 0, evidence separation
  2 = 0. Their complete declared inputs match the current sources and their
  before/after identities. Full exit history remains: wrapper `[1, 0, 0, 0]`,
  hostile `[1, 1, 0]`, evidence separation `[1, 0]`.
- All six required source/binding/witness obligations and both empty audits
  passed. Over-limit and reject-all controls failed actual verification with
  4 at R1/R4. The assumption escape failed the actual audit with 2. Each
  negative gate returned 1 for the intended reason.
- The accepted hostile suite executed 9,000 generated cases and 68 fixtures
  with the approved seeds/counts. Supplemental tests passed 500 generated
  cases and 23 fixtures. The assertion controls accepted 4 stable inputs and
  rejected 16 mutations. Effect-bypass and duplicate-dispatch each failed
  the real test process with 1 for an assertion reason; each gate returned 1.
- Mislabeled property_tested/eval_measured evidence, wrong artifact identity,
  invented passing-case count and changed spec identity each returned gate 1
  for the required reason. Invented-count rejection followed fresh real checks.
- Both accepted evidence files match three separate fresh gate runs byte for
  byte, with matching proved-source links. Source evidence SHA-256:
  `be32ef9e27fee402aefd9fab6de9cc66ceb03d1d68101d6b238364756ebd8c86`.
  Property evidence SHA-256:
  `77d94ab0c41ea5c887924515f0921f6c0362c32d427b3f11d7afc79f21cbe0dd`.
  Generated module SHA-256:
  `d462e12309766d5b055715500daab5c238e9c9d06236b47577d43941c22b4dda`.
- All 373 earlier Stage 8 record files matched their preserved hashes. The
  original blocked status, failed attempts, seeds, shrinks, raw output and
  approval proposals remain unchanged. Model quality is unmeasured; no
  passing eval_measured record or real payment execution is claimed.

The [completion record](results/stage8/completed/completion.json) binds all
final EXIT commands/codes, source identities, controls and canonical artifacts.
The [boundary report](docs/stage8-refund.md) states the universal source
guarantees and the finite test, compiler, parser, clock, payment and deployment
limits. See append-only U073. Stage 8 is DONE; Stage 9 is CURRENT. Publish and
verify this checkpoint, then stop. No Stage 9 implementation has started.
`end_to_end=false`.

### Stage 9 — PROVENANCE

**Status: DONE — all six official EXITs passed under one request and one lock (v3.6, 2026-10-29; U169)**

Sign evidence bundles using pinned sigstore/in-toto tooling. Before allowing a
deployment, verify the signer identity, artifact digest, and policy version.
Bind container packaging to the checked binary and verify deployed identity when
reporting deployment coverage. Keep canonical evidence separate from signature
envelopes and external transparency records, which may contain time metadata.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case valid-bundle` | A valid signed bundle for the intended artifact and policy passes the release check. | 0 (passed, attempt 0001, lock `5f78da21`, request `8a6ba7f4`, 2026-10-29T23:01Z). Earlier v3.5 run: 0 (U164). |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case unsigned` | An unsigned bundle is rejected. | 0 (passed, attempt 0001, same lock and request). Earlier v3.5 run: 0. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case wrong-signer` | A bundle from an unauthorized signer is rejected. | 0 (passed, attempt 0001, same lock and request). Earlier v3.5 run: 0. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case wrong-digest` | A valid signature over the wrong artifact digest is rejected. | 0 (passed, attempt 0001, same lock and request). Earlier v3.5 run: 0. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case wrong-policy` | A bundle for an unaccepted policy version is rejected. | 0 (passed, attempt 0001, same lock and request). Earlier v3.5 run: 0. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case deployed-identity` | Actual deployed digest matches the accepted release; a mismatch is reported and prevents a coverage claim. | 0 (passed, attempt 0001, same lock and request, run last, 2026-10-29T23:04Z). Earlier v3.5 run: 1 (`not_established`, `Permission denied` on `/opt/forge`, U164). |

`$LOCK` is the installed implementation lock. The harness refuses any other launch
(U131); run the inline lock/bootstrap byte check first.

Run the established signature verifier for the actual accept/reject decision.
Signing an unsupported claim does not make it established.

#### Initial trust proposal preparation (historical)

The published Stage 8 base is `80a65d46b1dbc8f3ccfd249bfd628568406c5774`.
[proposals/provenance.md](proposals/provenance.md) contains the exact proposed
contract, policy and identity-lock additions, complete patch and file digests.
No protected changes have been applied. The user requires exact approval before
changing this trust boundary. The proposal names one GitHub Actions signer,
pinned Cosign 3.1.4, Sigstore public TUF trust, both existing binary claims,
fresh full kernel replay, strict evidence methods, request freshness and actual
container filesystem observation. Its deployment claim is file identity at
observation time; it does not claim RISC-V execution or deployment correctness.
An exact release-gate/workflow implementation requires separate approval.

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 proposals/provenance/check_proposal.py` | 0 | Proposal integrity only: three unapplied additions, 47 locked existing files, unchanged complete module/assumption lists. |
| `git apply --check /Users/mackianni/forge/proposals/provenance/protected.diff` | 0 | Patch applicability only; no application. |

These are not Stage 9 EXIT results. All six required EXIT commands remain NOT
RUN. Cosign was not installed or executed. No signature or deployment was made.
Preparation logs and identity snapshots are under `results/stage9/preparation/`.
All 30 existing protected files and all old Stage 7–8 records remain unchanged.
See U074. `end_to_end=false`.

#### Approved contract adoption and implementation proposal (historical)

The user approved only the three contract additions at
`097431cf458e5c62332575b09e953224471fa64d`. The public manifest, patch and candidate
bytes matched. The exact patch was applied. The new contract, policy and lock
match their approved SHA-256 digests. All 1,360 snapshotted prior files remain
unchanged at adoption. [proposals/provenance-decision.md](proposals/provenance-decision.md)
records the approval; `results/stage9/contract-adoption/` preserves commands and
identity checks. This did not authorize a gate, workflow, signing or deployment.

[proposals/provenance-implementation.md](proposals/provenance-implementation.md)
contains 11 exact, unapplied additions: eight protected implementation files,
two manual workflows and the six-case EXIT harness. Its lock binds 60 files
and 45 upstream Python dependency files. Actual signature/proof/deployment
execution remains untested and unapproved. A dedicated pinned runner is an
explicit, unprovisioned prerequisite; no runner registration was performed.

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git apply --check /Users/mackianni/forge/proposals/provenance/protected.diff` | 0 | Approved contract patch dry-run. |
| `git apply /Users/mackianni/forge/proposals/provenance/protected.diff` | 0 | Applied only the three approved additions. |
| `python3 --version` | 0 | Observed Python 3.10.11. |
| `docker version --format '{{json .}}'` | 0 | Read-only runtime inventory. |
| `docker buildx version` | 0 | Read-only Buildx inventory. |
| `docker buildx inspect default --format '{{json .}}'` | 125 | Unsupported flag; original complete output preserved. |
| `docker buildx inspect` | 0 | Supported read-only retry; Docker driver, desktop-linux, BuildKit 0.25.1. |
| `python3 proposals/check_provenance_implementation.py` | 0 | Proposal hashes, syntax and workflow structure only. |
| `git apply --check /Users/mackianni/forge/proposals/provenance-implementation/proposed.diff` | 0 | Implementation proposal applicability only; patch not applied. |

All six Stage 9 EXITs remain NOT RUN. The preparation checks do not verify a
signature or establish a proof. No Cosign installation, new proof execution,
container build/start, workflow activation or signing occurred. Every failure
remains preserved in `results/stage9/implementation-preparation/`. Stop for the
next exact approval; do not change the approved contract to fit the proposed
implementation. See U075. `end_to_end=false`.

#### Approved implementation adoption and safe preparation

The user approved only the exact 11 additions at
`06b40caa6bf5fb6963756b39646413559f84c61d`, bound to the published manifest,
patch and individual file hashes. Those bytes are applied unchanged. The
approval explicitly excludes workflow dispatch, public Sigstore signing,
runner registration and deployment execution. See the
[approval record](proposals/provenance-implementation-decision.md).

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git apply --check /Users/mackianni/forge/proposals/provenance-implementation/proposed.diff` | 0 | Approved 11-file patch dry-run. |
| `git apply /Users/mackianni/forge/proposals/provenance-implementation/proposed.diff` | 0 | Applied exactly the 11 approved additions. |
| `python3 scripts/check_stage9_installation.py` | 0 | Exact installed bytes, syntax, manual workflow structure, 60 locked files and 45 Python dependency files. |
| `python3 scripts/audit_stage9_receipts.py --output results/stage9/implementation-adoption/receipt-audit-0001 --work build/stage9-receipt-audit-0001` | 1 | Local real receipt-validator audit; three unexpected non-rejections. No proof, signature or deployment. |
| `python3 results/stage9/implementation-adoption/preservation-check/check.py` | 0 | All 33 prior protected files unchanged; all 11 additions exact; append-only uncertainty history and historical audit inputs preserved; public archive contains the exact raw kernel log. |

The validator accepted invalid dependency hashes and a copied ELF that was
substituted or missing when the receipt manifest matched those inputs. It
rejected a nonce mismatch with `STALE_PROOF_RECEIPT` and a file changed after
manifest creation with `PROOF_RECEIPT_BYTES`. These are helper-level findings;
they are not signed release admissions or newly executed kernel results.
Historical logs were deliberately reused as untrusted negative fixtures.
No fixture is accepted evidence. All commands, raw logs, identities, generated
fixtures and the failing audit remain in `results/stage9/implementation-adoption/`.

The [signing audit](docs/stage9-signing-preparation-audit.md) records the existing
checks, missing byte bindings and trust limits. Freshness depends on the trusted
producer job and GitHub artifact handoff; matching metadata cannot establish it
alone. The [runner plan](proposals/stage9-runner-provisioning.md) covers isolation,
credentials, exact pins, resource allocation, admission and teardown. Read-only
metadata confirms a public, user-owned repository. No enforced workflow
allowlist has been established; a runner label is insufficient.

All 1,446 snapshotted prior files were unchanged at adoption. The original
failures remain intact. No protected bytes were adjusted after application.
The final preservation check found only ROADMAP.md and the append-only unsure.md
changed among those prior files; the other 1,444 retain their original hashes.
All six EXITs remain NOT RUN. No runner registration, workflow dispatch,
Cosign execution, container build/start or fresh proof execution occurred.
Stop at the required approval boundary. See U077. `end_to_end=false`.

#### Integrity repair preparation (unapplied)

A four-file repair for the three audit gaps waits for exact-byte approval. See
the [repair proposal](proposals/provenance-integrity-repair.md). No protected
file is changed.

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 proposals/provenance-integrity-repair/fetch_base_identity.py --output results/stage9/integrity-repair-preparation/base-identity-0001` | 0 | Read-only registry fetch; base config and 55 diff_ids verified by content digest. |
| `python3 proposals/provenance-integrity-repair/build_identities.py --reference-work build/stage9-receipt-reference-0002 --base-identity results/stage9/integrity-repair-preparation/base-identity-0001 --output proposals/provenance-integrity-repair/artifact-identities.json --report results/stage9/integrity-repair-preparation/identities-0001.json` | 0 | Approved identities cross-checked against the Stage 7 record. |
| `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0001 --work build/stage9-integrity-tests-0001` | 1 | Harness defect in one package mutation; kept. |
| `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0002 --work build/stage9-integrity-tests-0002` | 0 | All negatives rejected; installed validator accepted 17 of 31 receipt negatives. |
| `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0003 --work build/stage9-integrity-tests-0003` | 0 | Rerun on unchanged candidate bytes; no unexpected cases. |
| `python3 proposals/provenance-integrity-repair/build_approval.py --output results/stage9/integrity-repair-preparation/approval-0001 --scratch build/stage9-integrity-apply-0001` | 0 | Lock, diff, manifest; `git apply` checked only in a scratch copy. |

Execution blockers: the runner image store (containerd versus classic), the
untested `docker image save` layout, runner admission and execution
authorization. All six EXITs remain NOT RUN. See U078. `end_to_end=false`.

#### Approved integrity repair adoption

The user approved the four exact files and the diff hash `df0bd7fb…`. The
approval excludes runner registration, dispatch, signing and deployment.

| Adoption command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git apply --check --verbose results/stage9/integrity-repair-preparation/approval-0001/proposed.diff` | 0 | Dry run of the approved patch. |
| `git apply results/stage9/integrity-repair-preparation/approval-0001/proposed.diff` | 0 | Applied the four approved files; hashes match. |
| `common.context('9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76')` | 0 | New lock binds 61 files. |
| `common.context('6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa')` | 1 | Old lock rejected: `UNAPPROVED_IMPLEMENTATION`. |
| `python3 -m py_compile gate/provenance/release.py gate/provenance/producer.py` | 0 | Syntax only. |
| `python3 scripts/check_stage9_installation.py` | 1 | Historical check for the earlier 11-file approval; replaced bytes no longer match it. Unchanged. |

Records are in `results/stage9/integrity-repair-adoption/`. All six EXITs
remain NOT RUN. See U079. `end_to_end=false`.

| Post-adoption command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 proposals/provenance-integrity-repair/derive_installed_test.py` | 0 | Derives `test_installed.py` from the unchanged suite by counted replacements. |
| `python3 proposals/provenance-integrity-repair/test_installed.py --output results/stage9/integrity-repair-adoption/installed-tests-0001 --work build/stage9-integrity-installed-tests-0001` | 0 | Installed gate rejected all negatives; pre-repair baseline accepted 17 of 31 receipt negatives. No kernel, Docker, Cosign or deployment. |

See U080. `end_to_end=false`.

#### Image-store observation (Docker running)

| Observation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `docker info --format '{{json .DriverStatus}} driver={{.Driver}}'` | 0 | `io.containerd.snapshotter.v1`: containerd image store. |
| `docker version --format '{{.Server.Platform.Name}}'`; `docker buildx version`; `docker buildx inspect desktop-linux` | 0 | Matches the pinned Desktop 4.48.0, buildx and BuildKit v0.25.1. |
| `python3 -I results/stage9/image-store-observation/observe.py --image redis:7-alpine --output results/stage9/image-store-observation/redis-7-alpine-0001` | 0 | Streamed save; Config path is not `blobs/sha256/<Id>`. |
| `python3 -I results/stage9/image-store-observation/observe.py --image ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a… --output results/stage9/image-store-observation/checker-base-0001` | 0 | Config blob equals approved `base_config` `e49a3a57…`; not equal to `Id`. |

Gzip layers, blob paths and diff_id binding match the gate. Under this store
the package step fails closed. No build, container start, kernel, Cosign,
workflow or deployment ran. See U081. `end_to_end=false`.

The user chose the classic image store for the runner and switched the local
Docker Desktop setting.

| Observation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `docker info --format '{{json .DriverStatus}} driver={{.Driver}}'` | 0 | `overlay2`; no containerd snapshotter. |
| `docker pull --platform linux/amd64 ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a…` | 0 | Pinned base pulled into the classic store. |
| `python3 -I results/stage9/image-store-observation/observe.py --image ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a… --output results/stage9/image-store-observation/checker-base-classic-0001` | 0 | `Id` = Config = approved `base_config` `e49a3a57…`; 55 uncompressed layers match diff_ids. |

The runner plan now requires the classic store. No build, container start,
kernel, Cosign, workflow or deployment ran. See U082. `end_to_end=false`.

#### Local package-step observation (classic store)

The user authorized a local package build. These runs call only the installed
`producer.package()` under the approved lock. They are not EXIT results.

| Observation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 results/stage9/package-build-observation/run_package.py --implementation-sha256 9b10a237… --output results/stage9/package-build-observation/package-0001` | 0 | Lock, runtime pins, base, build, save, config identity, added layer and extracted ELF accepted; config `f15f5bd4…`. |
| Same command with `--output …/package-0002` | 0 | `result.json`, `package.json` and `package-identity/` byte-identical to 0001 (BuildKit cache may apply). |

One container was created per run and not started. Read-only GitHub checks
found that `main` still has the pre-repair gate (lock `6b43c193…`). No runner
was registered. No dispatch, signing or deployment ran. See U083.
`end_to_end=false`.

#### Repository visibility change (user decision)

The user chose a private repository for runner admission ("go private for now").

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh api -X PATCH repos/mack-dot/forge -f visibility=private` | 0 | `visibility=private`; `id` and `owner.id` unchanged. |
| `curl … https://api.github.com/repos/mack-dot/forge` (no token) | 0 | HTTP 404. |

The installed gate fetches GitHub data without a token, so it now fails closed.
An unapplied amendment is in
[proposals/stage9-runner-admission.md](proposals/stage9-runner-admission.md)
(sha256 `dfdca5d5…`). Records: `results/stage9/visibility-change-0001/`. See U084.
`end_to_end=false`.

#### Platform decision: public repository and GitHub-hosted Linux runners

U085 withdrew option A: the verifier must not use the producer's token. The
user then chose a public repository and GitHub-hosted `ubuntu-24.04` producer
runners. The contract and policy contain no macOS or self-hosted requirement,
so the change is implementation-level. See
[proposals/stage9-hosted-runner.md](proposals/stage9-hosted-runner.md).

| Command | Actual exit code | Scope |
| --- | --- | --- |
| `gh api -X PATCH repos/mack-dot/forge -f visibility=public` | NOT RUN | Denied by the Claude Code permission check; the repository is still private. |
| `python3 -c "import yaml; yaml.safe_load(open('proposals/stage9-hosted-runner/probe.yml'))"` | 0 | Probe YAML syntax only; not pushed or dispatched. |

No protected file changed. See U086. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh api -X PATCH repos/mack-dot/forge -f visibility=public` (run by the user) | 0 | Public; `id` and `owner.id` unchanged; unauthenticated API read returns 200. |
| `gh api -X PUT repos/mack-dot/forge/contents/.github/workflows/stage9-hosted-probe.yml …` | 0 | Commit `ac6dfe51…` on `main`; blob `4470a811…` equals the local probe. |
| `gh workflow run stage9-hosted-probe.yml -R mack-dot/forge --ref main` | 0 | Run 40713187818. |
| `gh run watch 40713187818 -R mack-dot/forge --exit-status` | 0 | Conclusion `success`. |
| `gh run download 40713187818 -R mack-dot/forge -D results/stage9/hosted-probe-0001/artifact` | 0 | Probe records. |

Probe result: ubuntu-24.04 image `20261026.354.1`, 4 CPUs, 16.7 GB RAM,
91.9 GB free disk. Docker Engine 28.0.4 with the classic store (`overlay2`).
The pinned checker pull took 72 s and used 3.9 GB of disk. Its `Id` equals the
approved `base_config` `e49a3a57…`. No proof, signing or deployment ran. See
U087. `end_to_end=false`.

#### Checkpoint publication to `main`

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … status --porcelain` (scratch clone of `main`, work tree = local root) | 0 | No path on `main` is missing locally; two ELF entries differ only in file mode. |
| `git … -c core.fileMode=false add -A`; `commit`; `push origin HEAD:main` | 0 | Commit `70d46565…`: the four approved repair files, ROADMAP, unsure.md and 2,698 new record files (4.6 MB; no token or key patterns). |
| `common.repository_identity(policy, implementation, '70d46565…', records)` under lock `9b10a237…` | 0 | All 61 locked files on `main` match; records in `results/stage9/publication-check-0001/`. |

`main` now carries the approved repaired gate. See U088. `end_to_end=false`.

#### Hosted-runner probe 2 (measurement only)

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `d722ecef…`: probe 2 workflow and `replay_probe.py`. |
| `gh workflow run stage9-hosted-probe-2.yml -R mack-dot/forge --ref main` | 0 | Run 40715761881. |
| `gh run watch 40715761881 -R mack-dot/forge --exit-status` | 1 | docker-pin job success (exact Engine 28.5.1 install); replay job failed at the volume clone (`dubious ownership`). |

The 45 Python dependency files matched the lock. No proof ran. See U089.
`end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `21851412…`: chown of the seed `.git` to 1000:1000. |
| `gh workflow run stage9-hosted-probe-2.yml -R mack-dot/forge --ref main` | 0 | Run 40717015652. |
| `gh run watch 40717015652 -R mack-dot/forge --exit-status` | 0 | Both jobs succeeded in 20.3 min. |
| `python3 proposals/stage9-hosted-runner/replay_probe.py --implementation-sha256 9b10a237… --output probe2/replay` (in the run) | 0 | Fresh proof 793 s; no OOM; receipt (656 files, 579 closure objects) accepted by the installed `validate_receipt()`. |
| `python3 $ST/scripts/stage7_build_own.py` (in the run) | 0 | Own ELF rebuilt byte-identical, `8ced2ab6…`. |

This is measurement with a synthetic request, not an EXIT result. No signing ran.
See U090. `end_to_end=false`.

#### Repository transfer (user action)

The user transferred the repository to the `superpowermentors-1` organization.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh api repos/mack-dot/forge` (redirect) | 0 | `superpowermentors-1/forge`, id 1434789853 unchanged, owner id 235148649, public. |
| `gh api repos/superpowermentors-1/forge/collaborators` | 0 | Three admins: mack-dot, sam-spm, superpowermentorss. |
| `gh api orgs/superpowermentors-1/actions/permissions` | 1 | HTTP 403; token lacks `admin:org`. |

The installed policy still names `mack-dot/forge`, so the gate now fails closed
until an approved identity change. See U091. `end_to_end=false`.

#### Hosted-runner and identity candidate (unapplied)

The user confirmed `superpowermentors-1/forge` as the permanent owner. The
candidate is in `proposals/provenance-hosted/` (diff `11ee6957…`, new lock
`acf73308…`, 10 files). No protected file is changed.

| Check actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 -I proposals/provenance-hosted/build_candidate.py` | 0 | Candidate files, lock, diff, manifest. |
| `git apply --check` / `git apply` (scratch copy) | 0 / 0 | All 10 files equal the candidate bytes. |
| `common.context('acf73308…')` (scratch) | 0 | 62 locked files. |
| `common.context('9b10a237…')` (scratch) | 1 | `UNAPPROVED_IMPLEMENTATION`, as required. |
| `run_package.py --implementation-sha256 acf73308…` (scratch, Mac controller profile) | 0 | Config `f15f5bd4…`; all 12 commands 0. |

See U092. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `e0eae926…`: candidate and dry-run workflow. |
| `gh workflow run stage9-candidate-dry-run.yml …` (first) | 1 | HTTP 404; workflow not yet registered. |
| `gh workflow run stage9-candidate-dry-run.yml …` (second) | 0 | Run 40724981390. |
| `gh run watch 40724981390 … --exit-status` | 1 | Hosted pins, setup and preflight passed; package config `45570f02…` ≠ controller `f15f5bd4…` → `INDEPENDENT_PACKAGE_REPRODUCTION`. |
| `docker buildx build --builder desktop-linux --output=type=docker,rewrite-timestamp=true --no-cache …` (twice, Mac) | 0, 0 | Different IDs; the Docker driver ignores `rewrite-timestamp`. |

Directory mtimes in the ELF layer make the package unreproducible. The
installed gate has the same defect. See U093. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `docker buildx build --builder <pinned docker-container BuildKit v0.25.1> --output=type=docker,rewrite-timestamp=true --no-cache …` (twice, Mac) | 0, 0 | Same ID `f5843050…`; base layers unchanged. |
| `python3 -I proposals/provenance-hosted/build_candidate.py` | 0 | Updated candidate: diff `5593a720…`, lock `f9f09a2f…`. |
| `git apply --check` / `git apply` (fresh scratch) | 0 / 0 | 10 of 10 files match. |
| `run_package.py --implementation-sha256 f9f09a2f…` (scratch, Mac controller, new builder) | 0 | Config `f5843050…`. |

See U094. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `64a77603…`: updated candidate and dry run. |
| `gh workflow run stage9-candidate-dry-run.yml -R superpowermentors-1/forge --ref main` | 0 | Run 40731196167. |
| `gh run watch 40731196167 … --exit-status` | 0 | Conclusion success, 40.5 min. |
| `python3 gate/provenance/hosted_setup.py` (candidate, in the run) | 0 | Pinned Docker and Stage 7 prerequisites, 1,377 s. |
| `python3 gate/provenance/preflight.py --implementation-sha256 f9f09a2f…` (candidate, in the run) | 0 | Hosted runner and Linux Cosign. |
| `python3 proposals/provenance-hosted/dry_run.py …` (candidate, in the run) | 0 | Hosted package equals the controller package (`f5843050…`); fresh proof receipt (656 files, 579 closure objects) accepted. |

The candidate is ready for exact-byte approval. It is not applied. Not an EXIT
result. See U095. `end_to_end=false`.

#### Trust-boundary review of the candidate (read-only)

| Item | Result | Evidence |
| --- | --- | --- |
| 1. `contract_approval_commit` | FAIL | Names `097431cf…`, the old contract approval; the candidate replaces those bytes. |
| 2. macOS-path link | PASS | Same checked interpreter; one pip run; 45 outputs hash-checked twice; read-only mount. |
| 3. Identity bindings | FAIL | Internally consistent, but GitHub now reports `mack-dot/forge`, owner 235131950 (`superpowermentors-1/forge` → 301). |
| 4. Admin access and branch rules | FAIL | Not named in the contract; one admin now; no rules or protection on `main`. |
| 5. Hashes versus manifest | PASS | 10 of 10 files, diff `5593a720…`, published copy at `27e6044b…` equal. |

The candidate is not ready for approval. See U096. `end_to_end=false`.

#### v2 candidate on the `mack-dot/forge` boundary (unapplied)

The user kept `mack-dot/forge`. The approved contract stays; only the
implementation changes (7 files, diff `39c6c3d7…`, lock `30880e08…`).

| Check actually run | Actual exit code | Scope |
| --- | --- | --- |
| Raw fetch of `spec/provenance/protocol.md` at `097431cf…` | 1 | HTTP 404: that commit publishes `proposals/provenance/*`, not `spec/`. |
| Contract audit against the published proposal files | 0 | Approval reference valid; contract bytes unchanged; identity matches live GitHub. |
| `python3 -I proposals/provenance-hosted-v2/build_candidate.py` | 0 | 7 files, lock, diff, manifest. |
| `git apply --check` / `git apply` (scratch) | 0 / 0 | 7 of 7 files match; contract unchanged. |
| `common.context('30880e08…')` / `('9b10a237…')` (scratch) | 0 / 1 | New lock passes; old lock `UNAPPROVED_IMPLEMENTATION`. |
| `run_package.py --implementation-sha256 30880e08…` (fresh builder) | 0 | Config `f5843050…`, descriptor identical to v1. |
| Five `gh api` settings changes | 0 each | Vulnerability reporting, Dependabot alerts, secret scanning, fork approval, SHA pinning. |

See U097. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh workflow run stage9-candidate-dry-run-v2.yml …` (first / second) | 1 / 0 | HTTP 404 (not yet registered) / run 40743117460. |
| `gh run view 40743117460` / `gh run download …` | 0 / 0 | Success: hosted package equals the controller package (`f5843050…`); fresh receipt (656 files, 579 objects) accepted. |
| `python3 proposals/provenance-hosted-v2/negative_controls.py --implementation-sha256 30880e08… …` (scratch, v2 applied) | 0 | 1 positive control accepted; 5 attacks rejected (`PACKAGE_CONFIG_IDENTITY` ×2, `PACKAGE_ROOTFS_BINDING`, `PACKAGE_FILESYSTEM_ELF:substituted`, `BUILDER_VERSION`). |

The repository is private, so release verification fails closed (U101, U102).
Measurements and controls only; not EXIT results. See U102, U103.
`end_to_end=false`.

#### v2 approval readiness (local, nothing pushed)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| Hash recomputation of the v2 manifest, diff, 7 files and lock | 0 | All match. |
| Installed `repository_identity()` against the private repository | 3 | `HTTPError 404`: verification fails closed. |
| F1 control: added `gate/provenance/argparse.py`, then `preflight.py` | 1 | Decoy code ran before any check (marker written). |
| F1 control: `context('30880e08…')` with the decoy present | 0 | Lock check passed: unlisted files are not bound. |
| Hash-checked Python archive, offline, Ubuntu 24.04 x64 container | 0 | Python 3.10.11 and bundled pip run without PyPI. |

Verdict: REVISE. See U104. `end_to_end=false`.

#### v3 candidate (unapplied, local)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| `python3 -I proposals/provenance-hosted-v3/build_candidate.py` | 0 | 8 files; diff `5d3e838f…`; lock `0215a316…` (89 files). |
| `git apply --check` / `git apply` (fresh scratch) | 0 / 0 | 8 of 8 files match; contract unchanged. |
| `context('0215a316…')` / v2 lock / installed lock | 0 / 1 / 1 | Only v3 passes. |
| `python3 -B proposals/provenance-hosted-v3/f1_controls.py …` | 0 | Clean commit accepted; 6 tree attacks and 2 verifier guards rejected. |

See U105. `end_to_end=false`.

#### Pre-verification execution and v3.1 (unapplied, local)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| v3: planted `json.py`, unchecked-hash `.pyc`, `PYTHONPATH` before `release.py` | 9 / 9 / 9 | Attacker code executed in all three: F1 unresolved in v3. |
| v3 `source_tree()` on a commit with a forged lock | 0 | Accepted (gap). |
| `python3 -I proposals/provenance-hosted-v31/build_candidate.py` | 0 | 9 files; diff `d24ff942…`; lock `6f3aafe6…`. |
| `git apply` (scratch) / `context('6f3aafe6…')` | 0 / 0 | 9 of 9 files match. |
| v3 F1 controls against v3.1 | 0 | 9 of 9 pass. |
| `python3 -B proposals/provenance-hosted-v31/controls.py …` | 0 | 14 of 14 pass; attacker code executed in none. |
| `check_no_signing.py` on the dry run / on production workflows | 0 / 1 | No signing path / correctly flagged. |

See U106. `end_to_end=false`.

#### B preparation (local)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| `negative_controls.py --implementation-sha256 6f3aafe6…` | 0 | 1 positive, 5 attacks rejected (v3.1). |
| v3.1 `validate_receipt()` on the hosted v2 receipt / byte flipped / other challenge | — | ACCEPTED / `PROOF_RECEIPT_BYTES` / `STALE_PROOF_RECEIPT`. |
| Inline check and `bootstrap.py --check` with the pinned Linux Python | 0 / 0 | 48 and 78 modules, all from the archive. |
| `bootstrap.py --check` with a planted `json.py` | 1 | Planted code did not run. |
| `check_no_signing.py .github/workflows/stage9-private-dry-run-v31.yml` | 0 | No signing path. |
| `b3_verify.sh … forge-verifier-nonexistent-test-item` | 3 | Stopped before any network request. |

See U107. `end_to_end=false`.

#### B1–B2′ (owner-authorized, measurement only)

| Command actually run | Actual exit code | Result |
| --- | --- | --- |
| B1: `git push` of `993bee7b…` (tree `32bfb2dd…`) | 1, then 0 | First attempt: zsh refspec error; second: pushed. |
| B2: `gh workflow run stage9-private-dry-run-v31.yml` (run 40771238211) | 0 | Run failed: `no space left on device` at the checker pull; trust steps passed. |
| B1′: direct push / PR #16 merged by the owner | 1 / — | Ruleset requires a PR; `main` = `3670d688…`, tree `3822a938…` as reviewed. |
| B2′: `gh workflow run stage9-private-dry-run-v32.yml` (run 40787574980) | 0 | Success: hosted package = Mac package (`f5843050…`); fresh receipt accepted; token read-only. |
| B3 run 1 (owner): `b3_verify.sh ~/forge-b3-check ~/forge-b3-out-1` | 3 | No Keychain item `forge-verifier-readonly`; stopped before the checks and any network request. |
| B3 run 2 (owner): `b3_verify.sh ~/forge-b3-check ~/forge-b3-out-2` | 1 | Keychain value failed the token format check before any request; wrapper crashed in `store()`; scan clean. |
| B3 run 3 (agent, owner waiver U117): reviewed wrapper v2 `6190aa58…`, OUTPUT `~/forge-b3-out-3` | 3 | Keychain value is not a GitHub token (length 68, prefix other); stopped before any check or request. |
| B3 run 4 (agent, owner waiver U117): wrapper v2 `6190aa58…`, OUTPUT `~/forge-b3-out-4` | 3 | Keychain value is not a GitHub token (length 4); stopped before any check or request. |
| B3 run 5 (agent, owner waiver U117): wrapper v2 `6190aa58…`, OUTPUT `~/forge-b3-out-5` | 0 | 8/8 cases PASS; API identity read with the token matches policy; fresh store per run; no credential copy in 687 record files. |

Not EXIT results. See U108–U121 and `results/stage9/b3-0001/`. `end_to_end=false`.

#### v3.2 installation (owner-approved, U122)

| Command actually run | Actual exit code | Result |
| --- | --- | --- |
| Proof gate on PR #17 (run 40807060051) | 1 | `UNAPPROVED_PROTECTED_CHANGE`: the gate approves only exact spec text, never its own code. |
| Agent: `gh pr merge 17 --squash --admin` | — | Refused by the Claude Code classifier (Merge Without Review). |
| Owner: `gh pr merge 17 --squash --admin --match-head-commit edb729a8…` | 0 | `main` = `d260d2a9…`, tree `1b77abd0…` = reviewed candidate. |
| Fresh `main` clone: inline lock check; `bootstrap.py --check` | 0; 0 | Lock `be23ec85…`; `BOOTSTRAP_VERIFIED`. |
| `common.source_tree` on `d260d2a9` / `3670d688` | 0 | ACCEPTED / `IMPLEMENTATION_LOCK_AT_COMMIT`. |
| Local sync of the 9 files; local `bootstrap.py --check` | 1, then 0 | First: `BYTECODE_CACHE`; caches removed; then verified. |
| Proof gate on records PR #18 (head `2ca14bdd…`); owner squash merge | 0; 0 | `main` = `d43f5f4d…`, tree `9f6bb222…` = records branch tree. No other run; no variables. |
| Rehearsal request (U124): `producer.py --action request` from a fresh `main` clone (`d43f5f4d`) | 0 | 9 min; controller package `f584305022f2…` = B2′ package; challenge stored in the local controller. |
| Rehearsal dispatch: `gh workflow run provenance.yml --ref main` (run 40810179164) | 0 | Conclusion success in 32 min: `proof` success, `sign` skipped; token Contents/Metadata read only. |
| Rehearsal verification with controller code (`results/stage9/rehearsal-0001/verification.json`) | 0 | Artifact digest `34b215d3…` matches; request, package, receipt (656 files), evidence and statement bindings pass; 4/4 tamper controls rejected. |
| `proposals/approval-integrity/audit_main_approvals.py mack-dot/forge 5` | 1 | #16, #17, #18 OVERRIDE (rule-suite bypass, 0 reviews); `993bee7b`, `e37ef2c5` direct pushes. Forged-pass and missing-record controls: no false APPROVED. |
| Pinned Cosign 3.1.4 (darwin-arm64 `9f9b8cd5…`) on a public cli/cli SLSA bundle (`results/stage9/cosign-offline-0001`) | 0 | Verified OK with Forge's flags; wrong-signer and wrong-digest markers match; unsigned marker does not (D1). |
| Independent adversarial audit of main `d43f5f4d` (`results/stage9/v32-audit-0001/results.json`, 22 checks) | — | V1 HIGH: root `ensurepip.py`/`runpy.py` runs before authentication in OIDC jobs (emulated). V2 HIGH: root `pip/` runs after bootstrap. V3 MEDIUM: inventory scope. V4 MEDIUM: receipt freshness is a label. Other controls pass. |
| Permission test: `gh api user`; `gh api repos/mack-dot/forge --jq .permissions` | 0; 0 | Agent is still `mack-dot` with admin; no machine-account collaborator. Identity separation not in effect. |
| `proposals/provenance-hosted-v33/build_candidate.py` | 0 | v3.3 candidate: 9 files, lock `eb4b93db…`, diff `21e1a7a4…`. |
| `run_controls.py <candidate repo fc0a40d9> results/stage9/v33-controls-0001` | 0 | 43/43: V1/V2 exploits run on v3.2 behaviour and not on the candidate; V3 root rule in bootstrap and source_tree; V4 relabel accepted by v3.2, refused by the candidate; D3 relaunch; guard; credential isolation. |
| v3.1 `controls.py -B` and v3 `f1_controls.py` on the candidate | 0; 0 | 14/14; 9/9. |
| Independent re-attack of candidate `fc0a40d9` (`results/stage9/v33-audit-0001`) | — | V1–V3 blocked in every emulated job; V4 gate holds; new D3 bypass (imports before relaunch) and weak D1 attribution. |
| Final candidate (lock `a809f701…`, diff `b432024f…`); `run_controls.py` → `results/stage9/v33-controls-0003` | 0 | 48/48, including the D3 exploit reproduced on v3.2 and refused four ways on the candidate. |
| v3.1 `controls.py -B` and v3 `f1_controls.py` on the final candidate `405b453a` | 0; 0 | 14/14; 9/9. |
| Owner said "push it": `git push` of `stage9/v33-install` (`20207fb5`, tree `ae535888`) and `stage9/records-v33` (`29ef0d94`) | 0; 0 | PR #19 (9 files = manifest) and PR #20 (records) open, BLOCKED for review; nothing merged; main still `d43f5f4d`. |
| Owner merged #19 and #20 with the admin bypass | — | `main` = `19c4896b`; install merge `241a9def` tree `ae535888` = tested tree; lock `a809f701…`; fresh-clone `bootstrap.py --check` 0; audit: both OVERRIDE; no variables; no run after the merges. Local copy synced (check 0). |
| v3.3 rehearsal request (U132) and `gh workflow run provenance.yml` (run 40820302652) | 0; 0 | Run name `forge-stage9 <challenge>` recorded at dispatch; success in 36 min; `sign` skipped; token Contents/Metadata read. |
| `verify_rehearsal.py` on run 40820302652 (`results/stage9/rehearsal-0002`) | 0 | 13/13: digest, request, package, receipt, run record, evidence, statement; positive `run_identity`; relabel, foreign run, re-run, other request, byte flip rejected. |
| Identity switch (owner-approved): invite `mackiannii` Write; accept; `gh auth logout -u mack-dot` | 0; 0; 0 | Agent = `mackiannii` (pull, push, triage; no admin); rule suites unreadable (404). |
| Approval controls on PR #21 as the agent: self-approve; merge without approval; `--admin` merge; direct push of `policy/` to main | 1; 1; —; 1 | Refused; refused; NOT RUN (Claude Code classifier); refused by GH013, main unchanged. |
| Owner review of PR #21 commit A `88ad9c72` (review 5698193782), read by the agent | 0 | APPROVED by `mack-dot`. |
| Stale-approval control: agent pushes B `52cbf8cb` (adds `@mackiannii` as code owner) | 0 | GitHub dismissed review 5698193782 at B; BLOCKED, REVIEW_REQUIRED. |
| Agent pushes C `2e3587f8` (reverts B; tree `0f757d83` = tree of A); `gh pr merge 21 --squash --match-head-commit C` with the stale approval only | 0; 1 | Refused (may be a client-side check). REST merge NOT RUN (Claude Code classifier). An earlier local revert attempt: exit 129; its push refused (non-fast-forward). |
| Owner review of C (review 5699085293); agent `gh pr merge 21 --squash --match-head-commit 2e3587f8` | 0; 0 | Main `aac837a0` by `mackiannii` (no admin); tree = approved head tree; CODEOWNERS `d5f98954…`. |
| `audit_main_approvals.py mack-dot/forge 7` (`approval-experiment-0001/17-audit-after-merge.jsonl`) | 1 | `aac837a0` (#21) APPROVED (inferred: non-admin merge). #16–#20 OVERRIDE, `993bee7b` UNAPPROVED: unchanged. |
| `audit_main_approvals.py mack-dot/forge 42` (`approval-experiment-0001/20-audit-full-history.jsonl`) | 1 | 1 APPROVED (#21); 6 OVERRIDE inferred (#4, #16–#20); 35 UNAPPROVED direct pushes. Statuses unchanged. |
| `build_admission.py` → `proposals/approval-integrity/admission-v34` (not applied) | 0 | New lock `9bf8f905…`, diff `f31a1bad…`; `common.py` `d63010fc…`, `release.py` `778cebb9…`. |
| `lineage_controls.py` with `lineage.py` (`lineage-controls-0001`) and with candidate `common.py` (`-0002`) | 0; 0 | 17/17 each. Main `aac837a0` refused today at `19c4896b`; draft ratification 0001 admits it (simulated); 15 forged or stale variants refused. |
| Final record (sha256 `b0f61a88…`, per-commit evidence; #4 UNCERTAIN): `lineage_controls.py` → `lineage-controls-0003` / `-0004` (candidate) | 0; 0 | 17/17 each. |
| Ratification branch as the agent (head `0159b4d2`, one added file); `git push`; `gh pr create` | 0; 0; 0 | Push and PR #22 ran as **`mack-dot`**: the owner account became active in gh at 14:30Z (not by the agent). PR #22 is owner-authored and cannot be owner-approved. Stopped (U138). |
| Separation checks before the corrective PR (`ratification-pr-0001/04-separation-check.txt`), read-only | 1 FAIL; 2 NOT RUN; 3 FAIL; 4 FAIL | Active gh user `mack-dot`; push helper follows it; owner keychain items reachable by the same macOS user. Not pushed (U139). |
| Corrective PR as `mackiannii` only (owner accepted the check-4 residual): checks 1–3; `git push` of `0159b4d2`; `gh pr create`; `gh pr close 22` | 0; 0; 0; 0 | PR #23 by `mackiannii`, one file, sha256 `b0f61a88…` matches; #22 closed unmerged. Not approved, not merged (U140). |
| Correction on PR #23 as `mackiannii`: checks 1–3; one commit `174880e8` (35 evidence fields); `git push`; controls 17/17 ×2 | 0; 0; 0; 0; 0 | File sha256 `34ae62bc…` at head; `0f11517d` = head of #4 (UNCERTAIN); 34 direct pushes; BLOCKED, REVIEW_REQUIRED; not merged (U142). |
| Owner review of PR #23, read by the agent | 0 | Review 5699889214 APPROVED by `mack-dot` on exact head `174880e8`; CLEAN; not merged (U143). |
| Merge of PR #23 as `mackiannii` (checks 1–3; `gh pr merge 23 --squash --match-head-commit 174880e8`) | 0 | Main `9aadcd63`; tree `dcac5503` = approved head tree; file sha256 `34ae62bc…`. |
| `audit_main_approvals.py mack-dot/forge 43` (`ratification-pr-0002/08-audit-after-merge.jsonl`) | 1 | #23 and #21 APPROVED (inferred); 42 earlier rows unchanged. |
| Proposed `approved_lineage` on real main (`results/stage9/lineage-real-0001`, read-only) | 0 | `9aadcd63` ACCEPTED: #23 → #21 → ratified `19c4896b`; `aac837a0` refused. Not an EXIT (U144). |
| v3.4 candidate (main `9aadcd63` + 3 files, local `b3251278`): `bootstrap.py --check` v3.3 on main / candidate | 0; 0 | `BOOTSTRAP_VERIFIED` both. |
| `run_controls_v34.py` → `v34-controls-0001` / `-0002` | 1; 0 | 47/48 (harness passed the v3.3 lock to the v3.2 reproduction), then 48/48 after the fix. |
| v3.1 `controls.py -B` and v3 `f1_controls.py` in the candidate | 0; 0 | 14/14; 9/9. |
| Wiring check of candidate `release.verify` (`v34-regression-0001/03-wiring.txt`) | 0 | 8/8. Full positive `release.verify` NOT RUN (no signed bundle). |
| Authenticated verifier path, real urllib, stand-in token (`v34-tokenpath-0001`) | 0 | 10/10; token in 0 record files. Owner verifier token not used (U145). |
| v3.4 install PR as `mackiannii` (checks 1–3; push `ce7b5377`; `gh pr create`) | 0; 0; 0 | PR #24: tree = tested tree `d6793b63`; 3 files; BLOCKED, review requested from `mack-dot`. Not merged. |
| Lineage (v3.4 code, authenticated path) on PR #24 head / PR #23 branch head / main `9aadcd63` | 0 | Refused / refused / accepted (U146). |
| Merge of PR #24 as `mackiannii` (checks 1–3; `gh pr merge 24 --squash --match-head-commit ce7b5377`) | 0 | Main `f4f8a68c`; tree `d6793b63` = tested tree; lock `9bf8f905…`; 0 variables. |
| Fresh clone of `f4f8a68c`: inline lock check; `bootstrap.py --check` (`9bf8f905`); old lock | 0; 0; 1 | Verified; verified; `BOOTSTRAP_REJECTED: IMPLEMENTATION_LOCK`. |
| Installed v3.4, authenticated path: `repository_identity` and `approved_lineage` on `f4f8a68c`; lineage on `19c4896b` | 0 | Accepted; accepted (#24 → #23 → #21 → `19c4896b`); refused. |
| `audit_main_approvals.py mack-dot/forge 44` | 2; 2; 2; 1 | Three runs stopped on GitHub HTTP 503; fourth: #24 APPROVED (inferred), 43 earlier rows unchanged (U149). |
| Local sync of v3.4 files; local `bootstrap.py --check` | 1, then 0 | `BYTECODE_CACHE`; caches removed; then verified. |
| v3.4 rehearsal request (U150): fresh clone `f4f8a68c`, `producer.py --action request` via bootstrap (lock `9bf8f905`) | 0 | Package `f584305022f2…`; challenge `5ab0425c…`; 4.5 min. |
| `gh workflow run provenance.yml` as `mackiannii` (run 40902238551) | 0 | Success: `proof` success (34.5 min), `sign` skipped; token Contents/Metadata read, no IdToken; artifact zip `bb0096fd…` = GitHub digest; no Sigstore bundle. |
| `verify_rehearsal_v34.py` (`results/stage9/rehearsal-0003`) | 1, then 0 | 14/15 (harness status parser), then 15/15: digest, request, package, receipt, run record, evidence, approved lineage, override refused, statement; 5 tamper controls rejected. |
| Real HTTPS path on run 40902238551: `run_identity`, `approved_lineage`, `repository_identity` | 0 | Accepted ×3; token in 0 record files (U151). Not an EXIT. |
| Signing experiment (U152–U154): owner set `FORGE_SIGNING_AUTHORIZED`; request at `f4f8a68c`; R1 `provenance.yml` (run 40910241018) | 0; 0; success | `proof` and `sign` success: signed bundles uploaded (Rekor entries under `provenance.yml@refs/heads/main`). Artifacts preserved, digests match. |
| R2 `provenance-negative.yml` (run 40916168141, `producer_run_id` 40910241018) | failure | `GITHUB_TOKEN_REQUIRED:FORGE_PRODUCER_GITHUB_TOKEN` at preflight: stateless job token (~520 chars) fails `[A-Za-z0-9_]{20,255}`; negative signing skipped; no negative Rekor entry. |
| v3.5 token repair (`proposals/token-compat-v35`): offline token controls v3.4 / v3.5 | 0; 0 | 34/34 each; token in 0 files. Earlier: variant A 25/25 (one harness crash on NUL). |
| v3.5 real `preflight.py` on Linux (Docker amd64, Python 3.10.11) | 0 | 10/10: v3.4 reproduces R2's error; v3.5 reaches GitHub (401 for a fake token); R1 producer path succeeds; wrong run, bad id, 404, no token refused. |
| v3.5 regression on tree `36ee0f91`: 48 / 14 / 9 / lineage 17 | 0; 0; 0; 0 | All pass; `release.py` unchanged; independent audit: nothing blocks (U156). |
| v3.5 PR as `mackiannii` (push to a local clone by mistake, then to GitHub) | 1; 0 | PR #25: 2 files, tree = tested tree, lock `a177cb07…`; BLOCKED for review. Not merged (U157). |
| Owner review of PR #25; merge as `mackiannii` (`gh pr merge 25 --squash --match-head-commit 05a7ac1f`) | 0; 0 | Main `5b1b5570`; tree `36ee0f91` = tested tree; lock `a177cb07…`. |
| Fresh clone of `5b1b5570`: lock check; `bootstrap.py --check`; old lock; lineage on main; lineage on `19c4896b` | 0; 0; 1; 0; 0 | Verified; verified; refused; accepted (#25 → #24 → #23 → #21 → ratified `19c4896b`); refused. |
| `audit_main_approvals.py mack-dot/forge 45` | 1 | #25 APPROVED (inferred); 44 earlier rows unchanged (U159). |
| Attempt 2 (U160): request at `5b1b5570` (lock `a177cb07`); R1 `provenance.yml` (run 40929727313) | 0; success | `proof` and `sign` success; 6 Rekor entries (release 3574048063). |
| R2 `provenance-negative.yml` (run 40935393475, `producer_run_id` 40929727313) | success | Stateless token accepted by v3.5; R1 candidate downloaded; wrong-signer bundle signed (Rekor 3574086992). |
| EXIT setup: fresh clone `5b1b5570`, Cosign `9f9b8cd5…`, lock and bootstrap checks, `write_controller_config.py` | 0; 0; 0; 0 | Controller row pending; candidate = R2 artifact (U162). EXITs NOT RUN. |
| Official EXITs under v3.5 (lock `a177cb07`, request `9e1f885f`; token per U163) | 0,0,0,0,0; 1 | Five passed; `deployed-identity` `not_established` (UID 1000 cannot read the ELF; request consumed) (U164). |
| v3.6 repro, `producer.package` ×2, deployment controls, package controls, consumption audit | 0; 0; 0; 1 then 0; 0 | Cause confirmed (`opt/forge` 0444); package `d9e9fb40…` reproducible; 13/13; 6/6 (one harness typo); 5/5 (U165). |
| v3.6 regression on tree `6d6b2a2f`: 48 / 14 / 9 / lineage 17 / token 34 | 0; 0; 0; 0; 0 | All pass; independent review: no blocker; F1–F4 pre-existing (U166). |
| v3.6 PR as `mackiannii` | 0 | PR #26: 2 files, tree = tested tree, lock `5f78da21…`; review requested. Not merged (U167). |
| Owner review of PR #26 (review 5705585056, head `5867db32`); merge as `mackiannii` (`gh pr merge 26 --squash --match-head-commit 5867db32`) | 0; 0 | Main `624c9faf`; tree `6d6b2a2f` = tested tree; Dockerfile `c915c79d…`; lock `5f78da21…`. |
| Fresh clone of `624c9faf`: lock check; `bootstrap.py --check`; old lock `a177cb07`; lineage on main; lineage on `19c4896b` | 0; 0; 1; 0; 0 | Verified; verified; refused; accepted (#26 → #25 → #24 → #23 → #21 → ratified `19c4896b`); refused. |
| `audit_main_approvals.py mack-dot/forge 46` | 1 | #26 APPROVED (inferred); 45 earlier rows unchanged (U168). |
| Completion run (U169): `producer.py --action request` at `624c9faf` (lock `5f78da21`), `GH_TOKEN` unset | 0 | Package `d9e9fb40…` (= SIGNING-v36.md); challenge `8a6ba7f4…`; controller row pending. |
| R1 `provenance.yml` (run 40966460258, head `624c9faf`, title = challenge) | 0; success | `proof` 22:31:07–22:56:45Z, `sign` 22:56:47–22:57:58Z; artifacts signed `8ded75a0…`, unsigned `62a0adcc…`. |
| R2 `provenance-negative.yml` (run 40969828051, `producer_run_id` 40966460258) | 0; success | All steps succeeded in 42 s; artifact `27e144bc…`. |
| Download of 3 artifacts into new folders; digest check; Rekor listing | 0; 0; 0 | Digests = GitHub; 7 bundles, 7 dsse entries: 3578450049 (release), 3578452739, 3578453975, 3578456247, 3578458664, 3578462150 (`provenance.yml`), 3578489035 (`provenance-negative.yml`). Project total 20. |
| EXIT setup: fresh clone `624c9faf`, Cosign `9f9b8cd5…`, inline lock check, `bootstrap.py --check`, `write_controller_config.py` | 0; 0; 0; 0 | Candidate = R2 artifact; request `8a6ba7f4…`; lock `5f78da21`; row pending. |
| Six official EXITs, in order, verifier token from Keychain per U163 (`results/stage9/exits-0002/`) | 0,0,0,0,0,0 | All `passed` on attempt 0001; every gate outcome = SIGNING-v36.md; row now consumed; no file holds the token. |

Signing stays off: no repository variables; `provenance.yml` has never run. Not EXIT results.
See U123 and `results/stage9/v32-install-0001/`. `end_to_end=false`.

That note is historical (v3.2). Signing later ran under owner authorization (U155, U160, U169).
Stage 9 is DONE: the six official EXITs above each returned 0 under request `8a6ba7f4…` and
lock `5f78da21…`. Limits stay: the deployment claim is file identity at observation time only
(`deployment_correctness_proved=false`, `riscv_execution_claimed=false`); the agent ran the
verifier on the owner's machine (U163); the Docker daemon and builder are trusted; F1–F4 stay
open (U166, U169). `end_to_end=false`.

### Stage 10 — GATE BENCHMARK

**Status: DONE — EXIT report exit 0 on run-0002 (2026-10-30; U176)**

The owner replaced the real-repository shadow study with a controlled benchmark
(2026-10-29; [plan](proposals/stage10-benchmark.md), U171, U172). The shadow study
stays a separate future milestone (below).

Measure how Forge's unchanged gates classify a frozen corpus of PR-like changes in
[`bench/`](bench/README.md). The owner's approval conditions:

1. Forge's gate and trusted checker implementation stay unchanged.
2. The benchmark lives in `bench/`, runs in isolation, and keeps expected outcomes
   separately controlled.
3. All cases, expected decisions, input artifacts and their hashes are frozen before the
   official run (`bench/manifest.json`).
4. The corpus includes valid alternative implementations, adversarial invalid evidence,
   and explicit `unsupported` and `tool_failure` outcomes.
5. Every mismatch is preserved. Expectations never change after results are seen.
6. The report gives false accepts, false rejects, the outcome confusion table, p50/p95
   latency, total cost and reproducibility.
7. The report states that this is an internally authored controlled evaluation, not
   independent generalization or a real-PR shadow study.
8. The official run starts only after the owner approves the complete case list and the
   manifest hash. Stage 9 evidence stays unchanged; signing stays off.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_10.py --case report --run results/stage10/run-0002` | Checks the frozen manifest and every bench file, requires each case to have run once in each of the two passes, and reports false accepts, false rejects, the confusion table, p50/p95 latency, total cost and pass-to-pass agreement. A second call reproduces the report byte for byte. Exit 0 means a complete, reproducible measurement, not a perfect score. | 0, then 0 (second call reproduced `report.json` `5e776f59…` and `report.md` `38dcdd37…`). The default `--run` names run-0001, which is not established (U174). |

The scored result is a measurement. A false accept or false reject is a finding to
report and adjudicate, not a reason to change a gate or a label. `end_to_end=false`.

| Preparation command actually run | Actual exit code | Result |
| --- | --- | --- |
| `python3 -I author_cases.py <clone of 624c9faf> bench/cases` (scratch authoring script) | 0 | 51 case files; every edit anchor occurs exactly once in the base bytes. No gate or Dafny run. |
| `python3 bench/freeze.py` | 0 | `bench/manifest.json` sha256 `98df0272…4889`; all consistency checks pass. |
| `python3 bench/run.py --manifest bench/manifest.json --dry-run --out results/stage10/dry-run-0001 --work ~/forge-stage10-bench/dry-run-0001` | 0 | Base `624c9faf`, pins `74dcc4b8…`; sandboxed `dafny --version` 0; network probe refused; 51/51 case trees built and removed; no gate started (U172). |

These are not Stage 10 EXIT results.

| Official run command actually run | Actual exit code | Result |
| --- | --- | --- |
| `python3 bench/run.py --manifest bench/manifest.json --approved-manifest-sha256 98df0272… --out results/stage10/run-0001 --work ~/forge-stage10-bench/run-0001` | 0 | Not established: every gate stopped at its pin check (`PyYAML version differs from pin`, exit 2); host drift, not a gate result (U174). Kept unchanged. |
| `python3 -m pip uninstall -y PyYAML` (owner choice; user-site 6.0.3 only) | 0 | Pinned PyYAML 6.0.1 loads again; `check_dependencies` passes (U175). |
| `python3 bench/run.py … --approved-manifest-sha256 98df0272… --out results/stage10/run-0002 --work ~/forge-stage10-bench/run-0002` | 0 | 51 cases × 2 passes ran, 01:14–01:39Z; no harness error. |

Results (primary pass, `results/stage10/run-0002/report.md`):

| Expected class | Cases | Observed as expected | Observed otherwise |
| --- | ---: | ---: | --- |
| accept (3 seeds, 8 valid alternatives, 3 unchanged supplied evidence) | 14 | 14 | — |
| defect | 8 | 8 (`VERIFICATION_REJECTED`) | — |
| policy_reject | 11 | 11 (reason prefixes as expected) | — |
| missing_evidence (adversarial evidence) | 10 | 10 (reason prefixes as expected) | — |
| unsupported | 4 | 0 | 4 accepted (exit 0, `ACCEPTED: C1 C2 C3 C4 C5`, `checked=0`) |
| tool_failure | 4 | 4 (exit 2) | — |

False accepts 4 (all `unsupported`): PRs that change only `ts/ledger.ts` (fee bug),
`app/main.ts`, a new unverified `impl/Extra.dfy`, or `ts/refund.ts` get a full ledger
acceptance, because the PR gate checks only its own source scope and has no "no claim"
result. False rejects 0; misclassified 0; wrong reason 0. Latency per case (primary
pass): wall p50 3.2 s, p95 12.5 s; CPU p50 2.5 s, p95 10.4 s; total CPU 148.8 s
(295.9 s both passes) on an Apple M1 Pro. Repeat pass: 51/51 same decisions; 18/18
accepted evidence files byte-identical. Adjudications: none recorded. Limits: internally
authored; not independent generalization; not a real-PR shadow study; ledger, booking
and refund source-proof gates only. `end_to_end=false`.

#### Future milestone, not scheduled: real-repository shadow study

Run the gate on a real host repository's PRs in report-only mode for two actual
weeks. Do not block merges during this experiment. Log what the gate would have
blocked, why, and which claims and methods were involved. Distinguish an actual
defect from missing evidence, an intentional policy rejection, and a tool failure.
Include observation dates, sample size, human adjudication, unknown cases, and
cost denominators. Do not simulate elapsed weeks or claim a false-positive rate
without a defined review process and denominator. This needs its own owner
authorization and a host repository (U170).

### Stage 11 — INCREMENTAL VERIFICATION

**Status: DONE on the recorded host — all three EXITs exit 0 (U190). Not met: criterion 4 for CI (dependent gates cannot run on Linux yet). The candidate is PR-stacked on PR #27 and not merged.**

After PR #27 (coverage soundness, not assumed merged) the ledger PR gate is sound but
VERIFIED is reachable only for an empty diff. Make non-empty legitimate changes
VERIFIED by re-establishing every affected obligation from an auditable dependency
graph derived from the gates' own declared inputs, reusing accepted evidence only when
every relevant identity is identical, and reporting precise claim scopes. Order of
priority: soundness, useful acceptance, performance, developer experience, economics.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_11.py --case legitimate-change --eval results/stage11/eval-0007 --baseline results/stage11/eval-pr27-0003` | A real, non-empty ledger change passes its own proof and every affected dependent obligation (booking, model, witness, committed evidence) and is VERIFIED with an exact claim-scope report. | 0 (e02 VERIFIED, four dependents re-established fresh; e04, e05 VERIFIED; e03 UNSUPPORTED by contract) |
| `python3 scripts/exit_stage_11.py --case stale-dependency …` | A dependency change with stale evidence is REJECTED or UNSUPPORTED; uncovered code, weakened specs, stale proofs, unauthorized policies and tampered artifacts stay rejected or unsupported. | 0 (12 cases as required; e12 not constructible, excluded with a printed note) |
| `python3 scripts/exit_stage_11.py --case report …` | Frozen fresh evaluation (cases fixed before the run) reports correct acceptances, false accepts, false rejects/unsupported, latency and cost (cold and warm), reproducibility over two runs, and the comparison with PR #27 behaviour; the original 51 cases run only as a regression suite. | 0, then 0 (byte-identical `report.json` `865f0000…`): 18 cases; match 12; false accept 0; false reject 0; 5 frozen expectations superseded by the post-freeze design change; 1 not constructible. |

Hard limits: no bypass of human approval, no signing, no change to Stage 9 or Stage 10
evidence, protected PRs only for independently reviewable changes, stop before merge.
`end_to_end=false`.

| Step actually run | Actual exit code | Result |
| --- | --- | --- |
| Model `proposals/incremental-verification/model/Acceptance.dfy` (pinned Dafny) | 0 | 10 verified, 0 errors (model only). |
| Independent adversarial review, three passes | — | 6 blockers → 1 critical → none; every exploit reproduced and closed (U183–U186). |
| Stage 4 local / approval on the final gate | 0 / 0 | 13/13; 6/6 (`results/stage11/regression-0001/final3/`). |
| Stage 9 controls on lock `4e9e7e54…` | 0 ×5 | 48/48, 14/14, 9/9, token 34/34, lineage 17/17 (`suites-0005/`). |
| Frozen evaluation `eval-0007` (cases `ceec69ca…`; runner `319b65cd…`; cold + warm) | 1 (6 frozen mismatches, all design-change or unconstructible) | 0 false accepts; e02/e04/e05 VERIFIED (UNSUPPORTED under PR #27); cold wall p50 13.6 s, warm 7.4 s; 18/18 same decisions. |
| PR #27 baseline on the same cases `eval-pr27-0003` | 1 | Every non-empty change UNSUPPORTED. |
| Conformance of 53 recorded traces | 0 | 0 nonconforming. |
| Aborted runs kept: eval-0001..0005, eval-0006 (superseded), eval-pr27-0001/0002 | — | Runner PATH; refund lock race; N1 fix; e12 anchor; disk full; runner deleted the real Dafny through a symlink (restored, pins verified, U188–U189). |
| Protected PR as `mackiannii` (checks 1–3; push `a8dee75f`; `gh pr create` onto `gate/coverage-soundness-v1`) | 0 | PR #28: 8 files, tree `caaf0554` = tested tree, lock `4e9e7e54…`; stacked on PR #27; not merged (U191). |
| Owner review check (read-only API as `mackiannii`) | 0 | PR #28 APPROVED by `mack-dot` on head `a8dee75f` (2026-10-30T13:03:32Z). PR #27 `4ab56e04`: 0 reviews, blocked. Not merged; merge needs separate authorization and #27 first (U192). |
| Merge PR #27 as `mackiannii` (`gh pr merge 27 --squash --match-head-commit 4ab56e04`) | 0 | main `0bf31d9f`, tree = approved head tree `133cee25`; lock on main `4e2abe26…`; merged 2026-10-30T14:17:14Z after owner review 5713497921 and merge authorization (U194). |
| Retarget PR #28 to `main` (`gh pr edit --base main`; REST PATCH) | 1; 0 | GraphQL error, then PATCH ok. Approval dismissed by ruleset; mergeable_state dirty (pre-squash parent). Rebase push not performed (permission refused); owner decision pending (U194). |
| Replacement PR as `mackiannii` (branch from `0bf31d9f`; `cherry-pick -x a8dee75f`; tree check; `bootstrap.py --check` new / old lock; plain push; `gh pr create`; reviewer request) | 0; 0; 0; 0 / 1; 0; 0; 0 | PR #29 head `c00b85da`, tree `caaf0554` = tested tree, lock `4e9e7e54…`; recorded results apply unchanged; #28 branch untouched; not merged (U195). |
| Owner review check on PR #29 (read-only API) | 0 | `mack-dot` APPROVED on exact head `c00b85da` (2026-10-30T14:39:01Z, review 5713886773). Not merged; awaiting separate merge authorization (U196). |
| Merge PR #29 as `mackiannii` (`gh pr merge 29 --squash --match-head-commit c00b85da`) | 0 | main `4e4112c6`, parent `0bf31d9f`, tree `caaf0554` = tested tree; lock on main `4e9e7e54…`; merged 2026-10-30T15:22:33Z after owner review 5713886773 and merge authorization (U197). |

The original 51 Stage 10 cases were rerun as a regression suite under PR #27 only; under
Stage 11 the frozen `classes.json` does not know exit 3 and the four ledger alternatives
would now need regenerated evidence, so that rerun is deferred and disclosed.

## Execution record

### Continued integration readiness review — 2026-11-02 (no stage is CURRENT)

Owner authorizes review and proposal/test preparation, not approval, merge,
deployment, protection changes or Stage 12. See U207 and
`proposals/linux-ci-readiness/REVIEW.md`. PR #30 remains unapproved at
`561d2dda`; no implementation or active workflow was changed.

| Command actually run / check | Actual exit code | Result |
| --- | --- | --- |
| `python3 results/ops-readiness/integration-2026-11-02/check_archives.py /Users/mackianni/forge-backups` | 0 | Both original archives/manifests intact; independence unestablished. |
| `python3 proposals/linux-ci-readiness/audit_backup.py` | 0 | Actual children: intact copies 0; truncated archive 1; altered manifest 1; invalid destination 2 before SSH. |
| Inline exact-head git blob and lock audit | 0 | 100 entries match; tracked files equal commit; workflow/admission policy unchanged. |
| `python3 proposals/linux-ci-readiness/prepare_workflow.py` | 0 | Exact one-file Node proposal prepared, not applied. |
| `git apply --check /Users/mackianni/forge/proposals/linux-ci-readiness/node-workflow.patch` in forge-linux | 0 | Exact preimage accepts the patch; dry check only. |
| `git apply --check` for booking-a.patch / replay-observations.patch on their stated preimages | 0 / 0 | Both apply; no live change applied. Exact commands in proposal-validation.json. |
| `bash -n proposals/linux-ci-readiness/node-step.sh`; replay-step.sh | 0 / 0 | Shell syntax valid; no download or setup executed. |
| Python AST + YAML structural comparison + fixture anchor checks | 0 | Proposals parse; only intended steps differ; permissions/action refs preserved. |
| `python3 -I -S -B proposals/linux-ci-readiness/acceptance_linux.py --help`; audit_ci_artifacts.py --help | 0 / 0 | Interfaces usable; tests themselves NOT RUN. |

Effective-rule reads show required review and no configured required status in
the visible ruleset/branch summary. Full classic protection still HTTP 403;
administrator GET exports needed. No rule changed. Booking-only verification
does not need Node; that first genuine run can follow #30's authorized merge.
Linux ledger/Node/booking acceptance suites, optional observation execution,
off-machine copy and new CI cost measurements are **NOT RUN**. No savings claim.
Prepared tests require positive A/C, stale-dependency invalidation with current
safe overall refusal for B, and unsupported-code refusal. Positive changed-ledger
acceptance remains blocked on the separately approved evidence-profile design.

### Linux CI integration mission — 2026-11-02 (no stage is CURRENT)

Owner authorizes the existing integration path, with an explicit Phase 1 stop
when exact-head approval is missing. Stage 12 is not authorized. See U205 and
`results/ops-readiness/integration-2026-11-02/STATUS.md` for the scoped review,
immutable source identities, records and prepared backup procedure.

| Command actually run / observation | Actual exit code | Result |
| --- | --- | --- |
| `python3 results/ops-readiness/integration-2026-11-02/check_archives.py /Users/mackianni/forge-backups` | 0 | Both archive/manifests match; 10,160 files each; no mismatch. Independence not established. |
| `tmutil destinationinfo` | 0 | No destinations configured; not a passing off-machine-backup result. |
| `gh pr view 30 --repo mack-dot/forge --json number,url,headRefOid,baseRefOid,reviewDecision,mergeStateStatus,statusCheckRollup` | 1 initially; 0 direct; 1 redirected retry | Direct read: REVIEW_REQUIRED, BLOCKED; connection failures retained separately. |
| Inline Python exact-commit blob/digest audit | 0 | 100 lock entries match; GitHub tree/lock match; workflow and bootstrap unchanged. source-integrity.json. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 ac883083f6326b9d017f3228966f235c1108b05f4129f81c0de8020e1c127f1a --check` in clean export of 561d2dda | 0 | BOOTSTRAP_VERIFIED. Integrity check only. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 4e9e7e54f8cf9bf5b28889a9340c6b764175efdf1a3c9d0c391eb998c81983ed --check` in same export | 1 | BOOTSTRAP_REJECTED: IMPLEMENTATION_LOCK; expected old-lock rejection. |
| `sh -n results/ops-readiness/integration-2026-11-02/copy_backup.sh` | 0 | Procedure syntax valid; copy NOT RUN. |
| Historical GitHub run 41125456987, logs read now | 1 (historical gate) | UNAPPROVED_PROTECTED_CHANGE; no checker commands. No new CI proof. |

Connected API reads confirmed zero submitted reviews at head `561d2dda`.
Visible ruleset requires approval; classic protection is unverified (HTTP 403).
Separate merge authorization is absent. Stop before merge per owner mission.
Linux ledger proof, Node workflow application, booking scenarios A/B/C, remote
copy and cold/warm/invalidated CI measurements: **NOT RUN**. Expected outcomes
in the mission are not passing results. No stage transition or signing change.
Record packaging: initial manifest generation failed (own relative-path error,
Python 1 / shasum 2); corrected manifest generation and `shasum -a 256 -c
evidence-manifest.sha256` exited 0. No proof was run by these commands.

### GitHub status check — 2026-11-02 (no stage is CURRENT)

Read-only status check; no EXITs rerun and no stage transition. See U204.
GitHub main is `4e4112c6`: #27 and #29 merged, #28 closed without merge.
PR #30 remains at `561d2dda`, with no submitted review. GitHub's roadmap
still says Stage 9; it does not contain the current local execution record.
Historical Stage 11 "not merged" statements above are superseded by U197.

| Command or API observation | Actual exit code | Result |
| --- | --- | --- |
| `git status --short --branch` | 128 | This local records directory is not a git repository (U201). |
| `gh pr view 30 --repo mack-dot/forge --json number,url,headRefOid,reviewDecision,mergeStateStatus,statusCheckRollup` | 0 | REVIEW_REQUIRED; BLOCKED; verify FAILURE, report SUCCESS. |
| `gh run list --repo mack-dot/forge --limit 8 --json databaseId,workflowName,event,headSha,status,conclusion,createdAt,url` | 0 | Latest run 41125456987 failed on PR #30; pull_request_target event. |
| Connected GitHub log read: job 124302708053, run 41125456987 (historical CI result) | 1 (gate, from log) | UNAPPROVED_PROTECTED_CHANGE; dependent proofs not reached. |

Next: preserve records off-machine; exact-head review of #30; then the
separate pinned Node workflow change and a genuine booking-change CI run.
Ledger-change CI additionally needs per-profile committed evidence.
These are pending actions, not passing results. No GitHub writes were made.

### Post-Stage-11 operational readiness (owner-authorized 2026-10-30; no stage is CURRENT)

Planned steps (owner mission): verify main/lock/controller; Linux support for the dependent gates
with pinned, independently validated toolchain; one non-empty verification case on a fresh Linux
environment with measurements; disk/Docker audit without deleting evidence; close PR #28; report
blocks and the smallest protected changes. Rows below record actual exit codes only.

| Step | Exact command / record | Actual exit code | Result |
| --- | --- | --- | --- |
| Verify main, lock, controller | fresh clone `~/forge-main`; `bootstrap.py --implementation-sha256 4e9e7e54… --check`; old lock; read-only sqlite of the Stage 9 controllers | 0; 1; 0 | main `4e4112c6`, lock verified; no controller row for lock `4e9e7e54` (controller not updated, signing off) (U198). |
| Close PR #28 | comment + `gh pr close 28` as `mackiannii` → `results/stage11/close-28-0001.txt` | 0 | closed, not merged, branch kept at `a8dee75f` (U199). |
| Disk and Docker audit (read-only) | `du`, `docker system df -v`, `docker inspect` → `results/ops-readiness/disk-docker-audit-0001.md` | 0 | 25 GB regenerable gate scratch identified; evidence images/containers classified keep; nothing deleted (U200). |
| Records durability check | GitHub contents API vs local tree | 0 | Stage 9 v3.4–v3.6, 10, 11, coverage-repair records local-only; 27 MB curated set (U201). |
| Independent validation of Linux toolchain bytes | Dafny zip: CI pin = local download = GitHub release API digest `a46a9ff7…`; Node tarball: nodejs.org SHASUMS = tsinghua mirror = local `a962afad…`; Python 3.10.11 build `bin/python3.10` = pin `8cd5e3f3…`; pip 25.3 wheel = PyPI digest | 0 | all agree; record `results/ops-readiness/linux-toolchain-validation.txt`. |
| Candidate build (clone `~/forge-linux`, branch `ops/linux-profile-v1`) | host-profile pin selection; `toolchain/javascript-linux-pins.json`; evidence.json regenerated; lock `ac883083…`; `bootstrap.py --check` new / old on clean export | 0 / 1 | head `561d2dda`, tree `4d106778`, 13 files +187 −46 (U202). |
| macOS regression on the candidate | `scripts/check_stage_4_local.py`; `scripts/check_stage_4_approval.py` → `results/ops-readiness/stage4-*-macos-final.txt` | 0; 0 | 13/13 LOCAL_CONTROLS_PASSED; 6/6 (one earlier attempt failed on an uncommitted tree, kept). |
| Fresh Linux verification (ubuntu-22.04 amd64 container, pinned toolchain) | `linux_run.sh verify 561d2dda` → `results/ops-readiness/linux-0001/` | 0 (container); gate exits 0,0 / 0,0 / 0,0 / 2,2 | identical, booking alt, refund alt VERIFIED cold+warm; ledger rename NOT_ESTABLISHED (EVIDENCE_PROFILE); cold median 87 s, warm 49 s; evidence identities identical (U202). |
| Protected PR as `mackiannii` (checks 1–3; plain push; `gh pr create`) | `open_linux_pr.sh` → `results/ops-readiness/pr-open-0001.txt` | 0 | PR #30 head `561d2dda`; reviewer mack-dot requested; not merged (U202). |
| Records backup (raw + sanitized), scanned and verified | `results/ops-readiness/backup-2026-11-01/`; archives in `~/forge-backups/` (raw `e2491743…`, sanitized `ac84dd27…`) | 0 | 10 160 files; 0 hash mismatches on re-extraction; no credential patterns; same-disk only (U203). |
| PR #30 review package | `results/ops-readiness/pr30-review/PR30-REVIEW.md`; comment on PR #30 | 0 | lock delta 9 changed/3 added verified against tree; pins, provenance, cold/warm table, limits (U203). |
| Deletion proposal and Linux CI steps | `DELETION-PROPOSAL.md`; `LINUX-CI-STEPS.md` | — (proposals) | 25.3 GiB Tier 1 regenerable scratch identified; nothing deleted (U203). |

### Post-Stage-10 repair (owner-authorized; no stage is CURRENT)

| Step | Exact command / record | Actual exit code | Result |
| --- | --- | --- | --- |
| Reproduce the 4 Stage 10 false accepts on the original gate | `python3 proposals/coverage-soundness/repro_original.py <base 624c9faf> <plain> results/coverage-repair/phase1-repro-0001` | 0 | All four: gate exit 0, `ACCEPTED: C1 C2 C3 C4 C5; checked=0`, evidence written (U177). |
| Formal model | pinned `dafny verify proposals/coverage-soundness/model/Acceptance.dfy` | 0 | 8 verified, 0 errors (model only). |
| Candidate regression (clone `~/forge-coverage-v1`, lock `4e2abe26…`) | `scripts/check_stage_4_local.py`; `scripts/check_stage_4_approval.py`; `run_controls_cov.py`; v3.1 `controls.py`; `f1_controls.py`; `token_controls.py`; `lineage_controls.py`; `bootstrap.py --check` new / old lock | 0; 0; 0; 0; 0; 0; 0; 0 / 1 | 11/11; 6/6; 48/48; 14/14; 9/9; 34/34; 17/17; verified / refused (U178). Two aborted local attempts kept (own harness errors). |
| Held-out cases, frozen before any run | `python3 -I proposals/coverage-soundness/heldout/run_heldout.py cases.json e69611a3… …` (2 passes) | 0 | 32/32 as expected; identical decisions across passes (U178). |
| Frozen 51-case rerun on the candidate | `python3 -I proposals/coverage-soundness/rerun_bench.py …` (2 passes) | 0 | 8 decisions changed, all to UNSUPPORTED (4 false accepts, 4 ledger alternatives); 43 identical; 51/51 across passes (U179). Frozen Stage 10 report unchanged. |
| Conformance of recorded traces to the model | `python3 -I proposals/coverage-soundness/model/conformance.py …` | 0; 0 | 49 + 40 records, 0 nonconforming (bounded evidence). |
| Protected PR as `mackiannii` (checks 1–3; push `4ab56e04`; `gh pr create`) | `open_coverage.sh` → `results/coverage-repair/pr-open-0001.txt` | 0 | PR #27: 7 files, tree `133cee25` = tested tree, lock `4e2abe26…`; review requested from `mack-dot`; BLOCKED. Not merged (U180). |


Stage 0–3 EXIT checks are complete. The true arithmetic lemma was
verified; the false arithmetic lemma was rejected for its false postcondition.
The ledger refinement establishes C1–C5 at source level under the recorded
assumptions. No binary, deployment, or whole-application claim is established.
Stage 2 schema, policy, identity, and replay checks passed, including every
Stage 1 regression. Stage 3's model-comparison checks and approved demo invocation
also passed. Stages 4 and 5 are complete in their stage records above.
Stages 6–11 are complete in their records above; the Stage 11 candidate awaits review as a PR (U190).

Commands ran from the repository root. The required `dafny --version` invocation
used `export PATH="$PWD/.toolchain/dafny-4.11.0/dafny:$PATH"` in that shell. Other
Dafny checks below used its explicit local path. No global PATH was changed.

For each future run, append the following facts here before advancing a stage:

| Stage / case | Exact command | Expected behavior | Actual exit code | Observed result / log reference |
| --- | --- | --- | --- | --- |
| 0 / Node version | `node --version` | Prints selected version | 0 | `v24.3.0` |
| 0 / Python version | `python3 --version` | Prints selected version | 0 | `Python 3.10.11` |
| 0 / installation prerequisite, first attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | `curl: (6) Could not resolve host: github.com`; see `unsure.md` U008–U009 |
| 0 / installation prerequisite, second attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U009–U010 |
| 0 / installation prerequisite, third attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U010–U011 |
| 0 / installation prerequisite, fourth attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U011–U012 |
| 0 / installation prerequisite, fifth attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; the user subsequently supplied the archive; see `unsure.md` U012–U013 |
| 0 / archive checksum before extraction | `shasum -a 256 -c` with the checksum line shown in `toolchain/README.md` supplied on standard input | Matches the pinned archive SHA-256 | 0 | Archive: OK |
| 0 / extraction | `unzip -q .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip -d .toolchain/dafny-4.11.0` | Extracts the validated distribution | 0 | Completed |
| 0 / Dafny version | `dafny --version` | Prints locked version | 0 | `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` |
| 0 / bundled Z3 version | `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version` | Prints selected solver version | 0 | `Z3 version 4.12.1 - 64 bit` |
| 0 / CLI option validation | `.toolchain/dafny-4.11.0/dafny/dafny verify --help` | Confirms resource limit, time-limit 0, solver path, and worker options | 0 | Options confirmed from installed CLI |
| 0 / true lemma | `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files > toolchain/results/true.log 2>&1` | Verifies the true postcondition | 0 | [Raw output](toolchain/results/true.log): 1 verified, 0 errors |
| 0 / false lemma | `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files > toolchain/results/false.log 2>&1` | Rejects the false postcondition | 4 | [Raw output](toolchain/results/false.log): 0 verified, 1 error; expected rejection |
| 0 / Node version, final run | `node --version` | Matches selected version | 0 | `v24.3.0` |
| 0 / Python version, final run | `python3 --version` | Matches selected version | 0 | `Python 3.10.11` |
| 0 / pinned local checksums | `shasum -a 256 -c toolchain/checksums.sha256` | Matches the archive and all four listed executables | 0 | All five entries: OK |
| 1 / draft syntax, attempt 1; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 2 | `rbrace expected` at the attempted postcondition label; replaced labels with comments |
| 1 / draft syntax, attempt 2; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 2 | Ambiguous indentation warning at the C5 implication; parenthesized its premise |
| 1 / draft syntax, attempt 3; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 0 | `Dafny program verifier did not attempt verification`; no proof claim |
| 1 / planted bugs, first scenario run | `python3 scripts/exit_stage_1.py --case planted-bugs` | Rejects all fixtures and names the expected claims or rules | 1 | `self_transfer: expected claim/rule was not named`; corrected one-based diagnostic line mapping; see U020 |
| 1 / contract binding, first scenario run | `python3 scripts/exit_stage_1.py --case contract-binding` | Names the missing approved refinement relationship | 1 | Rejected for missing coverage instead of the expected refinement diagnostic; added explicit refinement preamble requirement; see U020 |
| 1 / final accepted ledger | `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Accepts C1–C5 and writes evidence | 0 | Real Dafny proof accepted; `source_proof`; `end_to_end=false` |
| 1 / final reproducibility | `python3 scripts/exit_stage_1.py --case reproducibility` | Two accepted runs produce identical evidence bytes | 0 | Gate exits 0 and 0; actual `cmp` exit 0 |
| 1 / final planted bugs | `python3 scripts/exit_stage_1.py --case planted-bugs` | All four fixtures pass basic units but fail the gate | 0 | Units 0 each; gate 1 each; verifier 4 for first three, audit 2 for sneaky_assume |
| 1 / final spec lock | `python3 scripts/exit_stage_1.py --case spec-lock` | Rejects changed spec with stale lock | 0 | Disposable-copy gate exit 1; `SPEC_LOCK` |
| 1 / final contract binding | `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects missing approved refinement | 0 | Disposable-copy gate exit 1; `SOURCE_SCOPE` |
| 1 / final audit controls | `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects all three proof escape controls | 0 | Actual auditor exit 2 and gate exit 1 for each control |
| 1 / published evidence candidate comparison | `cmp evidence.json build/stage1/reproducibility/evidence.json` | Root evidence equals tested reproducibility output | 0 | Files are byte-identical |
| 2 / archived evidence schema | `python3 gate/gate.py --schema-only results/stage1/evidence.json` | Validates exact Stage 1 record structure only | 0 | `SCHEMA_VALID`; no proof acceptance claimed |
| 2 / accepted ledger | `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Runs actual backend and enforces schema and critical policy | 0 | C1–C5 accepted; policy-bound format 2; 12 obligations |
| 2 / schema | `python3 scripts/exit_stage_2.py --case schema` | Both actual formats validate; malformed controls fail | 0 | Schema-only children 0 and 0; malformed-input gates 1 and 1 |
| 2 / artifact mismatch | `python3 scripts/exit_stage_2.py --case artifact-mismatch` | Rejects changed record digest, coherent forged digest, and manifest digest | 0 | Three gates exited 1 with `ARTIFACT_MISMATCH` |
| 2 / method policy | `python3 scripts/exit_stage_2.py --case method-policy` | Rejects methods not allowed by critical policy | 0 | Three gates exited 1 with `METHOD_POLICY`; no ranking or upgrade |
| 2 / round trip | `python3 scripts/exit_stage_2.py --case round-trip` | Supplied evidence equals a fresh actual checker result | 0 | Gate 0; `cmp` 0 |
| 2 / policy controls | `python3 scripts/exit_stage_2.py --case policy-controls` | Rejects all 15 deliberately altered inputs | 0 | All gate calls exited 1; intended diagnostics retained |
| 2 / Stage 1 reproducibility regression | `python3 scripts/exit_stage_1.py --case reproducibility` | Retains byte-identical evidence across runs | 0 | Gate 0 twice; `cmp` 0 |
| 2 / Stage 1 planted-bug regression | `python3 scripts/exit_stage_1.py --case planted-bugs` | Retains all four intended rejections | 0 | Units 0; gates 1; verifiers 4 or audit 2 |
| 2 / Stage 1 spec-lock regression | `python3 scripts/exit_stage_1.py --case spec-lock` | Rejects a changed spec with old lock | 0 | Gate 1 with `SPEC_LOCK` |
| 2 / Stage 1 contract-binding regression | `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects missing explicit approved refinement | 0 | Gate 1 with `SOURCE_SCOPE` |
| 2 / Stage 1 audit regression | `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects the three proof escapes | 0 | Audits 2; gates 1 |
| 2 / final evidence comparison | `cmp evidence.json build/stage1/reproducibility/evidence.json` | Current root evidence equals tested reproducibility output | 0 | Byte-identical |
| 3 / JS toolchain installation | `npm install --cache .toolchain/npm-cache --prefer-offline --ignore-scripts --no-audit --no-fund --fetch-retries=0` | Installs pinned direct dependencies | 1 | `getaddrinfo ENOTFOUND registry.npmjs.org`; user later installed externally |
| 3 / installed dependency check | `npm ls --depth=0` | Prints exact requested installed versions | 0 | All five direct pins match |
| 3 / tsx CLI prerequisite | `npx --no-install tsx --version` | Runs the pinned CLI | 1 | tsx 4.21.0 printed, then `listen EPERM` for local IPC |
| 3 / real JS model build | `python3 scripts/build_model.py` | Compiles the actual approved model with pinned Dafny settings | 0 | 12 verified, 0 errors; module digest recorded |
| 3 / loader demo | `node --import tsx app/main.ts` | Runs actual generated ledger through the bridge | 0 | `Ok`, then `Rejected`; not a substituted npx result |
| 3 / TypeScript check, attempt 1 | `npx --no-install tsc --noEmit` | Type-checks the implementation, bridge, app, and properties | 2 | The example input array needed a one-element tuple shape |
| 3 / TypeScript check, attempt 2 | `npx --no-install tsc --noEmit` | Same static check after the reported tuple fix | 0 | No diagnostics |
| 3 / correct TypeScript | `python3 scripts/exit_stage_3.py --case correct-typescript` | Actual comparison properties and gate pass | 0 | 300 seeded runs; 3,506 comparisons |
| 3 / planted self-transfer | `python3 scripts/exit_stage_3.py --case self-transfer` | Actual comparison rejects the planted bug | 0 | fast-check 1; gate 1; counterexample retained |
| 3 / evidence labels | `python3 scripts/exit_stage_3.py --case evidence-labels` | Distinct methods, bound source/model/TS artifacts, no proof upgrade | 0 | Source and TS gates 0; critical-tier TS gate 1 |
| 3 / deterministic reproduction | `python3 scripts/exit_stage_3.py --case reproducibility` | Builds and evidence reproduce byte for byte | 0 | Both gate calls 0; actual cmp 0 |
| 3 / loader scenario | `python3 scripts/exit_stage_3.py --case loader-demo` | Records actual loader stdout | 0 | Exact expected lines; npx EXIT still pending |
| 3 / original CLI demo | `npx tsx app/main.ts` | Runs the original demo invocation | 1 | `listen EPERM` for its local IPC socket; raw report under `build/stage3/cli-demo/` |
| 3 / original CLI scenario | `python3 scripts/exit_stage_3.py --case cli-demo` | Requires original CLI exit 0 and expected output | 1 | Actual child command failed; not counted as a passing EXIT |
| 3 / approved replacement, final run | `node --import tsx app/main.ts` | Runs the user-approved replacement invocation | 0 | Printed exactly `Ok` then `Rejected`; supersedes the original demo invocation only |

Record failed attempts as well as successful ones. Keep negative-checker codes
separate from their scenario script's code. Do not erase earlier failures.
The first failed scenario reports predate automatic log archiving. Their raw
files were overwritten during development. The observed failures above and in
U020 are retained; no missing raw log has been reconstructed or claimed.
Stage 2 preparation had one parse-time script error, exit 1, from a Unicode dash
inside a Python bytes literal. No statements ran. The corrected UTF-8 script
exited 0. This was not a checker or toolchain failure; see U025 and the Stage 2
result record. All Stage 2 EXIT scenarios passed on their first run.

## Open items

- Runtime provenance: Node and Python installer origins were not independently
  authenticated. Their checked versions and executable hashes are pinned. Keep
  the disclosed trust assumptions in `toolchain/pins.json` and `unsure.md` U015.
- Stage 8 is DONE after the exact approved snapshot repair and all three passing
  EXITs. Source proofs, finite runtime testing and unmeasured model quality stay
  distinct. Stage 9 is CURRENT; its implementation has not started. Deployment
  correctness remains unproved; `end_to_end=false`. Prior measurements retain
  their limits, and all historical failures remain archived.
- Publication: the user created [mack-dot/forge](https://github.com/mack-dot/forge).
  The connected app confirms public visibility, the mack-dot owner, and push
  access. The earlier 404/creation blocker is resolved. Publication uses that
  app because the local CLI could not connect and local `.git` writes are denied.
  Preserve the earlier failed commands as history; publication verification is
  recorded in the append-only `unsure.md` log.
- Distribution: choose an open-source license before describing a published
  repository as licensed for open-source reuse. Public visibility alone does
  not supply a license.



## Integration-readiness security continuation — 2026-11-02 (U208)

CURRENT remains none; Stage 11 merged. Stage 12 is not authorized.
The owner authorized receipt-authentication investigation and a proposed repair.
The original gate accepted a corrupted receipt without executing booking proof.
The security finding is confirmed; current GitHub main/#30 are not repaired.
The separate three-file repair and two-file hosted experiment remain unapproved
and unpublished. Full review and raw records: results/ops-readiness/receipt-auth-2026-11-02/STATUS.md.

| Actual command / case | Exit code | Observed result |
| --- | --- | --- |
| `python3 -B proposals/receipt-authentication/reproduce.py --repo /Users/mackianni/forge-linux --out /private/tmp/forge-receipt-auth-original-20261102` | 1 | Security regression FAILED: genuine cold gate 0; corrupted receipt adopted by full gate 0, without fresh booking proof. |
| `python3 -B proposals/receipt-authentication/prepare.py` | 0 | Isolated proposed repair, no change to #30. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9 --check` in proposed checkout | 0 | All locked inputs verified. Same command with old ac883083… lock: 1, IMPLEMENTATION_LOCK rejection. |
| `python3 -B proposals/receipt-authentication/regression.py --root /private/tmp/forge-receipt-auth-repair-20261102 --out /private/tmp/forge-receipt-auth-regression-20261102` | 0 | Ten parent-process cases and one genuine new-process test passed their assertions. |
| Repair A cold / B warm / C invalidated / B restored | 0 / 0 / 0 / 0 | Real proof / valid same-process reuse / real proof / valid reuse. |
| Receipt / artifact / coordinated rewrite / stale identity / protected harness / prior process | 1 / 1 / 1 / 1 / 1 / 1 | Specific fail-closed refusals. No accepted evidence. |
| Uncovered change | 3 | UNSUPPORTED. |
| Exact reproduce_cmd from repair A evidence, in new interpreter; argv retained in repair-results/cli-replay.json | 0 | Fresh booking proof; byte-identical evidence; no prior-process adoption. |
| `git apply --check` for repair.patch and booking-ci.patch in unchanged #30 checkout | 0 / 0 | Patch checks only; no application to #30. |
| `python3 -B proposals/receipt-authentication/prepare_hosted.py`; final syntax/YAML validation | 0; 0 | Draft manual booking-only workflow and harness. No Node. |
| Hosted harness actual local invocation (exact argv in proposal-validation.json) | 1 | Refused non-hosted execution before proof commands. |
| `python3 results/ops-readiness/integration-2026-11-02/check_archives.py /Users/mackianni/forge-backups` | 0 | Both archives intact; 10,160 members each; independent backup unconfirmed. |

Local A/B/C wall samples: 43.028 / 18.674 / 36.431 seconds. No hosted cost or
savings claim. Cross-run receipt authentication remains unsupported; new CLI
processes compute fresh proofs under the proposed containment. Linux/hosted
acceptance and billed runner-minutes: NOT RUN / not measured. Existing Stage 11
EXITs remain historical results, not validation of this repair.

Blockers: exact #30 owner review (head unchanged; zero reviews); separate repair
review/publication/merge authorization; full administrator protection exports
(403 remains); independent backup and remote read-back; separately approved
workflow and authorized exact-head dispatch. No signing-policy, protection,
deployment, Stage 12 or SPM change. Stop at the approval boundary.


U209 packaging checks: all 310 new package files match (shasum exit 0), manifest
`1e6f0fc473c88f3c13c28cdb290175cef18f90ab5a34e92748c3941b77813009`.
The previous 52-file integration and 28-file review manifests also pass (0, 0).
These are local integrity checks, not independent backup or provenance admission.


## Integration final local acceptance — 2026-11-02 (U210)

CURRENT remains none. Stage 12 unauthorized.

| Actual command / case | Actual exit | Result |
| --- | --- | --- |
| Original receipt corruption control (exact argv in finalize commands.json) | 1 | Security failure reproduced; full gate cold/corrupted both 0. |
| Committed tests/integration/receipt_authentication.py, root /private/tmp/forge-auth-final-reviewed-20261102, output /private/tmp/forge-auth-final-reviewed-results-20261102 | 0 | All 13 acceptance cases passed. |
| A cold / B warm / C invalidation / B restored | 0 / 0 / 0 / 0 | Actual booking launches 1 / 0 / 1 / 0. |
| Receipt / artifact / coordinated / stale / harness / prior process / missing anchor / invalid anchor | 1 each | Specific required refusals; no accepted evidence. |
| Uncovered file | 3 | UNSUPPORTED. |
| Actual separate-process reproduce command | 0 | Fresh booking proof; byte-identical evidence. |
| Main / #30 production patch dependency checks | 1 / 0 | Exact patch requires #30 first. |
| Original archives / previous 310-file manifest | 0 / 0 | Integrity only; independent backup unconfirmed. |
| integration_exit.py with final matrix/readiness records | 1 | NOT_ESTABLISHED: operational approvals and hosted evidence missing. |

First rerun failed due to stale test-fixture path (1); preserved, corrected, and
complete matrix rerun. Local PR head 6cfec85e3890378067cbf8142e13f8bae4cac429;
not published. Main/#30 unchanged. Hosted matrix/measurements NOT RUN. Exact
commands, source/evidence hashes, refusals and blockers are in
results/ops-readiness/finalize-2026-11-02/STATUS.md and commands.json.
Stop at publication/review/merge/dispatch authorization boundary; no Stage 12.


U211: Final package: 343 files, all hashes checked (exit 0). Manifest SHA-256 ff8afd6a10f34c9457be4a12b952e4558a7e6241ef9916cfebbf6f7b005ba9f0. No hosted execution or stage transition.


## Integration publication — 2026-11-02 (U212)

CURRENT none; Stage 12 unauthorized. User authorized repair PR publication only.

| Executed command/action | Actual result |
| --- | --- |
| git push exact prepared commit to new repair branch | 128; DNS failure |
| GitHub connector publish five-file tested tree and new branch | API success; remote b24fe624, tree equals tested b3cb9c42 |
| gh pr create stacked repair, prepared body | 1; GitHub API connection failure |
| gh pr list repair head | 0; empty, PR not created |
| git ls-remote repair/#30 branches | 0; b24fe624 / unchanged 561d2dda |

PR creation blocked on contributor API access. Working connector is sole code
owner; no owner-authored replacement or self-review created. Exact command and
body retained in results/ops-readiness/publication-2026-11-02/STATUS.md.
Prior 13-case local evidence unchanged; no new hosted result. No merge, workflow
publication, dispatch or stage transition. Integration EXIT NOT_ESTABLISHED.


## Repair draft publication — 2026-11-02 (U213)

CURRENT none; Stage 12 unauthorized.

| Executed action | Actual result |
| --- | --- |
| Contributor gh pr create retry | 1; API connection failure |
| Connected GitHub create draft PR | API success: #31 |
| Fresh PR metadata verification | Expected head b24fe624, base 561d2dda, five files, draft, unmerged |

User authorized proceeding with publication. PR: https://github.com/mack-dot/forge/pull/31.
Owner-authored draft still needs resolution of independent code-owner review;
no self-review, merge, workflow publication or dispatch. Proof tests not rerun.
Integration EXIT remains NOT_ESTABLISHED; operational blockers remain open.


U214: User approval acknowledged. Fresh #30/#31 review lists are empty; heads
unchanged and unmerged, #31 still draft. No self-approval, merge or bypass.
Required independent GitHub reviews remain absent. No EXIT commands rerun.
CURRENT none; Stage 12 unauthorized.


U215: At the owner's explicit instruction, submitted APPROVE for PR #30 exact
head 561d2dda904daf18f17a0fede93f28b502d72884. GitHub API success, review
5740665331; fresh list confirms APPROVED by mack-dot. No proof EXIT rerun,
merge, review bypass, PR #31 self-approval or dispatch. CURRENT none.


## PR #30 merge and hosted protected-change refusal — 2026-11-02 (U216)

CURRENT none; Stage 12 unauthorized. #30 merged at e7b5b52a after explicit
owner approval and merge authorization. No --admin or policy change.

| Executed command/case | Actual code/result |
| --- | --- |
| gh pr merge 30 --squash --match-head-commit 561d2dda… | 0; e7b5b52aad5d020224dd057e1019004b15dc8739 |
| Reparent #31 unchanged tested tree onto merged main | API success; head 9a0247e9, five-file diff |
| Real hosted trusted gate, run 41500184981 | 1; UNAPPROVED_PROTECTED_CHANGE, zero proof commands |
| Hosted report | success; publishes rejection |
| gh run view / gh pr view / git ls-remote | 0; final states confirmed |
| Full classic protection endpoint | HTTP 403 |

Observed job minutes: (71+50)/60 = 2.0166667, not billed cost. Booking hosted
A/B/C and security matrix NOT RUN. PR #31 draft review/authorship blocker,
independent backup and complete protections remain pending. Exact evidence:
results/ops-readiness/merge-2026-11-02/STATUS.md. Integration EXIT NOT_ESTABLISHED.


U218 contributor publication attempt: account switch 0; git push 128 (DNS),
API ref creation 1 (connection). No replacement created. Both cached accounts
exist; later local metadata reports owner active. Prepared contributor script
shell syntax 0; execution NOT RUN. Missing capability is contributor write API
access, not user authorization. No merge/dispatch/stage transition.


## Contributor repair PR verified — 2026-11-02 (U219)

CURRENT none; Stage 12 unauthorized. #32 replaces draft #31, author mackiannii,
head 9a0247e9, five files, exact tested tree. Closed #31 without merge.

| Actual command/case | Actual result |
| --- | --- |
| GitHub replacement/tree verification | API success; matches tested source |
| gh pr view 32 | 0; REVIEW_REQUIRED, not draft, BLOCKED |
| New hosted gate, run 41502156222 | 1; UNAPPROVED_PROTECTED_CHANGE; zero proof commands |
| Close superseded #31 | API success; unmerged |

No repair approval/merge, proof rerun, workflow dispatch or stage transition.
Next boundary: exact-head owner approval and explicit repair merge authorization.


U220: Actual owner approval of #32 verified at exact head 9a0247e9. gh pr view
exit 0: APPROVED, MERGEABLE, UNSTABLE (old protected-change refusals). No
merge/dispatch or proof EXIT rerun. Separate repair merge authorization pending.


## Receipt repair merged — 2026-11-02 (U221)

CURRENT none; Stage 12 unauthorized.

| Executed command/case | Actual result |
| --- | --- |
| gh pr merge 32 --squash --match-head-commit 9a0247e9… | 0; merged edd9f9d95b315ea9985c9d892522923a457a3964 |
| Merged tree identity | API verified b3cb9c42…, identical to tested repair |
| Prepared booking workflow patch/syntax/permissions/pins checks | 0 |
| New local/hosted proof matrix | NOT RUN |

Next: separately authorized workflow publication/review/merge and exact booking
CI dispatch. No signing, Node, protection or Stage 12 changes. Integration EXIT
still requires hosted results and independent backup/protection confirmation.


## Booking workflow publication preparation — 2026-11-02 (U222)

CURRENT none; Stage 12 unauthorized. User authorized workflow PR publication.

| Executed action | Actual result |
| --- | --- |
| Exact main/tree and two-file compare verification | API success |
| Workflow tree/commit preparation | API success; db5b76f0, tree 624ef75c |
| Contributor account switch | 0 |
| Contributor API branch creation | 1; network failure, no branch |
| Booking publication helper syntax | 0; execution NOT RUN |

Prepared contributor terminal helper. It publishes only; no merge/dispatch.
CLI restore failed under default token override; contributor remains locally
selected until helper restores owner. No hosted verification result claimed.


## Booking workflow PR verified — 2026-11-02 (U223)

CURRENT none; Stage 12 unauthorized. Contributor PR #33 is published with exact
prepared two-file tree; no duplicate owner-authored PR created.

| Actual command/case | Result |
| --- | --- |
| Session publish-booking-ci.sh attempt | 1; auth switch blocked |
| Independent GitHub PR/tree checks | API success; #33, db5b76f0, tree 624ef75c |
| gh pr view 33 | 0; REVIEW_REQUIRED/BLOCKED |
| Hosted trusted PR gate, run 41508999466 | 1; protected .github changes refused, zero proof commands |

No workflow approval, merge or dispatch. Hosted booking matrix remains NOT RUN.
Exact review/merge and later dispatch authorizations remain required.


## Booking workflow installed — 2026-11-02 (U224)

CURRENT none; Stage 12 unauthorized.

| Executed action | Actual result |
| --- | --- |
| Owner-directed exact-head APPROVE #33 | API success; review 5742634728 |
| gh pr view 33 | 0; APPROVED/MERGEABLE |
| gh pr merge 33 --squash --match-head-commit db5b76f0… | 0; merge f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3 |
| Merged workflow tree check | API verified 624ef75c…, approved contents unchanged |
| Exact one-file booking demo commit prepared | API object creation; 46e5aa426bf7800df7c98c732a764337e716f6bb |
| Booking PR / manual workflow dispatch / new proof matrix | NOT RUN |

No admin override, protection change, Node/signing/cross-run reuse or stage
transition. Next boundary: exact candidate publication and hosted dispatch
approval. Evidence: workflow33-merge-2026-11-02/state.json.


## First genuine hosted booking change — 2026-11-02 (U225)

CURRENT none; Stage 12 unauthorized. Owner authorized PR #34 and exact dispatch.
PR #34 candidate 46e5aa42, approved workflow/main f9eb1cbc, one file.

| Executed command/case | Actual result |
| --- | --- |
| Publish exact booking branch and draft PR #34 | GitHub API success |
| gh workflow run booking-reuse.yml, PR 34/head 46e5aa42 | 1; API connection failure; no manual run |
| Automatic hosted trusted gate, run 41516908347 | 0/VERIFIED; complete coverage, booking established fresh |
| Actual separate CLI reproduce command | 0; evidence byte-identical |
| Artifact upload / reporting | FAILURE; invalid colon filename / artifact missing |
| Overall PR workflow | FAILURE; not a passing pipeline |
| Receipt reconstruction and canonical evidence SHA-256 check | 0 |
| Artifact packaging patch preimage and filename checks | 0; fix not installed |
| Original archives checker | 0; independent backup unconfirmed |
| Strict integration status | 1; NOT_ESTABLISHED |

Actual job elapsed sum 108 s = 1.8 job-minutes; booking obligation reports
16.473 s; combined gate+fresh replay step 55 s. Billed cost unknown, no savings
claim. Manual warm/invalidation/adversarial matrix NOT RUN. No Stage 12.
Full evidence and exact identifiers: results/ops-readiness/hosted-demo-2026-11-02/STATUS.md.


## Assurance campaign audit and safe reproduction — 2026-11-02 (U226)

CURRENT none; Stage 11 merged. Stage 12 unauthorized. No stage transition.
Source main f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3; PR 34 unchanged at
46e5aa426bf7800df7c98c732a764337e716f6bb. No protected source change.
Exact argv/cwd and raw records: results/campaign-audit-2026-11-02/commands.json.

| Actual command / case | Actual exit | Result |
| --- | --- | --- |
| `python3 -B gate/gate.py --impl impl/Ledger.dfy --tier critical --check-evidence evidence.json --evidence build/campaign/ledger.json` in current-main clone | 0 | Fresh C1–C5 source proof; committed evidence matches. |
| `python3 -B gate/booking.py --evidence build/campaign/booking.json --work build/campaign/booking-work` in current-main clone | 0 | Fresh B1–B4 source proof. |
| Unchanged `tests/integration/receipt_authentication.py`, exact root/out in security-command.json | 0 | All 13 expected local cases; booking launches cold/warm/invalidation/restored 1/0/1/0. |
| Altered receipt / artifact / coordinated / stale / harness / prior process / missing anchor / invalid anchor | 1 each | Expected specific refusals, no accepted evidence. |
| Uncovered implementation | 3 | UNSUPPORTED / UNCOVERED_CHANGE. |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9 --check` in clean clone | 0 | BOOTSTRAP_VERIFIED. |
| Same bootstrap after local .toolchain symlink | 1 | ROOT_IMPORTABLE:.toolchain; expected guard, no policy change. Separate clean clone rerun 0. |
| `python3 -B gate/gate.py --schema-only results/stage7/accepted/own/evidence.json` | 0 | Structure only; not a proof. |
| `python3 -B scripts/stage7_emit_evidence.py --attempt results/stage7/own-proof/attempt-0001 --output /private/tmp/forge-campaign-serialized-20261102` | 0 | Historical serialization only; three cmp checks 0. |
| Frozen Stage 9 production receipt/package component audit | 0 | Bytes checked; stale challenge/wrong ELF rejected. No new crypto/admission. |
| `file` / `objdump -f` / `objdump -d` on exact ELF | 0 / 0 / 1 | Format identified; installed disassembler lacks RISC-V target. |
| `docker info --format '{{.ServerVersion}}'` | 1 | Socket permission denied; fresh kernel replay NOT RUN. |
| Exact authorized `gh workflow run booking-reuse.yml` for PR 34/head 46e5aa42 | 1 | API connectivity failure; no dispatch started. |
| Direct `gh run list` for booking-reuse.yml | 0 | Empty; full hosted matrix still NOT RUN. |
| Existing original archive checker | 0 | Both archives intact; independent backup unconfirmed. |
| Existing integration_exit.py with fresh local matrix and recorded readiness | 1 | NOT_ESTABLISHED; hosted/backup/protection blockers remain. |
| `git apply --check` artifact-path repair | 0 | Patch only, not installed or published. |
| `python3 -B results/campaign-audit-2026-11-02/validate_records.py` | 0 | Audit metadata consistent; not a custom proof checker. |

Local suite 181.530 s; cold/warm/invalidation 28.319/15.945/26.704 s. No billed
cost, matched baseline or savings claim. Historical hosted 108 s/1.8 job-minutes
remain a failed ordinary PR workflow, not the full matrix. Binary theorem and
historical release identity are partial; actual RISC-V execution, fresh independent
kernel replay and source-to-JavaScript semantics remain missing. end_to_end=false.
Report/graph/acceptance and exact next review packet are in
results/campaign-audit-2026-11-02/ and proposals/ci-artifact-paths/APPROVAL.md.
No new signing, publication, merge, policy, deployment, Node, SPM or Stage 12 work.

U226 package integrity: 172 files checked, actual exit 0. Manifest SHA-256
`6f66bdfb7972a5f713bfc95bbce2e507ee2fb64e75b0a177ff0bfa619042a613`.
This is a local integrity index, not provenance authentication or independent backup.


## Reviewable local packaging repair and runtime source audit — 2026-11-02 (U227)

CURRENT none; Stage 12 unauthorized. Existing main/PR 34 identities unchanged.
Prepared local commit 705457e069abbe399128808b1efc7242d8eaeaa1, tree
6b711b27efcd5c22248424a44d102b0dac6ae7ce. Only the previously proposed
ordinary PR upload path changes. No publication, approval, merge or dispatch.

| Actual command / case | Actual exit / result |
| --- | --- |
| `git ls-remote` main / `gh pr view 34` / booking `gh run list` | 0 / 0 / 0; unchanged identities, empty manual run list. |
| Isolated clone, patch preimage/application, `git diff --check`, exact one-file compare, local commit | 0 each; proposed workflow bytes match exactly. |
| `git bundle verify`, fresh bundle clone, exact checkout, `git fsck --strict`, replay diff check | 0 each; local source/tree/file integrity only. |
| curl QEMU release archive signature | 6; cannot resolve download.qemu.org. |
| Classic protection / effective rules generic fetch | HTTP 403 / tool HTTP 400; effective controls unverified. |
| Hosted matrix / RISC-V execution / fresh independent kernel replay | NOT RUN. |

Exact argv and local bundle: results/campaign-preparation-2026-11-02/. Review
packet: proposals/ci-artifact-paths/READY.md. It needs publication authorization;
the existing exact hosted-dispatch authorization is not missing owner consent.
QEMU source candidate commit 005c61c0… identified, but source authentication,
runtime build/dependencies and executable identity remain unestablished. Its
configure source requires Linux for linux-user; this Darwin host cannot provide
that path. No installation or execution attempted. Backup/admin/export/access
blockers remain; integration EXIT NOT_ESTABLISHED, end_to_end=false.

U227 integrity check: actual exit 0; 12 new files and all 172 prior frozen audit
files checked. New manifest SHA-256
`5a16cfb4a7d54f92322f7c1349ad658f5b2e8c80f9710f26f90cd663caf1d4c7`.
No independent backup or provenance authentication follows from this check.


## Revalidated external blockers — 2026-11-02 (U228)

CURRENT none. Stage 12 unauthorized. Previous turn made concrete preparation
progress; the same execution/access and publication boundaries remain for a third
consecutive goal turn. No further safe engineering step closes those boundaries.

| Actual command / case | Actual exit / result |
| --- | --- |
| `git ls-remote` main / `gh pr view 34` | 0 / 0; identities unchanged, PR draft/unmerged. |
| booking `gh run list`, before and after dispatch attempt | 0 / 0; both empty, no live manual run. |
| Exact U225-authorized `gh workflow run booking-reuse.yml` | 1; API connection failure. |
| `docker info --format '{{.ServerVersion}}'` | 1; socket operation not permitted. |
| Classic protection API | HTTP 403; effective controls remain unverified. |
| Backup read-back existence query | 0; expected destination-integrity.json absent, backup unconfirmed. |

Goal blocked audit meets the three-turn threshold. Request status blocked;
do not mark complete. Current source proofs/local security evidence stay recorded;
full hosted matrix, real RISC-V execution and fresh independent kernel replay
remain NOT RUN. Packaging commit 705457e0 is local and requires separate
publication authority. Existing exact booking dispatch already has authorization.
Evidence: results/campaign-preparation-2026-11-02/blocked-audit.json.
No new stage, policy, signing, publication, merge, deployment or SPM work.


## Hosted integration and exact-binary runtime audit — 2026-11-02 (U229)

CURRENT none. Stage 12 unauthorized. Owner resumed the campaign and authorized
publication of the exact prepared packaging repair. No stage transition occurred.
Earlier access failures in U225–U228 remain historical. Current authoritative
report and exact argv/cwd records: results/campaign-resume-2026-11-02/.

| Actual command / execution | Actual exit / result |
| --- | --- |
| `gh workflow run booking-reuse.yml --repo mack-dot/forge --ref main -f booking_pr=34 -f booking_head=46e5aa426bf7800df7c98c732a764337e716f6bb` | 0; run 41523691535 succeeded on GitHub-hosted Linux. |
| Hosted trusted 13-case harness | 0; all expected outcomes matched; cold/warm/invalidation/restored Booking launches 1/0/1/0. |
| Hosted A / B / C / restored gate returns | 0 / 0 / 0 / 0; covered, exact evidence bound, supported reuse only. |
| Hosted eight adversarial gate returns / uncovered return | 1 each / 3; expected refusals; no accepted evidence. |
| `python3 -B results/campaign-resume-2026-11-02/audit_hosted.py` | 0; API/run/source/ZIP digest, proof bytes, expected reasons and launches checked. |
| Fresh GitHub main / PR 36 reads | 0 / 0; main f9eb1cbc unchanged; PR 36 head 705457e0, OPEN, REVIEW_REQUIRED, no reviews. |
| Classic protection / effective rules / inherited rulesets reads | 1 (HTTP 404, Branch not protected) / 0 / 0. |
| Historical `signature_only.py` isolated new process | 0; real TUF/Cosign, 4.599941 s. Exact argv: signature-command.json. |
| Historical `verify_historical_bundle.py` isolated new process | 0; unchanged full release.verify, 68.136261 s. Exact argv: historical-bundle-command.json. |
| QEMU source GnuPG verification / Ubuntu package chain checks | 0 / 0; distinct authenticated versions; no source build or proof-image package install. |
| Initial exact-ELF mounted load | 1; no guest trace; cause unknown, preserved. |
| Exact-byte tmpfs ELF execution under pinned QEMU | 0; exit_group(0), 87.408430 s orchestration. Exact argv: riscv-copy-command.json. |
| Existing-predicate `ObservedStack.v` real Rocq compile | 0; observed SP violates Sv48 precondition; 577.665 s. Exact argv: stack-precondition-command.json. |
| Approved case-sensitive Stage 7 restoration | 0; exact image/source/ELF and original resource settings. |
| `python3 scripts/exit_stage_7.py --case own-proof` | 1; container 137; inspect/collect 1/1 after disappearance; 1496.251277 s; fresh kernel result NOT_ESTABLISHED. |
| Bounded Docker events reader | 1; reader timeout; destruction/OOM cause UNKNOWN. |
| `python3 -B proposals/binary-proof-replay/validate.py` | 0; six bash syntax checks, inline Python AST, setup/pin/permission comparisons and git apply --check. Hosted workflow NOT RUN. |
| `python3 -B results/campaign-resume-2026-11-02/update_assurance_graph.py` | 0; metadata only, 24 claims / 312 links; original sealed graph unchanged. Initial missing-record reference error 1 preserved separately. |
| Existing `proposals/receipt-authentication-final/integration_exit.py` with resumed readiness | 1; NOT_ESTABLISHED, off-machine backup unconfirmed. Exact argv: integration-exit-command.json. |

Hosted A/B/C times: 28.525340852 / 9.931031468 / 28.552900072 seconds.
Summed job consumption: 198 seconds = 3.3 runner-minutes. Public standard Ubuntu
usage reports 0 billable milliseconds, not zero computation or measured savings.
Warm still performs outer-ledger work. It skips only the Booking verifier.
Artifact 13179905102 ZIP SHA-256:
372cd7781b1be493a13bbd4398cb6871cbf2effe6458810425dd25fcf49efbf1.

H1 is ESTABLISHED within the supported same-process boundary. C invalidates the
Booking helper source; no separate cross-file dependency/model/policy case ran.
Raw Booking logs/TRX are retained; raw outer-ledger snapshot/audit/version logs
are absent from this upload. Prior/current hosted outer evidence bytes match;
only the earlier Booking digest survives, not its raw proof bundle.

PR 36 publishes exactly 705457e0. An initial owner-authored PR 35 was closed
unmerged and replaced with contributor-authored PR 36. No review identity was
used to self-approve. Independent exact-head review and merge authority remain.
The observed effective ruleset requires review but has no required status checks
or workflows. No protection setting or acceptance rule was changed.

E1 remains PARTIALLY_ESTABLISHED. Historical exact-binary proof and freshly
verified historical release bindings do not cover the QEMU launch: initial SP
0x2aaaab2abc30 violates the existing valid_entry premise. No fresh full independent
kernel replay passed. No new theorem or runtime refinement is established.
E2 and generic cross-run reuse E3 remain NOT_ESTABLISHED. Historical signed-bundle
consumer validation passed in a new process only under its old exact lock/source.

Concrete separate proposals: proposals/booking-raw-logs/REVIEW.md (retain omitted
raw logs), proposals/binary-proof-replay/REVIEW.md (no signing/admission), and
proposals/runtime-entry-domain/REVIEW.md (additional abstract property, NOT RUN).
New workflow publication and subsequent dispatch need their corresponding exact
approval; new property intent needs separate human review. Existing production
signing and obsolete dry-run workflows were not dispatched as substitutes.

Strict integration EXIT remains NOT_ESTABLISHED. Original independent archive
backup is unconfirmed. Protection inspection is complete, but passing-check
merge enforcement is absent; this is a separate administrator policy decision.
No `end_to_end=true`, signing, new admission, deployment, Node, new persistent
infrastructure, protection change, SPM change or Stage 12 work occurred.

Final local record inventory: `python3 -B
results/campaign-resume-2026-11-02/seal_records.py` returned **0**. It read back
759 files/links, 317634383 inventory bytes. Manifest SHA-256:
acfc18180e2e46ae4c1e9c1af9a1727b485660e64db10eb647ded69165c2c1a1.
The first inventory attempt returned 1 on a normal runtime-package symlink before
creating a manifest. Its record is preserved; the final inventory records link
targets without following them. This local inventory establishes integrity only,
not provenance authentication or independent backup. Prior sealed records were
not rewritten. No further execution authority was inferred from an unanswered
workflow-publication question.


## Historical consumer controls and independent kernel recheck — 2026-11-02 (U230)

CURRENT none. Stage 12 unauthorized. Previous goal turn made progress. The full
campaign remains active and incomplete. This continuation acquired fresh remote
proof material, executed adversarial consumer controls and started a real
independent kernel check. No stage transition or protected source change occurred.

| Actual command / execution | Actual exit / result |
| --- | --- |
| Fresh main and PR36 reads | 0 /0; main f9eb1cbc, PR36 exact705457e0, review-required, no reviews. |
| Existing checker image pull | 0; exact approved digest, no source volume restoration. |
| Locked input/source preparation | 0;579 .vo inputs,45 Python files, exact86 upstream tool/allowlist files. |
| `gh api repos/mack-dot/forge/actions/runs/40966460258/artifacts` | 0; original signed artifact12939158560 unexpired. |
| `gh api repos/mack-dot/forge/actions/artifacts/12939158560/zip` | 0; fresh56,645,241-byte ZIP. |
| ZIP/API digest, safe-member/CRC and baseline byte comparison | 0; all881 file members /132,535,811 uncompressed bytes match old bundle. |
| Initial `campaign-consumer-controls-2026-11-02/run_controls.py` | 1; harness predicted wrong ELF rejection name; verifier correctly rejected. All records retained. |
| Corrected `campaign-consumer-controls-2026-11-02/attempt-0002/run_controls.py` | 0; all14 expected outcomes match. |
| Corrected consumer child exits | Three0 positives/probe; eleven1 expected refusals. Nine bindings have Cosign0; two signature cases have Cosign1 and intended diagnostics. |
| Corrected consumer raw-record audit | 0;14 cases /464 actual command-output hashes match. |
| Consumer record `seal_records.py` | 0;12,124 files/links,2,123,171,281 inventory bytes; both attempts retained. |
| Initial optional runtime metadata probe | 1; Rosetta path not visible inside container; no proof result affected. |
| Revised runtime metadata observation | 0; exact Rocq/Python hashes and missing translator visibility recorded. |
| Parent audit-tool membership and anchor recheck | 0; exact file set, no extra audit tool observed. |

The exact full Docker/kernel command is in
results/campaign-kernel-recheck-2026-11-02/attempt-0001/kernel-invocation.json.
Actual independent `rocqchk -o -bytecode-compiler no … ForgeChecked.Wrapper
ForgeChecked.WitnessWrapper` is **RUNNING**, with no terminal exit. It uses the
unchanged published `_rocqchk`, exact archived .vo inputs and original resources.
Raw logs stream to the host. Session24949 / container
forge-archived-kernel-recheck-20261102-0001 is the existing handle to inspect;
never restart it because a poll expires. postflight.py is NOT RUN pending a real
terminal success. An actual process, advancing log and resource observation
confirmed liveness; they do not prove completion.

Fresh signed ZIP SHA-256:
8ded75a093cb5d9c1e24f240c4209279b363e4d5fc3338a73a20b086c984cfb4.
It equals the authenticated API digest and previous ZIP; all881 held bundle
members match. This confirms off-machine storage for that historical signed
bundle only. Original raw/sanitized archive backup and later local records remain
unconfirmed. Source identity is historical624c9faf, lock5f78da21; never upgrade
those identities to current main's lock or a new release.

Independent review confirmed the consumer's correct isolation and all14 final
results. The initial fixture changes packaged.elf, so unchanged release.py:160
rejects PACKAGED_ELF_BYTES; the initial prediction RELEASE_ELF_IDENTITY referred
to the separate trusted reference check. Correcting that expectation did not
weaken a verifier or permanent regression. Signature-negative expectations were
strengthened to require observed intended diagnostics. Both full positive checks
passed in55.370986 /55.054855 seconds. These are local observations, not billed
runner-minutes, cache savings or an independent physical-machine test.

Independent kernel-driver review found no blocking defect in this intended
certificate check, with explicit host/import-surface assumptions. Exact audit
membership passed before launch and live; postflight requires it again. The
recorded Rocq binary is3b432fdf…; Docker/amd64 translation, host OS/hardware and
pinned-image publisher remain trusted. Source rebuild, new theorem, runtime
refinement and new admission are not claimed by a future kernel pass.

Consumer inventory manifest SHA-256:
73ac8f86ed618e85b77765e8edd6bb1a0f5db3b16be3ed7f5518dbbf7e8b80a7.
This local inventory is integrity only, not authentication or independent backup.
Previous sealed campaign records remain unchanged. The new graph checkpoint
retains24 claims/312 links and marks kernel completion IN_PROGRESS.

Current report: results/campaign-kernel-recheck-2026-11-02/attempt-0001/STATUS.md.
Exact reproduction notes: REPRODUCE.md in that directory. Consumer report:
results/campaign-consumer-controls-2026-11-02/attempt-0002/STATUS.md.
E1 remains partial because the observed QEMU SP violates valid_entry and the full
runtime/approved assurance-contract links are absent. H1 stays established within
its previous hosted same-process boundary. Strict integration EXIT remains
NOT_ESTABLISHED. E2 and generic cross-run cache adoption remain NOT_ESTABLISHED.
No new workflow publication/dispatch, approval, merge, signing, controller access,
admission, deployment, protection change, Node, SPM or Stage 12 work occurred.


## Independent proofs and recorded execution conformance — 2026-11-02 (U231)

CURRENT none. Stage 12 unauthorized. Both real kernel sessions are terminal0.
The full objective remains incomplete. This turn produced checked mathematical
results and execution evidence, not a new accepted stage or admission policy.

| Actual command / execution | Actual exit / result |
| --- | --- |
| Historical independent `rocqchk` via unchanged published audit |0;579 modules/86 permitted closure assumptions; container0/no OOM. |
| Historical `postflight.py` |0; exact command, all inputs unchanged and audit-tool membership match. |
| Additional initializer proposition `rocq compile` / published wrapper/audit |0 /0;13 permitted primitive assumptions; proposed claim only. |
| Memory-independent proposition `rocq compile` / published wrapper/audit |0 /0;13 permitted primitive assumptions. |
| Memory-independent full published `_rocqchk` |0;569 recursive modules/86 permitted closure assumptions, within exact581-object anchored pool. |
| Memory-independent postflight |0; required two new objects included, no extra loaded dependency, before/after hashes equal, no OOM. |
| Separate-process empty-directory theorem/wrapper rebuild |0 /0; both .vo objects byte-identical. |
| Stronger arbitrary-register computation experiment |137; OOMKilled=true under unchanged4GiB,65.094146s; NOT_ESTABLISHED, source/log/state retained. |
| Pinned QEMU help / debug-help |0 /1; debug-help prints usage; not a guest/proof rejection. |
| Pinned per-instruction QEMU exact-ELF execution |0;21 preinstruction frames/13 distinct words, terminalexit_group0. |
| Initial observation-comparison import attempt |1; wrong logical prefix, setup failure retained; no negative-control credit. |
| Corrected Rocq entry/register/codeword equality |0; exact observed entry plus all fetched words. |
| One-bit instruction-word corruption |1; intended equality refusal, not setup failure. |
| Full21-frame PC/GPR/FPR projected-step equality via published `run_steps` |0; arbitrary data memory, model steps0..20. |
| Intermediate frame4 x10-bit corruption |1; intended transition equality refusal. |
| Extended projected equality with arbitrary reservation/FCSR |0; same21 frames; negative remains1. |
| Published assumption parser for extended comparison |0;13 permitted primitive assumptions. |
| Local proposal diff/apply checks and Git bundle verification |0; exact local head5bb008a1, only11 proposal files; not published. |
| Initial proposal packaging diff check / outer preparation |2 /1; original QEMU trailing whitespace retained. Lossless log compression and final diff check0; no evidence stripped. |
| Fresh main / PR36 / effective rules reads |0 /0 /0; mainf9eb1cbc unchanged; PR36 review-required, no reviews; no required status/workflow checks. |

Historical kernel parent wall1533.486016s(driver1530.232012s). LogSHA:
17f533b4873ea0ba11ede10140b6b1c41289402398737056862e00508e935758.
New memory-independent parent wall1599.281454s(driver1598.600330s). LogSHA:
413c743d3f67dbcc431f9945b862baea3ce13fe1f59f04392b70679cb1b94aaf.
These are local Docker/amd64-emulation observations, not a native benchmark,
billed runner usage or savings. The prior source rebuild remains failed; checking
archived compiled certificates is not falsely reported as a source build.

The exact additional source is
proposals/runtime-state-projection/MemoryIndependent.v.proposed, SHA256:
ffe5a677e14b5d426196b3c8e56c821f4775037855b63c2a902c2f253c7cebfc.
It uses existing LPS semantics/soundness and arbitrary data memory. No accepted
specification, axiom list, checker, policy, image or source baseline changed.
A fresh process recreated theorem8462ea5a… and wrapper1fd3d856… byte for byte.

The exact ELF8ced2ab6… really executed. Rocq compared all21 raw projected states
against existing `Omni.run_steps`; no new decoder/ISA/iterator was implemented.
The extended equality quantifies data memory/reservation/FCSR. Step21 pending
syscall94,arg0 is model-only; actual exit_group0 is a separate observation.
The comparison objects have compiler acceptance, not a new full standalone
kernel replay. Universal QEMU refinement, full physical-state abstraction and
outside-noninterference are not established by finite conformance.

E3 under the campaign's actual independent-PROCESS validation definition is
ESTABLISHED for the named historical conditional termination/witness claim and
exact old artifact/lock. All six evidence-authentication/identity/proof/refusal
steps ran. Generic durable receipt adoption is a separate unsolved capability
and remains disabled. No signature was transferred to the additional claim.
E1 remains PARTIALLY_ESTABLISHED: model proof and actual projected conformance
exist; accepted claim/profile and new release/runtime/package bindings do not.
The old native valid_entry SP premise is still false for this QEMU launch.

The campaign already authorizes safe local investigation/tests. Earlier local-
compile permission wording was too broad; no unanswered question became consent.
Adopting a new specification/profile, publication, merge, signing, dispatch and
deployment still need their corresponding exact authority. The earlier proof-
only workflow is now optional for a hosted rebuild, not a false remaining local
kernel blocker. It was not published or dispatched.

Prepared local proposal head5bb008a1b7d40b8887d045f50eb55e54544bb76f,
tree44c0d88af2c94978729f5e83fa71b9045e0e25a0, basef9eb1cbc… . Only11 files under
proposals/fixed-elf-assurance/** change; no gate/workflow/schema/policy activation.
BundleSHAab64719c4ffa6fc699f6a7558f084a9c9a4adcf6c8256427438d0e16459fb868;
patchSHAfe98e4c68fe0006c833fbeb946834b207ca0a7ea7a08e39c54354a3818868680.
Exact readable approval packet: proposals/runtime-state-projection/review-packet/
README.md. Claim-intent and publication decision requested; no remote write yet.

Strict integration EXIT remains NOT_ESTABLISHED: original independent archive
backup is unconfirmed. GitHub storage of the historical signed bundle does not
back up the original raw/sanitized archives or later local records. The observed
missing required-check rule needs a separate administrator policy decision;
no settings changed. PR36 needs independent exact-head review. E2 remains
NOT_ESTABLISHED. No Node, generic cross-run adoption, signing, new admission,
deployment, SPM change or Stage12 work occurred. end_to_end=false.


## Independent observation kernel completion — 2026-11-02 (U232)

CURRENT none. Stage12 unauthorized. Integration EXIT remains NOT_ESTABLISHED.
No stage transition, accepted claim, gate, workflow or protection changed.

| Actually executed command / operation | Actual exit / result |
| --- | --- |
| Read back five frozen local inventories |0;195 entries/68767020 inventory bytes unchanged. |
| Fresh empty-directory observation-source `rocq compile` |0; .vo byte-identical,2.363891s. |
| Published independent observation `_rocqchk` |0;567 actual recursive modules/86 permitted closure assumptions. |
| Kernel container / `postflight.py` |0 /0; no OOM; all580 pool identities unchanged; required root included. |
| Existing `check_archives.py /Users/mackianni/forge-backups` |0;10160 members each, no mismatch; independent backup unconfirmed. |
| `gh api .../rules/branches/main` / `.../rulesets/26065125` |0 /0; active review rules; no required status/workflow checks. |
| `gh api .../branches/main/protection` |1;HTTP404 classic protection absent; ruleset remains active. |
| GitHub connector final PR34/PR36/review reads |Read succeeded; both exact heads unchanged/open; PR36 reviews empty. |

Kernel parent wall1488.771601s; driver1485.525275s. Raw logSHA256:
8d4ea9d50da50abe71e95bd7e3cbae1bf5d111228fa3b483769b660cce361482.
These are local emulation measurements, not hosted minutes or savings. Current
run records are results/campaign-observation-kernel-2026-11-02/attempt-0001/.
Actual closure/assumptions determine the result. Inherited unused wrapper hash
and old module lists are explicitly corrected; no wrapper check is claimed.

This closes the separate kernel-check gap for the finite recorded trace
comparison. Universal runtime refinement/full physical-state abstraction and
new release/admission binding remain open. Earlier frozen packet5bb008a1 remains
unchanged/unpublished; its pre-test NOT RUN wording is superseded by the local
OBSERVATION-KERNEL-SUPPLEMENT.md. Its proposed statement was not changed.
Read-only peer review found no blocker to this limited evidence statement.

Previous hosted booking run41523691535 and historical proof/consumer controls
were not rerun in this continuation. Their recorded results remain distinct.
E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical E3 independent-process
validation ESTABLISHED only within its named old claim/artifact/lock scope.
Generic cross-run receipt adoption remains disabled. end_to_end=false.

Remaining boundaries: proposed claim/publication5bb008a1 needs its exact owner
decision; PR36 needs independent review and separate merge authority; original
independent backup requires an owner-selected destination and remote full
validation; required-check policy needs an administrator decision. No reply was
inferred. No publication, approval, merge, dispatch, signing, new admission,
deployment, Node, SPM or Stage12 work occurred in this continuation.

Final local evidence inventory/read-back returned0:44 entries,5407226 bytes.
ManifestSHA256:cb6d04e3004d02e0a2f22a8ab166448c56d5eba970ebd612624eb02bfb87850c.
The inventory is an integrity record, not authenticated provenance or an
independent backup. No proof session remains running.


## Proof-object adversarial controls — 2026-11-02 (U233)

CURRENT none. Stage12 unauthorized. Previous goal turn made progress through
an actual567-module independent kernel check. These are additional local tests;
the positive kernel and prior hosted booking matrix were not rerun.

| Actually executed command / operation | Actual exit / result |
| --- | --- |
| Pinned `rocq compile` for a20-state weaker proposition |0; real valid fixture, same module/lemma names. |
| Existing driver with one-bit-corrupted root object |1; exact DEPENDENCY_BYTES:/observed/ObservedTransitions.vo. |
| Existing driver with compiled weaker proof object |1; same exact intended identity refusal. |
| `python3 -B results/campaign-observation-adversarial-2026-11-02/attempt-0001/run_controls.py` |0; both reason/outcome checks pass; original anchor/driver/source/object unchanged. |
| Fresh GitHub connector main/PR36/review reads |Read succeeded; mainf9eb1cbc, PR36 head705457e0, reviews empty. |

No kernel launches or OOM occurred in the negative cases. The weak fixture's
compiler success is intentional; the held original proof-object identity rejects
substitution of this valid but different statement. The corrupt object's generic
compiled-candidate flag describes its ancestor only; the raw record is preserved
and metadata-corrections.json states the distinction. Read-only independent
review confirmed the intended refusals. It is not human/GitHub approval.

Compilation elapsed4.600383s; identity refusals0.584913s/0.525794s. These are local
orchestration measurements, not full-kernel cost, hosted minutes or savings.
Actual commands, fixture hashes, raw logs and outcomes are in
results/campaign-observation-adversarial-2026-11-02/attempt-0001/.

This adds local held-anchor integrity evidence. It does not establish durable
new-claim provenance or coordinated expected-anchor/candidate rewriting resistance.
The prepared proposal5bb008a1 remains unchanged/unpublished/unapproved. No gate,
accepted specification, policy, workflow, signing, admission, deployment, Node,
SPM or protection changed. No cross-run receipt adoption or Stage12 started.

E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical E3 scoped validation
unchanged. Integration EXIT NOT_ESTABLISHED; end_to_end=false. Next decisions
remain exact claim/publication scope, independent PR36 review/separate merge
authority, independent backup destination/read-back and required-check policy.


## Native-cache measurement preparation — 2026-11-02 (U234)

CURRENT none. Stage12 unauthorized. This is safe local measurement of the
existing booking workload, not another stage or acceptance-mode installation.
U233 evidence seal/read-back actually returned0:29 entries/258474 bytes,
manifest60cf61cfa6efa0f844ad91c1197b36903f8e0bdce42a6c05678b8857a540479b.

| Actually executed command / operation | Actual exit / result |
| --- | --- |
| Pinned Dafny version / modern internal help |0 /0; version4.11.0+fcb2042d… . |
| `python3 -B .../run_pair.py` |0; full-booking witness/member coverage; native reuse observed. |
| Two fresh Dafny commands for A |0 /0;33 members checked each;10.793149s/10.842894s. |
| Native A→A snapshot-pair command |0;10.632152s for whole pair;33 checked then0 checked/33 reused. |
| `python3 -B .../measure_forge.py` |0; unchanged incremental.check A/B/C, complete coverage. |
| Forge cold / warm / invalidation gates |0 /0 /0; booking launches1/0/1; gate wall27.589211/10.510417/27.120746s. |
| Forge isolated booking verifier work |10.193022/0/10.170594s; zero means no warm booking command; outer ledger checks still run. |
| `python3 -B .../native_invalidation.py` |0; source C matches Forge; required members complete. |
| Full native C / native A→C pair |0 /0;11.614398s/13.920191s; pair first33 checked, C1 checked/32 reused. |

The native changed member is Booking.Least(correctness). The raw unchanged
checker/parser chooses native dependencies; Forge supplies no custom proof
checker. For the same changed source, Forge invalidates its complete booking
receipt and runs the real booking verifier again. A/B evidence bytes match;
C artifact/key/evidence differ. A/C retain238 passing TRX batches, normalizing
into the same33 native member names. Read-only independent review confirms
raw logs/source hashes/counts and no gate bypass. No approval follows.

Exact measurements, commands, frozen source/tool identities and raw logs:
results/campaign-native-cache-feasibility-2026-11-02/attempt-0001/STATUS.md and
its adjacent result records. Native reused-row timings/resources remain producer
values and are not summed as current warm work. Member names, TRX batches and
reported assertion counts are different units. Native pairs include cold work
and use one process; full pairs use two. Native legacy trace and Forge modern
JSON/TRX differ. Full Forge gate adds outer ledger/binding, policy, audit and
integrity work. Direct total-speedup comparison is invalid. One local fixed-order
preparation sample is not a repeated benchmark or hosted cost/savings claim.
A counterbalanced complete-acceptance-path comparison remains NOT RUN.

Mainf9eb1cbc and the unpublished claim/publication packet5bb008a1 remain unchanged.
No gate, policy, spec, workflow, provenance, admission or protection changed.
Generic cross-run reuse remains disabled. No new signing/deployment, Node, SPM
or Stage12. E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical scoped E3
unchanged. Integration EXIT remains NOT_ESTABLISHED; end_to_end=false. Owner
claim/publication decision, independent PR36 review/separate merge authority,
independent backup destination/read-back and required-check policy remain open.

U234 final local seal/read-back actually returned0:50756 entries,514264438
inventory bytes. ManifestSHA256:
4441959026ae295a85b4b59ad976fb0663aaabf6e441c67488d52914ea057673.
This inventories retained inputs/outputs; it does not authenticate provenance
or establish independent backup. All proof/measurement/seal processes are terminal.


## Owner-boundary revalidation1 — 2026-11-02 (U234 unchanged)

CURRENT none. Stage12 unauthorized. Previous goal turn made progress; this
continuation is no progress1, not a verified wait. Full objective not achieved;
goal remains active. No additional proof/benchmark was run or counted as new work.

| Read-only command / operation actually run | Actual result |
| --- | --- |
| GitHub main/PR34/PR36/review reads |Succeeded; mainf9eb1cbc, heads46e5aa42/705457e0, PR36 reviews empty. |
| Exact proposal5bb008a1 GitHub commit lookup |HTTP422:No commit found; no publication confirmed. |
| Local proposal git HEAD / status |0 /0; unchanged exact5bb008a1 and clean. |
| Three completed proof-container inspections |0 /0 /0; all exited0; no live proof process. |
| Expected destination-integrity.json presence |Absent; independent backup remains unconfirmed. |

Evidence:results/campaign-boundary-audit-2026-11-02/attempt-0001/ . Same genuine
boundary:exact owner claim/publication decision, independent PR36 review/separate
merge authority, independent backup destination/read-back and required-check
policy decision. No unanswered question, completed process or old authorization
became a new grant. Prior passing evidence is unchanged. No protected change,
publication, approval, merge, signing, admission, dispatch, deployment, Node,
SPM or Stage12 action. Integration EXIT NOT_ESTABLISHED; end_to_end=false.
First audit-recording orchestration parse failure made no file changes; corrected
recording succeeded. No proof/test result follows from that recording error.


## Owner-boundary revalidation2 — 2026-11-02 (U234 unchanged)

CURRENT none. Stage12 unauthorized. Previous/current goal turns are no progress;
consecutive count2. Revalidated mainf9eb1cbc, PR36 exact705457e0 open/unmerged,
reviews empty. GitHub reads succeeded. Local proposal git HEAD/status returned
0/0:exact5bb008a1 and clean. Expected destination-integrity.json remains absent;
independent backup remains unconfirmed, not disproved globally. No new owner
reply or authorization. No verifier/benchmark rerun; no live wait claimed.
Same genuine owner claim/publication, independent review/merge, backup and
required-check policy boundaries remain. Evidence:
results/campaign-boundary-audit-2026-11-02/attempt-0002/ . Goal stays active;
full objective not achieved. No protected change, publication, approval, merge,
dispatch, signing, admission, deployment, Node, SPM or Stage12 action.
Integration EXIT NOT_ESTABLISHED; end_to_end=false. Prior proof evidence unchanged.


## Owner-boundary revalidation3 — 2026-11-02 (U235)

CURRENT none. Stage12 unauthorized. Three consecutive goal turns made no
progress because the same owner-action boundary remained. No verified wait:
all known proof processes are terminal. Full campaign objective is not achieved.
The blocked-audit threshold is satisfied; a goal-tool blocked update follows
this record. Its returned status is authoritative. No completion claim.

| Read-only operation actually executed | Actual result |
| --- | --- |
| GitHub main/PR36/reviews |Succeeded; mainf9eb1cbc, PR36 head705457e0 open/unmerged, reviews empty. |
| Local proposal git HEAD/status |0 /0; exact5bb008a1, clean. |
| Three known proof-container inspections |0 /0 /0; no running process; earlier proof exits0. |
| Expected backup destination-integrity.json |Absent; independent backup remains unconfirmed. |

Records:results/campaign-boundary-audit-2026-11-02/attempt-0003/ . Same missing
exact owner claim/publication decision, independent PR36 review/separate merge
authority, independent backup destination/read-back and required-check decision.
Prepared actionable packet:proposals/runtime-state-projection/READY.md. Earlier
owner approvals do not become new claim/profile/publication/merge grants.
A new grant or external-state change is required. No proof/benchmark repetition,
new framework, protected change, self-approval, bypass, publication, merge,
signing, admission, dispatch, deployment, Node, SPM or Stage12 occurred here.
E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical scoped E3 unchanged.
Integration EXIT NOT_ESTABLISHED; end_to_end=false. Existing evidence preserved.


## Resumed draft-publication preparation — 2026-11-02 (U236)

CURRENT none. Stage12 unauthorized. User resumed the goal as active. Fresh
blocked audit; this turn makes progress, so no-progress count resets0. Resume
is not publication/claim/policy/signing authority. Full objective unachieved.

| Actually executed command / operation | Actual exit / result |
| --- | --- |
| Initial real gate on sparse5bb checkout |1; protected files absent on disk; setup mismatch, not intended coverage refusal. |
| Sparse index/config/blob diagnosis |0; S flags, sparseCheckout=true, blobs present. |
| First fetch using assumed bundle branch |128; bundle advertises HEAD; failure retained. |
| Corrected bundle HEAD fetch / full5bb checkout / clean checks |0; complete physical checkout, exact5bb. |
| Current incremental gate on full5bb |3;11 UNCOVERED_CHANGE paths; no evidence; every checker command0. |
| v2 packet/raw archive read-back and Git commit/diff/bundle checks |0; source theorems unchanged; original5bb preserved. |
| Current incremental gate on fullfc85 |3;14 uncovered proposal paths, no evidence, every existing checker command0. |
| Both coverage-control assertions |0; exact intended unsupported status and no evidence verified. |
| Patch-application check / Git object check / packet byte equality |0 /0 /0. |
| Contributor role/identity preflight |Read commands0;mackiannii, push=true/admin=false; token never printed/stored. |
| Remote proposal branch / matching PR reads |1 /0;HTTP404 branch absent, no matching open PR. |

New local headfc85ecc2c7f12caa6c8991fa002410bdf78dd51d,
treede8b0d3c97077ea52b64932ce591f5a1bd3fec02, basef9eb1cbc… . Only14
proposals/fixed-elf-assurance/** paths change. New data include completed
observation-kernel567/86 output/context and26 original compiled-object-integrity
records. No new kernel pass is inferred from packaging. Actual executions stay
in U232/U233. Independent readonly review confirms byte equality and resolved
stale status metadata. It is not independent owner/GitHub approval.

PatchSHA71054f2f984692a052bf671c8d20acf3d3667964ff5070870010454c01dab19d.
BundleSHA2da3d5ca280218c68a299421376703b1056e14c8130460e12f47978e5aab2567.
Prepared exact draft body/publication arguments/decision packet:
proposals/runtime-state-projection/publication-v2/ . Original5bb artifacts remain
unchanged. Current publication request is ONLY an exactfc85 contributor-authored
draft, not mathematical-claim/profile adoption. The new request supersedes the
unapproved5bb publication target. Owner response pending; no consent inferred.

Current CI gate refuses these uncovered data paths. No coverage exception,
workflow change, verified admission or merge eligibility is created. Existing
automatic PR checks may run after authorized publication; no manual dispatch
or hosted Rocq success is claimed. The publication plan uses an explicit GitHub
URL because origin is local, and rechecks actor/head/base/remote state first.
No actual push/PR creation, review, merge, signing, admission or deployment.

E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical scoped E3 unchanged.
Generic cross-run reuse disabled. Original independent archive backup unconfirmed;
required-check decision and independent PR36 review/separate merge authority
still open. No protected source, new framework/persistent infrastructure, Node,
SPM, branch protection or Stage12 change. Integration EXIT NOT_ESTABLISHED;
end_to_end=false. Raw records:results/campaign-publication-readiness-2026-11-02/attempt-0001/.

U236 final local inventory/read-back exits0/0. Readiness records:59 entries,
90550 bytes, manifestSHAe17d380434c467422b4de809b53ea758d50956fa51cd845a794ae02a859115ed.
Publication-v2 packet:23 entries,2405261 bytes,
manifestSHA5256d59f64b998c42566386f44e8297881c6f71f6cbac37ed8036f49fd0e0667.
These are local integrity inventories, not authenticated new-claim provenance
or an independent backup. All preparation/check processes are terminal. Exact
draft-publication response remains pending; goal active and not complete.


## Resumed owner-boundary revalidation1 — 2026-11-02 (U236 unchanged)

CURRENT none. Stage12 unauthorized. Previous resumed turn made real publication
preparation progress. This continuation only revalidates the unchanged boundary:
no progress1 in the fresh resumed audit, not a verified wait. Mainf9eb1cbc and
PR36 head705457e0 remain unchanged/open with no reviews. GitHub reads succeed;
exactfc85 lookup returnsHTTP422/no commit found. Local fc85 HEAD/status0/0,
clean. Expected destination-integrity.json absent; independent backup remains
unconfirmed. The explicit draft-publication question is unanswered; no new grant.
No proof/benchmark repeated, no live proof process claimed, no publication,
review, merge, dispatch, signing, admission, deployment, protection, Node, SPM
or Stage12 action. Old blocked counter is not carried across resume/progress.
Evidence:results/campaign-boundary-audit-2026-11-02/resumed-0001/attempt-0001/.
Goal stays active, full objective unachieved, Integration EXIT NOT_ESTABLISHED;
end_to_end=false. Exact current decision packet remains
proposals/runtime-state-projection/publication-v2/READY.md. Other owner review,
claim/profile, independent backup and required-check decisions remain separate.


## Resumed owner-boundary revalidation2 — 2026-11-02 (U236 unchanged)

CURRENT none. Stage12 unauthorized. Previous/current turns are no progress;
fresh resumed consecutive count2, not a verified wait. Fresh GitHub reads:
mainf9eb1cbc unchanged, PR36 head705457e0 open/unmerged/reviews empty, exactfc85
lookupHTTP422/no commit found. Local candidate HEAD/status0/0, exactfc85 and
clean. Expected independent-backup read-back absent; backup remains unconfirmed.
No owner publication answer or new authority. No proof/benchmark rerun, process
restart, publication, approval, merge, dispatch, signing, admission, deployment,
protection, Node, SPM or Stage12 action. All prior evidence remains scoped.
Records:results/campaign-boundary-audit-2026-11-02/resumed-0001/attempt-0002/.
Goal stays active; full objective unachieved. Integration EXIT NOT_ESTABLISHED;
end_to_end=false. Exact pending publication packet remains
proposals/runtime-state-projection/publication-v2/READY.md. Other claim/profile,
independent review/merge, backup and required-check decisions remain separate.


## Resumed owner-boundary revalidation3 — 2026-11-02 (U237)

CURRENT none. Stage12 unauthorized. U236 resumed preparation made progress;
three subsequent resumed turns made no progress at the same owner boundary.
Fresh audit threshold3 is satisfied; old pre-resume count is not reused.
No verified wait, full objective not achieved. A blocked goal-tool update
follows this record; the actual returned status is authoritative.

| Actual read-only check | Actual result |
| --- | --- |
| GitHub main/PR36/reviews |Reads succeed; mainf9eb1cbc, PR36 head705457e0 open/unmerged/reviews empty. |
| Exactfc85 GitHub commit lookup |HTTP422/no commit found; no publication confirmed. |
| Local exact proposal HEAD/status |0 /0;fc85ecc2 and clean. |
| Known proof-container inspections |0 /0 /0; no running process. |
| Expected independent backup read-back |Absent; independent copy remains unconfirmed. |

No owner publication answer. Exact sealed packet/body/publication plan remains
proposals/runtime-state-projection/publication-v2/ . Same genuine authorization
and independent-storage boundary; no further passing test supplies those facts.
No proof/benchmark repetition, process restart, protected change, self-review,
publication, merge, signing, admission, dispatch, deployment, protection, Node,
SPM, infrastructure or Stage12 action. Raw audit evidence:
results/campaign-boundary-audit-2026-11-02/resumed-0001/attempt-0003/ .
E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical scoped E3 unchanged.
Integration EXIT NOT_ESTABLISHED; end_to_end=false. Existing evidence preserved.


## Second resumed owner-boundary audit1 — 2026-11-02 (U237 unchanged)

CURRENT none. Stage12 unauthorized. User resumed goal as active again; fresh
blocked audit, no old count carried. Previous/current turns are no progress;
current fresh count1. This revalidation is not a verified wait or new proof.
GitHub reads show unchanged mainf9eb1cbc and PR36 head705457e0/open/unmerged/no
reviews. Exactfc85 lookup422/no commit found. Local HEAD/status0/0, exactfc85
and clean. Effective main-rules read0, byte-for-JSON data equal to the last
verified rules:deletion/non-fast-forward/linear history/PR review; no required
status checks. No protection changes.

Used Google Drive routing skill for metadata-only searches of exact raw/
sanitized archive/manifest names and related forge-records/forge-evidence names.
Both connector reads succeed with empty results. This does not prove absence
outside accessible searched files. No contents fetched or uploaded; no secrets
exposed; independent backup remains unconfirmed. Expected local remote read-back
file remains absent. No owner publication answer or new authority arrived.

Evidence:results/campaign-boundary-audit-2026-11-02/resumed-0002/attempt-0001/.
No source, proof, acceptance, publication, review, merge, dispatch, signing,
admission, deployment, Node, SPM, infrastructure or Stage12 action. Goal remains
active, not complete. Integration EXIT NOT_ESTABLISHED; end_to_end=false.
Exact pending draft publication remainsfc85ecc2 with decision packet
proposals/runtime-state-projection/publication-v2/READY.md. Independent owner
review/claim/profile/merge, backup and required-check decisions stay separate.


## Second resumed owner-boundary audit2 — 2026-11-02 (U237 unchanged)

CURRENT none. Stage12 unauthorized. Previous/current turns are no progress;
fresh second-resume count2, not a verified wait. Initial PR36 metadata read had
a transient server disconnect. Retry of the same read succeeded:PR36 head705457e0
open/unmerged/no reviews. Mainf9eb1cbc unchanged; exactfc85 lookup422/no commit
found. Local HEAD/status0/0, exactfc85 and clean. Expected backup read-back
absent; latest accessible Drive searches remain empty, not global absence proof.
No owner publication answer or new authority. No proof/benchmark rerun, process
restart, publication, review, merge, dispatch, signing, admission, deployment,
protection, Node, SPM, infrastructure or Stage12 action. No transient metadata
failure was counted as a passing test or terminal proof process.
Evidence:results/campaign-boundary-audit-2026-11-02/resumed-0002/attempt-0002/.
Goal remains active; full objective unachieved. Integration EXIT NOT_ESTABLISHED;
end_to_end=false. Exact pending draft-publication packet is
proposals/runtime-state-projection/publication-v2/READY.md. Other owner claim/
profile/review/merge, independent backup and required-check decisions stay open.


## Second resumed owner-boundary audit3 — 2026-11-02 (U238)

CURRENT none. Stage12 unauthorized. Fresh GitHub reads confirm mainf9eb1cbc,
PR36 head705457e0/open/unmerged/no reviews. Exactfc85 lookup HTTP422/no commit
found. Actual local git rev-parse HEAD and status --porcelain exit0/0; exact
fc85ecc2 and clean. Expected independent-backup read-back remains absent.
The third consecutive audit makes no progress; no proof/benchmark was rerun.
No new publication grant arrived. The blocked threshold is satisfied; the goal
API blocked request follows and its returned status is authoritative. This is
not completion. Publication packet:proposals/runtime-state-projection/
publication-v2/READY.md. Independent owner review/claim/profile/merge, backup
and administrator required-check decisions remain separate. No publication,
review, merge, dispatch, signing, admission, deployment, protection change,
Node, SPM, infrastructure or Stage12 work occurred.
Evidence:results/campaign-boundary-audit-2026-11-02/resumed-0002/attempt-0003/.
Integration EXIT NOT_ESTABLISHED; end_to_end=false.


## Third resumed owner-boundary audit1 — 2026-11-03 (U238 unchanged)

CURRENT none. User resumed the goal; this starts a fresh blocked audit.
Previous/current turns are no progress. Fresh count1; no prior count carried.
Fresh GitHub reads: mainf9eb1cbc unchanged, PR36 exact705457e0 open/unmerged
with no reviews, exactfc85 lookup HTTP422/no commit found. Actual local
git rev-parse HEAD/status --porcelain exit0/0; exactfc85 and clean. Expected
independent-backup destination-integrity.json is absent; no remote confirmation.
No new exact publication grant arrived. Campaign section0 excludes automatic
publication authority. No running process was polled; this is not a verified
wait. No proof/benchmark rerun or external write occurred. Existing campaign
proof/hosted results retain their recorded scope. Publication packet remains
proposals/runtime-state-projection/publication-v2/READY.md. Independent owner
review/claim/profile/merge, backup and administrator required-check decisions
remain separate. Goal stays active and unachieved at fresh audit count1.
Evidence:results/campaign-boundary-audit-2026-11-03/resumed-0003/attempt-0001/state.json.
Integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## Third resumed owner-boundary audit2 — 2026-11-03 (U238 unchanged)

CURRENT none. Fresh GitHub reads show unchanged mainf9eb1cbc, PR36 exact
705457e0/open/unmerged/no reviews and exactfc85 lookup422/no commit found.
Local HEAD/status exit0/0; exactfc85 and clean. Backup destination read-back
remains absent. No new publication decision. Previous/current turns are no
progress; fresh resumed count2. No live process was polled, no proof rerun or
external write occurred. Exact publication packet remains publication-v2/READY.md.
Campaign section0 still requires the separate publication decision. Other
independent review, claim/profile/merge, backup and required-check decisions
remain open. Goal stays active and full objective unachieved.
Evidence:results/campaign-boundary-audit-2026-11-03/resumed-0003/attempt-0002/.
Integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## Third resumed owner-boundary audit3 — 2026-11-03 (U239)

CURRENT none. Previous/current turns are no progress; fresh resumed count3.
GitHub reads: unchanged mainf9eb1cbc; PR36 exact705457e0 open/unmerged/no
reviews; exactfc85 lookup HTTP422/no commit found. Actual local HEAD/status
commands exit0/0, exactfc85 and clean. Backup destination read-back absent.
No new publication grant or meaningful authorized action resolves the owner
boundary. No proof/benchmark rerun, live-process wait, source change or external
write occurred. Three-turn blocked audit satisfied; goal API blocked request
follows and returned status is authoritative. Full objective remains unachieved.
Exact next decision: publication-v2/READY.md, exactfc85 contributor-authored draft
only. Independent review/claim/profile/merge, backup and required-check decisions
remain separate. Evidence:results/campaign-boundary-audit-2026-11-03/
resumed-0003/attempt-0003/. Integration EXIT NOT_ESTABLISHED; end_to_end=false;
Stage12 unauthorized.


## Fourth resumed owner-boundary audit1 — 2026-11-03 (U239 unchanged)

CURRENT none. User resumed the goal; fresh blocked audit starts at count1.
Previous/current turns are no progress. No count carried from earlier runs.
Fresh GitHub mainf9eb1cbc, PR36 exact705457e0 open/unmerged/reviews empty;
exactfc85 lookup422/no commit found. Local HEAD/status exit0/0; exactfc85
and clean. Expected independent-backup read-back remains absent. Submitted
explicit asynchronous questions for exactfc85 draft publication and independent
backup destination/existing copy identity. Questions accepted for display; no
answer or authorization was received. Campaign section0 requires the separate
publication decision. No elapsed time/preselected choice supplies consent.
No proof rerun, live-process wait or external write. Existing evidence retains
its scope. Exact decision packet:publication-v2/READY.md. Other independent
review/claim/profile/merge, backup and administrator required-check decisions
remain separate. Goal active and full objective unachieved.
Evidence:results/campaign-boundary-audit-2026-11-03/resumed-0004/attempt-0001/.
Integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## Fourth resumed owner-boundary audit2 — 2026-11-03 (U239 unchanged)

CURRENT none. Fresh mainf9eb1cbc and PR36 exact705457e0 remain unchanged;
PR36 open/unmerged/reviews empty. Actual local HEAD/status commands exit0/0;
exactfc85 and clean. Expected independent-backup read-back remains absent.
Publication and backup destination questions remain unanswered. No new grant
or external-state change. Previous/current turns no progress; fresh count2.
No proof/benchmark rerun, live-process wait, source change or external write.
Goal active; objective unachieved. Exact packet:publication-v2/READY.md.
Evidence:results/campaign-boundary-audit-2026-11-03/resumed-0004/attempt-0002/.
Integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## Fourth resumed owner-boundary audit3 — 2026-11-03 (U240)

CURRENT none. Fresh mainf9eb1cbc unchanged; PR36 exact705457e0 open/unmerged/
reviews empty. Exactfc85 lookup422/no commit found. Actual local HEAD/status
commands exit0/0, exactfc85 and clean. Backup destination read-back absent.
Publication and backup questions unanswered; no new grant. Previous/current
turns no progress; fresh resumed count3. No proof/benchmark rerun, live-process
wait or external write. Blocked audit satisfied; goal API request follows,
returned status authoritative. Full objective unachieved. Next owner decision
packet:publication-v2/READY.md. Independent review/claim/profile/merge, backup
and required-check actions remain separate. Evidence:results/campaign-boundary-
audit-2026-11-03/resumed-0004/attempt-0003/. Integration EXIT NOT_ESTABLISHED;
end_to_end=false; Stage12 unauthorized.


## Focused hosted booking EXIT inspection — 2026-11-03 (U241)

CURRENT none. Owner-directed inspection yielded fresh authenticated GitHub
job/artifact metadata and a new download of artifact13179905102 from successful
run41523691535/attempt1/job125545854178. ZIP SHA372cd778… matches fresh API
and preserved archive. No new hosted run or verifier execution occurred.

Actual commands:
- python3 -B results/hosted-booking-exit-review-2026-11-03/attempt-0001/audit_hosted.py
  ->0;13 expected hosted cases; cold/warm/invalidation/restored launches1/0/1/0.
- python3 -B proposals/receipt-authentication-final/integration_exit.py
  --local-results results/campaign-audit-2026-11-02/security
  --readiness results/campaign-resume-2026-11-02/readiness.json
  --output results/hosted-booking-exit-review-2026-11-03/attempt-0001/integration-exit.json
  ->1;NOT_ESTABLISHED; sole false predicate off_machine_backup_confirmed.
- Raw retained Booking log/TRX inspection ->0; cold/invalidation each238
  verified/0errors and238 Passed TRX results. This is evidence inspection.

H1 hosted booking matrix ESTABLISHED under same-process trust boundary. No
failing booking acceptance case; no source fix warranted. Smallest remaining
operation is independent archive transfer/read-back after owner supplies a
private host or existing copy. Transfer NOT RUN; no readiness field changed.
Proof-report upload PR36 exact705457e0 remains open/unmerged and separate;
successful booking upload does not test that repair. No approval/merge/dispatch
or policy/protection change. Required-check enforcement gap remains separate
from protection inspection. Outer-ledger raw log retention and helper-only C
invalidation limits remain explicit. Evidence and exact commands in
results/hosted-booking-exit-review-2026-11-03/attempt-0001/. Full campaign
unachieved; integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## Exact prepared proposal publication — 2026-11-03 (U242)

CURRENT none. Owner explicitly approved commit/push of prepared work. Existing
clean commitfc85ecc2c7f12caa6c8991fa002410bdf78dd51d already contained the14
proposal files. Fresh exact-head/base/actor/role/hash/packet/scope checks passed;
git diff --check f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3 HEAD ->0.

Actual publication commands (existing contributor credential selected only in
subprocess environment; not recorded):
- git -C /private/tmp/forge-e1-publication-v2-20261102
  -c credential.helper= -c 'credential.helper=!gh auth git-credential'
  push https://mackiannii@github.com/mack-dot/forge.git
  fc85ecc2c7f12caa6c8991fa002410bdf78dd51d:refs/heads/proposal/fixed-elf-assurance
  ->0; remote exact-head read-back0. No force.
- gh pr create --repo mack-dot/forge --base main
  --head proposal/fixed-elf-assurance --draft
  --title 'Propose a termination claim for the fixed RISC-V ELF'
  --body-file /Users/mackianni/forge/proposals/runtime-state-projection/publication-v2/pr-body.md
  ->0; https://github.com/mack-dot/forge/pull/37 .
- gh pr view returned0; OPEN/draft, headfc85/basef9, author mackiannii,
  merge state BLOCKED. Independent connector read confirms identity/state.

Main remainsf9eb1cbc. No new empty/replacement commit. No approval, merge,
manual dispatch, claim/profile activation, signing, admission or deployment.
Filtered automatic-run query empty at read time; no fresh hosted result claimed.
The historical local coverage result remains3/UNSUPPORTED14 uncovered paths.
Publication is complete; independent review and later exact authorizations stay
separate. PR36 upload repair and backup confirmation remain separate. No backup
copy or readiness change. Evidence:results/elf-proposal-publication-2026-11-03/
attempt-0001/. Full campaign unachieved; integration EXIT NOT_ESTABLISHED;
end_to_end=false; Stage12 unauthorized.


## Live PR37 status — 2026-11-03 (U243)

CURRENT none. Fresh mainf9, PR37 exactfc85 draft/unmerged/no reviews, PR36
exact705457e0 open/unmerged. Actual PR37 verify job126044039402 in run41672433464
executes the Linux incremental gate and exits3/UNSUPPORTED,14 uncovered proposal
paths, no accepted evidence. Full receipt reconstructed from contiguous log
chunks; source/head/base validated. Report job SUCCESS does not override that
refusal. The event-filtered commit workflow query is empty despite this actual
run; full PR checks/logs are authoritative. No new gate change or dispatch.
This is expected fail-closed coverage behavior, not admission of the new claim.
Next boundary remains independent proposed-claim/profile review; no coverage
exception, self-approval or merge. H1 booking evidence remains scoped and passed;
strict integration's last actual1 is unconfirmed backup. Evidence:results/
elf-proposal-publication-2026-11-03/attempt-0001/{status-followup,hosted-pr37-receipt}.json.
Integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## PR37 assumption review — 2026-11-03 (U244)

CURRENT none. Exactfc85 reviewed technically and by independent agent. No source
defect found within its stated abstract-model scope; no owner/GitHub approval.
Actual identity audit0, HEAD/status0/0; two exact theorem inputs and five copied
published LPS source hashes match held records. No expensive checker rerun.
Actual command python3 -B proposals/receipt-authentication-final/integration_exit.py
--local-results results/campaign-audit-2026-11-02/security
--readiness results/campaign-resume-2026-11-02/readiness.json
--output results/pr37-assumption-review-2026-11-03/attempt-0001/integration-exit.json
->1/NOT_ESTABLISHED; off_machine_backup_confirmed remains false.
Technical gap remains concrete VM/loader/guest-exit to LPS mapping: register
projection and modeled94/0 do not establish every runtime assumption. Exact
canonical-state/no-lazy premises remain explicit. No new theorem/profile,
coverage exception, publication, merge, dispatch or signing/deployment. PR36
remains separate. Evidence:results/pr37-assumption-review-2026-11-03/attempt-0001/.
Integration EXIT NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized.


## Master mission / assumption checkpoint — 2026-11-03 (U245,U246)

CURRENT none. Stage12 unauthorized. Exact new owner mission saved in
FORGE_MASTER_MISSION.md; first7 audit/planning deliverables in
FORGE_CURRENT_STATE_AND_PLAN.md. No future stage or policy was activated.

| Actual check | Exit | Exact argv/output record under results/*-2026-11-03/ |
| --- | ---: | --- |
| Existing initializer and unchanged-theorem instantiation |0|fixed-elf-assumption-matrix/attempt-0001/formal-instantiation/positive-command.json|
| False lazy / halted premise |1/1|same directory negative-lazy/negative-halted command records|
| Pinned readelf ELF inspection |0|fixed-elf-assumption-matrix/attempt-0001/elf-header-command.json|
| Local raw/sanitized archives,10160members each |0|fixed-elf-assumption-matrix/attempt-0001/local-archive-integrity-command.json|
| Existing strict integration EXIT |1|fixed-elf-assumption-matrix/attempt-0001/strict-integration-exit-command.json;backup false|
| Aggregate accounting normalization |137/OOM|runtime-accounting-feasibility/attempt-0001/result.json;4GiB unchanged|
|21 separate instruction facts / empty-accounting helper |0|runtime-access-one-step,decomposition,batch command records|
| Combined proof initial / corrected |1/0|runtime-access-batch attempts0001/0002;tactic-focus failure preserved|
| WrongRange intended negative |0,expected1|Invalid oracle;preserved,not passing refusal|
| Pending boundary / false post-ecall pendingNone |0/1|runtime-pending-boundary/attempt-0001 positive/negative-command.json|
| Published4-root assumption inventory |0|runtime-access-assumptions/attempt-0001/result.json;13 existing names|
|100-file held lock/input identity |0|master-mission-audit/attempt-0001/source-and-trust-surface.json|
| Read-only effective-rule/ruleset administrator exports |0|master-mission-audit/attempt-0001 command records;classic404/CLI1|
| Proposed README/ROADMAP patch application check |0|proposals/current-status-docs/validation.json;not applied/published|

Exact strict command:python3 -B proposals/receipt-authentication-final/integration_exit.py
--local-results results/campaign-audit-2026-11-02/security
--readiness results/campaign-resume-2026-11-02/readiness.json
--output results/fixed-elf-assumption-matrix-2026-11-03/attempt-0001/integration-exit.json
returned1/NOT_ESTABLISHED,sole false predicate off_machine_backup_confirmed.
No readiness value changed. Newer evidence needs a separate preserved snapshot.

Matrix84rows includes all8machinefields,quantified/model premises,21 pinned-
SCOPE items and exact13/86 historical trust lists. Source/object identities
unchanged. Decomposed model-prefix proofs and pending boundary are locally
type-checked,not full physical-state/loader/syscall correspondence. Raw CPU
iteration is not process dispatch. New full recursive independent kernel and
new QEMU run NOT RUN. Invalid extra-step oracle and all failures preserved.

Fresh mainf9 and PR34/36/37 heads unchanged/unmerged. PR37 still draft/no
reviews; its recorded hosted gate3 refuses14 uncovered paths. Main's stale
Stage9 preface and differing README are documented; narrow2-file doc correction
is a proposal only. Existing review rules lack required status/workflow checks;
no protection mutation or bypass. Independent archive copy/restore unconfirmed;
empty accessible Drive searches are not global absence proof. No spec/theorem/
policy weakening,axiom,new framework,Node,SPM,approval/merge,dispatch,signing,
admission or deployment. Goal remains active and full mission unachieved.
Integration EXIT NOT_ESTABLISHED;end_to_end=false.


## Fixed-ELF auxiliary kernel and connection obligations — 2026-11-03 (U247)

CURRENT none. Original termination theorem and its premises unchanged.
Stage12 unauthorized;end_to_end=false.

| Actual command/check | Exit | Result |
| --- | ---: | --- |
| python3 -B results/runtime-auxiliary-kernel-2026-11-03/attempt-0001/run.py |0|Published recursive kernel0,594 modules,86 permitted closure assumptions;container0,no OOM|
| python3 -B results/runtime-auxiliary-kernel-2026-11-03/attempt-0001/postflight.py |0|Exact inputs/root closure/invocation checked;no new assumptions|
| python3 -B results/ops-readiness/integration-2026-11-02/check_archives.py /Users/mackianni/forge-backups |0|10160 members/archive,zero mismatches;local integrity only|
| Existing strict integration command below |1|NOT_ESTABLISHED;off_machine_backup_confirmed=false|

Exact strict command:python3 -B proposals/receipt-authentication-final/integration_exit.py
--local-results results/campaign-audit-2026-11-02/security
--readiness results/campaign-resume-2026-11-02/readiness.json
--output results/fixed-elf-assumption-matrix-2026-11-03/attempt-0002/final-integration-exit.json

Kernel argv and actual subprocess exits:results/runtime-auxiliary-kernel-2026-11-03/
attempt-0001/{kernel-invocation.json,kernel-command.json,kernel-output/independent-processes.json}.
Kernel log SHAad90c2208bcabb509cb98aa842ea84ccf962bc4aec1e26cee8eee85991c45768.
Actual kernel wall1415.391444559s;outer1418.698787666s. Local,new process on same
machine;not hosted cost or independent physical-machine reproduction. Existing
published checker,recursive checking,UID1000,oneCPU,4GiB and networknone retained.
No source recompilation or new QEMU run in this replay. Existing failures stay
preserved,including137/OOM and invalid extra-step oracle expected1/actual0.

This closes independent checking for the new21-step access/accounting,pending-
request guard and initializer obligations. It does not close physical state,
ROM/loading,concrete Model mapping,syscall/exit or QEMU/Linux/observer fidelity.
The84-row matrix retains its historical checkpoint;the current follow-up and
C1-C7 minimal obligations are in results/fixed-elf-assumption-matrix-2026-11-03/
attempt-0002/{STATUS.md,CONNECTION_OBLIGATIONS.md}. Newer observations cannot
retroactively establish unrecorded hidden state in the historical launch.

Fresh GitHub mainf9eb1cbc;PR37 exactfc85ecc2 remains draft/open/unmerged,no
reviews. No acceptance-profile/coverage exception or theorem change. PR36 stays
separate. Backup independent-copy/read-back/storage/restore remains unconfirmed;
no readiness value changed. Required status/workflow checks remain absent in
exported rules,no protection change. No publication,approval,merge,dispatch,
signing,admission,deployment,Node,SPM or Stage12 work. Next authorized technical
action:existing process-transition composition and justified entry-state relation.
Integration EXIT and full executable correctness remain NOT_ESTABLISHED.


## Process-prefix composition and debug-observer supplement — 2026-11-03 (U248)

CURRENT none;Stage12 unauthorized;end_to_end=false. Original theorem unchanged.

| Actual command/check | Exit | Record |
| --- | ---: | --- |
| python3 -B results/runtime-process-prefix-2026-11-03/attempt-0001/compile_case.py positive |1|First proof list-index inference failure;preserved|
| python3 -B results/runtime-process-prefix-2026-11-03/attempt-0002/compile_case.py positive |0|Existing21-step process-prefix composition|
| python3 -B results/runtime-process-prefix-2026-11-03/attempt-0002/compile_case.py negative-halted |1|Intended Some0-versus-None guard refusal|
| Fresh ProcessPrefix source rebuild and byte comparison |0/0|runtime-process-prefix/rebuild-0001;object39edf12f...|
| Published direct-assumption audit |0|runtime-process-prefix-assumptions/attempt-0001;same13 names|
| Exact Ubuntu source acquisition/extraction/full signed-source-chain replay |0/0/0|qemu-source-assumption-audit/attempt-0002;no source build|
| Pinned GDB package acquisition/unpack/version |0|fixed-elf-observer/attempt-0001;15.1-1ubuntu1~24.04.1|
| Exact observer metadata controls |0|fixed-elf-observer/attempt-0002/marker-controls-command.json;9 cases|
| Repaired local observer/QEMU/GDB |0/0/0|fixed-elf-observer/attempt-0002/capture-command.json and capture/commands.json|
| Complete344+60 LOAD read-back comparisons / corrupt capture |0/0 /1|Actual cmp commands;held ELF digest checked|
| Whole raw trace / exact pre-exit prefix comparison |1 /0|Only final process-ID-bearing exit line differs;458 lines retained|
| Existing strict integration EXIT |1|fixed-elf-assumption-matrix/attempt-0003/integration-exit-command.json;backup false|

Full new independent kernel:RUNNING at this checkpoint,session41686/container
forge-process-prefix-kernel-20261103-0001;no exit claimed. The previous594-module
check remains a separate completed operation. No kernel restart or limit change.
Exact Docker/tool argv,stdout/stderr,identities and results are in records above.
Source acquisition firstAPT100/outer1 and compile-dispatch preflight1 were
operational errors,not proof refusals;both original records remain preserved.

New GDB run observes FCSR0 and complete held ELF LOAD identity. Its pre-exit
CPU/register/mapping trace prefix matches old literals. Guest auxv identifies
new-run vDSO page2aaaab2ac000. Reservation/Model ledger remain unobserved;new
measurements do not establish historical hidden state. GDB string-table and
readelf .dynamic diagnostics remain explicit;zero readelf exit is not full
vDSO validity. Neither finite observation nor authenticated source establishes
QEMU/Linux/LPS refinement. Initial observer prefix-check bug has a preserved
counterexample and exact-field repair;hosted receipt tests are unchanged.

All100 accepted locked files unchanged. Source-only local review packet has
36 members/28proof sources;not standalone or authenticated authority. No
publication,approval,merge,policy/protection change,dispatch,signing,admission,
deployment,Node,SPM or new service/framework. PR37 remainsfc85 draft/unreviewed.
Strict integration remainsNOT_ESTABLISHED with backup unconfirmed;no destination
or independent read-back supplied. Current84-row inventory plus run-specific
updates:results/fixed-elf-assumption-matrix-2026-11-03/attempt-0003/STATUS.md.
Full physical correspondence and the full master mission remain unachieved.


## Completed prefix kernel / strict observer-content replay — 2026-11-03 (U249)

CURRENT none;Stage12 unauthorized;end_to_end=false. U248's kernel RUNNING
checkpoint is superseded by the following actual terminal result.

| Actual command/check | Exit | Evidence |
| --- | ---: | --- |
| python3 -B results/runtime-process-prefix-kernel-2026-11-03/attempt-0001/run.py |0|Published recursive rocqchk0,595 modules,86 permitted assumptions;container0,no OOM|
| python3 -B results/runtime-process-prefix-kernel-2026-11-03/attempt-0001/postflight.py |0|Exact frozen tool/source/object identities and root/closure membership|
| Complete observer publisher/package/used-tree replay,first |1|fixed-elf-observer/attempt-0002/producer-chain-command.json;22 generated bytecode files rejected|
| Same strict replay,fresh read-only package tree |0|producer-chain-readonly-command.json;2 signatures,4 indices,13 archives,413 members|
| Corrected read-only observer / QEMU / GDB |0/0/0|fixed-elf-observer/attempt-0003/capture-command.json and capture/commands.json|
| Post-execution observer member comparison |0|attempt-0003/producer-after-command.json;413 authenticated members,no caches|
| Complete LOAD comparisons / corrupt text control |0/0 /1|attempt-0003/capture/commands.json;404 bytes held ELF identity|
| Current versus prior debugger raw trace |0|attempt-0003/prior-debug-trace-comparison.json;historical raw PID difference remains1|
| Local raw/sanitized archive/member check |0|assumption-matrix/attempt-0003/local-archive-integrity-command.json;10160members each|
| Strict integration EXIT,last actual rerun |1|assumption-matrix/attempt-0003/integration-exit-command.json;backup false|

Kernel log SHA1876758495c140fb397af0dc349530c6aaafab8e46bb5c5aad39928120b5b0d9.
Actual kernel wall1658.714140672s;outer1659.407074542s. Independent process on
same machine,not a hosted performance result. Original theorem/premises intact.
Process-prefix model composition and source/object reproducibility established;
complete actual entry/Model relation,runtime refinement and canonical reservation
remain unestablished. Current new-run FCSR0/LOAD404/auxv observations do not
establish historical hidden values. vDSO tool diagnostics are not proof passes.

The generated-bytecode failure is preserved,not ignored:413 signed-package
members matched but22 extra files came from the first writable version probe.
Fresh extraction,read-only execution and disabled bytecode writes restore exact
publisher-content identity. No old files deleted,matcher weakened,proof receipt
adopted or accepted profile changed. Publisher authentication is not correctness.

Unpublished41-member/28-proof-source read-only-observer packet SHA
2c97ed61e3a817afd4de9094682852d312491c9a5f8306834484a323ad2a3414.
Original36-member packet preserved. Base dependencies remain external;clean-
machine replay NOT RUN. Claim boundary and review proposal are concrete;no
publication,approval,merge,dispatch,signing,admission or deployment.100 locked
inputs unchanged,PR37 exactfc85 draft/unreviewed,PR36 separate. Independent
backup/read-back/storage/restore unconfirmed. No Node,SPM,framework,infrastructure
service,protection change or Stage12. Strict integration remainsNOT_ESTABLISHED;
full executable correctness and full master mission remain unachieved.


## Goal-controller read-back — 2026-11-03 (U250)

Two actual get_goal readbacks report blocked for the master objective. No
update_goal call occurred in this turn;cause UNKNOWN. This corrects U249 goal-
active wording only. Current turn made concrete progress;kernel595/86 and
observer-content/capture results retain their exact scope. Full mission remains
unachieved;safe local preparation remains. No complete/pause/status mutation,
stage transition,authority grant or policy change. CURRENT none;Stage12
unauthorized;end_to_end=false. Evidence:assumption-matrix/attempt-0003/
goal-controller-readback.json.


## Owner resume / other-device backup report / local commits — 2026-11-03 (U251)

CURRENT none;Stage12 unauthorized;end_to_end=false. Owner authorizes continued
readiness work and local commits,and reports an existing backup on another
 device. That is owner attestation;archive identity/remote hashes/restore are
not yet independently verified. A concise contents/location question is pending.

| Actual operation | Exit | Result |
| --- | ---: | --- |
| Local documentation commit |0|3934b4e24ddc576b0e08e1512756f1b18d79dda2;4 files|
| Local observer/evidence commit |0|e60b97b697a6f78f0ca347054e17d2a72d7ad7b5;38 files|
| Final Git whitespace checks |0/0|Raw readelf log losslessly packed;original unchanged|
| Committed source/archive/raw-log readback |0|Frozen archive/kernel identities match;both worktrees clean|
| Trusted inventory/registry coverage preflight |3/3|4/38 uncovered paths;proof execution NOT RUN|
| Git bundle create/verify |0/0|Both full local branch histories;private local staging|
| Local bundle clone-restore/fsck |0/0|Separate object database;observer blob matches|
| Existing strict integration status |1|Owner copy reported;exact archive validation still pending|

Exact Git/Docker/Python argv,outputs and metadata:results/owner-resume-commit-
2026-11-03/attempt-0001/. No full proof/debugger rerun was needed for unchanged
packing inputs. New commits are local,not pushed/merged. Mainf9 and PR37fc85
unchanged;PR36 independent. No protected source,policy,workflow,branch setting,
authoritative profile,signing,admission or deployment change. Original proof
premises and all declared runtime gaps remain. Initial whitespace errors2
are retained;formatting corrections do not alter word/proof/evidence content.

Stable private handoff file:/Users/mackianni/forge-backups/
forge-readiness-commits-2026-11-03.bundle,SHA
f9ad6a46f892b204ea12b38bea12b971e0e4dc72e7b50f5dd0ec0fe5ee9a4ee6.
Its local restoration passed;it excludes original raw/sanitized archives and
external proof/runtime pools. Off-machine transfer/restore NOT RUN. The owner's
existing-other-device report is preserved without inventing independent tests.
Full master mission remains unachieved;integration status NOT_ESTABLISHED.


## Immediate behavioral vertical slice — 2026-11-03 (U252)

CURRENT none;Stage12 unauthorized;end_to_end=false. Existing mission retained.
The immediate target is one approved behavior through the exact executable,
justified concrete/abstract correspondence,authenticated provenance and
independent admission. Cross-run reuse,benchmarks and UI are later horizons.
Full audit and shortest path:VERTICAL_SLICE_STATUS.md.

| Actual command / execution | Actual exit / result |
| --- | --- |
| `python3 -B results/vertical-slice-audit-2026-11-03/attempt-0001/compile_cases.py positive` |0;exact loop pairs,GCD21,and modeled exit0 with arbitrary reservation/FCSR|
| Same dispatcher `negative` |1;intended21-versus22 proof type mismatch|
| Same dispatcher `audit` |0;fully qualified Print Assumptions|
| Published parser in existing pinned Linux image |0;13 permitted direct names,subset of prior86|
| Pinned Python3.10.11 `-I -S -B .../audit_identities.py` |0;39 held host proof objects/28 sources match;old policy excludes execution|
| `python3 -B .../admission_controls.py` |0;child consumer0/1/1,real Cosign0/0/0;unsigned scope upgrades reject EVIDENCE_DIGEST|
| `python3 -B .../finish_audit.py` |0;actual records and intended outcomes checked|
| Existing strict integration status |1;only off_machine_backup_confirmed false;owner reports copy,archive validation pending|

Initial host parser1(Linux YAML extension unavailable on macOS) and Linux short-
name input1 are preserved. Fully qualified output corrected metadata only. No
new axioms,parser change,policy weakening or tool installation. New Behavior.v
source5a230c7e...;objectf1d3b7e2.... New full independent recursive kernel NOT RUN;
previous kernel569/567/595 results remain historical. No new hosted execution.

Physical Model relation and actual exit_group boundary remain unestablished.
Existing policy authenticates the file,not execution. New exact statement/
profile approval,fresh bound provenance and independent release admission remain
required. PR37fc85 unapproved/draft/unmerged;PR36 remains separate. Mainf9
unchanged. No protected source/workflow/protection/signing/admission change.

Local audit commits under the existing owner grant (U253):docs9b0a678e and
observer supplementc8e87fd0,actual commit0/0;no push. Initial dispatcher1 and
whitespace2 preserved. Final whitespace0 and committed blob readback0. Raw
negative log is losslessly gzip-packed in Git;source/proof/output bytes unchanged.
Postflight0 verifies86 published tool files/45 Python dependencies,main tracked
diff0 and original unsure prefix. These review commits do not activate any
claim/profile or replace missing correspondence/provenance/admission evidence.


## Executable correspondence closure — 2026-11-03 (U254)

CURRENT none; Stage12 unauthorized; end_to_end=false. Detailed evidence and
exact argv: results/executable-correspondence-2026-11-03/attempt-0001/REPORT.md.
Verdict PARTIALLY_ESTABLISHED. The full behavioral kernel gap from U252 is closed.
Complete physical refinement, new claim approval/provenance/admission remain open.

| Actual command / child execution | Exit | Actual result |
| --- | ---: | --- |
| `python3 -B .../prepare_and_check.py` |0|Fresh Behavior/ExitBridge compile0/0; complete recursive kernel0;597 modules,86 assumptions |
| `python3 -B .../observe_controls.py` |0|Baseline guest/parent0;404 LOAD bytes; injected-register guest2 and observer1 expected |
| `python3 -B .../recheck_controls.py` |0|ExitBridge identical rebuild0; wrong-GCD/halt1/1 expected;9 marker cases matched |
| `python3 -B .../identity_controls.py` |0|Corrupt proof/substituted ELF1/1 expected before execution |
| Relocated `replay-packet/replay.py --rebuild-only` |0|Two identical objects; full recursive check not repeated here |
| Relocated `runtime-packet/replay.py` |0|Fresh producer/baseline/postidentity0; original worktrees not mounted |
| Host Python3.10 tar extraction |1|Unsupported data-filter argument; failure preserved |
| Pinned Python3.12.3 extraction with same data filter |0|No filter removed or installation |
| `python3 -B .../operational_audit.py` |0|Read-only effective rules obtained; classic protection HTTP404 child1; no required checks |
| Original archive validation / `restore_existing_backup.py` |0/0|10160 members each; local restore only |
| Existing strict integration status |1|Only off_machine_backup_confirmed false; owner report retained |
| `python3 -B .../finalize.py` |0|Actual records agree; end_to_end=false |

The new bridge source4aeaf560... / objectb433ae9a... makes the existing modeled
exit event explicit. Result21 is the fixed1071/462 GCD in intermediate a0.
Parent wait confirms physical exit0 in this run; GDB notification alone cannot.
No universal QEMU/Linux refinement or physical progress proof is claimed.

The exact conditional claim/profile and unapplied spec patch are prepared for
review. PR37fc85 stays draft/unreviewed; mainf9 unchanged; PR36 separate. No
publication, signing, admission, merge or dispatch. Required external backup
hash/restore test awaits the existing copy's location. Local packet relocation
and archive restore are not an off-machine verification. All old failures remain.


Local preservation for U254 (U255), under the owner's explicit commit grant:

| Actual operation | Exit | Result |
| --- | ---: | --- |
| Correspondence supplement commit |0|`0d0cdcee801401f620ad643fb36154a312332e54`;25 proposal files |
| Documentation commit |0|`6fd95ff32096dfc7cd2c99abc4cede1224ce531e`;2 status files |
| Final staged whitespace checks |0/0|No proof or raw evidence normalization |
| Committed file/archive readback |0|24 files and313 raw members; exact kernel/proof bytes |
| Git object checks / main tracked diff |0/0/0|Both worktrees clean; protected source unchanged |
| New private local bundle create / verify |0/0|SHA256 `d8aa9f1620da36e3681a38636b3ed5874a0397cba867256b15459a01425c6188` |
| New bundle clone restore / object check |0/0|Exact heads and both committed archives recovered |

New private bundle: `/Users/mackianni/forge-backups/forge-correspondence-commits-2026-11-03.bundle`.
This is same-machine recovery, not the pending independent archive restore.
The70MB runtime packet stays separately preserved. Independent review and exact
claim/profile adoption are the next boundaries. No publication/merge/dispatch/
signing/admission/deployment. Stage12 unauthorized; end_to_end=false.


## Exact fresh-observation binding — 2026-11-04 (U256)

CURRENT none; Stage12 unauthorized; end_to_end=false. Overall PARTIALLY_ESTABLISHED.
Existing model proof and prior kernel597/86 are unchanged. The new wrapper closes
an execution-to-trace identity integration gap; it does not prove QEMU/Linux refinement.

| Actual command / operation | Exit | Result |
| --- | ---: | --- |
| `python3 -B .../entry_experiment.py` |0|Actual entry a0=1 still exits0; trace differs |
| `python3 -I -B .../run_bound_observation.py --runtime-packet ... --out .../bound-final` |0|Fresh observer and full exact trace/LOAD binding;6.806320625 local seconds |
| `python3 -B .../test_matrix.py` |0|16 cases match; one positive0,15 required refusals1 |
| Real changed-entry record comparison |1|Expected TRACE_IDENTITY_MISMATCH despite actual QEMU exit0 |
| Held proof-source postflight |0|30 sources unchanged; new kernel NOT RUN |
| Local continuation / standalone review commits |0/0|`945499592c33a3a84f205c0ccf68c4088c3d6d8b` / `8125552117589b1c1274c48982fce37ae2f33415` |
| Committed readback |0|38 files and996 raw records; exact final wrapper bytes |
| Local bundle create / verify / restore / fsck |0/0/0/0|Private same-device recovery only |
| Existing strict integration EXIT |1|Independent archive hash/restore unverified |

Exact commands and evidence:results/fixed-elf-runtime-binding-2026-11-04/attempt-0001/.
Standalone draft head81255521 has40 proposal files and no active protected changes.
Publication approval is pending; no push/merge/dispatch/signing/admission performed.
Physical correspondence assumptions and exact claim/profile adoption remain open.


### Mission tracking preservation — actual local results

Local commit: `118b3d4d331ce513c92e1de3ee2cd9298572aa48` on
`docs/integration-readiness-20261103`. Commit exit0; staged whitespace check0;
committed readback0 for the exact mission and45 packet files; worktree clean.
The commit is local and unpublished. No research stage completed.

Local recovery bundle create/verify/clone-restore/fsck each returned0:
`/Users/mackianni/forge-backups/forge-mission-2026-11-04.bundle`.
SHA256 `d68852a498467f02fb1c8a6b841f60742da46a723b133546c00ee66688e237c1`.
24404340bytes; mode0600. Restored commit and mission bytes matched.
This is local recovery, not verification of the owner's off-machine copy.
Command records: `results/mission-m1-feasibility-2026-11-04/attempt-0001/`.


## Native audit and local execution authorization — U269

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner approved only the local ad-hoc signature required for the eventual
macOS arm64 refund executable in the resumed audit thread. That thread owns the
local link/sign/run actions. Release signing, publication, deployment and
protected changes remain unauthorized. No native signature or execution ran.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Installed ld -help | 1 | Unsupported option; preserved |
| Pinned source/manual checks | 0 | Linker default and candidate-normalizer/temp-path observations recorded |
| readback_certified.py | 0 | Exact source, six repeated exports and two intended refusal reasons checked |
| Local follow-up commit /14-file readback | 0/0 |3c5bb8ca; unsigned, unpublished; clean worktree |

[Exact scope and remaining gaps](proposals/refund-executable-feasibility/native-audit-followup-20261104/REPORT.md).
These are source/record checks, not native execution or new kernel replay.
Full-program/compiler, concrete runtime and native controls remain open.
Earlier no-signing observations remain historical; this approval is narrowly
scoped and does not authorize release admission or Stage12.


## Independent native-fixture checkpoint — 2026-11-04 (U272)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The frozen native fixture expectations now have direct HOL evaluation evidence.
This is separate from the original task's whole-program/compiler work.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Initial direct HOL batch | 1 |Default-heap intLib loading failure; preserved |
| Explicit pinned-heap batch / repeat | 0/0 |22 typed cases;44 identical serialized files |
| Initial control preparation / missing-script dispatch | 1/1 |Infrastructure failures; no accepted negative |
| Corrected preparation / malformed batch | 0/0 |Six exact model error cases |
| Wrong expected amount / swapped expected IDs | 1/1 |Required EQT_ELIM refusals |
| First / corrected closure inspection | 1/0 |Qualifier error fixed;229 theory nodes |
| Fixture/dependency readback / committed readback | 0/0 |228 theory file sets;300 committed files checked |

[Exact fixture evidence and trust limits](proposals/refund-executable-feasibility/native-fixtures-20261104/REPORT.md).
Local unsigned unpublished commit32e3613da6edc070d373101986c0bdfeb826f5c8.
All50 frozen protected paths and mission bytes match. Every failure remains.
Next: bind the exact arm8 compiler outputs to the final native artifact and
run the frozen28 input cases. Native execution is NOT RUN in this audit.
The real I/O relation, error-path/process-status bridge, installation/resource
premises and independent assurance remain open. U269's limited local signature
approval remains; no signature, release signing, deployment or Stage12 ran.
