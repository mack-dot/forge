# Unapplied diffs of the night shift of 2026-11-19 (NOT applied; owner decision)

Nothing in this folder is applied to the repository. `main` keeps the
merged sink, minter, dispatcher and suite. M1-B stays OPEN.
`end_to_end=false`.

## Why the fixes are diffs and not applied code

1. `ts/refund-finality/{encoding,minter,sink,dispatcher,proposer}.ts`,
   `tests/refund-finality/suite.ts`, `commit_cli.ts`, `dispatch_cli.ts`
   and `scripts/exit_slice1.py` are inputs of the recorded Slice 1
   bundle (`scripts/exit_slice1.py`, list `SUBJECT`). Some are inputs of
   the Slice 3 and M1 conformance bundles too. A changed byte changes a
   recorded bundle digest.
2. The merged 115-row suite does not complete on the hardened tree: it
   stops with exit 2 at row x1. Cause: row x1 makes a raw SQL write, and
   the hardened database now refuses that write (a trigger aborts the
   INSERT). The suite passes only with CHANGED expectations (owner items
   B-15, B-16). The owner has not accepted them. The owner's plan: ONE
   later pull request for B-15 and B-16.
3. `tsconfig.json` includes `tests/**/*.ts`. The new regression tests
   import hardened modules that are not on `main`. So they stay in the
   diff.

## Files

| File | Content | Source |
| --- | --- | --- |
| `hardening-code.diff` | 119 files: hardened `ts/refund-finality/` (sink, minter, dispatcher, proposer, encoding, key file, mint memory, store core, launch scripts), `tests/refund-finality/regress/` (the permanent regressions), `provider/`, `spec-conformance/`, `commit_cli.ts`, `dispatch_cli.ts`, `tests/demo-gauntlet/sink_tool.ts`, `scripts/demo_gauntlet.py`, `scripts/exit_slice1.py` | `git diff origin/main nightshift/B-trust@12d634f6 -- ts tests scripts`, without `suite.ts`. For these paths the tree at `12d634f6` equals the tree at `b22b6b34`, the last commit that the red team re-tested |
| `suite-expectations-B15-B16.diff` | `tests/refund-finality/suite.ts` only: the changed expectations | the same diff, `suite.ts` only |

The two diffs belong together: apply both, or none. One line of
`tests/refund-finality/spec-conformance/heavy_spec.sh` differs from the
branch: the local user name in a default path is replaced (see
`../integration/SANITIZE_MAP.tsv`).

Other unapplied diffs of the night (gate rules, admission, earlier
adoption drafts, `exit_m1_conformance.py`) stay where B stored them,
under `../orch-B/`; the list with digests is
`../integration/unapplied.tsv`. The JavaScript bound checker
(`../orch-B/h-gate/`) is ADVISORY ONLY by owner decision D-4: no
blocking gate rule comes from it.

## How to try them (in a scratch clone; never in the owner's checkout)

    git clone <repository> scratch && cd scratch
    git apply --check proposals/night-shift-20261119/unapplied/hardening-code.diff \
                      proposals/night-shift-20261119/unapplied/suite-expectations-B15-B16.diff
    git apply proposals/night-shift-20261119/unapplied/hardening-code.diff \
              proposals/night-shift-20261119/unapplied/suite-expectations-B15-B16.diff
    # pinned Node 24.3.0 first in PATH; node_modules and .toolchain linked as for the stage runs
    node --import tsx tests/refund-finality/regress/<test>.ts <tree> <compiled issuer module>

Exit 0 = safe, exit 1 = the defect is present. The compiled issuer
module is a build output: `dafny build impl/finality-core/IssueAuth.dfy
--target js` with the gate options, then the export footer (recipe:
`scripts/exit_slice1.py` in the diff, function for the issuer core). It
is not in the repository, and the modules that B and the red team used
are not on any branch (build outputs). Test keys are made at test time (temporary 0600 files);
no key is stored.

## Every changed suite expectation (owner items B-15, B-16)

Source: `../orch-B/h-suite/CHANGES.md` and the launcher's notes in
`../OWNER_REQUIRED.md` (decisions D-4 to D-6). "Old line" is the line in
the merged `suite.ts`. No row is deleted. Every old row name is kept.

| Row | Old line | Merged expectation | Proposed expectation | Stronger / weaker / semantic change |
| --- | --- | --- | --- | --- |
| x1 raw INSERT: an outbox row without a settled row | 506 | effects none; the dispatcher refuses: no settled row | the DATABASE refuses the write; store unchanged; effects none | STRONGER (the write never lands). This row is the cause of exit 2 of the merged suite on the hardened tree |
| x2 raw UPDATE before dispatch: amount 100 to 900 | 511 | effects none; refused: outbox intent is not the signed intent | the database refuses the write; store unchanged; the committed signed row (100) is dispatched as usual | STRONGER (write refused). Note: one effect is now sent, the honest one |
| x3 raw INSERT and UPDATE with an attacker's key | 516 | effects none; refused: signature does not verify | the database refuses the write; store unchanged; effects none | STRONGER |
| x3 public-key audit of that changed database | 518 | problems found: more than 0 | the same, on the variant-2 database; a sink that refuses to start counts as 1 problem | INTERFACE ADAPTATION (same claim) |
| x4 replay after dispatch: outbox rows deleted and inserted again | 522 | effects none; nothing refused | the database refuses the DELETE; store unchanged; effects none | STRONGER |
| x5 an emit that fails (crash between the ledger line and the effect) | 527 | effects [rq_x5_2]; nothing refused (the merged at-most-once record) | effects [rq_x5_2]; rq_x5_1 refused: IN DOUBT (1 row) | **SEMANTIC CHANGE** (delivery policy): the loss is reported as in doubt for an operator, not silently counted as sent. Red team C-ATT-18 |
| x6 raw INSERT: a validly signed token for an earlier state | 531 | effects none; refused: token does not continue the dispatched chain | the database refuses the write; store unchanged; effects none | STRONGER |
| x7 raw INSERT: a copy of a committed token under a new request id | 535 | effects none; refused: request id is not the signed one | the database refuses the write; store unchanged; effects none | STRONGER |
| x1, x2, x3, x6, x7 "variant 2" (NEW rows): a file writer that first drops the triggers, recomputes the chain, restores the triggers | new | (none) | the running sink halts; a restart is refused; the dispatcher reports the audit failure; effects none | STRONGER (new coverage) |
| x4 "variant 2" (NEW row) | new | (none) | the sink starts; effects none; nothing refused (the rewritten rows are byte-identical; the ledger stops a second effect) | STRONGER (new coverage; same result as the merged x4) |
| option "single-use on: another transition for a pre-state that has a signed token" | 589 | no token (single use per PRE-STATE) | a token that verifies (single use per charge id and request id; constant `SINGLE_USE_RULE = "per-request"`) | **WEAKER at token level**: two tokens can exist for one pre-state. The sink still commits at most one (TESTED-UNPROVED at the composed level). Reason: the merged rule lets a zero-amount refund freeze a charge (C-ATT-03). Owner item B-15 |
| option "another transition for a request id that has a signed token (same pre-state)" (NEW row) | new | (none) | no token | STRONGER (new coverage; holds under both readings) |
| report fields `counts.known_limit_rows`, `owner_decisions_pending` (NEW) | new | (none) | extra report fields | INTERFACE ADAPTATION |

Counts: 115 rows merged. `CHANGES.md` expected 122. B's later run of the
adapted suite on the branch tree at `b22b6b34`: exit 0, 126 rows, 0
failed (B's run; log `../orch-B/h-suite/logs/B-full-5.*`; `CHANGES.md`
does not list the four rows above 122: B's final record names "D-2
rows"). The integrator did NOT run the changed suite.
