# Bootstrap checklist for version 3 (three human actions)

Date: 2026-11-18 UTC (closeout of Round 4). Nothing below is merged.
Pull request 39 is open for action 1. Stage 12 unauthorized. Stage 9
deferred. `end_to_end=false`. Measured facts and their limits:
`REPORT-V3.md` section 9. Review text: `REVIEW-3.md`.

Round 4 code work is stopped by the owner's stop rule: the third
independent review found 0 fail-opens and 0 HIGH or MEDIUM accidental
defects. No gate byte changed after that review.

## Branches (built on `main` at `4143f4b2`; origin checked 2026-11-18 UTC)

| Branch | Commits on top of `main` | Content |
| --- | --- | --- |
| `proposal/v3a-gate-ratification-rule` (pushed; pull request 39) | `801777ea` then `26410d46` | step A (the rule); then record 0001 and the proposal text that it names |
| `proposal/v3b-print-effects` (pushed; no pull request yet) | the two above, then `f54e2507`, then `53534f64` (commit C) | step B (print effects); then records made again by real runs at `f54e2507` (evidence, Stage 5, fresh Stage 6 with the old Stage 6 records kept as `results/stage6-epoch1`) |

Commit C `53534f64` (1,031 files; protected paths: 0) holds the records
made at `f54e2507` on mains power: `gate/gate.py --impl impl/Ledger.dfy`
exit 0 (`evidence.json`, byte-equal to the file of the control
candidate); Stage EXIT cases 1, 2, 3, 4, 5, 8: 24 cases, exit 0 each;
`stage6_epoch2.py`: benchmark exit 0 (75 pairs, 905 s), controls exit 0,
identity check exit 0 (450 files), report EXIT exit 0 twice, report
byte-identical. Process seconds are 1 to 3 percent above the earlier
run; solver resource counts and reused members are equal. Stage 6
report EXIT in a clean clone at `53534f64`: exit 0. A first try of the
stage EXIT runner did not start (my harness error: a leftover folder
name); the cases ran in the second try.

The backup branch `backup/forge-local-2026-11-11` is NOT a base for
these. Its gate is an older local version without `main`'s Stage 11
modules.

Merge compatibility: `main` (`4143f4b2`) is the direct ancestor of both
branches (`git merge-base --is-ancestor`: exit 0 for each). No rebase is
needed. A squash merge or a rebase merge of action 1 gives the tree
`7ba590b83bd3438570df681a4dcd93cc87bba38a`.

## Protected paths that need the owner's merge

Action 1 (pull request 39):

| Path | Change | SHA-256 after |
| --- | --- | --- |
| `gate/approval.py` | modified, +157 −24 | `cabcbd5c97b899ccb4ce7cc9497dac97d3f7c371850ba8e22a21fac2eb475b3a` |
| `gate/incremental.py` | modified, +12 −5 | `1086e97b6bd46b23ae7726b006c5fa6154e6926709acce93feee083258c6b8ad` |
| `gate/ratification.py` | new, 142 lines | `93bb23bc64f1c36174829602c4b480b93a2063cd2cd779bc98582d2f89870336` |
| `governance/gate-ratifications/0001-print-effects.json` | new, 48 lines; protected from this merge on | `4b229269238cc0423a9dcf51052671f00431e57480cea98912b93b4dbff12a8f` |

Not protected, same pull request:
`proposals/forge2-pillar1-print-effects/v3/PROPOSAL-V3.md` (new, 76
lines, SHA-256 `a686092c2da23bc5358e0c562eb4f8b74d033a80a8233d1509f67e270aff6676`).

Action 2 (commit `f54e2507`; the six files that record 0001 names):

| Path | Change | SHA-256 old → new (first 12) |
| --- | --- | --- |
| `gate/ContractBinding.dfy` | +13 −0 | `da994efac59d` → `575dca825c94` |
| `gate/backends/dafny.py` | +1 −1 | `11b922b0da01` → `a6e78cdcff7b` |
| `gate/refund.py` | +1 −1 | `9d91b7543c06` → `bafc1b72d070` |
| `spec/refund/spec.lock` | +1 −1 | `993dade887f6` → `8b131ab82d3d` |
| `toolchain/linux-pins.json` | +2 −1 | `11128aa46f89` → `dbe9335f60f0` |
| `toolchain/pins.json` | +2 −1 | `74dcc4b81e45` → `4b612d8845e6` |

Not protected, action 2: `scripts/exit_stage_5.py` (+5 −2),
`bugs/print_effect.dfy` and `bugs/print_effect_marked.dfy` (new, 53
lines each), and the records of commit C.

The record regenerates byte for byte from the two commits:
`python3 -I -B make_record_0001.py 26410d46 f54e2507 <file>`, then
`cmp` with the committed record: exit 0.

## Read this first: six facts

1. Every action below ends with a NON-ZERO gate result on `main` as it
   is. That is correct behaviour, not a defect of the pull requests:
   - action 1 changes the gate: REJECTED (exit 1);
   - action 2 changes files that no obligation lists: UNSUPPORTED
     (exit 3), even with the record on `main`.
   So each action is a merge by the owner's authority, as with earlier
   gate changes (see ratification 0001). The agent does not merge and
   does not use administrator rights.
2. What the new rule gives in action 2: the gate proves that the
   protected bytes of the pull request are EXACTLY the bytes named in
   record 0001, and the floor controls ran. Without the record the
   answer is exit 1; with it the answer moves to exit 3.
3. The floor controls do not prove that a gate is not weaker. Three
   independent reviews showed that bytes written on purpose pass them.
   Read the diff of both branches yourself.
4. Review 3, finding F1 (MEDIUM; needs an owner-written record): the
   list of eight excluded PR-gate modules is NOT complete. Four more
   modules load in the PR-gate process and stay ratifiable at Tier 0:
   `gate/backends/dafny.py`, `gate/backends/__init__.py`,
   `gate/dependencies.py`, `gate/core.py`. Record 0001 itself names
   `gate/backends/dafny.py`. For such a file the floor controls exercise
   only the `gate.py` paths. The sentence in `gate/ratification.py`
   "the changed PR gate itself never runs" is false for these four
   files. NOT changed, by the stop rule. Decision D3 (yours): accept
   this as a stated limit, or ask for a scope change before the merge.
   A scope change that excludes `gate/backends/dafny.py` also takes
   step B out of Tier 0: step B would then need your merge like step A.
5. Stage 9 lock. `gate/provenance/implementation.lock` on `main` pins
   `gate/approval.py` and `gate/incremental.py`. After action 1 these
   two entries no longer match `main`; after action 2 eight entries do
   not match. Until the lock is renewed, Stage 9 operations on `main`
   stop with `IMPLEMENTATION_INPUT`. The earlier gate pull requests 27,
   29, 30 and 32 carried a new lock in the same pull request; this one
   does not. The lock's own SHA-256 is also pinned in
   `.github/workflows/booking-reuse.yml`. Decision D2 (yours): renew the
   lock in action 3 (as planned), or add a lock commit before action 1.
6. Do not edit `PROPOSAL-V3.md` on `main` after action 1. Record 0001
   binds its SHA-256. A changed text makes the record unusable
   (`RATIFICATION_BINDING`).

## Action 1 — bootstrap merge (owner)

Merge pull request 39 (`proposal/v3a-gate-ratification-rule`) into
`main`: https://github.com/mack-dot/forge/pull/39

- [ ] Read `gate/approval.py`, `gate/ratification.py` and the edits of
      `gate/incremental.py` (three files, commit `801777ea`).
- [ ] Read record `governance/gate-ratifications/0001-print-effects.json`
      (commit `26410d46`): six files with old and new SHA-256, two
      controls, the SHA-256 of `PROPOSAL-V3.md`.
- [ ] Read `REVIEW-3.md` (five findings; fact 4 above).
- [ ] Hosted gate result of pull request 39 (run 44213967396,
      `pull_request_target`, base `4143f4b2`, head `26410d46`, Linux
      profile): `gate/pr_check.py` exit 1, outcome REJECTED,
      `UNAPPROVED_PROTECTED_CHANGE: gate/approval.py,
      gate/incremental.py, gate/ratification.py`. Job `verify`:
      failure. Job `report`: success. Status `forge/proof-gate`:
      failure. Pull request: OPEN, MERGEABLE, BLOCKED (review required;
      failing status). The local run with `main`'s gate and the local
      profile gave the same exit code and the same text.
- [ ] Decide whether to write a governance ratification for this
      override, as for earlier ones.

## Action 2 — the print-effects pull request (owner)

Open a pull request from `proposal/v3b-print-effects` against `main`
after action 1. This is the first hosted run of `gate/pr_check.py` with
a record on the trusted side.

- [ ] Expected gate result with `main`'s present coverage rule:
      UNSUPPORTED (exit 3). Measured locally (local profile, trusted
      side = commit `26410d46`, candidate = `f54e2507`): exit 3; record
      0001 matched; 8 of 8 floor controls as expected (six planted bugs
      rejected, `impl/Ledger.dfy` accepted, function probe equal); four
      files that no obligation lists: `bugs/print_effect.dfy`,
      `bugs/print_effect_marked.dfy`, `scripts/exit_stage_5.py`,
      `toolchain/linux-pins.json`. Measured with
      candidate `53534f64` (commit C): exit 3, 8 of 8 floor controls as
      expected, 1,693 files that no obligation lists (the records).
- [ ] NOT measured: the hosted Linux profile. There
      `toolchain/pins.json` (the macOS pins) is probably the file that
      no obligation lists, instead of `toolchain/linux-pins.json`.
- [ ] Decision D1 (yours): keep the coverage rule and merge by your
      authority; or split the change; or change the rule so that
      ratified files count as covered. I did not change the rule.
- [ ] Shown on `main`'s gate: a ratified change that touches only files
      which obligations list gets exit 0 (VERIFIED), `main`'s six
      obligations are established again by the changed gate, and the
      saved command replays byte-identical (control set attempt 7,
      case 06).
- [ ] If `main`'s Stage 6 records change first (queued item Q1), commit
      C must be made again by the same flow.

## Action 3 — Stage 9 renewal (owner, hosted)

Status of the six Stage 9 EXIT cases: DEFERRED_TO_HOSTED_SIGSTORE_ON_PR.

- [ ] `gate/provenance/implementation.lock` pins two files that step A
      changes and six more that step B changes (fact 5). It needs a new
      lock, a new controller request and one hosted signing run. That
      run writes public Sigstore log entries that cannot be removed. It
      was not started from this session.
- [ ] `gate/provenance/` is outside Tier-0. The new lock enters `main`
      by your merge.
- [ ] `.toolchain/stage9/controller.json` and `results/stage9/<case>/`
      are not on this Mac now.

## Queued cleanup after action 1 (prepared; runs on your word)

Q0. Confirm the merge. `git fetch origin main`; the tree of
    `origin/main` is `7ba590b8…` if nothing else merged;
    `python3 -I -B proposals/round4-20261117/check_frozen_pr_gate.py origin/main`
    must exit 0 (exit 1 at present `main`: two modules differ, one is
    absent).

Q1. Stage 6 record on `main`. The EXIT `exit_stage_6.py --case report`
    exits 1 at `main` today (`TRUSTED_INPUTS`), since earlier merges
    changed pinned gate files. Step A changes none of the 20 pinned
    files. Prepared: local
    branch `records/stage6-epoch2-main`, commit `4cab1868` on `4143f4b2`
    (1,028 files: fresh records; the earlier records moved unchanged to
    `results/stage6-epoch1`; protected paths: 0; not pushed). Made by
    `stage6_epoch2.py` at `main`'s tree on mains power: benchmark exit 0
    (75 pairs, 868 s), controls exit 0, identity check exit 0 (450
    files), report EXIT exit 0 twice, report byte-identical. Solver
    resource counts and reused members equal the earlier run; process
    seconds are within −2.3 to +0.7 percent of it. Report EXIT in a
    clean clone at `4cab1868`: exit 0; at `26410d46` plus this commit:
    exit 0. After action 1: rebase (no common path), run the report
    EXIT again, open the pull request. A first run of the same flow
    (local commit `0b3fb727`, all exits 0) was made under load and on
    battery power; its process seconds were 15 to 44 percent higher,
    so this run replaces it. Limit: the records hold local absolute
    paths, as the Stage 6 records on `main` do now.

Q2. Links of `FORGE_MASTER_IDEA.md`. On `main` 10 of its 13 relative
    links have no target
    (`python3 -I -B proposals/round4-20261117/check_links.py origin/main FORGE_MASTER_IDEA.md`:
    exit 1). Prepared as the local
    branch `docs/master-idea-records` on `4143f4b2` (not pushed), made
    from the backup branch's files: the six `proposals/forge2-*`
    packets, `proposals/round2-20261117`, `round3-20261117`,
    `round4-20261117`, the two round plans, and `FORGE_MASTER_IDEA.md`
    without its note about missing records. Protected paths: 0. Result
    of the link check on that branch: `REPORT-V3.md` section 9. The
    branch is made again from the newest files before its pull request.

Q3. Decision (yours): `ROADMAP.md` on `main` still says "CURRENT: Stage
    9 — PROVENANCE" (1,740 lines), and `unsure.md` on `main` ends at
    U131 (it is a byte prefix of the backup branch's file). A new
    session that follows `AGENTS.md` on `main` would work on Stage 9.
    Recommended: carry `ROADMAP.md`, `unsure.md` and
    `FORGE_MISSION_STATUS.md` to `main` with Q2.

Q4. Stage 11 records. `scripts/exit_stage_11.py` on `main` reads
    `results/stage11/eval-0007` and `eval-pr27-0003`. They are not on
    `main` and not in the working tree; the verified backup of
    2026-11-01 holds them (178 files). Measured at `4143f4b2`: with
    them restored to a scratch folder, three cases exit 0; without
    them, three cases exit 1. Decision (yours): add them to `main`, or
    record the Stage 11 EXIT as "needs the backup".

Q5. Full check, then freeze. Stage EXIT cases 1, 2, 3, 4, 5, 8 (24),
    Stage 6 (1), Stage 11 (3) at the new `main`; then the eight PR-gate
    modules are FROZEN at the digests in
    `proposals/round4-20261117/frozen-pr-gate-modules.json`. Stage 9
    stays not green until action 3 (fact 5).

Each of Q1 and Q2 is a pull request with files that no obligation
lists. `main`'s gate will answer UNSUPPORTED (exit 3). So each needs
your merge.

## Not verified

- `gate/pr_check.py` with the new code and a record on the trusted
  side, on a hosted runner. Possible only after action 1.
- The Linux profile for every local result in this file.
- Review 3 did not run on Linux or on a file system that keeps letter
  case apart (findings F4, F5).
- Stage 7 with these branches (Stage 7 reads none of the changed files).
