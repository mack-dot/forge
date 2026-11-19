# Provider anchor 2: attack x defence layer at 370ff65c (h-provider2, 2026-11-19)

Status: TESTED-UNPROVED. FAKE provider only; no real provider contacted. Nothing here is proved. Cell = first layer
that refused after the attack began, with the exit code (0 SAFE, 1 NOT STOPPED, 2 CONTROL DOES NOT BITE). Logs:
logs/matrix1/<test>[_<case>]_<anchor>_<mode>.log; summary logs/matrix1/SUMMARY.tsv (200 cells; its swap gate failed
open: sysctl not in PATH). The gated re-run logs/matrix2 stopped at swap 1006 MiB after 9 cells, all equal to matrix1.
Modes: a key, b key+ceiling,
c none (control), d-a / d-b = a / b after the key retention window. Anchors: none; floor = dispatcher cfg.ledgerFloor;
head = sink cfg.outsideHead + onHead (freshness rule) + dispatcher cfg.expectedHead; full = floor + head.

## 1. Table (full restore = every local file restored: store, ledger, dispatch witness, adapter journal)
| attack (regression) | none: a / b / c / d-a / d-b | floor | head | full |
|---|---|---|---|---|
| full restore, ledger lagged the store at backup (p_full_ledger_lag) | key 0 / key 0 / NOT 1 / NOT 1 / NOT 1 (r3 twice, ceiling refused r2) | floor 0 (all modes) | as none (head does NOT see it) | floor 0 |
| full restore, host retries same tokens (p_full_restore_retry) | key 0 / key 0 / NOT 1 / NOT 1 / NOT 1 (r3 twice) | floor 0 | outside head 0 | outside head 0 |
| full restore, NEW id on stale balance = overpay (p_full_restore_new_ids) | NOT 1 (1500) / ceiling 0 / NOT 1 / NOT 1 / ceiling 0 | floor 0 | outside head 0 | outside head 0 |
| full restore, same id other amount (p_full_param_rebind) | key 0 / key 0 / NOT 1 / NOT 1 / ceiling 0 | floor 0 | outside head 0 | outside head 0 |
| C-ATT-28, ledger lost, newLedgerH0 left set (p_att28 ledger) | witness 0 / 0 / 2 / 0 / 0 | witness 0 | witness 0 | witness 0 |
| C-ATT-28, ledger AND witness lost (p_att28 ledger+witness) | key 0 / key 0 / NOT 1 / NOT 1 / ceiling 0 | floor 0 | as none (head does NOT see it) | floor 0 |
| partial: ledger only (p_ledger_restore) | witness, c = 2 | - | - | witness 0 |
| partial: store+ledger, retry (p_db_restore_retry) | witness, c = 2 | - | - | outside head 0 |
| partial: store+ledger, new id (p_db_restore_new_ids) | witness, c = 2 | - | - | outside head 0 |
| partial: same id other amount (p_param_rebind) | witness, c = 2 | - | - | outside head 0 |
| second ledger path, with and without newLedgerH0 (p_second_ledger) | witness, c = 2 | - | - | witness 0 |
| timeout after money, operator re-sends later (p_timeout_retry) | key 0 / key 0 / NOT 1 / NOT 1 / ceiling 0 | - | - | same as none |
| positive: zero amounts + honest flow + restart (p_zero_amount) | PASS 0 in all 5 modes | - | - | PASS 0 |
| positive: crash before money, refusal (p_provider_faults) | PASS 0 in all 5 modes | - | - | PASS 0 |
"-" = NOT RUN (the full anchor was run; the single layers only for the full-restore and C-ATT-28 rows).
"ceiling" in d-b rows means the total stayed <= the charge AND no key moved twice in that run; in the ledger-lag and
retry rows d-b moved r3 (100) twice inside the charge: NOT STOPPED.

## 2. Layers and their exact assumptions
- dispatch witness (always on): APPEND-ATOMIC, LEDGER-TRUSTED, and the witness file is NOT restored or deleted together
  with the ledger. Stops partial restores, a second ledger path, and a lost ledger. Does nothing against a full restore
  or a lost witness (its removal is the documented step to bind a new ledger).
- ledger floor (cfg.ledgerFloor): LEDGER-FLOOR-OUTSIDE (the value lives off the restored medium, ANCHOR-OUTSIDE) and
  LEDGER-FLOOR-FRESH (the host stores result.ledgerHead after every run that returns). Stopped every full-restore row and
  C-ATT-28. Gap (argued from the code, NOT TESTED): a run that throws in emit returns no ledgerHead, so the floor stays
  one claim behind; a restore to exactly that point is not seen.
- outside head (sink outsideHead + dispatcher expectedHead): ANCHOR-OUTSIDE, ANCHOR-FRESH (freshness rule), SINGLE-WRITER.
  Stops every restore that lowers the STORE. Does NOT stop a restore where the store head is unchanged and only the
  ledger and witness are older (ledger lag), nor C-ATT-28 (store intact).
- provider key: PROVIDER-IDEMPOTENT-KEY, PROVIDER-PARAM-BINDING, PROVIDER-KEY-RETENTION(W) with the attack inside W,
  PROVIDER-DURABLE, ADAPTER-KEY = request id. Stops re-emits of a known id; never stops a NEW id (overpay row).
- provider ceiling: PROVIDER-CEILING (atomic check per charge). Bounds the total by the CHARGE, not by the local policy,
  and does not stop a duplicate that still fits (d-b rows with r3).
- claim rule (in doubt): appears after a provider refusal; it stops nothing by itself in these runs.

## 3. What a deployment must configure for rollback resistance of money movement
Both local anchors, kept off the restored medium and fresh: dispatcher cfg.ledgerFloor (updated from every result's
ledgerHead) AND sink cfg.outsideHead + onHead with the freshness rule, AND dispatcher cfg.expectedHead = committed. In
this matrix `full` was SAFE in every mode for every restore row, also with the control provider c. Without the floor,
the ledger-lag full restore and C-ATT-28 (ledger+witness) are open whenever the provider has no live key record.
A provider with key + ceiling is a second layer only inside the key window; it does not replace the anchors.
Never leave cfg.newLedgerH0 set after the first run; it does not matter when the witness or floor is present.

## 4. What stays unprotected
- The operator's manual re-send after a timeout (p_timeout_retry): the local anchors play no part; only the provider key
  (inside W) or the ceiling (if the duplicate exceeds the charge) stop it.
- An anchor that is not fresh, or that is restored together with the local files (ANCHOR-OUTSIDE broken): not tested.
- The local RECORD after a provider refusal (in doubt rows) still needs a person and the provider's refund list.
- A real provider's behaviour: every provider row rests on assumptions checked only against the fake.
