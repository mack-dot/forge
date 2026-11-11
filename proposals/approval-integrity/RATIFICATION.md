# Ratification and release admission (prepared; nothing here is applied)

Prerequisite done: `aac837a0` (#21) is the first main commit with a
machine-checkable owner approval (U136). `CODEOWNERS` on main is `*  @mack-dot`.

## Ratification

- **What it is.** A pull request, opened by the agent account, that adds one file
  `governance/ratifications/NNNN-<name>.json` (schema `forge.ratification/1`).
  The file names a baseline commit, its tree and its implementation lock, and lists
  every earlier main commit with its audit status. The owner ratifies by an
  approving review of the exact head. The agent merges without admin rights.
- **What it is not.** It never changes a status. The audit keeps #4 and #16–#20
  as OVERRIDE and 35 commits without a merged PR as UNAPPROVED (34 direct pushes and `0f11517d`, the head of #4). The ratification is a new, later,
  APPROVED event that accepts the *result* (the baseline tree), not the process.
- **Revocation.** A later approved PR that deletes the file. Release admission
  reads the records from the release commit's own tree, so later commits lose the
  baseline.

### Ratification 0001 (prepared, not opened)

| Item | Value |
| --- | --- |
| Record | `proposals/approval-integrity/ratification-0001.json`, sha256 `34ae62bcdc77a916fd830cef49f6758f500298140286154d69326e48a6e01ddc`; PR #23, head `174880e85fef7e84d48870a7d6dbf6228bc9c6bd` |
| Target path | `governance/ratifications/0001-baseline-19c4896b.json` (the only file in the PR) |
| Baseline | `19c4896ba78cc9e41bbadaf8c804b8e74af20125` (#20), tree `6782921065f31fefe92ce0f5e2f9891e14dce521` |
| Lock at baseline | `a809f7017ce0980b26b81896216af7be30591a67a564adff273df576e2453a55` (v3.3) |
| Covers | 41 commits: OVERRIDE #16–#18 (recorded), #19–#20 (inferred), #4 (uncertain); `0f11517d` (head of #4, uncertain); 34 direct pushes (UNAPPROVED) |

Owner checks before approving, in the owner's own clone (not the agent's):

1. `git rev-parse 19c4896b^{tree}` prints `6782921065f31fefe92ce0f5e2f9891e14dce521`.
2. `git show 19c4896b:gate/provenance/implementation.lock | shasum -a 256` prints `a809f701…`.
3. The PR changes exactly one file, the record above.
4. You accept main at `19c4896b` as the trusted starting point, including #16–#20,
   which you merged with the bypass.

Steps: the agent opens the PR as `mackiannii`; the owner approves the exact head;
the agent runs `gh pr merge N --squash --match-head-commit <head>`;
`audit_main_approvals.py` must print APPROVED for the merge and the earlier rows unchanged.

## Release admission (v3.4, protected; needs separate approval)

Rule (`approved_lineage`, called by `release.verify` after `run_identity`): walk
first parents from the release request's source commit to the nearest commit that
a ratification record in the source tree names. Every commit before it must be
one PR merged into `main` whose owner's latest review before the merge (by numeric
id `policy.signer.owner_id`) is APPROVED on the exact merged head, and whose merge
tree equals that head tree. The baseline's tree must equal the record. A record
added by an override commit cannot help: that commit lies on the walk and fails.

| Item | Value |
| --- | --- |
| Build | `build_admission.py` → `admission-v34/` |
| New lock | `9bf8f905c9359cd6e5f926657ff434354b80028f45417f962635d6ee86284c90` (from `a809f701…`) |
| Diff | `admission-v34/proposed.diff`, sha256 `f31a1bada4287556dbeea6fc4e5285a71ab5fe92d671b08cd0f3829d1568cd47` |
| `gate/provenance/common.py` | `0c963d9c…` → `d63010fc674df43494f1b803268d0d81fa892679a5d1ae7546d120138daf0a64` |
| `gate/provenance/release.py` | `fc135970…` → `778cebb9bcca3bc1a7c42dd3fae5fa85fefedb7ec247d2771278815f3f9f4259` |
| Controls | `results/stage9/lineage-controls-0001` (lineage.py) and `-0002` (candidate common.py): 17/17 each |

Order: ratification PR first (without it every release is refused), then the v3.4
install PR (approved like #21), then a new request at a commit whose lineage passes.

## Not done or untested

- The full v3.4 candidate control suite (48 controls, v3.1 14, F1 9) has not run
  with the new files. Positive-path `release.verify` controls need a lineage stub.
- Fetches use the agent's `gh` read access; the `FORGE_VERIFIER_GITHUB_TOKEN` path
  is not exercised. 15 of 17 controls change one API response in memory.
- Inferred statuses assume the current ruleset existed at the merge; for #4 that
  is unverified.
- Reviews are read from one page of 100; a PR with more reviews is refused.
- An owner-authored PR cannot be approved (GitHub refuses self-approval), so it
  fails lineage unless a later record ratifies it.
- GitHub tells accounts apart, not people; the agent runs as the same macOS user.
