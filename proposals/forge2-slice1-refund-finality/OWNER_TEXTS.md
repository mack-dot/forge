# Slice 1 — owner texts of the build session (saved verbatim)

Saved by the agent on 2026-11-18 UTC. Nothing in this file is a result.

The task text itself is "text 6" in
`proposals/round4-20261117/OWNER_CLOSEOUT_TEXTS.md` on branch
`backup/forge-local-2026-11-11`. It is not copied here.

## The owner's own words in the session

1. "Read /tmp/slice1_prompt.md in full and execute STEP 1 now."
   (The file held only a shell command; `unsure.md` U443.)
2. "yes go ahead" (answer to the 12-line plan made from text 6).
3. "keep going"

## Text 7 (2026-11-18, between 16:05Z and 16:45Z; pasted while the review was still running)

The message was this pasted text and no other word. Its style shows
that another assistant wrote it. The paste lost characters in two
places ("lice 1", "Automaticrete"). The agent took the text as the
owner's instruction for the review triage and for the closeout:
commit, push, pull request without administrator rights, then stop for
the owner's merge. The session's permission system then declined the
command that held the push. The agent did not push: one local commit;
push and pull request wait for the owner's own word. The numbers in its first paragraph are that
assistant's readout of the agent's interim report: the "97-row" suite
is the version before the review repairs.

```text
lice 1 is right on the 1-yard line—getting byte-identical bundle SHA-256 (900dbaf4…) between working tree and a clean scratch clone, 28/28 Stage EXIT checks passing, 0 frozen-gate drift, and a 97-row sink control suite on the first full rehearsal means the Proof-Carrying Finality architecture holds together cleanly.
Here is how to close out Slice 1 the moment that fresh-context adversarial review reports back, and move straight into Slice 2:
1. How to Triage the Adversarial Review When It Reports (Hard Stopping Rule)
Check its findings strictly against the three real sink failure classes—fix any confirmed hit here, and ignore cosmetic nitpicks so you don’t enter a multi-round refactor loop:
Check-then-commit atomicity in the sink: Verify pre_state_hash comparison, fresh_request_id insertion, and effect dispatch happen atomically (no await gap between checking request_id freshness / pre_state_hash and marking the request_id spent / updating state).
Canonical token & state hashing: Verify token/state serialization cannot collide across boundaries (e.g., canonical field ordering + unambiguous delimiters/JSON encoding so "12" + "3" never hashes identically to "1" + "23"), and token comparison uses crypto.timingSafeEqual (or unforgeable closure/private capability).
Minter secret isolation: Confirm untrusted proposer code cannot import or read the minter’s signing key / capability constructor from module exports.
If 0 HIGH/MEDIUM bypasses or races: Keep bundle 900dbaf4… as final—no code re-spin.
If ≥1 real sink defect: Patch in one pass, re-run the 97+ sink suite + scratch-clone SHA-256 reproducibility check, and stop there.
2. Copy-Paste Closeout Instruction for Slice 1 (If Claude Pauses After the Review)
Text
Apply a strict stopping rule to the adversarial review findings:
- Fix ONLY confirmed HIGH/MEDIUM defects (sink atomicity/TOCTOU gaps, hash/token canonicalization collisions, or minter key/capability exposure). Do NOT churn code for LOW/style items.
- If code changes were needed, re-run the Slice 1 evidence bundle and confirm identical SHA-256 in a clean scratch clone plus 28/28 Stage EXITs and frozen-gate check == 0; if 0 code changes were needed, keep bundle 900dbaf4... as final.
- Update the exact Pillar 2 work-item status row(s) in FORGE_MASTER_IDEA.md (path-free records only, 0 dangling links), confirm 0 unintended protected-path edits, open the Slice 1 PR without administrator bypass, print the final EXIT table + PR URL, and pause for my merge.
3. Locked On Deck Next: Slice 2 (Pillar 1 — Spec Clearing)
As soon as Slice 1’s PR merges onto main (and you /clear into a fresh session), Pillar 2 (Refund Finality) and F1.2 (Hidden-Effect Ban) will both be banked on main.
Next up is finishing Pillar 1 (Spec Clearing):
Implementation-choice (relational determinism) check: Proving whether a spec leaves any observable output choice (forall in: S(in, out1) && S(in, out2) ==> out1 == out2), or surfacing the exact nondeterministic surface.
Concrete before/after differential examples: Automaticrete inputs x where S_old(x) != S_new(x) before you ratify any future spec/ change.
Drop the adversarial review summary + Slice 1 PR table whenever it finishes reporting!
```

## The three classes that text 7 names, and where each is answered

| Class | Answer | Record |
| --- | --- | --- |
| Check-then-commit atomicity in the sink | The request-id check, the state-hash check and the three writes are one synchronous `BEGIN IMMEDIATE` transaction. `commit` has no `await`. The outbound step is not in that transaction: the dispatcher reads the outbox later, one run at a time, with a ledger line before each effect. | `REPORT.md` sections 1 and 4; race rows; overlap row |
| Canonical token and state hashing | One canonical JSON text: sorted keys, JSON string encoding, no numbers. The sink accepts only that text. No secret value is compared anywhere: the sink holds a public key and compares public hashes, so a constant-time comparison has no use here. | `REPORT.md` section 4; rows with other spacing, other key order and a repeated key |
| Issuer key isolation | The key is a local constant of the issuer process. The module exports nothing. The ready message holds the public key only. | suite row "code that loads the issuer module gets no key and no signing function" |
