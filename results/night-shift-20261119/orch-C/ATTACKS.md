# Orchestrator C attack log and regression list (append only)

## C-ATT-01 (2026-11-19T14:32Z) proposer client: U+2028/U+2029 in a request id or charge id — CONFIRMED by C, KNOWN (unsure.md line 16105, review F5 LOW), STILL OPEN on target
- Class: malformed input; false rejection / liveness (no safety loss). Attacker: supplies an id text only.
- Target: 4af09308 + adoption-v6.diff; ts/refund-finality/proposer.ts:41-42 (node:readline splits at U+2028/2029; JSON.parse throws in the 'line' listener; the mint never resolves).
- Repro (cwd = target-v6; scrubbed env per WORKER_RULES): node --import tsx orch-C/c2-malformed/repro_proposer_u2028.ts <target-v6> <issuebytes2.cjs>
  SHA-256 958c02d9ec420ffdcb7dccbc5471cede352e3396ad96cd4974c5672ea1b9e879
- Expected: token delivered, sink commits. Actual (C's run): no answer, uncaught "Unterminated string in JSON"; EXIT 1. Control (`control` arg): EXIT 0. Logs: c2-malformed/recheck/f1.log, f1-control.log.
- Sent to B: 14:32Z. B regression: PENDING. Re-run against fix: NOT RUN.

## C-NEG-01 (14:32Z) malformed inputs, serializer, decoder, value conversion — NO counterexample (C re-ran: exit 0 each)
- c2-malformed/fuzz_mint_commit.ts 2000 cases seed 11: 204 issued = 204 committed (135 zero-amount), 0 defects; minter bytes == canon bytes; signedBytes injective on the cases. recheck/fuzz11.log.
- c2-malformed/variants.ts: 21 PASS 0 FAIL (Ed25519 S+L refused; 18 base64 variants refused; 12 non-canonical texts refused; zero-amount commits and dispatches; hostile ledger lines fail closed). recheck/variants.log.
- Worker runs only (not re-run by C): fuzz seeds 12 and 0, restart_boundary.ts 19/19.
- Note N4: ids that differ by NFC/NFD, case, trailing space are distinct refunds (spec: exact match). Not a defect.
