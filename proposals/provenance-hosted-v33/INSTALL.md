# v3.3 installation and Stage 9 EXIT procedure (prepared; nothing here has run)

Trusted baseline: main `d43f5f4de55573a17f4f9cf4d41528dd159e9f2f`, lock
`be23ec85ec2d9652bd1c87f6870c0d7130862af169319af24975b941ac3b5f57`.
Candidate: `approval-manifest.json` (9 files, new lock
`a809f7017ce0980b26b81896216af7be30591a67a564adff273df576e2453a55`, diff
`b432024f9f3a2a6c32a1469b5378a34521546458a48698ea543a8b37e6ca4f72`). Evidence:
`results/stage9/v33-controls-0003` (48/48 controls, 14/14 v3.1 controls, 9/9 F1 controls) and
`results/stage9/v33-audit-0001` (independent re-attack).

## Precondition (failed on 2026-10-29)

The agent's `gh` must not be `mack-dot`. Test: `gh api user --jq .login` must print
the machine account, and `gh api repos/mack-dot/forge --jq .permissions.admin`
must print `false`. On 2026-10-29 the test printed `mack-dot` and `true`.

## PR sequence (smallest)

1. **CODEOWNERS** (`* @mack-dot`). The agent account opens it; the owner approves
   it by review. `audit_main_approvals.py` must then print APPROVED for its merge
   commit: the first positive control of the approval path.
2. **v3.3 install**: exactly the 9 manifest files, as one commit on a branch made
   from main. The owner approves by review (no bypass). Check after merge: main
   tree equals the candidate tree; `bootstrap.py --check` with the new lock; the
   audit prints APPROVED.
3. **No-signing rehearsal** (needs a dispatch authorization): a new request from a
   fresh clone (`producer.py --action request`); dispatch `provenance.yml` with
   the variable unset. Expected: the run name is `forge-stage9 <challenge>`; the
   sign job is skipped; the receipt records the run; controller checks as in
   `results/stage9/rehearsal-0001`, plus `common.run_identity` on the real run
   (the first positive V4 control).
4. **Records PR.**

## EXITs (each needs the signing authorization; none may run before step 3)

1. Choose a main commit C equal to the merged v3.3 commit. Create a request from
   a fresh clone at C. Main must not move until step 4.
2. Owner: `gh variable set FORGE_SIGNING_AUTHORIZED --body true`, then dispatch
   `provenance.yml` (run R1) and `provenance-negative.yml` with
   `producer_run_id=R1` (run R2), then `gh variable delete FORGE_SIGNING_AUTHORIZED`.
   Public effect: 6 Rekor entries under `provenance.yml@refs/heads/main` and 1
   under `provenance-negative.yml@refs/heads/main`. These are permanent.
3. Download the R2 artifact into a new folder. Run
   `write_controller_config.py --root <clone at C> --request ... --controller ...
   --candidate <download> --implementation-sha256 a809f701…`.
4. In the clone at C, with the verifier token in the environment only:
   first the inline lock/bootstrap byte check, then
   `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 a809f701… -- scripts/exit_stage_9.py --case X`
   for valid-bundle, unsigned,
   wrong-signer, wrong-digest, wrong-policy, then deployed-identity last (it
   consumes the request). The harness refuses any other launch.
5. Acceptance: each EXIT result is `passed` with harness exit 0. A setup failure
   is `not_established` (exit 1) and never counts.
6. Cleanup: delete the variable (step 2); `docker rm` the stopped
   `forge.stage9.role` containers; remove the `forge-verifier-git-*` stores; keep
   all records.

Tools: Cosign 3.1.4 darwin-arm64 `9f9b8cd5…` at `.toolchain/stage9/cosign`
(installed and checked); Docker Desktop with the pinned builder; the verifier
token (read-only, forge only; the exposed one revoked first).
