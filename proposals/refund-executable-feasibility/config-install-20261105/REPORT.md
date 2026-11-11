# Refund configuration and installation trace — U300

CURRENT stage: none. Active milestone: M1. Stage12 unauthorized.
`end_to_end=false`. M1 and integration EXIT: **NOT_ESTABLISHED**.

The closure result now covers the actual register-allocation configuration update.
A separate checked word-language theorem gives a single installation epoch for
each execution with a recorded stack bound and a non-error result. Its all-clock
corollary retains both premises. Target installer exclusion remains unproved.

The target remains the refund R1–R5 decision/intent behavior over the full approved
integer and Unicode domain. No accepted claim, input domain, runtime permission,
compiler flag or verification policy changed. M2 admission, M3 reuse and M4
usability remain later priorities. The fixed RISC-V example remains supporting work.

## Exact checked results

[config.sml](records/config.sml) exports two statements in
`forge_refundConfigInstall`:

1. `to_clos_set_oracle`: for every configuration, program and allocation oracle,
   `SND(to_clos (set_oracle c oracle) p) = SND(to_clos c p)`.
2. `refund_config_no_install`: the exact `refund_prog` closure syntax contains
   no `Install` under `set_oracle arm8_backend_config oracle`, for every oracle.

This closes U299's configuration projection gap. It uses the exact U299 parent
theorem and the published backend definitions. The native executable identity is
unchanged. This statement concerns closure syntax, not machine reachability.

[space.sml](records/space.sml) exports three statements in
`forge_installSpaceBarrier`:

1. `install_outcomes`: a modeled word `Install` either succeeds with
   `stack_max = NONE`, or returns `SOME Error` and the original state.
2. `install_suffix_unbounded`: after a successful installation, any subsequent
   word evaluation still has `stack_max = NONE`.
3. `safe_run_excludes_install_suffix`: a run covered by
   `word_lang_safe_for_space` cannot have the same final state as such a suffix.

`NONE` means no recorded finite stack bound in this model. It does not prove
physical infinite memory use. The suffix theorem alone does not characterize
every nested execution context or establish target event exclusion.

[trace.sml](records/trace.sml) exports three statements in
`forge_spaceInstallTrace`. `epoch_single` is a list-composition helper. The central
statement is `bounded_stack_single_epoch`:

```text
evaluate (p,s) = (res,t)
AND res <> SOME Error
AND IS_SOME t.stack_max
IMPLIES LENGTH (wordProps.ptr_eq_trace p s) = 1
```

`safe_run_single_epoch` applies this statement to the published word entry call
`Call NONE (SOME start) [0] NONE` at every clock, provided that:

- `word_lang_safe_for_space initial start` holds; and
- every clocked entry evaluation has a result other than `SOME Error`.

These are premises, not resource or runtime results. The proof uses the published
`ptr_eq_trace`, `epoch_append`, evaluator induction and stack-bound monotonicity.
No new event tracer, machine semantics, evaluator, verifier or axiom was added.
The existing trace starts with one epoch and adds an epoch for a successful
modeled `Install`. A one-epoch conclusion excludes successful installations in
that trace. It is not, by itself, a theorem about target `InstallApp` events,
failed installation attempts or physical calls to `cake_install`.

The nine exact imported statements, including the historical U299 parent, appear
in [expected.sml](records/expected.sml) and
[expected-trace.sml](records/expected-trace.sml). The new theories export eight
statements in total. Each new theory reproduces four exported files byte for byte.

## Actual executions and preserved failures

| Command/check | Actual child exit | Result |
| --- | --- | --- |
| Configuration proof / repeat | 0/0 | Two exact statements; identical exports |
| Space proof first/corrected/repeat | 1/0/0 | Explicit monotonicity application resolves suffix goal |
| Trace bundle initial attempts1–5 | 1/1/1/1/1 | Main trace theorem saved on fifth; final corollary then fails |
| Separate corollary attempts2/3/4; complete repeat | 1/1/0;0 | Final projection fact resolves corollary; complete exports reproduce |
| Initial main import and three initial controls | 1 each | Missing wordPropsTheory preload; infrastructure failures |
| Corrected six-statement import / three-statement trace import | 0/0 | All nine statements match |
| Wrong program / omitted space premise / changed suffix bound | 1/1/1 | Intended exact-statement refusal after preload repair |
| Omitted non-error / omitted trace-space premise | 1/1 | Intended exact-statement refusal |
| readback.py | 0 | 386 closure nodes, 1917 files, exact identities and preserved history |
| New native/hosted execution, full independent replay/admission/restore | NOT RUN | No physical or operational completion |

[COMMANDS.md](COMMANDS.md) contains every full recorded command, working directory,
actual exit, source hash and observed local elapsed duration. These durations are
not performance benchmarks or hosted savings measurements.

The first broad trace proposal omitted the non-error premise. The failed
`MustTerminate` case exposed the missing condition: when its inner execution
times out, the published evaluator returns `Error` with the original state.
The outer stack-bound field therefore does not establish the bound of that inner
execution. The proposed lemma was corrected to retain non-error explicitly.
No approved specification or accepted theorem was weakened. No physical
counterexample or general falsification of the earlier proposal was produced.
Later trace failures concerned loop error propagation and the final pair
projection. All original sources and logs remain intact.

The first stop record counted five bundle invocations as five attempts for every
theorem. That count was too broad. The project limit is per failing proof.
`bounded_stack_single_epoch` failed four times and passed on its fifth attempt.
`safe_run_single_epoch` first failed at that point; it passed on its fourth
attempt. Its later runs preserve the successful prefix byte for byte. The old
[trace-stop.json](records/trace-stop.json) remains historical. The correction and
exact counts are in [attempt-accounting-final.json](records/attempt-accounting-final.json).
No proof exceeded five attempts. U290 and U297's previously stopped routes remain closed.

The first import and three controls failed before checking their claims because
`wordPropsTheory` was not preloaded. Loading that existing parent fixes setup.
The statement files are unchanged between those attempts. Setup failures do not
count as adversarial rejection. The five final controls test exact claim binding;
they are not physical counterexamples or admission decisions.

## Remaining assurance links

| Link | Classification and exact remaining obligation |
| --- | --- |
| Exact refund closure syntax under allocation-oracle update | PROVED locally; configuration gap closed |
| Single word trace epoch under bounded stack and non-error | PROVED locally; explicit premises retained |
| All-clock word entry corollary | PROVED conditionally; exact resource and non-error premises remain |
| Exact compiled refund word state satisfies those premises | NOT_ESTABLISHED here; existing compiler safety implications still need exact specialization |
| Word epochs correspond to lower-pass installation events | NOT_ESTABLISHED |
| Every exact target prefix avoids installer entry | NOT_ESTABLISHED |
| U298 handler-replacement theorem applies to physical runtime | NOT_ESTABLISHED |
| Complete physical entry/memory/FFI/interference/OS and resource conditions | U296 matrix remains open |
| Source interpretation, independent replay/review, new provenance and admission | NOT_ESTABLISHED |

The source audit found existing safety implications in
`data_to_wordProof.compile_semantics_oracle` and `backendProof`. They carry a
word-language space premise into the next pass. They do not themselves expose the
target installation-prefix condition required by U298. Final result equality,
unchanged oracle functions and matching hashes must not substitute for an event
correspondence proof.

**Next smallest authorized action:** specialize the word-state premises to the
exact refund compiler state, retaining every resource and non-error condition.
Then investigate an event-preservation link from the existing word trace through
the lower compiler simulations to target `InstallApp` events and U298's prefix
condition. Preserve failed-install and nested-error cases explicitly. Reuse the
published models; do not build a new tracer or retry U290/U297's stopped proofs.

## Review and authority packet

Independent review must cover the exact three new theory sources, both explicit
statement lists, their complete assumption closure and their applicability limits.
The corrected non-error premise and the per-theorem attempt accounting require
particular attention. This packet does not propose removing the physical installer
contract from any accepted claim. It grants no admission or publication authority.

The union dependency closure retains only `bool.SELECT_AX`, `bool.INFINITY_AX`,
`bool.ETA_AX` and `bool.BOOL_CASES_AX`. Imports have no explicit hypotheses or new
tagged axioms. They use the existing pinned heap and cached `DISK_THM` parents.
Fresh same-host imports are not independent full-chain source replay or producer
authentication. Hashes identify bytes; they do not authenticate a producer.

Baseline local commit: `0c4a7166f2a0f6d68b3983ed051758e8544e3406`.
Baseline tree: `99eec9e77146973c3cf076ea4297775af67a516a`.
The previous goal turn made progress. No GitHub state was refreshed here.
Readback binds 12 pinned source snapshots, 50 unchanged protected paths and all
540 members of U296–U299's packets. The mission and native identities remain unchanged.

The owner reports an off-machine backup. Exact required archive hashes and a
restore test on that copy remain unverified. Effective branch protections are
not newly verified. Local preparation and unsigned commits remain authorized.
Protected adoption, publication, push, merge, dispatch, signing, admission and
deployment retain their approval boundaries. No Stage12, Node, SPM or new infrastructure.

## Exact identities

| Item | SHA256 |
| --- | --- |
| config.sml | `00390171f00926ad6a6c976c9db2babb85302bdb90fe51a4286fc430393cde4c` |
| space.sml | `a56b2a7bdbf61b6a3cbc0e9e6224941a8764da8f30e60fb0d1e774ff04d3017a` |
| trace.sml | `bc02a55aae9bbf6f60fe044153c269fc998e1df38794612168d336c0e6f03ad0` |
| expected.sml | `c2cfa56848d89f2a6e11db67051836c1d99c79838db074ce67e306d852073be3` |
| expected-trace.sml | `f9b09779790c39643a3321831d959205fb0a212d087ab08796724dc7499864f1` |
| forge_refundConfigInstallTheory.dat | `372507feeaa971a9dd54329490306c42adbeb8e49111e51092099a2542cef146` |
| forge_installSpaceBarrierTheory.dat | `af08fc17c93472d6b53b81b7efb0216ebda89128a54e505295131d4f5fff6560` |
| forge_spaceInstallTraceTheory.dat | `5f2158bc5b57f30901dbca1d1d44898349b771e376cc7b76d07042c57f327b1b` |
| Existing native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

CakeML pin: `cd9155694c16831373ab695a670794f23282ed62`.
HOL pin: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
[readback.json](records/readback.json) records all closure and artifact hashes.
The required `end_to_end=false` value is preserved.

## Packaging checks

Full staged whitespace check: actual exit2. Authored-file check: actual exit0.
Pinned upstream files, generated proof exports and raw logs retain their exact
bytes. Full diagnostics are preserved in
[packaging-check.json](records/packaging-check.json). No Git whitespace setting
or proof policy changed.
