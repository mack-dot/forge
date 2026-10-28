# Stage 9 proof-to-artifact integrity repair (UNAPPLIED; awaiting exact-byte approval)

Status: proposal only. No protected file is changed. All six Stage 9 EXITs are
NOT RUN. `end_to_end=false`. No workflow, runner, Cosign, Docker, kernel or
deployment operation ran. This proposal supersedes the earlier unrecorded
draft `proposals/provenance-receipt-repair.md`. That draft covered gaps 1–2
only. It and its results stay unchanged as history. See U078.

Base: the installed implementation lock is
`6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa`. The
workspace has no `.git` directory, so commit
`9679265c326d8d630e54c728f307891e5d6422ab` cannot be checked locally. The
installed bytes match the installed lock.

## 1. Root causes

| Gap | Installed behaviour | Root cause |
| --- | --- | --- |
| 1. Dependency digests | `validate_receipt` checks only the count of `closure-identities.json` and the value length. | The digests are trusted as reported. Nothing binds them to the approved closure, to the bytes that the kernel loaded or to the copied bytes. |
| 2. Copied ELF | It compares `report.json`'s ELF hash, not `linux/gcd-selftest.elf`. | `receipt.json` is a self-describing manifest. When the attacker regenerates it, any file set is "consistent". There is no required-file set and no approved per-artifact hash. |
| 3. Signing inputs | `sign` checks the statement and receipt but never rehashes `packaged.elf` or the image. | `package_sha256` is a Docker metadata value. Nothing in the sign job checks the bytes that it names. |

The common cause: the validator checks internal consistency of attacker-shaped
metadata. It does not check equality with identities that were approved
independently.

## 2. Trust boundaries

Six properties are kept separate: source correctness, proof checking,
artifact integrity, signer authenticity, deployment identity, runtime
correctness.

| Boundary | Trusted bytes | Who establishes authenticity | Digest binding | Recomputed or trusted | Attacker influence | Trusted execution |
| --- | --- | --- | --- | --- | --- | --- |
| Source → compilation | `gcd_selftest.c`, pinned toolchain | Approved commit, `spec.lock` | Source/ELF sha in policy | ELF recomputed at receipt and sign | Repository write; it is blocked by the protected baseline | Compiler image by digest |
| Compilation → Rocq proof | 6 `.v`, `Program.v`, 2 `.hex`, 2 wrappers | Stage 7 record | `fixed_artifacts` (22) | **Recomputed (new)** | Producer workspace | `stage7_own_job.py`, checker image |
| Proof → independent kernel | 579 `.vo` and the raw kernel log | Upstream `rocqchk` run inside the producer job | `closure_sha256` (579), intern set, axiom list | **Recomputed (new)**. The kernel run itself is trusted. | Producer job | `rocqchk`, the producer runner, the volume |
| Kernel → receipt | `proof/**` | Producer job; same-run artifact | `proof_receipt_sha256` in the statement | Recomputed at sign and verify | Artifact store, if compromised | GitHub artifact handoff |
| Receipt → packaging | ELF, base config, added layers | Producer `docker save` | `package_sha256` = config blob, 55 base diff_ids | **Recomputed (new)**. Base layer bytes are trusted by diff_id. | Producer Docker daemon | Docker image store |
| Packaging → signing | Downloaded producer output | Sign job | Statement subjects | **Recomputed (new)** | Artifact handoff | Sign runner, Cosign pin |
| Signing → release verification | Bundle + statement | Fulcio/Rekor (GitHub OIDC identity) | Subject digests, predicate | Recomputed | None without the OIDC identity | Sigstore trust root |
| Release → deployed observation | Deployed file bytes | `observe.py` | ELF sha at `/opt/forge/gcd-selftest.elf` | Recomputed | Deployment host | Observer host |

Locally constructed metadata never authenticates a genuine kernel execution.
The repair binds bytes. It does not prove that a kernel ran.

## 3. Repair (items A–E)

Four files under `gate/provenance/` change. No other file changes:

- `release.py`: replace.
- `producer.py`: replace.
- `artifact-identities.json`: new.
- `implementation.lock`: replace (new hashes for the three files; serialization unchanged).

- **A. Dependency closure.** Every closure digest must match `^[0-9a-f]{64}$`.
  The key set must equal the approved 579 paths, and each value must equal its
  approved hash. Each object is also re-read from `proof/dependencies/<path>`
  and rehashed. Missing copies are rejected, and so are extra files. The interned
  set in the raw kernel log must equal the closure. The raw axiom list must equal
  the lock. The summary lines must match exactly. The kernel command must equal
  the approved argv.
- **B. Copied ELF and artifacts.** Each of the 22 fixed artifacts must exist and
  match its approved hash. That set includes `linux/gcd-selftest.elf`, which is
  also checked against `policy.release_artifact.sha256`. A file with a checked
  suffix that is not in the set is rejected. A file with ELF magic outside the
  approved path is rejected. The manifest must equal the actual file set. Symlinks
  are rejected.
- **C. Packaging.** `packaged.elf` is rehashed. `package.json` must equal the
  request descriptor. `package-identity/` holds `manifest.json`, the config blob
  and the added layers from `docker image save`. Each blob is rehashed. The config
  blob name must equal `package_sha256`. The config `rootfs.diff_ids` must equal
  the 55 approved base diff_ids plus the recomputed added diff_ids. The runtime
  config is checked. The added layers are parsed conservatively, including
  whiteouts, opaque directories, symlink ancestors, duplicates, ownership and
  mode. The final filesystem must contain exactly the approved ELF bytes at
  `opt/forge/gcd-selftest.elf` with mode 0444 and owner 1000:1000. zstd is
  rejected. Decompressed layers are limited to 16 MiB. The sign job runs these
  checks before it uses Cosign.
- **D. Preserved bindings.** The challenge nonce, source commit, controller
  consumption, `GITHUB_RUN_ATTEMPT==1`, the challenge-bound container name,
  signer identity, the lock self-binding and the order of the reason codes that
  the EXIT harness expects are unchanged.
- **E. Fail closed.** Every non-`Rejected` exception becomes
  `PROOF_RECEIPT_MALFORMED:<Type>` or `PACKAGE_MALFORMED:<Type>`. `main` writes a
  rejected result on any exception.

## 4. Invariants (finite tests; not formal verification)

| Invariant | Assumption | Enforcement | Counterexample rejected |
| --- | --- | --- | --- |
| I1 Receipt byte integrity | SHA-256 collision resistance | `checked_receipt` manifest loop and file set | unmanifested mutation; symlink |
| I2 Closure completeness | Approved closure equals the Stage 7 kernel record | closure equality, copy rehash, intern-set equality | missing, extra or substituted dependency; wrong loaded closure |
| I3 Proof → ELF identity | The fixed attempt path makes the objects reproducible | `fixed_artifacts` + policy ELF | missing or modified ELF; extra executable |
| I4 ELF → container | The registry's base diff_ids are authentic; the store type is classic | `image_identity`, `layer_effect` | whiteout, symlink ancestor, wrong ELF in a self-consistent image |
| I5 Signer identity | Fulcio/Rekor and the OIDC claims | unchanged `release.py` signature checks | wrong-signer EXIT (NOT RUN) |
| I6 Freshness / replay | Trusted controller, same-run handoff, fresh volume | nonce, commit, consumption, run attempt | stale nonce; wrong commit; replay against another request |
| I7 Refusal on absence | — | required files and fail-closed wrappers | missing kernel log, command, ELF or package identity |

The bounded layer model enumerates 1,884 stacks of 1–3 layers from 12 kinds
over 3 base variants. An independent whole-tree oracle checks each stack.
Candidate accepts ⇒ oracle accepts held in all 5,652 runs: 4,678 agreements,
974 conservative rejections, 0 unsound acceptances.

## 5. Test evidence (actual)

Command: `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0002 --work build/stage9-integrity-tests-0002`
→ exit **0**, `unexpected=[]`, Python 3.10.11. Attempt 0001 exited **1**
and is kept. It had one harness defect: a mutation helper returned
`write_bytes`'s integer as the request, so the candidate rejected with
`PACKAGE_MALFORMED:TypeError`, not `PACKAGED_ELF_BYTES`.

| Group | Cases | Candidate | Installed |
| --- | --- | --- | --- |
| Receipt (historical bytes, explicitly untrusted) | 1 positive + 31 negative | positive accepted; 31/31 rejected for the expected reason | positive accepted; of 31 negatives: 17 accepted, 9 rejected, 5 exceptions |
| Original audit | 5 | 5 rejected | 3 accepted |
| Package (synthetic) | 3 positive + 22 negative | 3 accepted; 22 rejected | no package check |
| Signing path (`sign()`, Cosign absent) | 5 | positive stops at `COSIGN_PIN`; 4 rejected earlier; no signature file | all 5 reach `COSIGN_PIN` or the statement check |
| Seeded properties (seed 90270001) | 3 × 40 | 120/120 rejected | — |

The required cases map to these reason codes:

- Invalid SHA syntax: `DEPENDENCY_DIGEST_FORMAT`.
- Wrong dependency digest: `DEPENDENCY_DIGEST_MISMATCH`.
- Missing dependency entry: `DEPENDENCY_CLOSURE_MEMBERSHIP`.
- Missing dependency bytes: `DEPENDENCY_BYTES_MISSING`.
- Extra dependency: `DEPENDENCY_CLOSURE_MEMBERSHIP` (extra entry) or `DEPENDENCY_EXTRA_FILE` (extra bytes only).
- Substituted dependency bytes: `DEPENDENCY_BYTES` or `DEPENDENCY_DIGEST_MISMATCH`.
- Wrong closure identity: `DEPENDENCY_CLOSURE_MEMBERSHIP` or `KERNEL_DEPENDENCY_MEMBERSHIP`.
- Missing copied ELF: `PROOF_REQUIRED_ARTIFACT_MISSING`.
- Modified copied ELF: `PROOF_ARTIFACT_BYTES`.
- Correct manifest over malicious bytes: `PROOF_UNEXPECTED_EXECUTABLE` or `PROOF_UNEXPECTED_ARTIFACT`.
- Missing packaged ELF: `PACKAGED_ELF_MISSING`.
- Substituted packaged ELF: `PACKAGED_ELF_BYTES`.
- Metadata that names the wrong executable: `PACKAGED_ELF_BYTES` or `PACKAGE_FILESYSTEM_ELF:substituted`.
- Stale nonce, wrong commit or replay against another request: `STALE_PROOF_RECEIPT`.
- Missing proof-check evidence: `KERNEL_LOG_MISSING`, `INDEPENDENT_KERNEL_EXIT` or `PROOF_NOT_ESTABLISHED`.

The positive controls show only that the validators accept bytes that equal
the approved identities. They are **not** kernel-checked proof. Exact outputs:
`results/stage9/integrity-repair-preparation/tests-command-000{1,2}/` and
`tests-000{1,2}/result.json`.

## 6. Effect on the six EXIT cases (expected; all NOT RUN)

- `valid-bundle`: it now also needs `proof/dependencies/` and
  `package-identity/` in the bundle. The upload path already covers the whole
  producer output.
- `unsigned`, `wrong-signer` and `wrong-digest`: unchanged.
- `wrong-policy`: unchanged; the reason stays `POLICY_BINDING`.
- `deployed-identity`: unchanged; the observer stays authoritative.

The receipt and package checks run after `PROOF_RECEIPT_BINDING`, so the
reasons that the harness expects keep their order.

## 7. Residual attack surfaces and assumptions

1. **Freshness is not cryptographic.** The fixed path `attempt-0001` makes the
   objects reproducible. Because of that, a relabeled historical receipt is
   accepted by content. Freshness depends on the trusted producer job, a fresh
   volume per run, the controller and the same-run artifact handoff.
2. **The kernel run is trusted.** It is not re-executed at signing time.
3. **Base layers are trusted.** At signing time they are bound only by the 55
   registry diff_ids, which were verified by content digest. Their bytes are not
   rehashed.
4. **Image-store mismatch (execution blocker).** Stage 7 records show
   `Id == RepoDigest`, which indicates the containerd store. Under that store,
   `docker inspect .Id` is a manifest digest, not a config digest. The approved
   `identity_kind: docker_image_config` would then be false, and the candidate
   fails closed with `PACKAGE_CONFIG_IDENTITY`. Do one of these: confirm a
   classic store on the runner, or approve a separate descriptor change. Do not
   relabel.
5. **Unverified format.** The `docker image save` layout and Docker version were
   not tested (the daemon was not running). Only the synthetic archive layout was
   tested.
6. **Unchanged trust roots.** The runner host, GitHub artifact storage, the OIDC
   issuer and the Sigstore trust root are trusted as before. Runner admission is
   unresolved (U077).

## 8. Runner isolation and execution readiness (separate; all unchecked)

- [ ] Provide a disposable runner instance per job and restore the host between the proof job and the sign job.
- [ ] Create a fresh Docker volume for each run, so that `attempt-0001` does not exist yet.
- [ ] Confirm the classic image store (`docker info` driver-type check) and the `docker image save` layout.
- [ ] Confirm that the producer output, including the base config, fits the artifact limits.
- [ ] Enforce workflow admission to the two approved workflows; labels are not sufficient (U077).
- [ ] Get explicit user authorization for registration, dispatch, signing and deployment.

## 9. Approval manifest

`results/stage9/integrity-repair-preparation/approval-0001/approval-manifest.json`

| Path | Action | Proposed SHA-256 | Bytes |
| --- | --- | --- | --- |
| `gate/provenance/release.py` | replace (from `e9f61515…`) | `1877aef9688a089fe7fee9026b08968b559044862535c6c398b0e7603a1c6d6f` | 19109 |
| `gate/provenance/producer.py` | replace (from `f3bcc1dc…`) | `243d4071dd6e7f7728e12d3f7498625843395afcdd883785d8c81bb7a7dfcf7e` | 21198 |
| `gate/provenance/artifact-identities.json` | create | `0f2c86a49738b5bbdf15cd00b3490347dfece5f5239a3414a46d75c212fa9718` | 97477 |
| `gate/provenance/implementation.lock` | replace (from `6b43c193…`) | `9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76` | 10913 |
| `approval-0001/proposed.diff` | — | `df0bd7fbbae0a2680ba076038b9096cbcc87beca3d9516492a8337c1567eda5e` | 121393 |

`git apply --check` and `git apply` returned 0 in the scratch copy
`build/stage9-integrity-apply-0001`, and the applied bytes are equal to the
candidates. The protected tree is the same before and after. After approval,
the controller must supply the lock SHA-256 `9b10a237…`.
