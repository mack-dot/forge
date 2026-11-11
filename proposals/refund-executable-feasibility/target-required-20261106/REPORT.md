# U321 — BLOCKED: AUTHORIZED_EXECUTION_TARGET_REQUIRED

CURRENT none. M1 execution blocked. Stage12 unauthorized. end_to_end=false.
Parent checkpoint: U320, commit3e81393815a44dde3d20518a4f0929d3f6ffb2ae.

Target discovery found no established authorized macOS ARM64 execution target.
This is a scoped finding, not a claim that no external target exists.

| Source checked | Result |
| --- | --- |
| Local workflow configuration |14 runner jobs in11 files; all use Ubuntu labels. No macOS or self-hosted label. |
| Historical macOS runner proposals |Review-only plan. That preparation explicitly established no usable or registered runner. It does not authorize M1 use. |
| Existing SSH configuration |9 distinct aliases; none establishes macOS architecture, isolation or Forge authorization. No connection attempted. No private keys read. Host/account values are not archived here. |
| Local VM inventory |Reuse U320's absent tool/application results. No redundant launch or sandbox probe. |
| Current GitHub runner registry |UNKNOWN. Read-only `gh api repos/mack-dot/forge/actions/runners` exits1: error connecting to api.github.com. No dispatch. |
| Connected tools |No applicable macOS execution service identified. Unrelated hosting/security services were not used as fallback shells. |

The first GitHub recorder exits1 while saving a string as bytes. Its returned
API status/content were not retained; no runner count is inferred. The partial
file and failure remain. The corrected recorder preserves the connection failure.
The GitHub connector lacks the runner-inventory endpoint, so the CLI was used
for that read only. No alternate network route followed the connection failure.

The minimum user action is to name one existing authorized target and supply
connection/access details with a trusted host identity. The target must provide:

- macOS on ARM64, with a private writable `/var/tmp` and functioning `mkstemp`;
- enforced isolation and exclusive control of proof inputs/outputs against other agents;
- verifiable pinned HOL, Poly/ML and runtime identities, with source/build provenance;
- sufficient memory, disk and process resources, with declared limits.

Validate these properties before proof commands. A new external transfer still
requires explicit approval of its exact payload after the target is identified.
No infrastructure installation, charges, security changes or transfer is implied
by target discovery. No hostname found in SSH configuration is treated as such
approval.

The U320 failure and assurance matrix remain unchanged. No same-sandbox diagnostic,
SAT, physical proof, native execution, swarm, or independent replay ran. No new
artifact or proof audit was needed to establish this missing-target blocker.
All previous failures and evidence remain. No protected edit, Stage12, release
signing, deployment or remote publication occurred.

| Actual command/check | Exit |
| --- | ---: |
| Scoped workflow/configuration discovery |0|
| First GitHub read recorder |1|
| Corrected GitHub runner-registry request |1|
| Target validation / transfer / unchanged SAT |NOT RUN|

Records: `results/authorized-target-discovery-20261106/attempt-0001/` and
this packet's `records/`. No target was selected; isolation, provenance and
execution capability therefore remain NOT_ESTABLISHED.
