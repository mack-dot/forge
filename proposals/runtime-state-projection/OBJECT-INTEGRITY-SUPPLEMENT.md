# Adversarial controls for the local proof-object anchor

Proposal commit5bb008a1 remains unchanged, local and unapproved. This supplement
does not change its mathematical claim, activate a policy or authorize release.

New actually executed controls:

| Operation | Actual exit |
| --- | --- |
| Compile a weaker20-state statement under the same Rocq module/lemma names |0|
| Existing audit-driver guard on corrupted original proof object |1|
| Same guard on the compiled weaker proof object |1|
| Expected-outcome matrix |0|

Both guards rejected with exactly
`AssertionError: DEPENDENCY_BYTES:/observed/ObservedTransitions.vo`.
Neither negative started the kernel or caused OOM. The original separately held
expected digest, driver, source and object remain unchanged. The previous full
positive567-module kernel check was not rerun.

This closes a direct adversarial check for local root-object identity. It does
not establish durable provenance or coordinated rewriting resistance when an
attacker controls both an expected identity and its candidate. The current
expected identity is held outside each candidate fixture mount. Cross-run
receipt adoption remains disabled.

Records: `results/campaign-observation-adversarial-2026-11-02/attempt-0001/`.
The corrupted fixture's inherited generic compiled-candidate flag describes its
ancestor, not the mutated bytes; an explicit correction preserves that distinction.
No accepted specification, baseline policy, workflow, runtime or Stage12 changed.
