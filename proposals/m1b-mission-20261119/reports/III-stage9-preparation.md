# Step III: Stage 9 preparation, NOT activated (W6, Opus, read-only)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W6 stage9-prep, step III. I changed no repository file and ran no state-changing git command. I did not use the network, Docker, HOL, Dafny, any signing step or any workflow. `git status` is unchanged by me. Draft: <session scratch folder>/m1b/W6/STAGE9_BINDING_PROPOSAL_DRAFT.md (marked NOT APPLIED, NOT AUTHORIZED). Scratch check: …/W6/packet-check/.

## Finding 1: inventory (I recomputed every digest; HEAD 8e772b55)
- `implementation.lock` (76b983ac…, 100 files): 92 equal, 8 different, 0 missing. The working tree and the HEAD blobs agree. The 8 different files: gate/approval.py, gate/backends/dafny.py, gate/incremental.py, gate/refund.py, scripts/exit_stage_5.py, spec/refund/spec.lock, toolchain/linux-pins.json, toolchain/pins.json.
- `spec.lock` (43610d81…): `contract` (protocol.md 2784bdd0…) is equal. `policy` (9e27f627…) is equal. `locked_existing_files`: 39 equal, 8 different, 0 missing. The 8 different files: gate/backends/dafny.py, gate/common.py, gate/core.py, gate/dependencies.py, gate/refund.py, scripts/javascript_env.py, spec/refund/spec.lock, toolchain/pins.json. The spec.lock digest pinned in the impl lock is still equal.
- The lock rule is in `common.py:167-201` and `bootstrap.py:22-78`. It applies to every file under gate/provenance/, and to files with a code suffix under scripts/ and examples/binary/.
  - Six required files are unlocked: scripts/demo_gauntlet.py, exit_m1_conformance.py, exit_slice1.py, exit_slice2.py, exit_slice3.py, spec_clearing.py.
  - The rule allows two unlocked files: scripts/generate_examples.ts (it is code, but `.ts` is not in CODE_SUFFIXES) and examples/binary/README.md.
  - The untracked scripts/__pycache__ makes a local bootstrap fail with BYTECODE_CACHE. This is about this working tree only, not about the lock.
  - gate/gate.py, gate/booking.py and gate/backends/typescript.py are not locked. They are outside the rule.
- Other pins: `.github/workflows/booking-reuse.yml:43` pins the lock 76b983ac…, and line 42 pins bootstrap.py 8895a088… (still equal). There are no other pins outside proposals/, ROADMAP.md and unsure.md.
- `python_container_dependencies`: 45 file digests of pip-installed PyYAML 6.0.3 and idna 3.20 (cp312 manylinux). They are installed from upstream `tools/oft/requirements.txt` into `.toolchain/stage7/pydeps` with `--require-hashes`. Whole-map equality checks them at `hosted_setup.py:67` and `producer.py:144`. They are not repository files.
- The unapplied packet of 2026-11-19 is still exact:
  - `git apply --check` on HEAD gives exit 0.
  - Applied in scratch, it gives lock 190f938e… with 107 of 107 entries equal to the tree, and spec.lock 256310d8… with 47 of 47 equal. No unlocked code file is left in the three roots.

## Finding 2: what Stage 9 binds today
- Artifact: the Stage 7 RISC-V ELF `results/stage7/accepted/own/gcd-selftest.elf`, 1,240 bytes, 8ced2ab6…. It is packaged into a linux/amd64 image at /opt/forge/gcd-selftest.elf.
- Claims: S7-OWN-TERMINATION and S7-OWN-VALID-EXECUTION, by `kernel_checked_proof` (Rocq/rocqchk). Stage 8 refund evidence is supplementary only.
- Signer: `mack-dot/forge/.github/workflows/provenance.yml@refs/heads/main`, GitHub OIDC, repository ID 1434789853, owner ID 235131950. The negative workflow is provenance-negative.yml.
- Rekor: 20 permanent entries exist (U159, U162, U169). The last positive run was U169 at 624c9faf with lock 5f78da21, by actor mackiannii.
- Nothing names the M1 executable b8ed5ec2…7bb8 (`proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`, ARM64 Mach-O, 238,776 bytes). The refund contract files are only locked inputs.
- `protocol.md` says "The only release artifact is the 1,240-byte ELF". The verifier and producer code is Rocq- and ELF-specific: rocqchk in `release.py:110-142`, the stage7_own_job replay in `producer.py:140-205`, and the subject name at `producer.py:211`.
- Binding M1 therefore needs a new owner-approved contract 2.0.0: protocol.md, policy (version and epoch), and spec.lock with HOL4 identity lists. It also needs a separate exact implementation approval for artifact-identities.json, producer, release, observe, hosted_setup, preflight, runtime.json, Dockerfile, common, bootstrap, exit_stage_9.py and both workflows. The lock is regenerated last. All of these files are protected.

## Finding 3: approval-boundary weaknesses (by severity)
1. HIGH, the shared account.
   - `approved_lineage` (`common.py:281-331`) trusts "only the owner uses the owner account" and needs an owner APPROVED review of the exact head.
   - With the agent on mack-dot: GitHub blocks self-approval, so PRs from the owner account can never pass. The agent can also set the signing variable, dispatch, and admin-merge. If a second account opened a PR, the agent could also submit the "owner" review. So the human-approval check cannot tell the agent from the owner.
   - Inference, not run: today's main fails lineage. 17 of the 27 first-parent commits since baseline 19c4896b have author mack-dot. The recent merges were administrator merges with no review.
2. MEDIUM, the dispatcher chooses the lock.
   - provenance.yml takes `implementation_sha256` as a dispatch input (lines 44-49) and signs any main commit whose lock matches that input.
   - So the authorized identity can put permanent Rekor entries on unapproved bytes. Only the local verifier's own lock and the lineage check reject them.
3. MEDIUM, the PR gate gives no positive approval for Stage 9.
   - gate/provenance/ and governance/ are protected (`incremental.py:38`) but not ratifiable (`approval.py:19-32`). Every lock change ends REJECTED, and the only path is an owner override merge.
   - A PR cannot approve itself through the PR gate: records are read from the trusted base only (`approval.py:45`, `:115`).
   - For provenance, ratification records are read from the source commit itself (`common.py:258-261`). A PR can carry its own baseline record, and only the owner review covers it (see item 1).
4. MEDIUM (F1, accepted limit): gate/core.py, gate/dependencies.py, gate/backends/__init__.py, gate/backends/dafny.py and toolchain/install_ci.py are Tier-0 ratifiable, but they run inside the PR gate.
   - Frozen: the 8 `PR_GATE_FILES` (`approval.py:23`). All 8 equal `frozen-pr-gate-modules.json` today.
   - The frozen check is a manual script under proposals/round4-20261117/. No CI job runs it, and proposals/ is not protected.
5. LOW-MEDIUM: `_lock_rebind_only` (`approval.py:66-93`, `:135`) applies to any file named spec.lock, so it includes spec/provenance/spec.lock. A Tier-0 toolchain ratification can rewrite the provenance contract lock. This fails closed, because the impl lock pins that digest.
6. LOW: CODE_SUFFIXES lacks .ts, .js, .cjs, .mjs, .sml and .dfy. A new code file with such a suffix under scripts/ runs unlocked beside approved bytes. Today: generate_examples.ts. This matters for HOL scripts under track M.
7. LOW: gate/ratification.py is pinned only in `approval.PR_GATE_FILES`, the incremental input snapshot (`incremental.py:246`) and the unprotected frozen JSON. It is in no Stage 9 lock. The sign job does not import it.
8. Open residuals from U166/U169: F1 (Tmpfs not inspected), F3 (parent-directory modes), F4 (PAX/GNU layer parsing).

What stops a new script under scripts/: bootstrap.py walks the roots on every launch and rejects UNLOCKED_EXECUTABLE (only for the code suffixes). `source_tree` does the same at the verifier.

## Finding 4: the six EXIT cases
- All six need:
  - a clone at merged commit C with an approved, consistent lock;
  - Python 3.10.11 (present);
  - cosign at .toolchain/stage9/cosign (present; 9f9b8cd5… equals the darwin-arm64 pin);
  - the network for TUF `cosign initialize`, the GitHub API and git fetch;
  - FORGE_VERIFIER_GITHUB_TOKEN (read-only; I did not check it);
  - .toolchain/stage9/controller.json (MISSING), the sqlite controller database with a pending request (MISSING), and the downloaded R1/R2 artifacts (MISSING; there is no new run);
  - a lineage that passes (it fails today).
- What each case adds:
  - valid-bundle: the release bundle and controls.
  - unsigned: the release bundle.
  - wrong-signer: the R2 wrong-signer.sigstore.json.
  - wrong-digest: control wrong-digest/different.bin.
  - wrong-policy: four signed controls.
  - deployed-identity: Docker Desktop 4.48.0 (207573, the plist matches the pin; daemon not run), the buildx builder moby/buildkit v0.25.1, and the local package image. The request step also needs these.
- The U169 evidence folder ~/forge-stage9-signing-0003 and results/stage9/freeze-0001 are not at their recorded paths.

## Draft proposal, in short
- Preconditions:
  - P1: M1-B closed.
  - P2: Phase II manifest final.
  - P3: no more planned code under the three roots.
  - P4: a non-admin machine account for the agent.
  - P5: the owner chooses track R and/or track M.
  - P6: F1, F3, F4 decided.
  - P7: the Mach-O deployment model decided.
- Track R (refresh 1.0.0; one PR, approved by owner review, no bypass): R1 spec.lock, R2 implementation.lock (packet A1, A2, B1, B3 plus new scripts), R3 the booking-reuse.yml pin, R4 a new `governance/ratifications/0002` baseline record. The packet covers R1 and R2. It lacks R3 and R4.
- Track M: M1 protocol 2.0.0, then M2 policy, M3 spec.lock, M4 artifact-identities.json, M5 to M8 code and workflows, M9 lock regenerated last, M10 the pins and the baseline record.
- Activation is public and permanent: 7 Rekor entries per attempt (6 under provenance.yml, 1 under provenance-negative.yml).
- The owner must do these personally: approve the contract text and the exact implementation, review each exact head, merge, set and delete FORGE_SIGNING_AUTHORIZED, dispatch both workflows, supply the verifier token, accept the Rekor entries, and sign the ratification statement.

## Could not determine
- The live GitHub state: the actual gh login, branch protection, the signing variable (last seen "false", U171), PR reviews. All need the network.
- Whether HOL4 replay of the M1 chain fits the hosted 300/360-minute limit.
- Whether the Mach-O link and loader are inside the proof chain (this depends on P2).
- Whether the six cases still pass on the refreshed lock (not run).
- Whether the verifier token still exists.

| step | status | evidence or blocker |
|---|---|---|
| III (Stage 9 prep) | REPORTED | Inventory recomputed (8+8 stale, 6 unlocked scripts); the packet applies to 8e772b55 and gives 190f938e/256310d8; draft at …/scratchpad/m1b/W6/STAGE9_BINDING_PROPOSAL_DRAFT.md; Stage 9 not activated |
| III activation | BLOCKED | Owner deferral (U470); P1 to P7; controller.json, controller database and run artifacts missing; shared owner account |
