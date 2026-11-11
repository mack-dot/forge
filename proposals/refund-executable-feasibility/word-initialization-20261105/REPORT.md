# Exact refund word initialization and conditional trace — U303

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. M1 and integration EXIT: **NOT_ESTABLISHED**.

The exact refund data-to-word code relation is now checked. The existing
`word_to_stackProof.make_init` supplies the fixed word-state fields. Composing
these facts with U302 removes the code-relation and static-initializer premises
from its conditional trace theorem. Sixteen source, state, resource and oracle
conditions remain. This is a defined model state, not a physical runtime witness.

The goal remains the full approved refund R1–R5 integer/Unicode behavior for the
exact executable. This packet does not narrow that contract. Its source branch
uses the existing canonical request contract. Error-input work remains separate.
The fixed RISC-V example is supporting work; M2–M4 remain later priorities.

## Checked links

| Link | Result and exact boundary |
| --- | --- |
| Data labels | PROVED. The exact compiled refund data labels are distinct and above reserved stub labels. |
| Data-to-word code relation | PROVED. An intermediate code map relates the exact data program to the exact `to_word` result; code domains match. No code-relation premise remains in the composed theorem. |
| Word initializer | PROVED for existing `make_init`: local0 return location, empty word stack, handler/termdep0, stack maximum1, locals size0, oracle state and supplied fields. The input stack state is still abstract. |
| Configuration | PROVED. Exact ARM8 data configuration is valid, GC is enabled, ISA width is64, and the dimension is supported. |
| Initialized one-epoch trace | PROVED under the sixteen listed conditions. It composes the exact code/initializer with U302, rather than assuming arbitrary code relations. |
| Lower compiler events and target-prefix exclusion | NOT_ESTABLISHED. One modeled word-trace epoch does not establish physical installer exclusion. |
| Full executable/runtime assurance and independent admission | NOT_ESTABLISHED. Resource adequacy, physical applicability and the approved assurance chain remain open. |

No new machine semantics, verifier, axiom, framework, runtime permission or
acceptance policy was introduced. Successful modeled Install events are excluded
from this conditional word trace. Target `InstallApp` and physical installation
are separate obligations. Failed attempts are not universally excluded here.

## Exact claims

[Source and code relations](records/word-code-exact.sml) export six theorems in
`forge_refundWordInitialization`:
`compiled_raw_code_rel`, `refund_data_labels`, `make_init_static`,
`compiled_word_code_rel`, `to_word_code_rel`, and `refund_word_code_rel`.

[Composition source](records/initialized-epoch-gc.sml) exports
`forge_refundInitializedEpoch.refund_word_config_facts` and
`refund_initialized_single_epoch`.
The [full printed statement](records/epoch-0002/stdout.log) preserves every premise.
[Explicit expected claims](records/expected.sml) state the same contract using the
published initializer. Seven statements match exactly. The last comparison uses
HOL's `let` reduction and a kernel proof of complete premise equivalence.

The related word state uses exactly:

```text
make_init arm8_config
  (arm8_config.reg_count - (LENGTH arm8_config.avoid_regs + 5))
  s
  (fromAList (SND (to_word arm8_config
    (set_oracle arm8_backend_config oracle) refund_prog)))
  co
  (word_ptr_eq (ensure_fp_conf_ok arm8_config
    (set_oracle arm8_backend_config oracle).data_conf))
```

`oracle` and `info` are the existing exact compilation artifacts. The theorem
replaces the FFI with `basis_ffi ext cl fs`. This is not evidence that the physical
loader or FFI satisfies that relation. U302's reference to “physical make_init”
should be read as an unresolved physical relation to the *modeled* initializer;
`make_init` itself is a model function, not a verified physical loader.

## Sixteen retained conditions

| Group | Conditions still required |
| --- | --- |
| Source/environment —4 | Exact canonical request on stdin; `wfcl cl`; `wfFS fs`; `STD_streams fs`. |
| Stack/frame accounting —2 | Nonempty input stack; frames equal those computed for the exact word code. |
| Memory/store —1 | `init_store_ok` for the input store without Handler, memory/domain and code/data buffers. |
| Resource adequacy —1 | Exact `data_lang_safe_for_space` for the source input, derived limits and frames. |
| GC/endianness —2 | Input GC function and endianness match the exact data configuration. |
| Compiler/oracle equations —4 | Exact data compiler-function equation, word-oracle equation, and the two retained `tcc`/`tco` abbreviation equations. |
| Future oracle programs —1 | Every data-oracle program respects reserved stub labels. |
| Pointer equality —1 | The all-clock representative-oracle equation for this initialized word state. |

The counts describe explicit antecedents, not independent physical assumptions.
Some will follow from existing lower-pass constructors and compiler lemmas.
None may be silently treated as satisfied. In particular, source non-failure
and a valid compiler configuration do not establish memory or resource adequacy.

## Executed checks

| Command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Code bundles1–3 / repeat | 1/1/0;0 | Constructor and overload qualifiers corrected; six claims checked |
| Epoch composition first/corrected/repeat | 1/0/0 | GC constructor qualifier corrected; two claims checked |
| Exact imports1–5 | 1/1/1/1/0 | Type annotation, reduction, memory-load and premise-normalization failures preserved |
| Premise diagnostic | 0 | Both complete antecedent sets contain16 conditions |
| Wrong return location / empty input stack | 1/1 | Both altered model claims reduce to an unproved false goal |
| Substituted word code | 1 | Exact code-relation statement mismatch |
| Omitted space condition | 1 | The required resource predicate remains unproved |
| readback.py | 0 | Eight claims,488 theory nodes,2421 hashed dependency files |
| Native/hosted execution, independent full-chain replay, admission, off-machine restore | NOT RUN | No new runtime or operational completion |

Both new theories reproduce all four exports byte for byte: eight identical
files. Imported claims have no explicit hypotheses or new tagged axioms. The
closure retains the four existing Boolean foundations: `SELECT_AX`, `INFINITY_AX`,
`ETA_AX`, and `BOOL_CASES_AX`. Cached same-host imports are not independent clean
full-chain source replay, producer authentication or release admission.

No failing proof exceeded five attempts. The code and composition proofs passed
on their first actual proof attempts after parsing fixes. The full premise-
equivalence proof failed once, then passed after normalizing the assumptions as
well as the goal. Earlier import parsing, conclusion comparison and loading
failures did not reach that proof. U290/U297 remain stopped.

The expected statement initially left a metadata type variable unconstrained.
After correcting that annotation, comparison exposed a `let` versus application
form. HOL reduced both forms. One remaining premise used `co`, GC and endian
fields while the exported theorem had already substituted their retained
equalities. A diagnostic identified precisely that difference. Normalizing both
sides under the unchanged equalities proves equivalence of all sixteen premises.
The theorem sources and exports did not change during these audit repairs.

`exact-import-0003` ran out of store while loading cached dependencies. It never
checked claims. That failure is preserved separately from proof/negative results.
After the other owned check was terminal, the same audit source loaded serially.
The cause of memory exhaustion is not proved. No host process was killed and no
toolchain, theorem, memory policy or CPU limit changed. Subsequent checks ran one
at a time. The earlier live-handle wording is clarified in the second memory
observation record; an empty process snapshot is not a verified live process.

Negative checks establish the stated model/claim refusals. They do not constitute
physical attacks, receipt-authentication tests or independent admission decisions.
A failed proof is not automatically a universal behavioral counterexample.

[COMMANDS.md](COMMANDS.md) records exact child argv, numeric exits, source hashes
and observed local durations. [Readback](records/readback.json) binds dependencies,
exports and inputs. Local durations are not hosted runner costs or benchmarks.

## Next smallest authorized action

Bind the word oracle to the existing exact `cake_orac` construction using
`backendProof.data_to_word_orac_eq_std` and the recorded compilation theorem.
Then instantiate the compiler-function and stack-state conditions with the
published lower-pass constructors. Keep the resource and pointer-representative
conditions explicit unless separately proved. Connect word events through the
remaining compiler passes to U298's target-prefix condition; equal final results
or oracle functions do not alone prove event correspondence.

The U296 physical/runtime matrix remains open. Independent full-chain checking,
source interpretation review, authenticated new claims/provenance and admission
remain required. Other-device archive hashes and restore remain unverified.
Effective GitHub protections were not refreshed. These operational limits are
separate from the mathematical premises.

## Review and authorization

Review the exact sources, eight claims, retained conditions, controls and closure.
This is a local proposal. Protected adoption, publication/push, merge, dispatch,
signing, admission and deployment retain their approval boundaries. No Stage12,
Node, SPM or infrastructure expansion occurred.

Baseline commit: `6116d584a0c1533c681bf45cde9d4156640acc00`.
The previous goal turn made progress; this turn closes further model links.
CakeML: `cd9155694c16831373ab695a670794f23282ed62`.
HOL: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
Nineteen pinned source snapshots,50 protected files,1612 prior packet members,
mission bytes and the native artifact match their recorded identities.
Tracked toolchain trees remain unchanged.

Native SHA256:
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.

| New theory data | SHA256 |
| --- | --- |
| `forge_refundWordInitializationTheory.dat` | `2c7a3b4f3f0ee40bc9ddbb2a69d392181d886f2f3565b6f617d3434306991833` |
| `forge_refundInitializedEpochTheory.dat` | `34e3a3972507a4d982994c6a4688f78aaa0b65efe4e88e56f241f5b8eb3fe1f5` |

## Packaging and tracking checks

The [mission checklist](../../../FORGE_MISSION_STATUS.md) records the next task.
Both workspace and Git worktree histories are preserved separately. U303 is
append-only; no previous uncertainty entry was changed.

| Executed check | Actual exit | Result |
| --- | --- | --- |
| Copied-record identity / Markdown links | 0/0 |532 raw files match; linked records exist |
| Full staged whitespace | 2 | Exact upstream/generated/log whitespace preserved |
| Authored whitespace | 0 | Excludes only upstream, generated .hol files and raw logs |

[Complete packaging diagnostics](records/packaging-check.json). The full whitespace
failure is retained. It is not a proof failure or a passing whitespace result.
A local unsigned commit does not authenticate or authorize these new claims.
