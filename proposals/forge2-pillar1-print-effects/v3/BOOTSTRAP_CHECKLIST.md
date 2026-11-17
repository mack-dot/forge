# Bootstrap checklist for version 3 (three human actions)

Date: 2026-11-17. Nothing below is merged. Stage 12 unauthorized.
`end_to_end=false`. Measured facts and their limits: `REPORT-V3.md`.

## Branches (built on `main` at `4143f4b2`)

| Branch | Commits on top of `main` | Content |
| --- | --- | --- |
| `proposal/v3a-gate-ratification-rule` | `@A@` then `@A2@` | step A (the rule); then record 0001 and the proposal text that it names |
| `proposal/v3b-print-effects` | the two above, then `@B@`, then `@C@` | step B (print effects); then records made again by real runs (evidence, Stage 5, fresh Stage 6 with the old Stage 6 records kept as `results/stage6-epoch1`) |

The backup branch `backup/forge-local-2026-11-11` is NOT a base for
these. Its gate is an older local version without `main`'s Stage 11
modules.

## Read this first: three facts that decide what the gate will say

1. Every action below ends with a NON-ZERO gate result on `main` as it
   is. That is correct behaviour, not a defect of the pull requests:
   - action 1 changes the gate and adds a record: REJECTED (exit 1);
   - action 2 changes files that no obligation lists: UNSUPPORTED
     (exit 3), even with the record on `main`.
   So each action is a merge by the owner's authority, as with earlier
   gate changes (see ratification 0001).
2. What the new rule gives in action 2: the gate proves that the
   protected bytes of the pull request are EXACTLY the bytes named in
   record 0001, and the floor controls ran. Without the record the
   answer is exit 1; with it the answer moves to exit 3.
3. The floor controls do not prove that a gate is not weaker. Two
   independent reviews showed that bytes written on purpose pass them.
   Read the diff of both branches yourself.

## Action 1 — bootstrap merge (owner, administrator rights)

Merge `proposal/v3a-gate-ratification-rule` into `main`.

- [ ] Read `gate/approval.py`, `gate/ratification.py` and the edits of
      `gate/incremental.py` (three files, commit `@A@`).
- [ ] Read record `governance/gate-ratifications/0001-print-effects.json`
      (commit `@A2@`): six files with old and new SHA-256, two controls,
      the SHA-256 of `proposals/forge2-pillar1-print-effects/v3/PROPOSAL-V3.md`.
- [ ] Expected hosted gate result: REJECTED, `UNAPPROVED_PROTECTED_CHANGE`
      (gate files and the record folder). Measured locally: exit 1.
- [ ] Decide whether to write a governance ratification for this
      override, as for earlier ones.

## Action 2 — the print-effects pull request (owner)

Open a pull request from `proposal/v3b-print-effects` against `main`
after action 1.

- [ ] Expected gate result with `main`'s present coverage rule:
      UNSUPPORTED (exit 3). Measured locally (local profile, trusted
      side = commit `@A2@`): all floor controls pass; the files that no
      obligation lists are named in the output. With commit `@C@` the
      list is longer (record files).
- [ ] NOT measured: the hosted Linux profile. There
      `toolchain/pins.json` (the macOS pins) is probably the file that
      no obligation lists, instead of `toolchain/linux-pins.json`.
- [ ] Decision D1 (yours): keep the coverage rule and merge by your
      authority; or split the change; or change the rule so that
      ratified files count as covered. I did not change the rule.
- [ ] Shown on `main`'s gate: a ratified change that touches only files
      which obligations list gets exit 0 (VERIFIED), and `main`'s six
      obligations are established again by the changed gate.

## Action 3 — Stage 9 renewal (owner, hosted)

Status of the six Stage 9 EXIT cases: DEFERRED_TO_HOSTED_SIGSTORE_ON_PR.

- [ ] `gate/provenance/implementation.lock` pins files that step B
      changes. It needs a new lock, a new controller request and one
      hosted signing run. That run writes public Sigstore log entries
      that cannot be removed. It was not started from this session.
- [ ] `gate/provenance/` is outside Tier-0. The new lock enters `main`
      by your merge.
- [ ] `.toolchain/stage9/controller.json` and `results/stage9/<case>/`
      are not on this Mac now.

## Not verified

- `gate/pr_check.py` (the hosted wrapper) with the new code.
- The code after the fixes for the second review has not been reviewed
  again by an independent reader.
- Stage 7 with these branches (Stage 7 reads none of the changed files).
