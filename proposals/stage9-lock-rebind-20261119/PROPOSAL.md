# Stage 9 lock rebind (exact-diff proposal; NOT APPLIED)

**STATUS, 2026-11-19 03:57Z: NOT APPLIED.** Pull request 53 held this
proposal with the two files changed. The owner then decided to keep
Stage 9 deferred until the M1 work is done, and the pull request was
closed without a merge (`unsure.md` U470). The two lock files on `main`
are unchanged. `proposed.diff` is against `main` `982890e5`. The diff
goes stale with every new code file under `scripts/` and with every
change of a listed file: it must be made again when Stage 9 is taken
up. The text below is the proposal as it stood in pull request 53; its
words "CURRENT" and "this pull request" describe that time.

Stage 9 is CURRENT for the deterministic closeout ONLY, by the owner's
word of 2026-11-19 (text below). M1 open. Stage 12 unauthorized.
`end_to_end=false`. This proposal changes two PROTECTED files. The
owner's merge of this pull request is the approval of their exact
bytes. The agent does not merge it.

## The owner's word (answer to a question of the agent, 2026-11-19)

"Unlock Stage 9 for the deterministic closeout ONLY:1. Write owed
record U469 (PR 52 merge 982890e5 + U468 clock correction) and the
Stage 9 lock proposal (update the 8 changed digests and include
gate/ratification.py so the gate pin is complete), then open the PR
and pause for my merge.2. After my merge, run the hosted signing run
and the 6 Stage 9 EXIT cases.3. Do NOT start the 540-run agent
benchmark. Also print your earlier note on what M1 actually needs on
disk."

## Exact bytes

| File | SHA-256 on `main` `982890e5` | SHA-256 proposed |
| --- | --- | --- |
| `gate/provenance/implementation.lock` | `76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9` | `190f938e387a92ef891a4a286c5d08ce4803d36fdb34a7d074631043aabb4a6b` |
| `spec/provenance/spec.lock` | `43610d8123ce21fdd1f9dac9469f78ad3efcb3af271a86011a18790099811a33` | `256310d851669cdeab2498b0a58fe6bcd4b7ba1f741396a9f608d644fa72a976` |

`proposed.diff` in this folder is the diff of the two files (SHA-256
`64c1b3d982afd15a5b5e6fbe1333ff7773c117b7eceb15eaac6af392e4e42187`). Both files keep their format (JSON,
two spaces, sorted keys). Only digest values change and seven keys are
added. No other field changes.

## Part A: what the owner named

A1. Eight changed digests in `implementation.lock` (each is the
SHA-256 of the file on `main`):

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

A2. One added entry in `implementation.lock`:

| Path | SHA-256 |
| --- | --- |
| `gate/ratification.py` | `93bb23bc64f1…` |

## Part B: MORE than the owner named. Each is needed for the lock to pass its own check. The owner can reject any of them

I found these after the owner's word. They are in the same diff. Say
so if a part must come out; then the EXIT cases cannot pass, for the
stated reason.

B1. Six scripts added to `implementation.lock`. Reason: the lock rule
(`gate/provenance/common.py`, `source_tree`, and `bootstrap.py`)
refuses every code file under `scripts/` that the lock does not list
(`UNLOCKED_EXECUTABLE`). These six files came with Slices 1 to 3 and
Wave Gates 1 and 3:

| Path | SHA-256 |
| --- | --- |
| `scripts/demo_gauntlet.py` | `a26cac635517…` |
| `scripts/exit_m1_conformance.py` | `96179077289b…` |
| `scripts/exit_slice1.py` | `4cea7b69a4d7…` |
| `scripts/exit_slice2.py` | `34d2448b61b4…` |
| `scripts/exit_slice3.py` | `23f4c3f3c2d4…` |
| `scripts/spec_clearing.py` | `99f1000eae23…` |

B2. Eight changed digests in `spec/provenance/spec.lock`
(`locked_existing_files`). Reason: `context()` in the same module
requires each listed file to have its listed digest (`LOCKED_INPUT`).
This file is under `spec/`: it is the lock of the approved provenance
contract. The contract text (`spec/provenance/protocol.md`) and the
policy do not change, and their digests in the lock still match.

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

B3. One more changed digest in `implementation.lock`, which follows
from B2:

| Path | Old | New |
| --- | --- | --- |
| `spec/provenance/spec.lock` | `43610d8123ce…` | `256310d85166…` |

## Actual checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| clean clone of `main` `982890e5`, the two candidate files copied in: `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 190f938e… --check` | 0 | `BOOTSTRAP_VERIFIED` |
| the same clone with `main`'s own two files and `main`'s lock value `76b983ac…` | 1 | `BOOTSTRAP_REJECTED: UNLOCKED_EXECUTABLE:scripts/demo_gauntlet.py` (the present lock cannot pass on the present `main`) |
| the same check in the owner's working tree | 1 | `BOOTSTRAP_REJECTED: BYTECODE_CACHE:scripts/__pycache__`: an untracked cache folder of earlier runs; not a result about the lock |
| one-off: every `files` entry of the candidate lock against the file | 107 of 107 equal | 100 old entries and 7 new |
| `scripts/exit_stage_9.py` (six cases); the hosted signing run | NOT RUN | they come after the owner's merge |

`BOOTSTRAP_VERIFIED` means: the lock bytes have the given digest, every
listed file has its listed digest, and no unlisted code is in the
executable roots. It is not a Stage 9 EXIT result.

## What this does not decide, and what step 2 needs

- A digest in a lock says which bytes are approved. It does not say
  that those bytes are right. The files behind the changed digests
  came to `main` through the owner's merges of pull requests 39, 43,
  45 to 51.
- NOT changed here: `.github/workflows/booking-reuse.yml` holds the
  old lock value `76b983ac…` in one command of an experiment workflow.
  After this merge that pin is stale. It is a protected path and
  outside this proposal.
- Step 2 (hosted signing run and six EXIT cases) needs more than this
  merge. From `proposals/provenance-hosted-v33/INSTALL.md`: the owner
  sets the variable `FORGE_SIGNING_AUTHORIZED` and dispatches
  `provenance.yml` and `provenance-negative.yml` with the new lock
  value; the run makes 7 PERMANENT public Rekor entries; `main` must
  not move between the request and the last EXIT case; the EXIT cases
  need Docker, a read-only verifier token and
  `.toolchain/stage9/controller.json` (absent on this machine; it is
  written from the downloaded run output). The same file records a
  precondition that FAILED on 2026-10-29 and is still false today: the
  agent's `gh` login must not be the owner's account. The owner must
  decide how step 2 runs under that precondition.
