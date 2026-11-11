# Refund initialization: static conditions discharged — U313

CURRENT stage: **none**. Active milestone: **M1**. Stage12 is unauthorized.
`end_to_end=false`. M1/integration EXIT: **NOT_ESTABLISHED**.

The full approved refund R1–R5 integer/Unicode behavior remains the target.
This result closes two conditions in the modeled initialization relation and
validates the preceding U312 checkpoint. It does not establish the full executable
claim. The fixed RISC-V example remains supporting evidence; M2–M4 remain later.

## Checked change

[Proof source](records/static-normalized.sml) builds four claims in
`forge_refundInitializationStatic`. The exact ARM8 backend configuration is valid;
its register-name map is a permutation; and every program from the exact stack
compiler oracle satisfies published `good_code`. Applying those facts removes
the permutation and future-code conditions from the initializer theorem.

| Claim | Scope |
| --- | --- |
| `refund_config_ok` | Existing exact compiler configuration satisfies `backend_config_ok` |
| `refund_name_permutation` | Its configured register-name map permutes the register names |
| `refund_stack_oracle_good` | All future programs of the exact compiled stack oracle satisfy `good_code` |
| `refund_initialization_static` | Fifteen remaining conditions imply initializer success and conditional stack/lab semantics equality |

The future-code proof applies the published `oracle_stack_good_code` theorem to
an abstract ARM8 configuration constructed with the published target and register
fields. Published `arm8_machine_config_ok` proves that configuration is valid.
Unused fields remain arbitrary. The resulting future-code theorem has no machine
configuration premise or chosen runtime state. This witness serves only to prove
that static compiler property. It does not replace the physical `mc`, memory or
runtime assumptions in the initialization claim.

The [fresh audit](records/expected.sml) specifies all seven parent/new statements.
It checks five directly after kernel normalization and proves equivalence of the
complete antecedent sets for both initialization statements. The original has
17 conditions; the final claim has15. No required condition is dropped by fiat.
[The executed audit](records/exact-import-0002/stdout.log) contains the results.

## Remaining conditions

The final15 conditions are: the exact `memory_assumption`; link-register exclusion
from saved registers; preservation of saved registers by I/O and calls; alignment
of memory and shared-memory domains; `good_code` for the exact initial stack
program; three saved-register memberships; and five register-name equalities.
The success conclusion is `SND initial <> NONE`. Stack/lab semantics equality also
requires stack non-failure. The [printed claim](records/static-0003/stdout.log)
gives the complete terms, quantifiers and source/configuration identities.

These are the conditions of this lemma, not a count of every M1 assumption.
The separate source, pointer, resource and FFI/OS premises remain required.
The model initializer can still fall back when its premises are not met. No
physical memory-layout witness is established by this conditional theorem.
Final semantics equality does not prove U298's every-prefix installer exclusion.

## Actual checks and preserved failures

| Check | Actual exit(s) | Result |
| --- | --- | --- |
| Static bundles1/2/3 | 1/0/0 | Name-resolution failure;16-condition checkpoint;15-condition final claim |
| Complete imports1/2 | 1/0 | First refuses incomplete premise reduction; second checks all seven statements |
| Original initialization / static proof repeat | 0/0 | Both theories reproduce their four exports |
| Export-byte comparisons | 0 | Eight identical export files |
| Substituted stack code / substituted oracle / omitted memory | 1/1/1 | Intended refusals after all seven positive checks |
| Missing-memory first/corrected; sequence/completion guards | 1/1;1/0 | Initial tactic error is refused; corrected control exposes the premise |
| Evidence readback | 0 | Exact files, dependency closure, source pins and previous packets match |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Complete assurance remains open |

The first bundle names `find_name` in the wrong theory. The published source
shows it is an overload for `tlookup`; using the existing overload fixes the
parser error. The second bundle proves all four results but leaves the name-map
condition in the combined claim. Its helper contains the `set_oracle` expression;
the combined statement has already projected the unchanged stack configuration.
The first complete audit refuses the resulting16-condition statement. Normalizing
the already checked helper lets the third bundle remove that condition. The
expected15-condition contract and the original theorem remain unchanged.

No failing proof exceeds five attempts. U290/U297 remain stopped. All parsing,
path-discovery, incomplete-composition and audit failures remain in the records.
A script error is not a successful security rejection.

The controls reject a substituted empty stack program and a substituted lab
oracle at exact statement binding. Removing the memory condition leaves the
published `memory_assumption` subgoal unproved. These are claim/premise controls;
they are not physical execution counterexamples or release-admission decisions.
Each first completes the unchanged seven-statement positive audit.
The first missing-memory script instead failed at `MATCH_MP_TAC` with `No match`.
The sequence guard rejected that reason. A new copy uses `DISCH_TAC` to preserve
the conjunctive conclusion before applying the theorem. The attempted premise-free
claim is unchanged. Only the corrected run counts as the missing-memory control.

[COMMANDS.md](COMMANDS.md) records exact child commands, numeric exits and local
durations. All seven claims have no explicit hypotheses or new tagged axioms.
The audited closure contains 483 theory nodes and 2406 hashed dependency
files. It retains only the existing Boolean foundations: `SELECT_AX`, `INFINITY_AX`,
`ETA_AX`, `BOOL_CASES_AX`. Same-host imports of cached parents are not independent
clean full-chain replay or authenticated evidence production.

## Exact identities and measurements

| Item | Value |
| --- | --- |
| Baseline local commit | `195ad87e6e82badbc16151bb231581c410cebdb7` |
| Final proof source SHA-256 | `303ea5ad004ab8988ba79acc804d4a9055a64ec892f5285750ebf4d3970cdf67` |
| Final theory data SHA-256 | `985e43cd906cd26f82f69da2ae3081ee7c768eb710a8a7e8de1f8d6239c3f948` |
| Existing native artifact SHA-256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Final proof wall seconds | 73.43925004199264 |
| Full successful import wall seconds | 74.49953612498939 |
| Original / static repeat wall seconds | 96.35147487500217 / 83.72585545800393 |
| Hosted runner-minutes / performance comparison | NOT RUN |

[Readback](records/readback.json) binds14 published source files,50 protected
paths, mission/native identity and892 prior packet members in each copy.
The U311/U312 packets remain immutable. Local durations are observations, not
hosted costs or measured performance savings. No new native execution occurred.

## Smallest next executable check

Discharge `good_code` for the exact initial stack program. Reuse published
`to_word_labels_ok`, `data_to_word_compile_conventions`,
`word_to_stack_compile_lab_pres` and `word_to_stack_stack_convs`. Preserve the
exact compilation/configuration binding and the reserved stub-label bounds.
Then discharge justified saved-register/configuration conditions through the
published ARM8 initialization relations. Preserve the actual memory and alignment
requirements. Continue to the lower-pass transition relation and U298's complete
prefix condition; final-output equality is insufficient.

Physical applicability, source/resource/FFI/OS conditions, independent review and
replay, and new authenticated provenance/admission remain open. The owner reports
another-device backup; exact required archive hashes and a restore on that device
are still unverified. Effective GitHub protections were not refreshed here.

Local checks, proposals and unsigned commits remain authorized. Protected
adoption, publication/push, merge, dispatch, signing, admission and deployment
retain their exact approval boundaries. No new stage, framework, semantics,
axiom, persistent infrastructure, Node integration or SPM work is introduced.

## Packet and tracking integrity

Packet-copy and documentation/history/link checks exited `0`. All201 raw files
match, and each uncertainty log retains its exact previous prefix. The separate
workspace U310 history remains intact. See [package readback](records/package-readback.json)
and [documentation check](records/documentation-check.json).
The full staged whitespace check exited `2` on preserved raw/generated bytes;
the authored-file check exited `0`. [Exact record](records/whitespace-check.json).
No proof evidence was edited to remove formatting warnings. These checks do not
establish physical applicability, independent replay, admission or backup completion.
