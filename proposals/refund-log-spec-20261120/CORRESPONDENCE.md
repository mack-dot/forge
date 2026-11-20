# Correspondence: the proposed refund-log specification and the silicon sink today

SPECIFICATION PROPOSAL. NOT approved. `end_to_end=false`. This table compares TEXT with TEXT. I read
`src/silicon_sink/sink.rs` (248 lines, unchanged, at `main` `b1c98822`). I ran no engine, no test and
no proof about the engine. "Implements" in a row means: the code line does this when I read it. It
does not mean: proved, or tested by me.

Files: `RefundLogSpec.dfy` (the specification, "spec" below), `RefundLogSpecLemmas.dfy` (the
lemmas), `sink.rs` = `src/silicon_sink/sink.rs`, `RefundSpec` = `spec/refund/RefundSpec.dfy`
(approved, `90a21c71…`, unchanged).

## 1. Clause by clause

| # | Clause in plain words | Spec (line) | `sink.rs` today (line) | Gap |
| --- | --- | --- | --- | --- |
| C1 | The approved stateless rule is reused, not copied. | `import R : RefundSpec` (12); first line of the file | The sink has no Dafny text. Its native checks transcribe the rule by hand (163, 167, 168, 171) | None in the spec. The sink's transcription is not proved |
| C2 | The state of one charge: charge id, original amount, remaining amount, refund flag, settled ids, epoch. | `LedgerState` (15-21) | `Ledger` (77-79): `charge`, `original`, `remaining`, `epoch`, `ids`. Also `tail`, `effects`, `len` | G2: the sink has NO refund flag. `tail`, `effects`, `len` are integrity and bookkeeping fields; the spec leaves them out on purpose |
| C3 | Genesis: the full amount remains, no id is settled, epoch 0. A well-formed state has a non-empty charge id, `0 <= original <= MaxMoney` and `0 <= remaining <= original`. | `Genesis` (29-32), `WellFormed` (35-38), `ValidGenesis` (40-43) | `init` (220-232) writes kind `'G'`, epoch 0, pre-hash 0, the charge id and the original amount; `scan` reads it (90-91): `amount <= MAX_MONEY`, canonical id (88) | The genesis record holds no refund flag (G2). The sink's ids are stricter: 1 to 24 bytes of `[A-Za-z0-9_-]` (56). The spec allows every non-empty string. That direction refuses more, so it is a completeness question, not a safety question |
| C4 | `requestOpen` is read from the state: the request id is not settled. | `RequestOpen` (46-49) | The stored meaning: `commit` refuses a settled id (167, `DUPLICATE_REQUEST_ID`); `scan` stops at a repeated id (92, `l.ids.insert`) | G1: the BIT that the binary receives is chosen by the caller. `parse` checks only its spelling (133: `True` or `False`). The native check at 167 restores the meaning after the binary answers |
| C5 | `refundEnabled` is read from the state: a bit of the charge, fixed at genesis (OWNER DECISION D1, option B proposed). | `RefundEnabled` (52-55); field (19) | NOT read. The caller's bit is checked for spelling only (133). No stored counterpart | G2: the sink has no stored flag and never refuses for it. If the caller sends `False`, the binary rejects (test `tests/silicon_sink/test_silicon_crash.py:295`, read, not run by me). So a `False` bit can only cause a refusal; a disabled charge cannot be stated |
| C6 | Allowed = the approved `Eligible` on the context built from the state and the request. Nothing is added; nothing is removed. | `ContextAt` (58-62), `Allowed` (64-67) | Conjunct by conjunct, the native checks after the binary: reason (163), id fresh (167), charge, original and remaining equal to the stored state (168), `amount <= remaining` (171); amount is `u64` from canonical digits (58-61), so `0 <= amount`; ids non-empty (56, 136) | G3, call order: `handle` asks the binary (192) BEFORE `commit` takes the lock (166). The binary sees the caller's state and flags, not the stored ones. Safety does not rest on the binary's answer, because the checks at 163-171 run under the lock. The binary decides only completeness |
| C7 | Effect: remaining decreases by exactly the amount, the id joins the settled set, the epoch advances by one, nothing else changes. | `Effect` (71-77) | `commit` writes `encode(kind, l.epoch + 1, l.tail, request, amount)` (172). `scan` applies it: `remaining -= amount` (93), `ids.insert` (92), `epoch = i` (96); charge and original are set only at index 0 (91) | No gap in the fold as read. The record also carries a reason kind (172) and a pre-hash; the spec state keeps no reason. The reason is checked (C6), not stored in the state |
| C8 | One decision per request: the post-state if allowed, else no change and no effect. The specified method has no other freedom. | `DecidePost` (80-84), `Decide` (86-88) | Every refusal returns before the write (163-171); OUTCOME_UNKNOWN (181, 184) is the one refusal after which a record may stay | OUTCOME_UNKNOWN and crashes are out of scope (section 2). A record that stays is judged by the fold like any other record |
| C9 | The fold step: `Some(post)` exactly when Allowed, with the Effect (lemma `StepIsDecidePost`). | `Step` (90-95) | The body of the loop in `scan` (84-97), after the framing checks (87-88) | `scan` mixes framing (magic, CRC, epoch, pre-hash, id padding) with the rule. The spec has only the rule. Format F (the 64-byte record, lines 7-11) maps bytes to `RefundRequest`; F is NOT in this proposal (Task V1 writes it; Report D, decision (c)) |
| C10 | A history is valid when the genesis is valid and every record is allowed at its pre-state, in log order. Decidable by a fold. | `Replay` (98-106), `ValidHistory` (109-112) | `scan` (82-100) folds the WAL. It STOPS at the first record that fails (95) and keeps the prefix. The rest is a torn tail if it is at most 64 bytes (98), else `CORRUPT_WAL` | G4: the sink never reports "this record breaks the rule". A failing last record is cut by `open_ledger` (119-121) or, if the ratchet already names its epoch, refused with `EPOCH_REGRESSION` (118). A verifier against `ValidHistory` reports it as a violation (Report F, task V1) |
| C11 | At most once: no request id is in two records of a valid history. | `AtMostOnce` (115-118); proved: `AtMostOnceHolds`, `RepeatedIdIsRefused` | 167 (commit) and 92 (scan stops) | None as read. Report D notes that "one record per id in `Scan(W)`" is true by construction of `scan` (92); the spec states it over the log, not over `scan`'s output |
| C12 | Conservation: `original == remaining + sum(amounts)`, `0 <= remaining <= original`; the settled set is the set of the ids of the log, one per record; epoch = number of records. | `SumAmounts` (121-125), `Ids` (127-131), `Conserves` (134-140); proved: `Conservation`, `ReplayInvariant` | `u64` subtraction guarded by `amount <= remaining` (92, 171). No explicit sum is kept or checked | None as read; the sink has no sum check, and the spec does not need one: it follows from the fold (lemma) |
| C13 | Epoch: genesis 0, plus one per committed refund. | field (21), `Effect` (74), `Conserves` (139) | record epoch must equal its index (87); commit writes `l.epoch + 1` (172); ratchet (101-104, 112-118) | The ratchet guards rollback; rollback is out of scope (section 2) |
| C14 | Zero amounts are allowed (OWNER DECISION D2; default: keep the approved rule). | no extra conjunct in `Allowed`; proved: `ZeroAmountIsAllowed` | `money("0")` is canonical (59); 171 allows 0; test "zero on an empty charge" expects COMMITTED (`test_silicon_crash.py:340`, read, not run) | None. Zero-amount refunds with fresh ids each commit and each settle an id |

## 2. What the specification leaves out on purpose, and why

Each item is a hypothesis of theorem D-1 or D-2 in `proposals/assurance-chain-20261120/REPORT_D_MINIMAL_THEOREM.md`,
or a separate later step. Putting it in this specification would make the text larger and would not
make the safety statement about a log stronger.

| Left out | Why | Where it is handled |
| --- | --- | --- |
| Crashes, torn writes, recovery | The spec judges the committed log. A crash model is a statement about the engine (D-2, M-g) | `sink.rs` 119-121, 179-181; Report D, D-2 C2, H_STORE |
| Durability (`sync_all`, the drive) | A property of the store and hardware, not of the authorization | H_STORE (D-2); `sink.rs` 14 says the kernel and drive are assumptions |
| Rollback, restore of both files, forks | The fold cannot see a log that was cut back to an earlier valid prefix. This needs a witness or an anchor | H_LOG.1, H_LOG.2 (D-1); tasks V2, V3 |
| The external payment effect | The spec says which effects are authorized. What the provider did is outside | H_LOG.3 (D-1); task V4 |
| More than one charge per store | Each silicon store holds one charge (`sink.rs` 3). A multi-charge store needs keys per charge and a new state | D-1 "does NOT give": properties across charges |
| Who sent the request | The record has no requester field | Report D, D-1 "does NOT give" (A9.7) |
| Format F (bytes to records), CRC-32, FNV-1a-128 | A mapping and integrity checks, not authorization. F is an owner decision of its own | Task V1 (`RecordFormat.dfy`), Report D decision (c) |
| The CAS fields of a request (`tail`, claimed original and remaining) | A concurrency guard: "the request names the present state". In the spec, the pre-state IS the present state | `sink.rs` 168 |
| The third flag of the wire request | `RefundSpec.Context` has two flags. The sink's wire has three (133). Report D names the third `Grammar(q)`; I did not re-check its meaning in the binary | open; see `unsure.md` U924 |
| Liveness, timeouts | Not a property of a log | protocol.md (Stage 8) |

## 3. Owner decisions in this text

- D1 `refundEnabled` (see README, options A to E). Proposed: B, a stored bit fixed at genesis.
- D2 zero amounts. Proposed: keep the approved rule (zero allowed).
- D3 where the files go and the lock name (see `RATIFICATION_DIFF.md`).
