# FORGE — NEXT ORCHESTRATION OBJECTIVE (owner directive 2, pasted 2026-11-19 ~14:16Z, stored verbatim)

Note: this file stores the owner's pasted directive. It supersedes the goal
lists in DIRECTIVE.md where they conflict. It does not authorize merges,
signing, deployment, protected-file changes, or stage promotion.

## Mission: Counterexample Closure and Executable Refinement

Continue autonomously. Do not stop after producing an interim report. Do not declare a stage CURRENT or M1-B closed without satisfying the existing authorization and evidence gates.

**Primary objective:** Convert the discovered counterexamples into permanent, executable, adversarially tested guarantees and progressively bind the formal proofs to the production implementation.

### Orchestrator A — HOL and proof-to-executable chain

1. Finish the running HOL job without interference.
2. Record its exact theorem statements, assumptions, exit codes, proof logs, and remaining obligations.
3. Identify the smallest missing refinement boundary between the proved properties and the actual executable.
4. Assign parallel workers to independent proof obligations where resource limits permit.
5. Preserve all previous assumptions and authorization boundaries. Do not silently weaken a theorem to get a passing result.

### Orchestrator B — Adversarial implementation hardening

1. Produce minimal reproducible regressions for both duplicate-effect counterexamples.
2. Implement durable database-level safeguards for request identity, atomic effect commit, charge binding, and cumulative refund limits.
3. Test concurrent writers, process restarts, cross-charge replay, partial failure, and retries.
4. Diagnose the nine false rejections in the stricter gate. Categorize each by precise cause. Preserve rejection of all unsafe submissions while recovering legitimate acceptance.
5. Run the full v6 patch suite once a heavy-job slot is available.
6. Address rollback and forged initial databases explicitly. A database cannot authenticate its own history. Specify the required external trust anchor and freshness mechanism; do not claim rollback resistance without it.
7. Compare the actual sink against the approved formal specification, rather than relying solely on model-to-model equivalence.

### Independent red-team workers

[text garbled in paste; likely "Continuously"] uously attempt to break proposed fixes using new counterexamples, including concurrency, replay, malformed inputs, identity substitution, zero-value refunds, crashes, and state rollback.

Keep attack generation independent from fix implementation. Every genuine counterexample becomes a permanent regression.

### Owner decisions

For B-10, use the existing approved, versioned policy and authoritative persisted charge state as the governing context. Where ambiguity remains, report the precise conflicting alternatives and required owner decision. No unapproved policy changes.

Do not bypass OWNER_REQUIRED.md, change protected files without authorization, or promote Stage 12.

### Resource and execution discipline

- A's running HOL job retains its current heavy-job slot.
- B performs lightweight analysis and tests until a slot becomes available.
- Stop workers before disk free space falls below 30 GB.
- Avoid redundant temporary copies and competing heavyweight proof runs.
- Commit and push authorized, tested incremental work with evidence.
- Automatically queue the next independent objective after each successful task.
- Report blockers without stopping unrelated productive work.

### Acceptance criteria

- Both duplicate-effect exploits fail against the fixed implementation.
- Previously legitimate transactions still succeed.
- All seven known unsafe gate submissions are rejected.
- The nine observed false rejections are explained and resolved, or explicitly documented as unresolved.
- The complete v6 suite passes.
- The HOL result is independently reproducible.
- Every security claim names its actual trust assumptions.
- The remaining path to end_to_end=true is documented with exact unproven transitions.

**Do not optimize for the number of proofs or amount of code written. Optimize for the number of real, independently verified attack classes eliminated.**

After closing each counterexample class, search for the next counterexample at the nearest unproved implementation boundary. Continue until genuinely blocked by owner authorization or an irreducible technical dependency.
