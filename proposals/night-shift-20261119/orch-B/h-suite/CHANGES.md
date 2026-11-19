# h-suite: changes to the Slice 1 EXIT suite and its callers (night shift 2026-11-19, Orchestrator B)

Base: nightshift/B-trust f08a21c1 (code identical at dd3bec6e). Diff: `h-suite.diff` (SHA-256 in `h-suite.diff.sha256`).
"Old line" = line in suite.ts at f08a21c1. "New line" = line after the diff. No row is deleted. Every old row name is kept.
Rows: 115 before; 122 expected after (+6 variant-2 rows, +1 option row). The x3 audit row is kept (one row).

Classes: IA = interface adaptation; HR = hostile write now refused; OD = design change that needs the owner.

| row (name, short) | old line | new line | old expectation | new expectation | reason | class |
|---|---|---|---|---|---|---|
| x1 raw INSERT: an outbox row without a settled row | 506 | 606 | effects []; refused: no settled row | v1: the database refuses the write; store unchanged; effects []; nothing refused | trigger h_outbox_bi (S2) aborts the raw INSERT; the old row crashed the suite (exit 2) | HR |
| x1 ... ; variant 2 (file writer) | new | 609 | (none) | running sink halted; sink restart refused; effects []; refused: store audit failed | file writer drops triggers, writes with a recomputed chain, restores triggers | HR |
| x2 raw UPDATE before dispatch: amount 100 -> 900 | 511 | 616 | effects []; refused: outbox intent is not the signed intent | v1: the database refuses the write; store unchanged; effects [rq_x2_1]; nothing refused | h_outbox_bu (S5) aborts; the committed signed row (100) is then dispatched as usual | HR |
| x2 ... ; variant 2 | new | 620 | (none) | as x1 variant 2 | | HR |
| x3 raw INSERT and UPDATE, attacker's key | 516 | 624 | effects []; refused: signature does not verify | v1: refused write; unchanged; effects []; nothing refused | h_settled_bi aborts (and NOT NULL prev/self) | HR |
| x3 ... ; variant 2 | new | 629 | (none) | as x1 variant 2 | writer also updates state (blob, seq, refunded) | HR |
| x3 the public-key audit of that changed database | 518 | 633 | problems found: more than 0 | same; now on the variant-2 database; a sink that refuses to start counts as 1 problem | h1 Sink constructor refuses a store whose start-up audit is false | IA |
| x4 replay after dispatch: outbox rows deleted and inserted again | 522 | 636 | effects []; nothing refused | v1: refused write; unchanged; effects []; nothing refused | h_outbox_bd (S5) aborts the DELETE | HR |
| x4 ... ; variant 2 | new | 640 | (none) | sink starts; effects []; nothing refused (= the merged expectation) | the rewritten rows are byte-identical (h1 needs seq, prev, self); the ledger stops a second effect | HR |
| x5 crash between the ledger line and the effect | 527 | 656 | effects [rq_x5_2]; nothing refused | effects [rq_x5_2]; rq_x5_1 refused: in doubt (1 row); 0 already dispatched | h-dispatch C-ATT-18 (at most once; in doubt is reported). Adopted from unapplied/suite-C-ATT-18.diff with a try/catch and the OLD row name kept | IA (delivery policy; owner may review) |
| x6 raw INSERT: a validly signed token for an earlier state | 531 | 663 | effects []; refused: token does not continue the dispatched chain | v1: refused write; unchanged; effects []; nothing refused | h_settled_bi aborts | HR |
| x6 ... ; variant 2 | new | 665 | (none) | as x1 variant 2 | | HR |
| x7 raw INSERT: a copy of a committed token under a new request id | 535 | 668 | effects []; refused: request id is not the signed one | v1: refused write; unchanged; effects []; nothing refused | h_settled_bi aborts | HR |
| x7 ... ; variant 2 | new | 670 | (none) | as x1 variant 2 | writer also turns CHECKs off (CHECK request_id = token request id) | HR |
| option: single-use on: another transition for a pre-state that has a signed token | 589 | 726 | no token | depends on constant SINGLE_USE_RULE (line 33). per-pre-state: no token (merged). per-request: a token that verifies (branch proposal; SET) | B-15: the merged rule freezes a charge (C-ATT-03); the branch minter keys on (charge id, request id) | OD (OWNER DECISION PENDING) |
| option: another transition for a request id that has a signed token (same pre-state) | new | 732 | (none) | no token (holds under both readings: P-idem) | gives the option group a check that the memory rule is on | OD (added with B-15) |
| report: counts.known_limit_rows, owner_decisions_pending | new | 751, 753 | (none) | extra report fields | makes KNOWN-LIMIT rows and B-15 visible in report.json | IA |

Already on the branch before this diff (h-sink, not mine; listed for the owner): `world()` gives the sink config
`initialState` and the dispatcher config `newLedgerH0` (line 251 area); the "no stored state" row gives `initialState` (401). IA.

## Callers
| file | change | reason | class |
|---|---|---|---|
| tests/demo-gauntlet/sink_tool.ts | h-dispatch unapplied/sink_tool-C-HOST-06.diff applied unchanged: refuse a config without initialState; never take the anchor from the command line | evaluated: correct; the h1 Sink needs cfg.initialState; init checks the argument against it | IA |
| scripts/demo_gauntlet.py | config gets `initialState` = the demo charge; issuer gets a module built from impl/finality-core/IssueOnce.dfy (new `compile_issuer_core`; its SHA-256 goes into the act-2 record as `issuer_module_sha256`) | without both the demo stops: h1 sink refuses the config; the branch minter refuses a module without IssueOnce | IA |
| scripts/exit_m1_conformance.py | the issuer gets an IssueOnce module (`issuer_core`, compiled once per run, verified); the driver keeps the record-pinned RefundFinality module; SLICE1 inputs list IssueOnce.dfy, IssueBytes2.dfy, SerModel.dfy; result has `issuer_core` | same minter refusal | IA |
| scripts/exit_slice1.py | NO change needed (it already builds IssueOnce and does not pin row counts) | | |
| commit_cli.ts, dispatch_cli.ts | NO change needed (suite reads status, reason, onTime, emitted, stopped: all still present) | | |

## KNOWN-LIMIT rule (proposal)
A variant-2 row whose change passes the sink restart, the halt and the dispatcher audit gets the observed prefix
`KNOWN-LIMIT (recomputed chain, no outside head)` and `pass = false`. So the suite FAILS (exit 1) rather than counting a
stated limit as a passed safety claim. `counts.known_limit_rows` counts them. If the owner wants such rows to not block
EXIT, the honest option is a separate control class "limit" excluded from `failed` but reported, decided by the owner.
In this run no row landed there (0).
