# Stage 9 completion experiment under v3.6 (plan only; nothing here has run)

Preconditions: PR for v3.6 approved by the owner at its exact head and merged by `mackiannii`
without bypass (merge commit C). Lock `5f78da2142699d51f4b9b47c41ba3202919196af575fee3ae67bed7f7ad264b0`.
`approved_lineage(C)` accepted: v3.6 → #25 → #24 → #23 → #21 → ratified `19c4896b`.
`FORGE_SIGNING_AUTHORIZED` as the owner configures it (`true` today, U155).

## Identities that change

| Item | v3.5 attempt 2 | v3.6 (expected) |
| --- | --- | --- |
| Source commit | `5b1b5570` | C (new) |
| Lock | `a177cb07…` | `5f78da21…` |
| Dockerfile (`recipe_sha256`) | `bb0a3d3d…` | `c915c79d…` |
| Package (image config) | `f584305022f2…` | `d9e9fb40f9d2…` (built twice locally, identical) |
| ELF (`artifact_sha256`) | `8ced2ab6…` | `8ced2ab6…` (unchanged) |
| Proof statements, policy, spec | — | unchanged |

The controller rebuilds the package from C; the request must show `d9e9fb40…`. Any other
value stops the plan before dispatch.

## Steps and authorizations

1. **Dispatch authorization** (owner): new request at C (fresh clone, `producer.py --action
   request`, new challenge); R1 `provenance.yml`; after R1 success, R2
   `provenance-negative.yml` with `producer_run_id=R1`. Preconditions checked by script:
   agent `mackiannii`, main = C, variable `true`, no active runs.
2. **Downloads**: R1 signed and unsigned, R2 negative, into new empty folders; digests equal
   GitHub's; list Rekor entries from the bundles.
3. **EXIT setup** (no credential): fresh clone at C; Cosign darwin-arm64 `9f9b8cd5…`;
   `write_controller_config.py` with candidate = R2 artifact, request = the new request,
   lock `5f78da21…`; inline lock check and bootstrap check.
4. **EXITs** (verifier token from Keychain `forge-verifier-readonly` per U163, or owner-run):
   one request, one lock, one candidate, in this order: `valid-bundle`, `unsigned`,
   `wrong-signer`, `wrong-digest`, `wrong-policy`, then `deployed-identity` **last** (it
   consumes the request).

## Expected outcomes

| EXIT | Positive gates | Negative gates (reason) |
| --- | --- | --- |
| valid-bundle | verified twice (Cosign 0) | altered evidence (`EVIDENCE_DIGEST`), fabricated receipt (`PROOF_RECEIPT_BINDING`), wrong method (`CLAIM_METHOD_BINDING`) |
| unsigned / wrong-signer / wrong-digest | positive before and after | `SIGNATURE_REJECTED` with Cosign non-zero |
| wrong-policy | — | `POLICY_BINDING`, `STALE_OR_SUBSTITUTED_REQUEST`, `EVIDENCE_BINDING`, `CLAIM_METHOD_BINDING` |
| deployed-identity | accepted deployment: UID 1000 reads `8ced2ab6…` in the running container | substitution mount (`DEPLOYED_ARTIFACT_MISMATCH`), duplicate admission (`STALE_OR_CONSUMED_REQUEST`) |

## Public disclosure

7 new permanent Rekor entries (6 under `provenance.yml@refs/heads/main`, 1 under
`provenance-negative.yml@refs/heads/main`). Project total after this run: 20 (13 so far).

## Retries and failures

- A GitHub 503, a network error or a setup error is `not_established` (exit 1), never a pass
  and never a security rejection. Each case keeps up to 5 attempts; then stop and diagnose.
- Cases 1–5 do not consume the request and may be re-run. A `deployed-identity` failure after
  admission spends the request (`CONSUMPTION.md`); a retry then needs a new request, R1 and R2
  (7 more entries) and a re-run of all six EXITs under that request.
- Before the EXITs: `docker rm` of stopped `forge.stage9.role` containers is not needed; keep
  them as evidence.

## Acceptance

Stage 9 is DONE only when all six official commands report `passed` with harness exit 0 under
one request and one lock, with real Cosign verification, the verifier credential, and the
records kept. `end_to_end` stays false.
