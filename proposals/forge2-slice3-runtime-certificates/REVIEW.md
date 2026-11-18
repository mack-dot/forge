# Slice 3 — the one fresh-context adversarial review (text and disposition)

Date: 2026-11-18. One review by a separate agent with a new context. Its
task: find defects in the unproved code of this slice, with
reproductions. It got the code and the questions, not the author's
conclusions. It did not change the repository.

The reviewer's text is below, word for word, with two changes: the
repository folder is written `<repository>` and the reviewer's scratch
folder is written `<review scratch folder>`. Its line numbers are those
of the files BEFORE the repairs. Its probe files are not in the
repository. The folder that the text names `clearing/certificate/` is
now `certificate/` (moved after the review; paths only).

## Disposition (by the build agent; one repair pass; NOT reviewed again)

Rule of the owner (text D): repair confirmed FAIL-OPEN, HIGH and MEDIUM
findings in one pass; leave LOW items with an honest statement.

| Finding | Severity | Disposition |
| --- | --- | --- |
| R1: an optimizer process, as the same user, writes the sink database behind the sink | HIGH | REPAIRED, with a trusted tool: the runner starts every optimizer under the macOS sandbox tool with a profile that denies file writes, network use, signals and the task port of other processes. New control row (a write now, and a write by a detached process later: no file). The sink configuration now pins the hash of the first board; `init` takes no other board and the audit starts there. The trusted-base text says that the sandbox is trusted and not proved. NOT done: "look at the effects after all descendants are dead" (the sandbox denies the writes). Reading files stays allowed. |
| R2: the 15 adversary runs pass when the adversary does not run | HIGH | REPAIRED: for every adversary mode the EXIT script pins the counts (lines, proposals not feasible, not readable, forged offers) and the two texts of every row (line of the optimizer, answer of the issuer side). A copy of the EXIT script with a missing adversary program now fails. |
| R3: one optimizer line makes the issuer client wait for ever | MEDIUM | REPAIRED: the client refuses a message above the line limit of the issuer itself, and no request waits longer than 30 seconds. New control row and a new adversary mode in the swap (`control-bytes`). |
| R4: the runner kills only the direct child | MEDIUM | REPAIRED: the optimizer gets its own process group; the runner kills the group and closes its streams. New control row (no process of the optimizer is left). Stated: this is housekeeping, not containment. |
| R5: evidence from the object under test; fields that cannot fail | MEDIUM | REPAIRED: the suite, the swap run and the EXIT script compute the checker id and the specification id again from the files and compare. Claim Z1 now says what is checked (commands of the EXIT script, bytes of the compiled core, proof inputs, ids); it no longer says "no start of Dafny". The constant field is removed; claim R1 says what is observed and what is only read. The specification id is described as a label. |
| R6: the audit misses three kinds of wrong database; few audit rows | LOW to MEDIUM | REPAIRED IN PART: pin of the first board (finding 2a now reported); the audit answers for a sink with no board; four new audit rows. NOT repaired, stated in `sink.ts` and in the report: a database that is set back as a whole to an earlier state of its own chain (shown as a row of the suite: the audit does not see it), and a waiting batch that is changed before its commit (intake is trusted). |
| R7: a token is not bound to one sink; a stale token is valid again when the board returns to an old value | LOW | NOT repaired. Stated limit. |
| R8: no sign rule: needs, capacities and values below zero pass | LOW | NOT repaired. Stated: the proof holds for all integers; a need below zero makes capacity grow. |
| R9: an honest proposal with numbers above 18 digits in the token is refused with a misleading reason | LOW | Wording repaired (reason text and comment). Behavior unchanged: it is refused. |
| R10: the recorded rows cannot find a conversion that loses precision | LOW | One row added (values of 17 digits that differ by 1, gaps 0 and 1). A copy of the issuer that converts through floating point now fails. |
| R11: the issuer holds unread answers in memory | LOW | NOT repaired. Only the trusted caller can do this. |
| R12: loose or dead controls | LOW | In part: reason pinned for the changed signature; a wrong core with a wrong request id added; the sink copies its configuration by value; a second first board is refused; the swap run checks the reason of every refusal and that the issuer is in service at the end. NOT changed: the row with 20000 characters; effects are read through the sink's own accessors. |
| Sentences that say more than the code supports | — | Corrected in `exit_slice3.py`, `sink.ts`, `guest.ts`, `swap.ts`, `suite.ts`, `issuer.ts`, `encoding.ts`, `reference.ts`, the two optimizer headers, the bridge file and one fixture header. The reviewer's words on how little the bridge lemma says are now in that file and in the report. |

After the repairs: every EXIT case ran again (actual exits in
[REPORT.md](REPORT.md) section 7), and the removed-check copies ran
again with the reviewer's cases added.

## The reviewer's text

```text
ADVERSARIAL REVIEW OF SLICE 3 (branch slice3/runtime-certificates). Repository not changed. All probes are in S = <review scratch folder>/ . Every probe runs as: cd <repository> && PATH=/opt/homebrew/bin:$PATH node --import tsx <file> [args].

FAIL-OPEN in Sink.commit or in the issuer's signing: NONE FOUND. Effort: 60000 mutated token texts against the real sink (0 not rejected, database byte-equal, read by an independent reader); 6000 differential cases through the real issuer process against reference.ts and against my own BigInt check written from the Dafny text (0 differences, 81 tokens with values above 15 digits, 841 cases one basis point below the least gap); about 40 targeted cases. Two HIGH findings are outside commit(): one is an effect with no token by a path that the stated assumptions exclude but nothing enforces; one is an EXIT verdict that passes with no adversary.

## 1. Findings

R1. HIGH. An optimizer process can change the board with no token; the run reports PASS; audit() reports nothing.
- Where: ts/booking-certificate/guest.ts:23 (spawn as the same user, cwd = repository root, no isolation); claim at scripts/exit_slice3.py:187-188 ("It cannot make the sink take an allocation without a token"); ts/booking-certificate/sink.ts:142 (audit takes the first board hash from the same database).
- This is not a defect of commit(). The assumption "database file writable only by the sink" (sink.ts:15-16) is listed. The runner is the code that breaks it for the process it starts. The three shipped optimizers do not do this.
- Reproduction (OBSERVED): S/guest_same_user.py reads its parent's command line with `ps`, answers one harmless line, and leaves a detached process that after 3 s writes `state` and `meta` in the sink databases. Command: `node --import tsx tests/booking-certificate/swap.ts $S/swap-sameuser build/slice3/sink-controls/attempt-0001/core/model.cjs sameuser 2 20000 python3 $S/guest_same_user.py` then `node --import tsx $S/p5_after.ts $S/swap-sameuser`.
- Output: `swap.ts exit 0`; `report: failed 0 ; rows pass: [True, True] ; effects: [0, 0]`; `database 0 after the run: board {"capacity":["777","777","777","777"]} ; settled rows 0 ; outbox rows 0 ; audit(): []` (same for database 1).
- The same access reaches the repository files, the compiled core in build/, and signals to the issuer (READ).
- Smallest repair: (a) say in TRUSTED_BASE that an optimizer process is trusted not to touch the sink files, the repository and the issuer process, OR isolate it (other user or sandbox, no write access); (b) put the first board hash into SinkConfig so that audit() has a pin outside the database; (c) take the "effects" look after all descendants of the optimizer are dead.

R2. HIGH (EXIT verdict passes without the test it names). The 15 adversary runs of `swap` pass when the adversary does not run.
- Where: scripts/exit_slice3.py:493-495 (only tokens == 0, committed == 0, no_token == batches); the comment at :106-107 states "70 lines" but no check enforces it; tests/booking-certificate/swap.ts:61-76 and :97-111 (a row with no answer has no problem).
- Reproduction (OBSERVED, real function): `python3 -B $S/p9_real_swap.py $S/<new folder>` imports the real scripts/exit_slice3.py, calls the real swap() with the recorded core and Rust binary, and changes one thing: the adversary file name does not exist.
- Output: `swap() RETURNED WITHOUT A FAILURE`; v1 and v2 as pinned; every `v3-*` line: `answers 0 tokens 0 committed 0 forged offers 0`. The recorded real run has answers 70 and forged offers 70 for the same modes.
- Also OBSERVED directly: swap.ts with `python3 guests/booking/no_such_adversary.py overbook` exits 0; with interpreter `python3-not-installed` exits 0.
- Smallest repair: pin per mode in EXPECT_SWAP the counts answers, proposals_not_feasible, proposals_not_readable, forged_offers, and for the limit modes the row text ("line too long", "no line", "time limit"). Require the issuer reason to be in a known set.

R3. MEDIUM. One optimizer line makes the issuer client wait for ever (swap.ts hangs, EXIT hangs: subprocess.run has no time limit).
- Where: guest.ts:13 (16384 bytes allowed), guest.ts:76-79 (no time limit, no handling of an answer with id null), issuer.ts:94 and :101-103 (65536 byte limit, answer with id null). JSON escaping makes a control character 6 bytes: 16384 x 6 > 65536. With a large batch (47 kB observed for 32 x 64) plain `"` characters are enough.
- Reproduction (OBSERVED): S/guest_ctrl.py writes 16000 bytes 0x01 and a line end. `perl -e 'alarm 25; exec @ARGV' -- node --import tsx tests/booking-certificate/swap.ts $S/swap-ctrl <core> ctrl 1 20000 python3 $S/guest_ctrl.py` was killed by the alarm after 25 s; no report.json. Probe S/p1_issuer.ts case f1: `NO ANSWER FOR THIS ID AFTER 4 s ; new id-null answers: [{"id":null,"ok":false,"reason":"message too long"}]`.
- Smallest repair: in IssuerClient.send, refuse locally when the message is above the issuer limit; add a time limit per request; treat an id-null answer as the end of the oldest waiting request or as a fatal error. Or raise MAX_LINE_BYTES above the worst case (about 160 kB).

R4. MEDIUM. The runner kills only the direct child. Descendants live on and keep the runner process alive.
- Where: guest.ts:24-29 (kill of one pid, streams not destroyed), :33-40.
- Reproduction (OBSERVED): S/p4_runner.ts. Case 2 (`sh -c "yes A... | tr -d '\n'"`): answer "line too long" at 1.1 s, but `yes` and `tr` stayed (PPID 1) and the probe process did not exit; it exited at 138.7 s, 2 s after I killed the two orphans. Case 1: grandchild `sleep 9.123` alive after the time-limit kill. Through swap.ts: S/guest_holder.sh 12 gives exit after 13 s (baseline 0 s) with the line already taken.
- Smallest repair: in finish(): `child.stdout.destroy(); child.stdin.destroy(); child.unref()`; spawn with `detached: true` and kill the process group. Say that this is not containment (a child can leave the group).

R5. MEDIUM. Evidence taken from the object under test, and fields that cannot fail.
- exit_slice3.py:499-502: `dafny_starts` counts the commands that this script started in the loop. All are `node ... swap.ts`. The check cannot fail unless the loop is edited. Children of swap.ts are not observed. Z1 (:148-149) and the report line (:567) say "no start of Dafny". The real checks are the module digest (:486) and the proof input snapshot (:503).
- exit_slice3.py:556-557: `'each_with_a_token_of_the_compiled_core': True` is a constant.
- suite.ts:56-57 and swap.ts:46-47: the sink pins come from `issuer.ready`. exit_slice3.py:488-489 only compares ids between runs. Nothing recomputes the checker id or the specification id from the files. OBSERVED today they are right (S/p3_sink.ts line 0: both `true`).
- The specification id is a label: issuer.ts:30 hashes any two files of its command line. OBSERVED (S/p7_label.ts): the same core started with BookingCertificateSpecLoose.dfy and package.json reports another spec id, the same checker id, issues a token, and a sink that pins that report commits it.
- Smallest repair: recompute both ids in suite.ts, swap.ts and the EXIT script from file digests and require equality; reword Z1 to what is checked; drop or rename the constant.

R6. LOW to MEDIUM. audit() misses three kinds of wrong database, and most audit branches have no control.
- Where: sink.ts:139-168; controls only at suite.ts:322-338 (2 rows: board, outbox text).
- OBSERVED (S/p3_sink.ts): 2a board and meta row changed before the first commit: `audit: []`. 2b last settled row and outbox row removed and board set back: `audit: []`; then `the SAME second token again: committed ; outbox seq numbers: [1,3] ; audit: []`. 2c waiting batch changed (values 5,7 to 500,700): token for the changed batch commits, `audit: []`. 3a `audit()` of a sink with no board THROWS.
- No control for: a changed settled token, request id, ids, gap, signature, batch, a break in the middle of the chain, outbox length.
- Smallest repair: pin of the first board hash in SinkConfig; return a problem in place of the throw; add raw-change rows for each audit branch; state the three limits in the comment.

R7. LOW. A token is not bound to one sink. A stale token becomes valid again when the board returns to an old value.
- Where: encoding.ts:21-25 (no sink or board identity), sink.ts:107-124.
- OBSERVED (S/p3_sink.ts): case 1 `one token offered to two sinks ...: committed / committed`; case 5 old token a: stale, then `committed` after a batch with need -1 gave the capacity back.
- Repair: a sink id (or first board hash) in the board hash or in the token body, if more than one sink can pin one issuer key.

R8. LOW. No sign rule anywhere. Needs, capacities and values below zero pass intake, the specification and the core.
- Where: encoding.ts:32 (INT allows a minus sign), BookingCertificateSpec.dfy:5-6, sink.ts:44 and :58.
- OBSERVED (S/p1_issuer.ts): `b2. capacity 1, need -5 (capacity grows) => TOKEN ... "post":{"capacity":["6"]}`; b1 capacity -1 with need -1 gives a token. The corpus has 0 negative entries.
- Repair: refuse negative needs and capacities in isBoard and isBatch, or state that they are allowed.

R9. LOW. Honest input is refused with a misleading reason when the value or a remaining capacity leaves 18 digits.
- Where: issuer.ts:58-60 with encoding.ts:32. OBSERVED: two requests of value 10^18-1, both booked, optimal certificate: `no token: conversion: token`; 30 of 6000 fuzz cases. Fail-closed. The comment at issuer.ts:56-57 says this means a conversion defect.
- Repair: a wider pattern for value and post, or a lower input bound, and a true reason text.

R10. LOW. The recorded rows cannot find a conversion that loses precision.
- OBSERVED (S/p0_corpus.ts): `maxDigits: 2, negativeEntries: 0, maxRequests: 14`. The suite has no accepted proposal with a value above 7. A `Number()` in issuer.ts would pass every row. The present code is right (my 6000 cases).
- Repair: rows at 17-18 digits with a gap pair alpha and alpha-1.

R11. LOW. The issuer holds unread answers in memory (no backpressure): issuer.ts:84-86, :96-113. OBSERVED (S/p6_flood.ts): RSS 81 MB to 446 MB after 10 MB of empty lines with no reader. Only the trusted caller can do this. 10 odd lines (60000-deep nesting, id 1e400, bad UTF-8) gave 10 answers and no crash.

R12. LOW. Loose or dead controls (READ).
- suite.ts:208: "a text of 20000 characters" gives "token shape" with or without the length check at sink.ts:88.
- suite.ts:207: no reason pinned.
- suite.ts:70-78 and swap.ts:53-57: effects are read through the sink's own accessors and do not cover the tables batches and meta.
- swap.ts:74-76: if the issuer dies during the last batch of an adversary run, the row passes with "no token: token issuer process ended".
- No wrong-core fixture puts a wrong request id into the token.
- sink.ts:31: the SinkConfig object is kept by reference; a later change of `maxAlphaBps` by the caller is not checked.
- sink.ts:44-55: a second init with another board gives no error (OBSERVED 3b).
- Note: build/slice3/sink-controls/attempt-0001 holds 93 rows; the present suite gives 94 (the record is older than suite.ts).

## 2. Attacks that did NOT work
- OBSERVED: 60000 mutated token texts (byte changes, splices from 3 other real tokens, field swaps with canonical text kept), before and after the commit: all rejected, database unchanged.
- OBSERVED: String object, Buffer, array, text + line end, `1` escape, gap "00", duplicate body key, duplicate signature key, NUL, BOM: all rejected.
- OBSERVED: tokens for another board, another request id, a gap above the largest gap: rejected with the right reason; replay gives "replayed".
- OBSERVED: request ids "1", "01", "1.0", "1e0", "0x1", "a", "A", "-1", "001", "1.": no aliasing in SQLite (11 of 11 separate).
- OBSERVED: sink with a batch and no board: rejected, 0 rows.
- OBSERVED: largest gap NaN, 1.5, -1, "2000", null, undefined, 10001, Infinity: constructor refuses.
- OBSERVED: issuer against my own check, 6000 cases with 18-digit and negative numbers, wrong lengths, gaps -1, 10001, 10^18-1: 0 differences, 0 wrong token bodies, 0 unmatched answers.
- OBSERVED: proposal with duplicate key (last one is judged and bound), `__proto__` key, nesting 16000, BOM, "-0": no wrong token.
- OBSERVED: 32 x 64 problem: 13 ms; token text 955 characters.
- OBSERVED: runner: endless bytes with no line end ("line too long", RSS 116 MB), bytes FF FE 00 CR (one line, replacement characters, second line dropped), 16384 bytes taken and 16385 refused, child that closes its output ("time limit"), child that does not read a 300 kB input (answer taken).
- OBSERVED: one Dafny job. The "check written out" fixture text with the missing part put back verifies (`52 verified, 0 errors`, exit 0, S/dafny/CoreFullCheckWrittenOut.dfy). So that fixture family is refused for the planted reason.
- OBSERVED: no `assume`, `{:axiom}`, `expect`, `{:extern}`, `{:verify false}`, `decreases *`, bodiless member in the Slice 3 Dafny files or BookingDualCert.dfy (grep; only `{:isolate_assertions}` in impl/Booking.dfy). Reused files equal HEAD (git diff empty).
- OBSERVED: recorded report.json files hold no key, signature, path or time. The compiled module has the same SHA-256 in three builds and holds no path.
- OBSERVED: the existing suite runs: exit 0, 94 rows, 0 failed.
- READ: reference.ts equals the Dafny text of Accepts. Accepts implies feasibility and the bound for every 0/1 alternative (lemma Quality, weak duality, no sign assumption needed). IssueIsNearOptimal has satisfiable preconditions (IssueWitnesses). `remaining` is c - A x for the caller's c.
- READ: framing code in issuer.ts (one answer per line, drop state correct); no path gives a signature without `is_Issue === true`; token fields come from the core result; no cross-protocol reuse with refund tokens (other domain text inside the signed bytes, other key set).
- READ: compiled Decide and Accepts (model.cjs:1199-1347): loops, no deep recursion, `0 <= alphaBps` tested before the nat parameter.

## 3. Sentences that say more than the code supports
- scripts/exit_slice3.py:187-188 "It cannot make the sink take an allocation without a token." True only for an optimizer that uses the line protocol alone (R1).
- scripts/exit_slice3.py:18-19, :148-149, :567 "0 starts of Dafny between them". Counted over this script's own commands (R5).
- scripts/exit_slice3.py:143-144 (R1 claim) "a token that the issuer made after the compiled core accepted". No run observes this; it follows from issuer.ts by reading. :556-557 is a constant.
- scripts/exit_slice3.py:106-107 "'answers' of the adversary: 70 lines". Not checked (R2).
- ts/booking-certificate/sink.ts:6 "if and only if". The "if" side fails on a transaction error; the "only if" side holds for commit() only.
- ts/booking-certificate/sink.ts:135-138 "one chain from the initial board". The first board hash is read from the same database (R6).
- ts/booking-certificate/guest.ts:4-6 "with a byte limit and a time limit". The time limit ends the wait for the line. It does not end the process tree or let the runner exit (R4).
- tests/booking-certificate/swap.ts:1 and :123, guests/booking/v1_baseline.ts:2, ts/booking-certificate/issuer.ts:41 "the proved checker / proved core". What runs is compiled JavaScript of a core proved at source level against a CANDIDATE specification (`source_to_module_proved: False`, exit_slice3.py:415). The :123 text goes into the bundle.
- ts/booking-certificate/encoding.ts:85 "Identity of the claim text". It is the hash of two files named on the issuer's command line; no link to the compiled core (R5).
- ts/booking-certificate/issuer.ts:56-57 "a difference here means that a conversion in this file is wrong". Also fires for honest large values (R9).
- tests/booking-certificate/fixtures/CoreHaltsAtRunTime.dfy:1 "issues a token for every proposal". It halts at run time for a proposal that is not accepted.
- clearing/certificate/BookingBridge.dfy:1-7 and exit_slice3.py:140-142 (Q6): accurate, but it is very little. Each slot must have the capacity exactly 1, so the lemma does not apply to a second batch on the same board. It needs only Feasible; prices, values and gap play no part. It says nothing about Decide, a token, the sink, or bookings made before the batch. `ActiveOf` is a map that the bridge defines itself.
- tests/booking-certificate/suite.ts:5 "The report has no key, signature...". True for report.json. The same folder gets race-config.json (public key) and race-*.token (signatures).
- tests/booking-certificate/reference.ts:3-4 "A difference ... is found by the rows that use it". Only for values up to 2 digits and no negative entry (R10).

## 4. Not looked at
- ROADMAP.md, unsure.md, proposals/forge2-slice3-runtime-certificates/ (not read).
- EXIT cases core-proof, core-controls, clearing, sink-controls, evidence: not run. I ran the real swap() once in my scratch folder and one own Dafny job.
- The logic of v2_fast.rs and solvers.ts (imports only); impl/Ledger.dfy, LedgerSpec.dfy; gate/ beyond the file heads; tsc type check.
- Linux behaviour; key theft through operating-system debugging; timing channels; a two-process stress beyond the suite's race row; mutation of the unproved code (the main loop runs that).
```
