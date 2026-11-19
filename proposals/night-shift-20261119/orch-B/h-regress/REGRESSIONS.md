# Refund-finality regressions (night shift 2026-11-19, task h-regress)

Permanent, executable regressions for the counterexamples that the night shift confirmed against the refund
finality sink. A TEST, not a proof. Each attack regression asserts the SAFE outcome on durable state (outbox rows,
stored state) and on effects (dispatcher emissions). It does not assert error texts.

## How to run

From the repository root, with the pinned Node 24.3.0 first in `PATH`:

```
node --import tsx tests/refund-finality/regress/run.ts <sinkModulePath> <dispatcherModulePath> [expectedHeadMode] [--encoding <encoding.ts>]
```

- The sink and the dispatcher are loaded BY PATH. Only the public interface is used: `new Sink(path, cfg)`,
  `init`, `commit(tokenText)`, `close`, `new Dispatcher(db, ledger, dcfg, emit)`, `flush`.
- `cfg` always carries `initialState`. Durable state is read with raw SQL from the tables `state`, `settled` and
  `outbox`. The hostile-writer regressions write these tables from a second connection.
- `expectedHeadMode`: `none` (default) or the path of an anchor adapter module that exports
  `capture(h, dbPath)` and `apply(cfg, head)` (see `harness.ts`). Only X6-P1 uses it.
- The encoding module defaults to `encoding.ts` next to the sink module.
- Output: one line per regression, `PASS|FAIL id: reason`. Exit 0 only if every line is PASS; exit 2 on a usage
  error. One file can also run alone: `node --import tsx tests/refund-finality/regress/<file>.ts <sink> <dispatcher>`.
- Each regression uses a fresh directory under the system temp directory. The directories are removed at exit.
  Fixed ids and amounts; no clock; no network. The test key is generated in the process (no result depends on it).
- Model of a faulty signer: the trusted test key signs an arbitrary body (canonical bytes from `encoding.ts`).

## Table

| id | attack class (assumption) | unsafe outcome on the merged sink | expected safe outcome | evidence |
|---|---|---|---|---|
| C1–C5 | positive controls (none) | none: all PASS | honest refund, zero-amount refund, two zero refunds, replay (no second effect), amount == remaining: each intent once in the outbox and emitted once | spec/refund/protocol.md (zero is legitimate) |
| X1 | request-id mismatch (faulty signer) | 2 outbox intents and 2 effects for `rq_victim` | at most 1 intent and 1 effect for `rq_victim`; the honest one is emitted once | U530, U534; d-reqid Contrast.dfy, single_runs.ts |
| X2 | cross-charge (faulty signer) | 2 effects for (`ch_2`, `rq_x`), 100 for a charge of 50 | at most 1 effect for (`ch_2`, `rq_x`), at most 50 for `ch_2`; no `ch_2` intent in `ch_1`'s outbox | U534; r-reqid Attack.dfy CrossChargeWithReqIdPatch |
| X2b | foreign post-state (faulty signer) | `ch_1`'s store holds `ch_2`; no `ch_1` refund commits again | store keeps `ch_1`; a later honest `ch_1` refund is emitted once | Attack.dfy ForeignPostLocksStore |
| X3 | upgrade from a legacy gap store (faulty signer before the upgrade) | 1 effect before + 1 after for `rq_victim` | at most 1 effect in total for `rq_victim` | U534; r-reqid upgrade_run.ts (mode flushed) |
| X4 | signed but unauthorized token (faulty signer; B-10; POST-RULE open) | all 5 cases commit and are emitted (case a: 1001 of 1000) | no outbox row, no effect, state unchanged; a later honest refund is emitted once | U555, U557; d-v6sink conformance_v6.ts; r-v6 rv6_cases.ts |
| X5a | balance reset (database writer without key) | outbox total 2000 for a charge of 1000 (the dispatcher still emits only 1000) | outbox total and emitted total at most 1000 | U554; r-repairs attack_v4.ts S1 |
| X5b | outbox amount rewrite (database writer without key) | `rq_2` settled on the tampered store | no unsigned intent emitted; no new settlement while the rewritten row is present | U554; r-repairs attack_v4.ts S2 |
| X6-Z1 | zero-row deletion, then re-commit (database writer without key) | `rq_z1` settled again (also on the v6 draft: finding F1) | `rq_z1` not settled again; emitted at most once | U565; r-v5 attack_rv5.ts Z1 |
| X6-P1 | prefix rollback (database writer; a STATED LIMIT) | (documented) the store starts | without an anchor: the sink starts (documented limit); with an anchor adapter: refuses to start or to settle `rq_2` again; `rq_2` emitted at most once in both modes | U565; r-v5 attack_rv5.ts P1 |

A reject-all sink passes most "at most" assertions. The positive controls, and the liveness parts of X1, X2, X2b
and X4 and the setup checks of X5 and X6, make it FAIL.

## Evidence of this task (h-regress; actual exit codes; light single runs, each under 2 s)

| Run | Log | Exit | Result |
|---|---|---|---|
| (a) merged sink + merged dispatcher (tree-a = git archive of nightshift/B-trust at de538868) | logs/run-a-4.log, run-a-5.log | 1, 1 | C1–C5 PASS; X1, X2, X2b, X3, X4, X5a, X5b, X6-Z1 FAIL; X6-P1 PASS (documented limit) |
| (a) in place, after `patch -p1` of h-regress.diff into tree-a | logs/run-a-inplace-1.log | 1 | same lines as run-a-4 |
| (b) v6 draft (tree-b = tree-a + p-adopt2/adoption-v6.diff; sink.ts 1ba4682b…, dispatcher.ts 5cecfd77…) | logs/run-b-4.log, run-b-5.log | 1, 1 | C1–C5 PASS; X1–X5b PASS; X6-Z1 FAIL (review finding F1, U565); X6-P1 PASS |
| (b) with standins/anchor_stub.ts (v6 ignores the field) | logs/run-b-anchorstub-2.log | 1 | X6-P1 FAIL "rollback accepted with an anchor" (as intended: no anchor support), X6-Z1 FAIL |
| reject-all stand-in (standins/reject_all_sink.ts) + merged dispatcher | logs/run-rejectall-2.log | 1 | C1–C5 FAIL; 13 of 14 FAIL; X3 PASS (refusal is safe there) |
| usage error (no arguments) | (console) | 2 | usage text |
| tsc --noEmit -p tsconfig.json on tree-a + new files | logs/tsc-1.log | 2 | 3 errors, all in tests/booking-certificate/corpus.ts (the export lacks proposals/forge2-pillar3-dual-certificate); 0 in regress/ |
| git -C <B-trust worktree> apply --check h-regress.diff | logs/apply-check-1.log | 0 | new files only |

Runs 4 and 5 of (a) and of (b) give identical PASS/FAIL lines (determinism check, 2 runs each).

## Red-team hand-off: run against any sink

```
cd <repository root with the regress files>
PATH=/opt/homebrew/bin:$PATH node --import tsx tests/refund-finality/regress/run.ts <path/to/sink.ts> <path/to/dispatcher.ts> [none|<anchor adapter.ts>] [--encoding <path/to/encoding.ts>]
```
Example for the hardened sink after its diff is applied on the branch:
`node --import tsx tests/refund-finality/regress/run.ts ts/refund-finality/sink.ts ts/refund-finality/dispatcher.ts`
For its anchored mode, write a 5-line adapter like standins/anchor_stub.ts with the real config field.
