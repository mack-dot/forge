# Refund data behavior and conditional word trace — U302

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. End-to-end and integration EXIT: **NOT_ESTABLISHED**.

The exact refund data program now has a checked non-failure result derived from
its source behavior. That result composes with the published compiler theorem
and U300's word trace theorem. The new composition no longer assumes data
non-failure separately. It still requires the complete compiler initial-state,
code, oracle and space conditions. This packet does not establish those
conditions for the physical executable.

The objective remains the full approved refund R1–R5 decision/intent behavior,
including its integer and Unicode input domain. No specification, acceptance
policy, input restriction or runtime permission changed. The fixed RISC-V
example remains supporting work. M2 admission, M3 reuse and M4 usability remain
later priorities.

## Checked chain

| Link | Actual result and boundary |
| --- | --- |
| Source behavior to exact compiled data semantics | PROVED conditionally. `refund_data_behavior` uses the existing exact compiler result and public source/flat/data preservation theorems. |
| Exact data semantics does not equal `Fail` | PROVED under the existing canonical-input, `wfcl`, `wfFS` and `STD_streams` conditions. Arbitrary limit/frame tracking is justified by the published `semantics_zero_limits`; it does not prove resource adequacy. |
| Data non-failure to word non-error | PROVED under every retained premise of `data_to_wordProof.compile_semantics`. No extra word non-error assumption is added. |
| Exact refund data program to one word trace epoch | PROVED conditionally for a related 64-bit word state with the explicit basis FFI. Source/data identity is bound; the word initial-state and compiler relations remain premises. |
| Exact compiled word initial state satisfies those premises | NOT_ESTABLISHED. This packet supplies no complete runtime witness. |
| Word events to target installation-prefix exclusion | NOT_ESTABLISHED. U298 is not yet applicable to the physical runtime. |
| Full concrete runtime, new provenance and independent admission | NOT_ESTABLISHED. The U296 runtime matrix still applies. |

One epoch excludes successful modeled Install events in the published word trace.
It does not establish physical installer exclusion, target `InstallApp` exclusion,
or a universal statement about failed installation attempts.

## Proof artifacts and exact claims

- [data-pairs.sml](records/data-pairs.sml): `forge_refundDataBehavior` exports
  `compiled_source_data` and `refund_data_behavior`.
- [word-qualified.sml](records/word-qualified.sml): `forge_compilerWordTrace`
  exports `error_implies_failure`, `semantics_nonerror`, `extended_nonfailure`,
  `compiled_word_nonerror` and `compiled_word_single_epoch`.
- [refund-word-instantiate.sml](records/refund-word-instantiate.sml):
  `forge_refundWordPremises` exports `refund_data_nonfailure` and
  `refund_word_single_epoch`.

[expected-data.sml](records/expected-data.sml),
[expected-word.sml](records/expected-word.sml) and
[expected-refund.sml](records/expected-refund.sml) bind all nine statements.
The last check reconstructs compiler premises from the pinned public theorem.
Its conclusions match exactly. HOL proves equivalence of the complete premise
sets, including conjunction order and the existing `Abbrev` marker definition.
No candidate-selected premise may be omitted.

The final theorem retains these conditions:

| Group | Required conditions |
| --- | --- |
| Source environment | Exact canonical nine-field request on stdin; `wfcl cl`, `wfFS fs`, `STD_streams fs`. The actual physical environment is not established here. |
| Word initialization | `init_store_ok`; return location in local 0; empty stack; handler/termdep 0; stack bound `SOME 1`; locals size `SOME 0`; positive stack limit. |
| Code and configuration | Exact refund data program in `code_rel`; `code_rel_ext`, matching domains, configuration validity, 64-bit ISA, GC function and endianness. |
| Compiler authority | Exact source-derived compiler function/oracle, their full-compilation equations and stub-name bounds. |
| Pointer equality | Required pointer relation, initial oracle `NONE`, and the all-clock representative-oracle equation. |
| Resources | Exact `data_lang_safe_for_space`, `get_limits`, frame sizes and non-`None` GC. These remain premises. |

The model explicitly replaces the FFI field with `basis_ffi ext cl fs`.
The overwritten old field may have an arbitrary type. This is a property of the
published polymorphic record update, not evidence about the physical FFI state.

## Executed checks

| Command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Data proof attempts1–4; repeat | 1/1/1/0;0 | Two parsing failures, pair-goal tactic failure, then two checked statements |
| Word proof setup/corrected; repeat | 1/0;0 | Missing parent preload fixed; five checked statements |
| Refund composition bundles1–7; repeat | 1/1/1/1/1/1/0;0 | Setup/helper/matching failures retained; final two statements checked |
| Word import / data import | 0/0 | Seven exact statements |
| Refund import attempts1–5 | 1/1/1/1/0 | Context, expected type and marker handling corrected; two full claims checked |
| Omitted data non-failure / omitted space / substituted data program | 1/1/1 | Intended exact-claim refusals |
| Omitted canonical input, four audit versions | 1/1/1/1 | HOL leaves the exact `stdin_content` condition unproved |
| Source/type diagnostics | 0/0 | Read-only theorem/type inspection |
| `readback.py` | 0 | Exact outputs, dependencies, preserved inputs and failures checked |
| New native/hosted execution, independent full-chain replay, admission, off-machine restore | NOT RUN | No operational or executable assurance completion |

Each new theory reproduces all four exports byte for byte. The union closure has
486 theory nodes and 2415 hashed files. It retains only the four existing Boolean
foundations: `SELECT_AX`, `INFINITY_AX`, `ETA_AX`, `BOOL_CASES_AX`. Imported claims
have no explicit hypotheses or new tagged axioms. Same-host cached `DISK_THM`
imports are not independent full-chain source replay or producer authentication.

The main refund composition failed matching three times and passed on its fourth
attempt. Earlier bundles failed before reaching that composition. Its successful
data non-failure prefix is unchanged across later attempts. No failing proof
exceeded five attempts. [Attempt accounting](records/attempt-accounting.json)
preserves the distinction. U290/U297 remain stopped.

The matching fix uses existing HOL `INST_TY_TERM` and `MP`. It instantiates the
hypotheses together with the conclusion. It does not remove hypotheses. The
import initially restricted the overwritten FFI field to the new field's type.
A typed diagnostic exposed that error. The proposed theorem was unchanged.
The attempted record-order explanation was not confirmed and is superseded by
this type finding. The final premise comparison also expands the published
`Abbrev` definition. All failed imports remain in the records.

The negative cases check claim binding and premise preservation. They are not
physical counterexamples, receipt-authentication tests or admission decisions.
Failure to prove the altered input claim is not a universal falsification theorem.

[COMMANDS.md](COMMANDS.md) lists exact commands, numeric exits and observed local
elapsed durations. [readback.json](records/readback.json) records all hashes.
These durations are not hosted runner measurements or performance benchmarks.

## Next smallest authorized action

Instantiate the retained code/state/oracle conditions using the published
`word_to_stackProof.make_init` and the exact
`SND(backend.to_word arm8_config cfg refund_prog)` output. Discharge static
initialization conditions with existing compiler lemmas. Preserve the resource
condition unless it is separately established. Then connect the word trace to
lower compiler events and U298's target-prefix condition. Do not substitute final
result equality or equal oracle functions for event correspondence.

No complete physical entry/memory/FFI/OS relation or space-adequacy witness is
provided here. Source interpretation, independent review/replay, authenticated
provenance and new claim/profile admission remain open. Exact other-device archive
hashes and a restore test remain unverified. Effective GitHub protections were not
refreshed. These operational gaps are separate from the mathematical premises.

## Review and authority

Review the three theory sources, exact claim files, complete dependency closure,
negative controls and retained applicability conditions. The packet is a local
proposal. It does not authorize an accepted claim/profile or protected code change.
Publication, push, merge, dispatch, signing, admission and deployment retain their
approval boundaries. No Stage12, Node, SPM or new infrastructure work occurred.

Baseline local commit: `6cdb235c02e3d47a78fea3ace4788656920a27dc`.
The previous goal turn made documentation progress. This turn adds checked links.
CakeML pin: `cd9155694c16831373ab695a670794f23282ed62`.
HOL pin: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
Both tracked toolchain trees are unchanged. Fourteen pinned source snapshots,
50 protected paths and 926 prior packet members match their expected hashes.
The mission bytes and native executable remain unchanged.

Native SHA256:
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.

| New theory data file | SHA256 |
| --- | --- |
| `forge_refundDataBehaviorTheory.dat` | `afc716d5d2f486fdbcd7c38b2f645ef108735afc349e96acdf648750d9f6a84f` |
| `forge_compilerWordTraceTheory.dat` | `8f2ee0c5a0f2a9ca33c96d17d6bb7ae45846cd0f5dbc49f3e1c61036363232d5` |
| `forge_refundWordPremisesTheory.dat` | `ec4712f6a53b11c62550789c2315a2a2f4a2c0bfc789e2e7f787dec73022b1f5` |

## Evidence packaging and Markdown tracking

The current checklist is in [FORGE_MISSION_STATUS.md](../../../FORGE_MISSION_STATUS.md).
U302 records this result. U301 was allocated concurrently to a separate workspace
record; no existing uncertainty entry was edited or renumbered. Workspace and
Git worktree histories remain separate and preserved.

| Executed packaging check | Actual exit | Result |
| --- | --- | --- |
| Copied-record identity and Markdown links | 0 |683 raw record files match; report links resolve |
| Full staged whitespace check | 2 | Original upstream/generated/log whitespace retained |
| Authored whitespace check | 0 | Excludes only upstream snapshots, generated .hol exports and raw logs |

[Complete whitespace diagnostics and commands](records/packaging-check.json).
The full-check failure is preserved. It is not a proof failure or passing
whitespace result. No evidence bytes were normalized. A local unsigned commit
does not authenticate these new claims or grant publication/admission authority.
