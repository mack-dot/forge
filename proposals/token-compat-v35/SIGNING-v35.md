# Stage 9 signing attempt 2 under v3.5 (plan; nothing here has run)

Installed: main `5b1b557037f4daaecb5e34f15ae69745f68f1e3f` (#25), lock
`a177cb07e3d1efa3f70c4af62cd707c6a1f2e1df62da8b4c53e23300a7a22be1`. Approved lineage:
#25 → #24 → #23 → #21 → ratified `19c4896b` (U159). `FORGE_SIGNING_AUTHORIZED` is `true`
(owner decision, U155).

## History kept (attempt 1, lock 9bf8f905, commit f4f8a68c)

- R1 run 40910241018: signed. 6 permanent Rekor entries under
  `provenance.yml@refs/heads/main`: log indices 3571986339 (release), 3571986951,
  3571987562, 3571988224, 3571988995, 3571989402 (controls). Artifacts preserved at
  `~/forge-stage9-signing-0001/artifact-r1/` (digests match GitHub).
- R2 run 40916168141: failed at preflight (stateless token); no Rekor entry.
- These cannot pair with attempt 2 (different lock and commit). They stay as evidence.

## Attempt 2 (each numbered step needs the authorization named)

1. **Dispatch authorization (owner):** "dispatch R1 and R2".
   - Preconditions checked by script: main = C (`5b1b5570` or a later approved merge whose
     lineage passes), variable `true`, no active runs, agent = `mackiannii`.
   - New request from a fresh clone at C: `producer.py --action request`, lock `a177cb07…`.
   - R1: `gh workflow run provenance.yml` with the request. Expect `proof` and `sign`
     success, 6 new Rekor entries.
   - R2: after R1 succeeds, `gh workflow run provenance-negative.yml` with
     `producer_run_id=<R1>`. Expect `negative` success, artifact
     `forge-stage9-negative-<R2>` with the wrong-signer bundle, 1 Rekor entry under
     `provenance-negative.yml@refs/heads/main`. This is the first real use of a stateless
     token by Forge code and by `actions/download-artifact`.
   - Download both artifacts into new empty folders; check digests; list Rekor entries.
2. **EXIT setup (agent, no credential):** fresh clone at C; copy the pinned Cosign
   darwin-arm64 (`9f9b8cd5…`) to `.toolchain/stage9/cosign`; run
   `write_controller_config.py --root <clone> --request <request.json> --controller
   <controller.sqlite> --candidate <R2 download> --implementation-sha256 a177cb07…`.
3. **EXITs (owner runs, with the read-only verifier token):**
   `proposals/token-compat-v35/run_exits_owner.sh <clone>` in the owner's own terminal.
   It reads the token without echo, runs the inline lock check, the bootstrap check and
   the six cases through the bootstrap (`deployed-identity` last), records every exit
   code, scans the records for the token, and unsets it.
4. **Acceptance:** each EXIT `passed` with harness exit 0. A setup error is
   `not_established` (exit 1) and never counts; up to 5 attempts per case are kept. A
   GitHub 503 is `not_established`. `end_to_end` stays false. Stage 9 completes only when
   all six pass.

## Open decisions for the owner

- The verifier token: the agent never handles it. If it is the token pasted into the chat
  (U119), it is exposed. It is read-only on a public repository, so it cannot forge
  GitHub's answers, but the record will say "exposed verifier credential".
- `FORGE_SIGNING_AUTHORIZED` stays `true` until the owner changes it.
