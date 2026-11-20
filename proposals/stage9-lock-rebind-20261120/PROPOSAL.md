# Gate F2a: Stage 9 lock rebind (exact-diff proposal; NOT APPLIED until the owner merges)

CURRENT none. Stage 9 stays deferred. M1-B open. Stage 12 unauthorized.
`end_to_end=false`. This pull request changes two PROTECTED files. The
owner's merge is the approval of their exact bytes. The agent does not
merge, does not use administrator rights and does not bypass the gate.
No EXIT case of Stage 9 ran. No signing run was started.

Source of the task: Gate F2, step F2a, of the finish-line directive
(`proposals/forge2-finish-line/DIRECTIVE.md` on branch
`docs/finish-line-directive`). The start word came to this session
from the launcher session, not from the owner directly. The directive
says F2 starts after the F1 merge; F1 (pull request 70) is NOT merged.
See "Order of merges" below: that order decides whether these bytes
are still valid at merge time.

## Exact bytes

Base: `main` `33055a591fd6c85eb7a342f0cc5e5de78f2145a3`.

| File | SHA-256 on the base | SHA-256 proposed |
| --- | --- | --- |
| `gate/provenance/implementation.lock` | `76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9` | `08ae51d078e8e8f1bd392e98477927c3c6fe72f9a228eb53ad5081066326f6cb` |
| `spec/provenance/spec.lock` | `43610d8123ce21fdd1f9dac9469f78ad3efcb3af271a86011a18790099811a33` | `256310d851669cdeab2498b0a58fe6bcd4b7ba1f741396a9f608d644fa72a976` |

[proposed.diff](proposed.diff) is the diff of the two files (SHA-256
`39ae7819a238aefb2b9c4223c34137570e29a3af6a7d8a201860fcba2eb34cee`).
Both files keep their format (JSON, two spaces, sorted keys, one final
newline): each file on the base is byte-equal to its own re-serialized
form. Only digest values change, and nine keys are added to `files`.
No other field changes. The proposed `spec.lock` is byte-equal to the
one of the closed pull request 53 (same digest `256310d8…`).

[regen_locks.py](regen_locks.py) made the bytes. It is not under
`scripts/` on purpose: a new code file there would make the lock stale.

## Part A: named by the directive ("the stale digests and `gate/ratification.py`")

A1. Eight changed digests in `implementation.lock` (new value = SHA-256 of the file on the base):

| Path | Old | New |
| --- | --- | --- |
| `gate/approval.py` | `8eedbadd24c1…` | `cabcbd5c97b8…` |
| `gate/backends/dafny.py` | `11b922b0da01…` | `a6e78cdcff7b…` |
| `gate/incremental.py` | `3d087455211b…` | `1086e97b6bd4…` |
| `gate/refund.py` | `9d91b7543c06…` | `bafc1b72d070…` |
| `scripts/exit_stage_5.py` | `048d8083c1e5…` | `14e40c6d4dc3…` |
| `spec/refund/spec.lock` | `993dade887f6…` | `8b131ab82d3d…` |
| `toolchain/linux-pins.json` | `11128aa46f89…` | `dbe9335f60f0…` |
| `toolchain/pins.json` | `74dcc4b81e45…` | `4b612d8845e6…` |

A2. One added entry. No lock rule requires it; the directive names it:

| Path | SHA-256 |
| --- | --- |
| `gate/ratification.py` | `93bb23bc64f1c36174829602c4b480b93a2063cd2cd779bc98582d2f89870336` |

## Part B: MORE than the directive names. Each is needed for the lock to pass its own check. The owner can reject any of them

B1. Eight scripts added to `implementation.lock`. Reason:
`gate/provenance/bootstrap.py` and `source_tree` in
`gate/provenance/common.py` refuse every code file under `scripts/`
that the lock does not list (`UNLOCKED_EXECUTABLE`). Six were in the
packet of pull request 53. Two are new since then (Goal 19, Goal 20).

| Path | SHA-256 | Since |
| --- | --- | --- |
| `scripts/demo_gauntlet.py` | `a26cac6355178d9a13797229a1ddbdc3618dd286b63d14012b2f79918aaf3334` | packet 53 |
| `scripts/exit_goal20_sdk.py` | `0ea4a0aa87ec9c5d2203da47f4437316e725c8c6acc5e3631898029f45d89787` | NEW |
| `scripts/exit_m1_conformance.py` | `96179077289b6242a7d14384e363219a47c6ba9d49eb846a0fbd4969b4d6fa52` | packet 53 |
| `scripts/exit_silicon_sink.py` | `b8787e515f554c654677cdb66ea29fa57494b971fd0af3290dea83cfb58cf717` | NEW |
| `scripts/exit_slice1.py` | `4cea7b69a4d74b61de7234c953c0d681bb8d5530acf84df4c908500b8b1680b9` | packet 53 |
| `scripts/exit_slice2.py` | `34d2448b61b45a8303e98517994bc7edc5c8056047d8f3fc8976ebd3c59b51d2` | packet 53 |
| `scripts/exit_slice3.py` | `23f4c3f3c2d49d8457fa194aac3d0fb3b95726f5c414837bee5c6352d03e08bc` | packet 53 |
| `scripts/spec_clearing.py` | `99f1000eae2340aa344b0d9f8d0dac1895c52c4c29c4843f4c03c2972d29ffc5` | packet 53 |

B2. Eight changed digests in `spec/provenance/spec.lock`
(`locked_existing_files`). Reason: `context()` requires each listed
file to have its listed digest (`LOCKED_INPUT`). The contract text
(`spec/provenance/protocol.md`) and the policy
(`policy/provenance.json`) do not change; their digests in the lock
still match.

| Path | Old | New |
| --- | --- | --- |
| `gate/backends/dafny.py` | `ef81d8d190c3…` | `a6e78cdcff7b…` |
| `gate/common.py` | `06b1e37f7df2…` | `8233902b5a70…` |
| `gate/core.py` | `bf8f0a54a149…` | `7c53738a4009…` |
| `gate/dependencies.py` | `df8e9dafebdb…` | `873a692b4b02…` |
| `gate/refund.py` | `da370619a34d…` | `bafc1b72d070…` |
| `scripts/javascript_env.py` | `0beb81134ed5…` | `22c882c3c7f8…` |
| `spec/refund/spec.lock` | `993dade887f6…` | `8b131ab82d3d…` |
| `toolchain/pins.json` | `74dcc4b81e45…` | `4b612d8845e6…` |

B3. One more changed digest in `implementation.lock`, which follows from B2:

| Path | Old | New |
| --- | --- | --- |
| `spec/provenance/spec.lock` | `43610d8123ce…` | `256310d85166…` |

## Actual checks (this session, worktree of the base with the two files changed)

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 regen_locks.py <worktree>` (dry run), then `--write` | 0; 0 | 8 + 9 changed digests, 9 added keys; 109 `files` entries, 47 `locked_existing_files` entries |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 08ae51d0…f6cb --check` | 0 | `BOOTSTRAP_VERIFIED` |
| the same command with the old value `76b983ac…` on the new bytes | 1 | `BOOTSTRAP_REJECTED: IMPLEMENTATION_LOCK` |
| the base's own two files with the old value `76b983ac…` | 1 | `BOOTSTRAP_REJECTED: UNLOCKED_EXECUTABLE:scripts/demo_gauntlet.py` (the present lock cannot pass on the present `main`) |
| one-off: every entry of both proposed locks against the file | 109 of 109 and 47 of 47 equal | after the change |
| `git apply --check proposed.diff` on the base's two files | 0 | the diff is exact |
| `scripts/exit_stage_9.py` (six cases); the hosted signing run; the benchmark | NOT RUN | they come after the owner's merge and the owner's batch word |

`BOOTSTRAP_VERIFIED` means: the lock bytes have the given digest, every
listed file has its listed digest, and no unlisted code is in the
executable roots. It is not a Stage 9 EXIT result. The check ran in a
git worktree, not in a fresh clone.

## Order of merges (finding; needs the owner's decision)

The lock lists every code file under `scripts/`. Four open pull
requests add or change such files. If one of them merges AFTER this
pull request, the merged lock is stale again. If one merges BEFORE,
this pull request's bytes are stale and must be made again with
`regen_locks.py` (new digests, new owner review).

| Pull request | Lock-relevant files (from `git diff --name-status origin/main...<branch>`) |
| --- | --- |
| 70 (F1) | adds `scripts/exit_goal21_intent.py`, `scripts/intent_clearing.py`, `scripts/intent_restate.py` |
| 72 | changes `scripts/exit_goal20_sdk.py` |
| 73 | changes `scripts/exit_goal20_sdk.py` |
| 74 (T19) | changes `scripts/demo_gauntlet.py`, `scripts/exit_m1_conformance.py`, `scripts/exit_silicon_sink.py`, `scripts/exit_slice1.py` |
| 68, 69, 71, 75 | none |

So this pull request is valid for a merge only while `main` is
`33055a59` in the listed files. The safe order is: 70, 72, 73, 74
first (those the owner wants), then a regeneration, then this merge,
then the signing run with `main` frozen.

## What this does not decide

- A digest in a lock says which bytes are approved. It does not say
  that those bytes are right.
- NOT changed here: `.github/workflows/booking-reuse.yml` line 43 holds
  the old lock value `76b983ac…` in one command of an experiment
  workflow. After this merge that pin is stale (it fails already today,
  for the reason in the third check row). It is a protected path and
  outside the directive's words.
- NOT in this pull request: a new baseline record under
  `governance/ratifications/`. The draft
  `proposals/m1b-mission-20261119/drafts/STAGE9_BINDING_PROPOSAL_DRAFT.md`
  (row R4) infers, without a run, that the release check rejects
  today's lineage (`UNAPPROVED_LINEAGE`), because the merges since the
  baseline `19c4896b` were administrator merges without a review. If
  that holds, the EXIT cases of Stage 9 cannot pass after this merge
  alone. It was NOT checked here.
- The hosted PR gate cannot approve this change: `gate/provenance/` is
  protected and not ratifiable. The expected hosted result is exit 1
  (REJECTED), as for pull request 53. That is not an approval and not a
  defect of this diff.
- Step F2b needs the owner personally: the variable
  `FORGE_SIGNING_AUTHORIZED`, two workflow dispatches with the new lock
  value, 7 PERMANENT public Rekor entries per attempt, a read-only
  verifier token, Docker, `.toolchain/stage9/controller.json`, and a
  `main` that does not move until the last EXIT case
  (`proposals/provenance-hosted-v33/INSTALL.md`). The agent's `gh`
  login in this session is the owner's account (`gh api user`); the
  install text names that as a failed precondition.
- The two "dead Stage 9 links" of the directive are not touched here.
