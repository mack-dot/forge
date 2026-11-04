# Fixed-ELF conditional assurance — review scope

This packet requests no merge, dispatch, signature, admission or deployment.
CURRENT none. Stage12 unauthorized. The exact source/claim/profile is for review.
The final report supplies terminal check results and immutable packet digests.

## Exact proposed claim

For ELF8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6,
the specified LPS initial machine computes GCD(1071,462)=21 in a0 after15
instructions, must exit0 under the explicit Model premises, and has a modeled
trace ending in ExitEv0. The recorded finite QEMU execution has matching
PC/GPR/FPR/instruction projections, complete relevant file-backed LOAD identity,
and an observed normal host process exit0.

The relationship to actual execution is conditional on the reviewed assumptions
T1–T6 below. It is not a universal QEMU or Linux correctness theorem. It is not
an arbitrary-input GCD claim. Approval must not convert assumptions into facts.
The new claim is separate from PR37's existing canonical initializer statement.

| ID | Assumption requiring independent review | Evidence and precise limit |
| --- | --- | --- |
| T1 | Kernel/checker, primitive assumptions and image import are sound; held expected identities are authentic |Full recursive replay, exact assumption names and loader/source/ELF binding. Cryptographic hashes alone do not establish authority. |
| T2 | Entry abstraction maps the actual stopped entry to the modeled observable initializer and running/no-lazy Model conditions |All observable registers, PC and relevant LOAD bytes match; formal initializer satisfies the guards. The physical Model relation and initial logical pending-syscall interpretation remain assumptions. |
| T3 | QEMU faithfully executes/captures the used instruction sequence and no relevant code/register interference occurs in the baseline |Finite21-frame equality and no-data-access model proof; actual register interference changes exit to2 and is rejected. This is finite evidence, not a universal simulation proof. |
| T4 | QEMU's non-RVE a7/a0 dispatch and Linux exit_group/wait behavior have the stated exit meaning |Authenticated source inspection, pending94/0 model fact, modeled ExitEv0, GDB report and independent parent wait. GDB report precedes host exit; parent wait is required. |
| T5 | Runtime/observer/container/VM/host translation/hardware are faithful; required progress is supplied |Pinned QEMU/GDB/image and observed host identity; no physical-machine or host-kernel formal proof. Universal physical termination needs stronger progress/noninterference conditions than one successful run. |
| T6 | The authoritative producer, review, source, receipt and admission bindings remain trustworthy |Existing Stage9 mechanisms can be extended after review. Current local results have no new authorized producer signature or admission. |

## Smallest protected contract change

The proposed patch adds `spec/provenance/fixed-elf-correspondence.md` as a
non-activated contract. Its bytes derive from this exact claim and assumptions.
No existing theorem, required claim, policy, allowlist or consumer is modified.
Review/adoption of this contract is separate from implementation approval.

After claim/profile review, the smallest implementation proposal must bind:

1. Approved contract digest and exact statement identities.
2. Freshly checked proof objects, wrapper/root identities and complete actual closure.
3. The same fixed ELF digest and generated-image binding.
4. Pinned checker image, published tools and exact allowed assumption names.
5. Existing in-toto/Sigstore authorized producer/source/run identities.
6. Approved QEMU/GDB/loader/host profile and observer script digests.
7. Actual run-specific artifact read-back, trace, result register and parent exit.
8. Trusted expected admission policy, fresh controller request and atomic replay refusal.

The existing integration points are `gate/provenance/producer.py`,
`gate/provenance/release.py`, `gate/provenance/observe.py`, their implementation
and artifact locks, and `policy/provenance.json`. Current release.py checks exact
canonical evidence, proof receipt, claim/method, producer and source. Preserve
those checks. The current policy's `riscv_execution_claimed=false` and
`scope=deployed_file_identity` cannot be upgraded by adding candidate metadata.

A fresh authorized producer must execute the selected proof/observation steps
in the approved environment. Signing copied local summaries cannot stand in for
that execution. A different hosted environment may produce a different entry
state; capture and recheck it before applying this exact observed-entry theorem.
Do not silently reuse this local run's SP or profile for GitHub-hosted execution.

## Approval boundaries

- Independent review of PR37 atfc85ecc2 and this separate supplement is pending.
- Human intent review must cover the exact fixed-input result, conditional scope
  and T1–T6; exact profile adoption must cover its pinned inputs and open limits.
- Any protected producer/consumer/policy/workflow diff requires its own concrete
  review. This packet does not authorize a future unspecified implementation.
- Publication, merge, workflow dispatch, signing, admission and deployment each
  retain their corresponding explicit authorization. No self-approval or bypass.
- PR36's upload repair stays separate. Operational backup validation stays
  separate from mathematical correspondence. Keep end_to_end=false.
