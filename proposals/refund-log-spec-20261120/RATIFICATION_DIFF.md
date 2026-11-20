# Ratification diff (exact bytes; NOT APPLIED)

**STATUS: NOT APPLIED. NOT ratified.** The agent changed no protected path. `ratification.diff` in
this folder is the exact change that ratification would apply. The owner's merge of these exact
bytes is the ratification. `end_to_end=false`.

Base: `main` `b1c98822`. The diff ADDS two files under `spec/refund/`. It changes no existing
file. It changes nothing under `gate/`, `policy/`, `clearing/`, `governance/`, `toolchain/`, and not
`spec.lock`, `spec/refund/RefundSpec.dfy` or `spec/refund/spec.lock`.

## Exact bytes

| File | SHA-256 |
| --- | --- |
| `spec/refund/RefundLogSpec.dfy` (new; the same bytes as `RefundLogSpec.dfy` in this folder) | `1a8c7c2a306cd651ea691a9d93f96063c5dffb1686ee1f43845e2de727b4bc5a` |
| `spec/refund/RefundLogSpec.lock` (new) | `44eb5be6080fbba9f9c04929725feef862826c86048f8efc82a1f0a6732be391` |
| `ratification.diff` (this folder) | `9b52151fc42a4af1e64b15ec8bee0a56bfd71073968e1418036c8bd10465ff09` |

The lock, in full (it is also in the diff):

```
{
  "dafny_build": "4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2",
  "dafny_version": "4.11.0",
  "dependencies": {
    "spec/refund/RefundSpec.dfy": "90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57",
    "spec/refund/spec.lock": "8b131ab82d3d5bb8f284086e207fa4207c3599ffcae887aa70b13d225ce9375b",
    "toolchain/pins.json": "4b612d8845e6b00c24be3d02c51557b1d2bd01a1db943ac6b87a0377ad5b7fbe"
  },
  "domain": "refund-log",
  "end_to_end": false,
  "intent_proposal": "proposals/refund-log-spec-20261120/README.md",
  "schema_version": 1,
  "spec_file": "spec/refund/RefundLogSpec.dfy",
  "spec_sha256": "1a8c7c2a306cd651ea691a9d93f96063c5dffb1686ee1f43845e2de727b4bc5a"
}
```

How the lock was made. No tool in the repository writes `spec/refund/spec.lock`: it came by hand
with the Stage 8 adoption (`d2d557e2`) and was changed by hand in `d026e109`. Its bytes are exactly
`json.dumps(value, indent=2, sort_keys=True) + "\n"`; I checked that on the existing file (equal).
The new lock uses the same keys and the same format. Its `dependencies` follow the booking precedent
(`spec/booking/spec.lock` pins the specification it imports and that specification's lock), plus
`toolchain/pins.json` as `spec/refund/spec.lock` does. Each value is the SHA-256 of the file on the
base. A person can check every digest with `shasum -a 256`, without a script.

## The binding: what the gate does with these files, and what I could not determine

Read in `gate/approval.py`, `gate/incremental.py`, `gate/coverage.py`, `gate/refund.py`,
`gate/provenance/common.py`; checked by the runs below.

1. The PR gate has NO machine path to approve a file under `spec/refund/`. `approval.authorize`
   accepts a protected change only as (a) a spec approval whose files are exactly
   `{spec/LedgerSpec.dfy, spec.lock}` (`SPEC_PATHS`, `approval.py:17`), or (b) a Tier-0 gate
   ratification of files under `gate/` or `toolchain/` (`approval.py:19-22`). So a record under
   `gate/approvals/` would NOT be read for these files, and `governance/gate-ratifications/` cannot
   cover `spec/`. I propose NO such record: it would look like a binding and bind nothing. The hosted
   gate on the ratification pull request is therefore expected to REJECT with
   `UNAPPROVED_PROTECTED_CHANGE` (the local probe below gives exactly that). The owner's merge of
   the exact bytes is the ratification, as for pull requests 71 and 76.
2. `gate/refund.py` is NOT changed. Its `APPROVED` table binds the stateless contract that its proof
   obligation (R1 to R5) uses. No gate obligation uses the new specification today. Task V1 will
   name it in its own records. A change of `gate/refund.py` would also change the digests that
   `gate/provenance/implementation.lock` and `spec/provenance/spec.lock` hold for it, which is the
   area of pull request 76.
3. The provenance locks are NOT changed. `gate/provenance` treats only `gate/provenance/`, `scripts/`
   and `examples/binary/` as roots for unlisted code (`common.py:167`). The bootstrap check gives
   the same result before and after the diff (runs below).
4. The new lock is NOT named `spec.lock`. `gate/coverage.py:125` reads every `spec/**/spec.lock`
   as an approved lock (`lock_dependents`). With the proposed name the coverage rule does not change
   (run below: equal before and after). If the owner prefers the booking layout
   (`spec/refund-log/spec.lock`), the coverage rule WILL read it: a later pull request that changes
   `spec/refund/RefundSpec.dfy` would then also need an obligation that lists the new lock. I did
   not run that variant.
5. Not determined: (a) whether the owner wants a gate obligation that re-verifies the new
   specification on each pull request (none exists; it would be a gate change, Tier-0 or protected);
   (b) whether a later change of `spec/refund/RefundSpec.dfy` should be blocked until the new lock
   is updated (today nothing enforces it; the lock records the digest only); (c) whether
   `gate/coverage.py` treats the new `.dfy` file as an uncovered change in the ratification pull
   request (the protected-change rejection comes first; I did not run the hosted gate).

## Commands the OWNER runs

To check the bytes before applying (no script):
```
git fetch origin && git switch -c ratify/refund-log-spec origin/main   # after the proposal pull request merged; else use its branch for the two files of this folder
shasum -a 256 proposals/refund-log-spec-20261120/ratification.diff      # 9b52151fc42a4af1e64b15ec8bee0a56bfd71073968e1418036c8bd10465ff09
git apply --check proposals/refund-log-spec-20261120/ratification.diff  # exit 0
```
To apply and check:
```
git apply proposals/refund-log-spec-20261120/ratification.diff
shasum -a 256 spec/refund/RefundLogSpec.dfy spec/refund/RefundLogSpec.lock   # 1a8c7c2a306cd651ea691a9d93f96063c5dffb1686ee1f43845e2de727b4bc5a, 44eb5be6080fbba9f9c04929725feef862826c86048f8efc82a1f0a6732be391
cmp spec/refund/RefundLogSpec.dfy proposals/refund-log-spec-20261120/RefundLogSpec.dfy   # exit 0
shasum -a 256 spec/refund/RefundSpec.dfy spec/refund/spec.lock toolchain/pins.json      # the three dependencies
git status --short     # exactly two new files under spec/refund/
git add spec/refund/RefundLogSpec.dfy spec/refund/RefundLogSpec.lock
git commit -m "Ratify the stateful refund-log specification (owner)"
```
Then open a pull request and merge it. The hosted gate will report `UNAPPROVED_PROTECTED_CHANGE`
(exit 1), as explained above.

If `origin/main` changed `spec/refund/RefundSpec.dfy`, `spec/refund/spec.lock` or
`toolchain/pins.json` after `b1c98822`, the lock values are stale: the diff still applies, but
the `shasum` line for the three dependencies shows the difference. Then the lock must be made again.

## Interaction with pull request 76

Pull request 76 (Stage 9 lock rebind, OPEN, head `4096904a`) changes
`gate/provenance/implementation.lock` and `spec/provenance/spec.lock` (plus its own proposal folder,
`ROADMAP.md`, `unsure.md`). This diff changes neither file, and neither lock of pull request 76
lists a file that this diff adds. Read: its `implementation.lock` lists five `spec/` files
(`spec/provenance/protocol.md`, `spec/provenance/spec.lock`, `spec/refund/RefundSpec.dfy`,
`spec/refund/protocol.md`, `spec/refund/spec.lock`); this diff changes none of them. So the two
ratification diffs touch no common line, and the order of the merges does not matter for them.
The two pull requests both append to `ROADMAP.md` and `unsure.md`; those are text conflicts of the
records, not of protected bytes.

A finding outside this proposal: on `main` `b1c98822` (after pull request 81), three entries of the
`implementation.lock` that pull request 76 proposes differ from the files on `main`
(`scripts/demo_gauntlet.py`, `scripts/exit_archia_mcp.py`, `scripts/exit_universal_primitives.py`).
Pull request 76 says that its lock goes stale when `main` changes a listed script; this has
happened. I did not regenerate it.

## Actual checks (scratch clones of `b1c98822`; Python only, no Dafny, no hosted service)

| Check | Actual exit | Result |
| --- | --- | --- |
| `git apply --check -v ratification.diff` (clone B) | 0 | both files apply |
| `git apply`, commit (scratch) ; `git diff --name-status HEAD~1 HEAD` | 0 | exactly `A spec/refund/RefundLogSpec.dfy`, `A spec/refund/RefundLogSpec.lock` |
| `cmp spec/refund/RefundLogSpec.dfy` with this folder's `RefundLogSpec.dfy` | 0 | identical bytes |
| `git apply --check` a second time | 1 | refused: the files exist (as expected) |
| `check_frozen_pr_gate.py HEAD`, clone A (base) and clone B (applied) | 0; 0 | the eight PR-gate modules are unchanged |
| probe (`records/apply-check-gate-probe.log`): `incremental.protected_manifest` A vs B; `approval.authorize(A, …, B)`; `refund.APPROVED` and both refund locks against B; `coverage.lock_dependents` A vs B | 0 | changed protected files = exactly the two new files; authorize = `Rejected: UNAPPROVED_PROTECTED_CHANGE` (what the hosted gate is expected to say); every `APPROVED` digest of `gate/refund.py` still matches; `spec/refund/spec.lock` dependencies match; the new lock's four digests match; `lock_dependents` equal before and after |
| `gate/provenance/bootstrap.py --implementation-sha256 76b983ac… --check`, clone A; clone B | 1; 1 | the same rejection on both (`UNLOCKED_EXECUTABLE:scripts/demo_gauntlet.py`, a known state of `main`, see pull request 76): the diff does not change the bootstrap result |
| `git diff --quiet HEAD~1 HEAD -- clearing/ gate/ policy/ spec.lock spec/refund/RefundSpec.dfy spec/refund/spec.lock` | 0 | none of these changed; the Slice 2 bundle inputs (`clearing/`) are untouched |
| hosted `gate/pr_check.py`; `gate/refund.py` full run; Stage EXIT cases | NOT RUN | |
