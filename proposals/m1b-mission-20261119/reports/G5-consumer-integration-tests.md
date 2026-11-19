# Step G5: consumer tests 7 to 14 with a thin harness over the existing M1 caller draft, issuer and sink (Z5, Opus; a finite test of a harness that is not product code)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Z5 report: consumer tests 7–14 for links X15 and X16

**Scope.** This is a finite TEST of a thin harness that is not product code. It proves nothing. It upgrades no link beyond TESTED-UNPROVED. M1-B stays OPEN, `end_to_end=false`, Stage 9 is deferred. I changed no repository file: the SHA-256 recheck of the 5 `ts/refund-finality/*.ts` files, `m1_fail_closed.py` and `frame.py` is OK. `TRACKER.md` was already marked M before I started. I ran no git write, no HOL, no Dafny and no build.

**Harness.** The harness composes the existing parts unchanged:
- the real sink: `sink.ts`, loaded from source by tsx.
- the real issuer: `minter.ts` with core `model.cjs` (SHA `e6d5f5e5…`, copied from Y6), single-use off. It is reached through a relay over a Unix socket.
- the pinned executable (SHA `b8ed5ec2…`), called through `m1_fail_closed.decide`.

The order is fixed:
1. Read the stored state.
2. Build ONE record and derive both inputs from it.
3. Guard G1: M1 fields == the M1 view of the issuer message.
4. Run M1. Ask the issuer only if M1 says AUTHORIZED.
5. Guard G2: M1 fields == the M1 view of the signed token body; M1's echoed amount and reason == the token intent; the pre-state hash == SHA-256 of the stored blob.
6. Commit to the sink.

**Field mapping** (M1 ← record → issuer):
- `charge`, `request`, `reason`: M1 gets UTF-8 bytes. The issuer gets Unicode text: at most 256 UTF-16 code units, no U+0000, no lone surrogate. M1 has no length limit.
- `original`, `remaining`, `amount`: M1 gets integers. The issuer gets decimal text matching `0|[1-9][0-9]{0,18}`. The issuer's post-state remaining is computed as remaining − amount.
- `enabled` ↔ `refundEnabled`.
- `opened` and `candidate` exist ONLY on the M1 side. `Check` fixes the request as open and the response as a candidate.
- Only on the issuer side: the pre-state hash, `post`, `intent` and the signature.

**Findings**
1. **Test 7.**
   - Correct harness, stale `remaining` for M1: G1 stops it before M1 runs.
   - The AND alone (the two-source variant): M1 says AUTHORIZED, the issuer answers `core: Refuse`. No token.
   - 7b, one source with a commit between the read and our commit: M1 AUTHORIZED, `Check` issued a token, and the sink refused it ("stored state is not the token's pre-state"). So a token CAN exist for a stale state. Only the sink stops it.
   - 7c, the same values to both sides: M1 accepts a 257-character id and an id with U+0000. The issuer refuses both as `shape`. These are real disagreements. They are safe because both sides must accept.
2. **Test 8.** All 10 rows give no token, no commit, and the issuer is never asked. There are 8 planted results plus 2 real runs whose output I cut. In each row, `Check` alone accepted the same request.
3. **Test 9.** One token, committed once. A replay of it gives `replayed`. Remaining is 960 and the audit is empty. If the same request is sent again after the commit, M1 has no state, so it accepts again. The issuer then signs a NEW token on the new state. The sink refuses it ("already settled with another token").
4. **Test 10.** The correct harness refuses all 9 field differences at G1. The broken two-source harness commits on 6 of 9 (charge, request, reason, original, remaining, amount): the effect differs from what M1 checked. So the test catches it.
5. **Test 11.** SIGKILL after M1 and after signing: no commit and the store is consistent. After a restart, exactly one commit. SIGKILL after the commit, then a restart: the restart gets a new token, which the sink refuses. A restarted caller cannot learn "I already committed" from `replayed`. It must read the settled row.
6. **Test 12.** Zero amount: both sides accept and the sink commits outbox rows with amount 0. Remaining does not change, so the pre-state hash does not change. Several zero-amount requests on one state all commit, and a replay gives `replayed`.
7. **Test 13.** The executable accepts non-canonical wire text (`040`, `+40`, `01000`) and prints the canonical frame, which `decide` then AUTHORIZES. Safety depends on the caller building the wire. In `consumer.py` the only builder is `M.wire` (counted in the source). The strict parser refuses `040`, `+40`, ` 40`, `40.0` and `4e1` before M1 runs. With a careless `int()` reader and no guards, M1 accepts 40 and the issuer refuses `040`: no token.
8. **Test 14.** U+00E9, U+20AC, astral characters, CJK, quote and backslash, tab/LF/CR, U+0085/U+2028, 256 × é (512 bytes) and 128 astral characters all agree and commit. The executable echoed each one exactly as the D11 expected frame, because AUTHORIZED requires that match.
   - 129 astral characters: M1 accepts, the issuer refuses.
   - A lone surrogate: the harness refuses it.
   - Non-UTF-8 bytes (`\xe9`, `\xff\xfe`, `\x80`, a cut `\xc3`): M1 alone says AUTHORIZED, but the issuer has no form for them.
   - A Latin-1 encoder: G1 catches it. Without guards it commits after M1 checked other bytes.
9. **Negative controls** (each must fail at least one test):

| variant | tests failed | what fails |
|---|---|---|
| m1-alone | 7 | 7a: a token is issued for M1's view; the sink then refuses it. Also the 6 field rows of test 10 |
| exit0-alone | 8 | test 8 rows with exit status 0: a token and a commit |
| two-source | 6 | the 6 field rows of test 10 |
| latin1-noguard | 7 | 14L and the 6 field rows of test 10 |

**What a real integration must add:**
- The AND, G1 and G2 inside ONE trusted process before signing, preferably inside the issuer process, on the exact `Check` inputs, not in a separate caller.
- A rule for `opened` and `candidate`, or their removal.
- Trust in: the executable pin, the strict wire builder, the UTF-8 and integer mapping, and the relay and IPC.
- A policy for re-sent request ids and zero amounts.
- A way for a restarted caller to learn that its request was already committed.

**Files** (folder `<session scratch folder>/m1b/Z5/`):
- `consumer.py` (SHA `32fffeaf…`)
- `tests.py` (`abfa5367…`)
- `sinkctl.ts` (`9e695031…`)
- `model.cjs` (copy)
- `results/all.json` (`09ea299d…`)
- `logs/all-final.txt`, `logs/repo-sha256-before.txt`

**Ran:**

| command | exit |
|---|---|
| `python3 -I tests.py smoke` (first run) | 1 (a bytes serialization bug, fixed) |
| `python3 -I tests.py smoke` (second run) | 0 |
| `tests.py all`, run 1 | 1 |
| `tests.py all`, run 2 | 0 (157 rows) |
| `tests.py all`, run 3 | 0 (157 rows) |
| `tests.py all`, final | 0 (157 rows, 55 under test, all passed) |
| issuer | 0 (120 tokens signed) |
| `shasum -c` of repository files | all OK |

Run 1 had two causes: my wrong expectation for test 11 after the commit, and a control row that I had counted as under test. Run 2 then passed, but its `latin1-noguard` loop rows still used UTF-8. Run 3 fixed that encoding in `consumer.py`, and the final run fixed the variant labels in `tests.py`. The last three runs gave the same counts.

**Could not determine:** behaviour under power loss or concurrent consumers (not tested), and kills inside the sink child (D6 covers those).

| step | status | evidence or blocker |
|---|---|---|
| tests 7–11 | PASS (finite) | `results/all.json` |
| 12–14 | RECORDED | findings 6–8 |
| negative controls | each failed ≥1 test | table above |

| link id | proposed class | evidence |
|---|---|---|
| X15 | TESTED-UNPROVED (no change) | test 8 rows |
| X16 | TESTED-UNPROVED for this scratch harness only; MISSING in the repository | tests 7–14 |
