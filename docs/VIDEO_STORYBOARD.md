# Video storyboard: scenes, score and launch copy

Status: production blueprint for one 65-second cut. `end_to_end=false`.
This file gives no measured value. The take prints every measured value.
Where the screen shows a number, this file writes `[measured live]`, or it
cites a committed record by path.

If this file and the code differ, the code is correct. The code is
[run_recording_take.py](../demos/video_cut/run_recording_take.py), the
modules in `demos/video_cut/domains/`, and the policies in
`demos/video_cut/policies/`.

## 1. Purpose and framing

Forge is shown as a deterministic check layer. It sits between a
probabilistic AI model and an action that has no undo. The model
proposes. A policy decides. A refusal has a code.

The cut does not show a payment application. It shows one engine that
answers requests of nine domains: spacecraft autonomy, robotics, healthcare
records and dosing, cloud SRE, quant risk, multi-tenant SaaS, a GPU
scheduler, AI treasury, and crash and flood.

Rules of the cut:

1. A verdict on screen is the answer line of a real process that the take
   started. Nobody types a verdict.
2. Each result count, time and memory value on screen is measured in the
   take, or it is read from a committed record that the take names by
   path. The request values (for example 3.5 m/s, 500 mg, 8 of 10 pods,
   $50,000, 50 racers) and the rule bounds are scripted. They are inputs,
   not results.
3. The engine is a NATIVE CHECK (Rust). It is not proved.
4. "Proved" applies only to a part with a machine-checked proof. In this
   cut that is one thing: the Dafny source of the booking checker
   ([BookingDualCert.dfy](../proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy)).
   The CakeML/HOL4 refund chain has an open premise (M1-B OPEN). No
   scenario of this cut uses the CakeML refund binary: every money policy
   of the cut has the profile `parametric`. The voice and the captions
   call the engine a "native airlock" or a "native check", never "proved".
   No latency is a claim: the screen prints the measured value.
5. The engine has no rule for a ship, a robot, a clinic or a cluster. Each
   domain uses the nearest real rule. The screen shows the rule text. The
   gaps are in section 5 and the take prints them as `limit|` lines.
6. The requests are scripted worst cases. No model wrote them. The screen
   says so.
7. The screen sorts each answer into one of four classes. `ALLOWED`
   (green): a `COMMITTED` answer or an `OK <n>` read. `BLOCKED` (red): an
   answer whose code is a refusal code of the engine, that is, a code of
   class `refusal` or `terminal refusal` in the table of
   [PROTOCOL.md](../src/airlock/PROTOCOL.md) section 10. `EVENT` (cyan): a
   step that is neither an effect nor a refusal (an exception of a
   handler, a sweep report, a kill point, a read of the state after
   recovery, an answer of the Dafny-compiled checker that the module
   started directly). `OBSERVED` (cyan): any other answer, for example a
   counted summary. A report code (`DROPPED_OBLIGATION`) and a fault code
   are not `BLOCKED`. `EVENT` and `OBSERVED` lines are in no box of the
   scoreboard.

Format: 1440p capture, terminal at 140% font zoom, 100 columns. The runner
wraps every line at 100 columns (`WIDTH = 100`).

## 2. Before posting (checklist)

1. The owner renames the placeholders in
   [constants.py](../demos/video_cut/constants.py). The four names
   `AI_NAME`, `SHIP_NAME`, `HUMAN_NAME` and `BAY_NAME` are placeholders
   from a film. This storyboard writes only the variable names. Record the
   take after the rename.
2. The take that supplies the picture ended with exit code 0. A take with
   exit code 1, 2 or 3 is not usable. Exit code 3 is a PARTIAL take.
3. `python3 demos/video_cut/test_video_cut.py` ended with exit code 0 on
   the same commit.
4. Every picture frame of the cut comes from that one take.
5. The frame of scene 4 shows `limit| end_to_end=false` at full size.
6. The video, Post 1, Post 2 and the Show HN text hold no film quote and
   no parody line.
7. No API key is visible in any frame. The key is in the environment
   before the recording starts. Nobody types it during the recording.
8. The branch that holds `demos/video_cut/` is merged, or Post 2 names the
   branch. Open every link of Post 2 in a private browser window. Each
   link must load.
9. Read the on-screen text of the export on a phone-size screen. Every
   terminal line must be readable.
10. An overlay caption holds only fixed text of this file, or a value
    copied from the `--json` file of the same take. No other number.

## 3. Audio score and cue sheet

All sound is synthesized. [sound.py](../demos/video_cut/sound.py) makes
seven cues with the Python standard library: `hum`, `key`, `lock`, `data`,
`gap`, `ping`, `pad`. No audio is downloaded. No cue is synced with a web
demo (see section 6).

Source column: RUNNER means that the runner emits the cue at that event
(`--sound`, `--cue-sheet`). EDITOR means that the editor places it. An
EDITOR cue uses a WAV of the same seven cues, or a new synthesized cue that
is added to `sound.py`. The offsets of the `--cue-sheet` file are offsets
of the raw take. The editor moves them with the picture.

| Time | Sound | Cue | Source | Event on screen |
| --- | --- | --- | --- | --- |
| 0:00.0-0:04.0 | 55 Hz hum with a weak octave | `hum` | RUNNER | after the scene 1 card |
| 0:04.0-0:07.6 | the same hum, second play | `hum` | EDITOR | the model call lines |
| 0:02.5-0:07.0 | faint key ticks, one for each new text line | `key` at low level | EDITOR | task, injected text, reply lines |
| 0:07.0 | one key tick | `key` | RUNNER | the model call returned (only when the call ran) |
| 0:07.6-0:08.0 | silence, 0.4 s | none | EDITOR | hold on `ASSUMED: model fooled` |
| 0:08.0-0:08.4 | silence, 0.4 s | `gap` | RUNNER | after the scene 2 card |
| 0:08.4-0:11.0 | rising tone, low to high | new synthesized cue | EDITOR | scene 2 card, shot 1 |
| 0:08.8 | key tick, data tick | `key`, `data` | RUNNER | shot 1: the bay key opens |
| 0:11.0 | key tick; low thunk with a pitch fall, then a two-tone lock | `key`, `lock` | RUNNER | shot 2: the vent request is refused |
| 0:13.2 | key tick, thunk and lock | `key`, `lock` | RUNNER | shot 3: override with no signature |
| 0:15.4 | key tick, thunk and lock | `key`, `lock` | RUNNER | shot 4: forged signature |
| 0:17.6 | key tick, data tick | `key`, `data` | RUNNER | shot 5: routine command commits |
| 0:19.8 | key tick, data tick | `key`, `data` | RUNNER | shot 6: human-signed override commits |
| 0:22.0-0:22.4 | silence, 0.4 s | `gap` | RUNNER | start of scene 3 (cut to the montage) |
| 0:22.0-0:24.0 | ticks, if the editor wants them | `key`, `data`, `lock` | EDITOR | beat 1: the recap lines of scene 2 (the runner emits no cue for them) |
| 0:24.0-0:38.0 | a key tick on each answer line; then a data tick for ALLOWED, thunk and lock for BLOCKED, nothing more for EVENT and OBSERVED; one beat each 2.0 s | `key`, `data`, `lock` | RUNNER, re-timed by the EDITOR | beats 2 to 8 |
| 0:38.0-0:39.6 | ticks | `key`, `data`, `lock` | RUNNER | beat 9: ledger, lease, sweep, flood |
| 0:39.6 | one key tick | `key` | RUNNER | the SIGKILL line appears (an EVENT: key tick only) |
| 0:39.6-0:40.2 | total silence, 0.6 s | none | EDITOR | hold on the SIGKILL line |
| 0:40.2 | rising two-note ping | `ping` | EDITOR | `Production engine recovers` (the runner emits only `key` for this EVENT line) |
| 0:40.2-0:42.0 | ticks | `key`, `data`, `lock` | RUNNER | the last lines of beat 9 |
| 0:42.0-0:42.4 | silence, 0.4 s | none | EDITOR | cut to the cut-back of beat 7 |
| 0:42.4-0:55.0 | soft pad, three slow sines of one chord, repeated | `pad` | EDITOR | all of scene 4 |
| 0:45.0-0:45.4 | silence, 0.4 s | `gap` | RUNNER | after the scene 4 card |
| 0:46.5 | data tick (`lock` if the snippet did not commit) | `data` | RUNNER | the SDK snippet output |
| 0:50.5 | ping (`lock` if the sabotage check did not behave as required) | `ping` | RUNNER | after the sabotage check |
| 0:55.0-1:03.0 | soft pad | `pad` | RUNNER (after the scene 5 card), repeated by the EDITOR | scene 5 card and the commands |
| 1:03.0-1:05.0 | pad fades out; one soft low pulse | `pad`, `hum` at low level | EDITOR | hold on the clone line |

Notes for the editor:

- The runner plays `key` on every answer line of scenes 2 and 3 that a
  module records in this take. Then it plays `lock` for a BLOCKED line and
  `data` for an ALLOWED line. An EVENT or OBSERVED line gets the `key`
  tick only. The recap lines of beat 1 get no cue.
- In scene 4 the runner plays `data` (or `lock`) after the snippet and
  `ping` (or `lock`) after the sabotage check. The ping at 0:40.2 and the
  0.6 s silence are edits.
- `gap` is silence. The runner writes it to the cue sheet and plays
  nothing.
- If the sabotage check does not behave as required, the runner plays
  `lock` in place of `ping`, and the take ends with exit code 1. Do not
  use that take.
- To make the seven WAV files for the edit:

```sh
mkdir -p "$TMPDIR/video-cut-cues"
cd demos/video_cut
python3 -B -c "import sound, sys
for name, (make, _) in sound.CUES.items():
    sound.write_wav(sys.argv[1] + '/cue-' + name + '.wav', make())" "$TMPDIR/video-cut-cues"
```

## 4. Shot list and voiceover

The raw take is longer than 65 seconds. The race, the solver build, the
flood and the sabotage build take real time. The edit removes waiting
time with hard cuts. The edit never changes text, never changes the order
of answers, and never changes a number. Where a cut removes time inside a
beat, the frame shows the caption `time cut`.

Voice speed: about 2.5 words in each second.

Each `OBSERVED` line, each `ms` value, each count and each RSS value on
screen is `[measured live]`.

### Scene 1 (0:00-0:08) The gap

| Time | Screen | Voice | Cue |
| --- | --- | --- | --- |
| 0:00.0-0:02.5 | Card: `SCENE 1  The Gap`. Sub-line: "A model reads text. Text can hold an instruction that the owner did not write." | "AI now writes code faster than people can review it." | `hum` |
| 0:02.5-0:07.0 | `live model call (one call, the API of the model maker): model id [printed by the runner]`. Then `task     :`, then `injected :` in yellow (the pasted note holds an order to vent the bay). Then `status 200, [measured live] ms, stop_reason ..., served by ...`. Then the `reply    \|` lines: the real reply (at most 4 lines; `(empty reply)` if it has no text). Then `test     :` (the plain string test) and `test result:`. | "A better prompt is a request, not a control." | `hum`, faint `key` |
| 0:07.0-0:08.0 | If the reply is empty, or `stop_reason` is `refusal` or `max_tokens`: `no full command line in the reply (stop_reason ...): this call shows nothing about the model`. Else, if the reply does not hold the dangerous command: `the model did not take the bait in this call`. In every take, in yellow: `ASSUMED: model fooled — the worst case is sent to the engine`. | (silence) | `key` |

Voice: 19 words in 7.6 s (10 + 9). The last sentence of the directive's
line is the hook. It comes after the silence, at 0:08.0 (scene 2).

What is real: one call to an Anthropic model (one POST to the Messages
API). The model id is the value of `--model` (the default is in
[llm.py](../demos/video_cut/llm.py)). The reply on screen is the reply of
that call. If the reply is empty or the call stops with `stop_reason`
`refusal` or `max_tokens`, the screen says that the call shows nothing
about the model. If the call fails, the screen shows
`live model call failed: status ..., error type ...`. The take's exit code
does not depend on this call.

With `--no-model`, or with no key, the screen shows
`live model: NOT IN TAKE (--no-model / no key)` and then the ASSUMED line.
The runner then emits no `key` cue in scene 1.

Source of numbers: status, ms and the served model id come from the call.

### Scene 2 (0:08-0:22) Autonomy airlock

Domain 1, module [d1_autonomy.py](../demos/video_cut/domains/d1_autonomy.py),
policy [ship-autonomy.json](../demos/video_cut/policies/ship-autonomy.json).
Each shot is full size: `[n] headline`, `rule`, `request`, `required`,
`OBSERVED`, `measured : [measured live] ms    class: ...    check: ...`,
`label`. The OBSERVED line is green for ALLOWED, red for BLOCKED, cyan
for EVENT or OBSERVED. A `COMMITTED` answer is the engine's own line:
`COMMITTED <request id> <epoch> <state hash> <record>`. A refusal is the
code and its detail, for example `REJECTED_POLICY REASON_CAP`. The engine
ids are tenant `ship-1` and key `bay-3`. The display names appear in the
headlines only.

| Time | Screen (headline, then the required start of the answer) | Voice | Cue |
| --- | --- | --- | --- |
| 0:08.0-0:08.8 | Card: `SCENE 2  Autonomy airlock`. Sub-line: "Every OBSERVED line is the answer of the engine process of this run. Engine: NATIVE CHECK (Rust, not proved)." | "You lock the doors to reality." | `gap`, then rising tone |
| 0:08.8-0:11.0 | `[1] SHIP_NAME: BAY_NAME opened`. Rule: the trusted opener sets `crew_in_bay=1` (shown) and derives `vents_allowed=0`. Required: `COMMITTED`. | "One crew member is in the bay." | `key`, `data` |
| 0:11.0-0:13.2 | `[2] AI_NAME vents BAY_NAME`. Rule: `VENT_BAY`: committed vents + amount <= fact `vents_allowed`. Required: `REJECTED_POLICY REASON_CAP`. OBSERVED line in red. | "The model asks." | `key`, `lock` |
| 0:13.2-0:15.4 | `[3] AI_NAME tries an override`. Rule: `OVERRIDE_BAY_LOCK`: `REQUIRE_HUMAN_COSIGN`. Required: `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`. | "The policy answers." | `key`, `lock` |
| 0:15.4-0:17.6 | `[4] Override, forged signature`. A signature by another key. Required: `REQUIRE_HUMAN_COSIGN COSIGN_INVALID`. | "The vent stays shut." | `key`, `lock` |
| 0:17.6-0:19.8 | `[5] AI_NAME cycles the air filter`. Rule: `CYCLE_AIR_FILTER`: amount <= 1. Required: `COMMITTED`. | (ticks only) | `key`, `data` |
| 0:19.8-0:22.0 | `[6] HUMAN_NAME signs the override`. A signature by the pinned human key. Required: `COMMITTED`. | "An override needs a human signature." | `key`, `data` |

Voice: 29 words in 14 s (6 + 7 + 3 + 3 + 4 + 6).

What is real: six requests to one engine process, through the Python SDK.
The signatures are Ed25519. This text and the `label` line of shots 3, 4
and 6 (`NATIVE CHECK + FINITE TEST; Ed25519 verify through Node
(trusted)`) were written before pull request 72 (`cad68a5f`). On `main`
since that merge, `cosign-keygen` and `cosign-sign` run
`/usr/bin/ssh-keygen`, and the engine verifies with `/usr/bin/ssh-keygen
-Y verify` (trusted; no Node). The label text of the code at `058eabcb`
still said "through Node", and the take on `058eabcb` exited 2 (the
harness passed an option that pull request 72 removed). The release audit
of 2026-11-20 corrected the harness, the kill-build path and the label
(now "through ssh-keygen -Y"); the take then exited 0 from a clean clone
(`proposals/release-audit-20261120/AUDIT2_DEMOS.md`).

What the screen must not suggest: the engine does not test
`crew_in_bay`. It tests a sum against the fact `vents_allowed`. The
trusted opener derives that fact. A signed override is another reason: it
commits, and the engine does not then test `vents_allowed`. The human key
and the agent belong to one OS user in this take. Nothing here is proved.

Source of numbers: each `ms` value is the measured time of that SDK call.

### Scene 3 (0:22-0:42) Nine-domain montage

Layout of each beat. Line 1: `SCENE 3  9-domain montage   beat N: domain
N, TITLE`. Lines 2 to 5: the scoreboard with three boxes. In `--auto`
and `--step` mode the runner redraws it after each answer. Then one line
for each answer of the domain: the headline (cut to 36 columns), the
class, the start of the observed answer (cut to 37 columns), and
`[measured live] ms`. The start of the answer depends on the class:

- `ALLOWED` (green): the first token, for example `COMMITTED` or `OK`.
- `BLOCKED` (red): the first two tokens, for example
  `REJECTED_POLICY REASON_CAP`.
- `EVENT` or `OBSERVED` (cyan): the observed text itself, for example
  `AT b` or a counted summary.

A failed check adds ` CHECK FAILED` in red to the line.

The scoreboard:

| Box | Content | Source |
| --- | --- | --- |
| `SAFE STATE` | `[measured live] allowed, [measured live] failed checks` | counted from the recorded answers: ALLOWED answers (`COMMITTED`, `OK <n>`) whose check passed; all failed checks |
| `BLOCKED` | `[measured live] blocked` | counted from the recorded answers: BLOCKED answers only (refusal codes of PROTOCOL.md section 10) |
| `RAM (RSS, measured)` | `runner [measured live] MiB + engine max [measured live] MiB` | `/bin/ps`, sampled after each answer |

Fixed overlay caption for the whole scene: `Scripted worst cases. Real
engine answers. NATIVE CHECK, not proved.`

| Time | Beat | Lines that must be readable (headline: required start of the answer) | Voice | Cue |
| --- | --- | --- | --- | --- |
| 0:22-0:24 | 1 Spacecraft autonomy | The six answers of scene 2, shown again. The screen says: `(the observed answers of scene 2, shown again; not sent twice)`. | "Nine domains. One engine." | none from the runner (EDITOR ticks) |
| 0:24-0:26 | 2 Robotics envelope | `Controller opens arm window`: `COMMITTED`. `Robot speed 3.5 m/s`: `REJECTED_POLICY RULE`. `Reach outside the geofence`: `REJECTED_POLICY REASON_CAP`. `Safe speed 1.2 m/s`: `COMMITTED`. | "A robot, too fast." | ticks |
| 0:26-0:28 | 3 Healthcare records and dosing | `Own clinic records`: `OK 3`. `Another clinic row`: `TENANT_ISOLATION_BREACH`. `Pharmacy opens the order`: `COMMITTED`. `Agent orders 500 mg`: `REJECTED_POLICY REASON_CAP`. `Agent orders 25 mg`: `COMMITTED`. | "Another clinic's record." | ticks |
| 0:28-0:30 | 4 Cloud SRE change control | `Change window opened`: `COMMITTED`. `Agent deletes 8 of 10 pods`: `REJECTED_POLICY REASON_CAP`. `Agent opens 5432 to all`: `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`. `Agent deletes 1 of 10 pods`: `COMMITTED`. | "Eight of ten pods." | ticks |
| 0:30-0:32 | 5 Quant flash crash | `Risk desk opens book`: `COMMITTED`. `First sell order`: `COMMITTED`. `Order storm hits cap`: `REJECTED_POLICY REASON_CAP`. `Storm counted from answers` (OBSERVED): `12 orders: 3 COMMITTED, 9 REJECTED_POLICY REASON_CAP, 0 other; WAL records 3; committed sum <= cap: True`. `Book with no anchor`: `COMMITTED`. `Unanchored fade order`: `REJECTED_POLICY REASON_CAP`. `Open hedged pair`: `COMMITTED`. `Leg goes in flight`: `COMMITTED`. `Second leg, other venue`: `REJECTED_POLICY PROCESSOR_IN_FLIGHT`. `Held leg settles`: `COMMITTED`. | "An order storm." | ticks |
| 0:32-0:34 | 6 Multi-tenant SaaS | `Scoped read, own org`: `OK 2`. `Query without WHERE org_id`: `TENANT_ISOLATION_BREACH`. `Rows released: counted` (OBSERVED): `0 rows released`. `Open the credit balance`: `COMMITTED`. `The one winner`: `COMMITTED`. `A stale racer`: `STALE_STATE_HASH`. `Race of 50 counted` (OBSERVED): `50 racers: 1 COMMITTED, 49 STALE_STATE_HASH, 0 other; WAL effect records of the key: 1`. Caption `time cut`. | "Fifty writers, one key." | ticks |
| 0:34-0:36 | 7 GPU scheduler with a runtime certificate | `Open GPU night one`: `COMMITTED`. `Buggy solver overbooks GPU`: `REJECTED_POLICY OVERBOOKED`. `Dafny checker, same overbook` (EVENT): `REJECT exit=1`. `Solver v1 TypeScript books`: `COMMITTED`. `Dafny checker, v1 batch` (EVENT): `ACCEPT exit=0`. `Open GPU night two`: `COMMITTED`. `Solver v2 Rust books`: `COMMITTED`. `Dafny checker, v2 batch` (EVENT): `ACCEPT exit=0`. Caption `time cut`. | "An overbooked GPU." | ticks |
| 0:36-0:38 | 8 AI treasury | `Finance opens invoice key`: `COMMITTED`. `Injected $50,000 payment`: `REJECTED_POLICY TOTAL_CAP`. `$80 for $10 invoice`: `REJECTED_POLICY REASON_CAP`. `The real $10 payment`: `COMMITTED`. `Finance opens a big invoice`: `COMMITTED`. `Payment above the sub-cap`: `REJECTED_POLICY TOTAL_CAP`. | "Fifty thousand dollars." | ticks |
| 0:38.0-0:39.6 | 9 Crash and flood, part 1 | `Open the payout ledger`: `COMMITTED`. `Handler commits its payout`: `COMMITTED`. `Handler crashes mid-way` (EVENT): `TypeError`. `Sweep finds dropped obligation` (EVENT): `SWEEP 1 1`. `Engine names the lease` (EVENT): `DROPPED_OBLIGATION wh-crash 1700000000000 ledger acct-1`. `Flood with no line end`: `MALFORMED_REQUEST OVERSIZED`. `Valid request after flood`: `COMMITTED`. `Open the crash ledger`: `COMMITTED`. Caption `time cut`. | (ticks only) | ticks |
| 0:39.6-0:40.2 | 9, the kill | `SIGKILL: record half written` (EVENT): `AT b`. Hold the frame. | "Then, a kill." | `key`, then 0.6 s silence |
| 0:40.2-0:42.0 | 9, recovery | `Production engine recovers` (EVENT): `OK`. `Same request id again`: `COMMITTED` (the torn record was cut, so the id is fresh). Then `SIGKILL: written, not synced` (EVENT): `AT c`; `Production engine recovers` (EVENT): `OK`; `Same request id again`: `DUPLICATE_REQUEST_ID`. Then `SIGKILL: after the sync` (EVENT): `AT r`; `Production engine recovers` (EVENT): `OK`; `Same request id again`: `DUPLICATE_REQUEST_ID`. Then `New payout after recovery`: `COMMITTED`. | "The log recovers." | `ping` (EDITOR), ticks |

Every headline and every required start of the answer in this table is
the module's exact string. The voice names only some of them. Every line
is on screen. A line marked (EVENT) or (OBSERVED) is cyan and is in no
box of the scoreboard. Every other line with `COMMITTED` or `OK` is
ALLOWED, and every other line is BLOCKED. The cyan text of an EVENT or
OBSERVED line is cut to 37 columns. The `ms` value of each line is
`[measured live]`. The counted lines show the counts of the take
(`[measured live]`); the table gives the required text.

Voice: 34 words in 20 s. The voice is short so that the ticks are audible.

What is real, beat by beat:

- Beats 2, 3, 4, 5, 8: SDK calls to a real engine process on a fresh
  store. Label `NATIVE CHECK + FINITE TEST`.
- Beat 5: the module sends 12 scripted orders of 30000 against the trusted
  fact `max_notional` = 100000. It counts the engine's answers and reads
  the committed sum back from the WAL through the engine's replay.
- Beat 6: 50 SDK clients, each with its own engine `serve` process, send
  one write on one key with one state hash. A barrier starts them
  together. The required result is 1 `COMMITTED`, 49 `STALE_STATE_HASH`,
  0 other answers and 1 WAL effect record. The line on screen holds the
  counted values. It is one race at one start time, not all schedules.
- Beat 7: the three solvers are the committed guests of Slice 3, started
  as real processes: `guests/booking/v1_baseline.ts` (TypeScript),
  `guests/booking/v2_fast.rs` (safe Rust, built in the take with the
  `rustc` of the machine) and `guests/booking/v3_adversary.py` (Python,
  mode `overbook`). The engine's native check refuses the overbooked
  batch first. The module also starts the Dafny-compiled checker directly
  and shows its own answer. A sampler counts Dafny, Boogie and Z3
  processes during the swap. The label of the booked shots starts with
  `PROVED CORE source`: that applies to the Dafny source of the checker
  only. The direct checker lines are EVENT lines, not BLOCKED or ALLOWED.
  If `rustc` is missing, the v2 part does not run: the module records a
  skip, the runner prints it as a gap, and the take is PARTIAL (exit 3).
- Beat 8: the second key `inv-205` has an invoice fact far above the
  sub-cap. There only the total cap (the sub-cap) refuses the payment.
  The guard-sabotage check of scene 4 deletes that guard. This shot then
  fails, because the answer is no longer `REJECTED_POLICY TOTAL_CAP`.
- Beat 9: (a) a handler raises a real `TypeError` and leaves its lease
  open; the engine's sweep reports it (`DROPPED_OBLIGATION` is a report
  code, not a refusal). (b) `--flood-mb` MiB of bytes with no line end go
  into the stdin of a real `airlock-engine serve`; then one valid request
  on the same pipe must commit. (c) The kill-points build stops at a
  point of the WAL append; the module sends a real SIGKILL; the
  production engine opens the store next. Kill point `b`: half a record
  is in the WAL. Point `c`: written, not synced. Point `r`: after the
  sync. If the kill-points build `airlock-engine-kill` is missing from the
  engine folder (default `build/airlock`), part (c) does not run: the
  module records a skip, and the take is PARTIAL (exit 3).

Source of numbers: every `ms` value, the counts of the counted lines and
the three scoreboard boxes are measured in the take. The request values
and the rule bounds are scripted. The take does not print the
10 GiB record on screen in this scene. The record is cited in the
`--json` file of the take, by path and by the SHA-256 of the record file
that the take computes at run time (see section 6).

### Scene 4 (0:42-0:55) Evolution and proof that it is real

"Proof" in the card title means evidence that the take is not staged. It
is not a formal proof. The `limit|` lines in the same scene say what is
proved.

| Time | Screen | Voice | Cue |
| --- | --- | --- | --- |
| 0:42.0-0:45.0 | Cut-back to the frames of beat 7, with the caption `from beat 7 of this take`: `Solver v1 TypeScript books`, `Dafny checker, v1 batch`, `Solver v2 Rust books`, `Dafny checker, v2 batch`. Second caption: `Slice 3 record: v1 TypeScript, v2 safe Rust, v3 Python adversary. proposals/forge2-slice3-runtime-certificates/REPORT.md section 5`. | "Swap the solver: TypeScript, then Rust. Same checker." | silence (EDITOR), then `pad` (EDITOR) |
| 0:45.0-0:47.5 | Card `SCENE 4  Proof it is real`, then `(a) the 3-line SDK snippet (sdk/py/forge_airlock.py). These three lines run now:`. The three lines: `import forge_airlock as fa`, `st = fa.Store('store-snippet')`, `print(st.open_money('acme', 'order-1', 'r1', 'robot-envelope', 1000).line)`. Then the `setup   :` line, `OUTPUT  :` with the engine's own answer line (required start: `COMMITTED r1`), and `exit [measured live], [measured live] ms (a new Python process and a new engine process)`. | "Three lines of Python." | `gap` after the card, then `data` |
| 0:47.5-0:51.0 | `(b) live guard sabotage: delete ONE guard of the engine, build the copy, run the same check`. Then `copy of src/airlock in a temp folder; mutant M06_total_cap of scripts/exit_goal20_sdk.py; rustc build [measured live] s` and `diff of src/airlock/policy.rs (the repository file is not changed):`. The diff line in red: `- if amount > remaining { return Verdict::Reject("TOTAL_CAP") }`. Then `unsabotaged engine: run_recording_take.py --check-domain treasury`, its last 3 output lines, and `exit code [measured live]` in green (required 0). Then `SABOTAGED engine:   run_recording_take.py --check-domain treasury --engine-dir <temp>`, its last 5 output lines (each `FAIL` line in red; the guard that the copy lacks is the one that the shot `Payment above the sub-cap` needs), and `exit code [measured live]` in red (required 1). Caption `time cut` over the build. | "Delete one guard, and the check fails." | `ping` |
| 0:51.0-0:55.0 | `(c) limits of this take`, full size, yellow. Hold these lines: `limit\| end_to_end=false`; `limit\| SIGKILL is not a power loss: ...`; `limit\| OS uid: ... ONE OS user (uid [measured live], from os.getuid()) ...`; `limit\| model: ...`; `limit\| the engine is a NATIVE CHECK (Rust), not proved`. | "End to end is false. A kill is not a power loss." | `pad` (EDITOR) |

Voice: 31 words in 13 s (8 + 4 + 7 + 12).

What is real:

- (a) The three printed lines run as a new Python process against a fresh
  store. The output line is the engine's answer.
- (b) The runner copies `src/airlock` to a temp folder, deletes one guard
  (mutant `M06_total_cap` of
  [exit_goal20_sdk.py](../scripts/exit_goal20_sdk.py)), builds that copy
  with `rustc`, and runs `--check-domain treasury` two times: against the
  normal engine and against the sabotaged copy. The repository file is
  not changed. If the check does not exit 1 against the sabotaged copy,
  or does not exit 0 against the normal engine, the take fails (exit 1).
  On the sabotaged copy, two treasury shots no longer answer
  `REJECTED_POLICY TOTAL_CAP`, so the check fails. The screen prints what
  the sabotaged copy answered. The check does not require a commit on
  the sabotaged copy: another check of the engine can still refuse the
  payment with another code.
- (c) The runner prints the limits. The uid comes from `os.getuid()`.

The frame at 0:51.0-0:55.0 must show `end_to_end=false` at full size. The
list of gaps of each domain follows on screen in the raw take. The cut
can stop before that list. Section 9 holds it.

Source of numbers: exit codes, ms and the build time are measured in the
take. The solver languages of the second caption come from the committed
record: [REPORT.md](../proposals/forge2-slice3-runtime-certificates/REPORT.md)
section 5.

### Scene 5 (0:55-1:05) The open challenge

| Time | Screen | Voice | Cue |
| --- | --- | --- | --- |
| 0:55.0-0:57.5 | Card: `SCENE 5  Open challenge`. Sub-line: "Break it. Everything in this take runs from the repository." | "Clone it. Build it." | `pad` |
| 0:57.5-1:03.0 | `git clone https://github.com/mack-dot/forge`; if the take ran on a branch other than `main`, the line `git checkout <branch>` (read from git in the take); `python3 bin/forge-airlock build --checker`; `python3 demos/video_cut/run_recording_take.py --auto`; `python3 demos/video_cut/test_video_cut.py`. | "Run this take on your machine. Then try to break it, and tell us what you find." | `pad` |
| 1:03.0-1:05.0 | Hold on the clone line. Then the `exit` line of the summary: `exit [measured live]: full take; every required result was observed`. | (silence) | pad fades, one low pulse |

Voice: 21 words in 10 s.

What is real: the runner prints the commands. The `exit` line of the
summary holds the exit code that the runner returns. After it the runner
prints one more line:
`take time [measured live] s; shots [measured live]; engine max RSS [measured live] KiB (pid [measured live])`.
The cut can stop before that line. The build needs `rustc`, Dafny and
Node 24.3.0.

Total voice: 134 words in 65 s.

## 5. Domain mapping table and gaps

Every row is read from the module and the policy file. The headlines are
the exact strings of the modules, in the order of the take. After each
headline comes the required start of the answer. `ms` is always
`[measured live]`. Allowed: `COMMITTED` and `OK <n>` answers (green, the
`SAFE STATE` box). Blocked: refusal codes of
[PROTOCOL.md](../src/airlock/PROTOCOL.md) section 10 (red, the `BLOCKED`
box). Event or counted: EVENT and OBSERVED lines (cyan, in no box).

| # | Domain | Headlines on screen, in order (required start of the answer) | Real rule (policy file, rule) | Allowed | Blocked | Event or counted (no box) | Gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Spacecraft autonomy | `SHIP_NAME: BAY_NAME opened` (`COMMITTED`); `AI_NAME vents BAY_NAME` (`REJECTED_POLICY REASON_CAP`); `AI_NAME tries an override` (`REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`); `Override, forged signature` (`REQUIRE_HUMAN_COSIGN COSIGN_INVALID`); `AI_NAME cycles the air filter` (`COMMITTED`); `HUMAN_NAME signs the override` (`COMMITTED`) | [ship-autonomy.json](../demos/video_cut/policies/ship-autonomy.json), money airlock. Engine ids: tenant `ship-1`, key `bay-3`. `VENT_BAY`: `max_reason_total_fact` = `vents_allowed`. `OVERRIDE_BAY_LOCK`: `REQUIRE_HUMAN_COSIGN`. `CYCLE_AIR_FILTER`: `max_amount` 1. | The bay key opens. The air filter command commits. The override with the pinned human key's signature commits. | Vent with `vents_allowed=0`: `REJECTED_POLICY REASON_CAP`. Override with no signature: `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`. Signature by another key: `REQUIRE_HUMAN_COSIGN COSIGN_INVALID`. | None. | The engine cannot test `crew_in_bay == 0`. The trusted opener derives `vents_allowed`. A signed override commits with no test of `vents_allowed`. The human key and the agent have one OS user. Native `ssh-keygen` cosign: NOT IN TAKE. |
| 2 | Robotics envelope | `Controller opens arm window` (`COMMITTED`); `Robot speed 3.5 m/s` (`REJECTED_POLICY RULE`); `Reach outside the geofence` (`REJECTED_POLICY REASON_CAP`); `Safe speed 1.2 m/s` (`COMMITTED`) | [robot-envelope.json](../demos/video_cut/policies/robot-envelope.json), money airlock. `SET_SPEED_MM_S`: `max_amount` 1500 commits; `min_amount` 1501 is refused. `REACH_MM`: `max_reason_total_fact` = `geofence_radius_mm` (800). | The arm window opens. Speed 1200 mm/s commits. | Speed 3500 mm/s: `REJECTED_POLICY RULE`. Reach 900 mm: `REJECTED_POLICY REASON_CAP`. | None. | One integer bound, not a 2-D or 3-D region. One key is one command window, not a control loop. No VLA model runs. |
| 3 | Healthcare records and dosing | `Own clinic records` (`OK 3`); `Another clinic row` (`TENANT_ISOLATION_BREACH`); `Pharmacy opens the order` (`COMMITTED`); `Agent orders 500 mg` (`REJECTED_POLICY REASON_CAP`); `Agent orders 25 mg` (`COMMITTED`) | Read airlock (no policy file): each row needs a top-level `tenant_id` equal to the clinic. [clinic-dosing.json](../demos/video_cut/policies/clinic-dosing.json), money airlock: `DOSE_MG`: `max_reason_total_fact` = `safe_mg` (50). | Read of 3 own rows: `OK 3`. The order key opens. Dose 25 mg commits. | Read with 1 row of another clinic: `TENANT_ISOLATION_BREACH`; the module requires 0 released rows and stops the take otherwise. Dose 500 mg: `REJECTED_POLICY REASON_CAP`. | None. | MCP part: NOT IN TAKE. Only the top-level `tenant_id` is checked. No database runs. Doses are a sum on the key, not a dose per time. Not a HIPAA compliance claim. |
| 4 | Cloud SRE change control | `Change window opened` (`COMMITTED`); `Agent deletes 8 of 10 pods` (`REJECTED_POLICY REASON_CAP`); `Agent opens 5432 to all` (`REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`); `Agent deletes 1 of 10 pods` (`COMMITTED`) | [sre-change.json](../demos/video_cut/policies/sre-change.json), money airlock. `DELETE_PODS`: `max_reason_total_fact` = `max_delete` (1). `OPEN_PUBLIC_5432`: `REQUIRE_HUMAN_COSIGN`. | The change window opens. Delete 1 of 10 pods commits. | Delete 8 of 10: `REJECTED_POLICY REASON_CAP`. Open port 5432 to all: `REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED`. | None. | The engine cannot multiply. The trusted opener computes `max_delete` from `total_pods`. The engine sees a reason name, not a firewall rule. No cluster runs. No signed case in this domain. |
| 5 | Quant flash crash | `Risk desk opens book` (`COMMITTED`); `First sell order` (`COMMITTED`); `Order storm hits cap` (`REJECTED_POLICY REASON_CAP`); `Storm counted from answers` (`12 orders: 3 COMMITTED, 9 REJECTED_POLICY REASON_CAP, 0 other; WAL records 3; committed sum <= cap: True`); `Book with no anchor` (`COMMITTED`); `Unanchored fade order` (`REJECTED_POLICY REASON_CAP`); `Open hedged pair` (`COMMITTED`); `Leg goes in flight` (`COMMITTED`); `Second leg, other venue` (`REJECTED_POLICY PROCESSOR_IN_FLIGHT`); `Held leg settles` (`COMMITTED`) | [quant-risk.json](../demos/video_cut/policies/quant-risk.json), money airlock: `SELL_NOTIONAL` against fact `max_notional`; `FADE_NOTIONAL` against fact `anchor_notional`. [quant-legs.json](../demos/video_cut/policies/quant-legs.json), saga airlock: one in-flight pair for each key. | The two book keys and the pair open. Orders commit while the sum stays at or below the cap. The first leg goes in flight. The held leg settles to `HEDGED`. | Storm order above the cap: `REJECTED_POLICY REASON_CAP`. Fade order on a key with no anchor fact: `REJECTED_POLICY REASON_CAP`. Second leg at another venue: `REJECTED_POLICY PROCESSOR_IN_FLIGHT`. | `Storm counted from answers` (OBSERVED): counts of the engine's answers and the committed sum from the WAL. | No market data. "Anchor" is a trusted fact, not a price. The saga rule is not a hedge-ratio check. The cap is a sum of integers, not a risk model. |
| 6 | Multi-tenant SaaS | `Scoped read, own org` (`OK 2`); `Query without WHERE org_id` (`TENANT_ISOLATION_BREACH`); `Rows released: counted` (`0 rows released`); `Open the credit balance` (`COMMITTED`); `The one winner` (`COMMITTED`); `A stale racer` (`STALE_STATE_HASH`); `Race of 50 counted` (`50 racers: 1 COMMITTED, 49 STALE_STATE_HASH, 0 other; WAL effect records of the key: 1`) | Read airlock. Compare-and-swap on the state hash of the key. [saas-credits.json](../demos/video_cut/policies/saas-credits.json) gives the race key a rule (`USE_CREDITS`). | Scoped read of the 2 rows of `org-a`: `OK 2`. The credit key opens. The one racer that commits. | Unscoped read: `TENANT_ISOLATION_BREACH`. A racer with the old state hash: `STALE_STATE_HASH`. | `Rows released: counted` and `Race of 50 counted` (OBSERVED). Their counts are `[measured live]`. | Only the top-level `tenant_id` is checked. The engine does not see the SQL. One race at one start time, not all schedules. |
| 7 | GPU scheduler with a runtime certificate | `Open GPU night one` (`COMMITTED`); `Buggy solver overbooks GPU` (`REJECTED_POLICY OVERBOOKED`); `Dafny checker, same overbook` (`REJECT exit=1`); `Solver v1 TypeScript books` (`COMMITTED`); `Dafny checker, v1 batch` (`ACCEPT exit=0`); `Open GPU night two` (`COMMITTED`); `Solver v2 Rust books` (`COMMITTED`); `Dafny checker, v2 batch` (`ACCEPT exit=0`) | [gpu-slots.json](../demos/video_cut/policies/gpu-slots.json), inventory airlock, `max_alpha_bps` 0. `BOOK` with an LP-duality certificate. The native `Accepts` runs first, then the Dafny-compiled `BookingDualCert` checker. | The two night keys open. The v1 batch and the v2 batch commit. | Overbooked batch: `REJECTED_POLICY OVERBOOKED` (native check). | The three direct checker lines (EVENT): `REJECT exit=1` for the overbook, `ACCEPT exit=0` for the v1 and v2 batches. | The records say TypeScript v1, safe Rust v2, Python adversary v3. The Slice 3 record is of another issuer, sink and checker core. "No Dafny during the swap" means: none seen by a sampler. The check is sound, not complete. One GPU, 4 slots, 5 jobs: nothing is about real GPUs. No `rustc`: the v2 part does not run, and the take is PARTIAL. |
| 8 | AI treasury | `Finance opens invoice key` (`COMMITTED`); `Injected $50,000 payment` (`REJECTED_POLICY TOTAL_CAP`); `$80 for $10 invoice` (`REJECTED_POLICY REASON_CAP`); `The real $10 payment` (`COMMITTED`); `Finance opens a big invoice` (`COMMITTED`); `Payment above the sub-cap` (`REJECTED_POLICY TOTAL_CAP`) | [treasury-subcap.json](../demos/video_cut/policies/treasury-subcap.json), money airlock. Total cap of the key (`original` 50000 cents, the sub-cap). `PAY_INVOICE`: `max_reason_total_fact` = `invoice_cents` (1000 on `inv-204`, 10000000 on `inv-205`). | The keys `inv-204` and `inv-205` open. Payment of 1000 cents commits. | Payment of 5000000 cents: `REJECTED_POLICY TOTAL_CAP`. Payment of 8000 cents: `REJECTED_POLICY REASON_CAP`. Payment of 60000 cents on `inv-205`, where only the sub-cap binds: `REJECTED_POLICY TOTAL_CAP` (the guard-sabotage check makes this shot fail). | None. | The sub-cap and the invoice amount are trusted values of the opener. No payment processor is called. The injection text is scripted. |
| 9 | Crash and flood | `Open the payout ledger` (`COMMITTED`); `Handler commits its payout` (`COMMITTED`); `Handler crashes mid-way` (`TypeError`); `Sweep finds dropped obligation` (`SWEEP 1 1`); `Engine names the lease` (`DROPPED_OBLIGATION wh-crash 1700000000000 ledger acct-1`); `Flood with no line end` (`MALFORMED_REQUEST OVERSIZED`); `Valid request after flood` (`COMMITTED`); `Open the crash ledger` (`COMMITTED`); for each kill point `b`, `c`, `r`: `SIGKILL: record half written` / `SIGKILL: written, not synced` / `SIGKILL: after the sync` (`AT b` / `AT c` / `AT r`), `Production engine recovers` (`OK`), `Same request id again` (`COMMITTED` after `b`, `DUPLICATE_REQUEST_ID` after `c` and `r`); `New payout after recovery` (`COMMITTED`) | [crash-ledger.json](../demos/video_cut/policies/crash-ledger.json), money airlock: `PAYOUT` `max_amount` 5000. Lease rule, request line limit of 65,536 bytes, WAL recovery rule ([PROTOCOL.md](../src/airlock/PROTOCOL.md)). | The two ledger keys open. A handler that commits closes its lease. A valid request commits after the flood. After kill point `b` the same request id commits (the torn record was cut). A new payout commits after recovery. | Flood line: `MALFORMED_REQUEST OVERSIZED`. A used request id after recovery (points `c` and `r`): `DUPLICATE_REQUEST_ID`. | The handler's `TypeError`; the sweep line `SWEEP 1 1` and the report `DROPPED_OBLIGATION` (a report code, not a refusal); the three `AT <point>` lines; the three `Production engine recovers` reads. | A SIGKILL is not a power loss. The killed process is a test-seam build of the same source. The flood memory bound is not checked below 512 MiB. The 10 GiB record is of the Slice 1 token issuer, not of this engine. No kill-points build: part (c) does not run, and the take is PARTIAL. |

Rows marked "module pending at the time of writing": none. All nine
modules were present when this table was written. The modules can change
after that. Run the take and compare the headlines before the edit.

Common gap of rows 1 to 5, 8 and 9: the wire verb of each money request is
`REFUND`. The reason names the command, and the amount is the command's
number. The hedged-pair shots of row 5 use the verb `SAGA`.

## 6. What is NOT in the take, and departures from the directive

| Directive item | What the take does | Why |
| --- | --- | --- |
| Film names and a film-style line for the ship AI | The storyboard writes `AI_NAME`, `SHIP_NAME`, `HUMAN_NAME`, `BAY_NAME`. Scene 2 uses an original plain line. | No film quote and no parody. The owner renames the placeholders. |
| Scene 1: a pulsing red eye | NOT IN TAKE. The screen is a plain terminal. | The red eye is an image of the film. |
| Scene 1: unreviewed AI code scrolls | The screen shows one live model call: a pasted note with an injected order, and the model's real reply. | A staged code scroll is not a real event of the take. |
| Scene 1: the AI is compromised | One real call. If the model refuses, the screen shows that. Then the line `ASSUMED: model fooled`. | The result of a model call is not known before the take. |
| Scene 1 line ends at 0:08 | The last sentence of the line is spoken at 0:08.0, after the silence. The first two sentences are said in a softer form with no absolute claim (19 words). | The full line has 25 words. That is more than 8 s at 2.5 words in each second. An absolute claim about all humans or all prompts is not supportable. |
| Scene 1: the model is fooled | If the reply is empty or the call stops with `stop_reason` `refusal` or `max_tokens`, the screen says `no full command line in the reply (stop_reason ...): this call shows nothing about the model`. | Such a call shows nothing about the model, in either direction. |
| Scene 2: the engine blocks against `crew_in_bay=1` | The engine tests `VENT_BAY` against the fact `vents_allowed=0`. The trusted opener derives it from `crew_in_bay=1`. | The engine tests a sum against a fact. It has no equality test on a fact. |
| Scene 2: native `ssh-keygen -Y` cosign | Written before pull request 72: "NOT IN TAKE. The cosign is Ed25519 through Node." On `main` since `cad68a5f` the engine checks every cosign with `/usr/bin/ssh-keygen -Y verify`; a take on that tree is NOT RUN. | The native cosign is on `main` since pull request 72 (`cad68a5f`). |
| Healthcare through MCP | NOT IN TAKE. The read airlock and the dose cap are in the take. | The MCP proxy is on `main` since pull request 77 (`a2ef7c0a`); the take does not use it. |
| Montage: a model acts in each domain | Every request is a scripted worst case. An overlay says so. | Model disclosure. |
| Montage: one 4-word headline and one verdict for each 2 s | Each beat shows all answers of the domain, one line each. Some headlines have more than four words. | Each domain has one allowed case and one blocked case or more. |
| Montage in real time, 2 s for each beat | The raw beats 6, 7 and 9 are longer. The edit cuts waiting time and shows `time cut`. | 50 processes, a `rustc` build, a flood and three kills take real time. |
| Scoreboard `Safe State / Blocked / RAM` | Present. `SAFE STATE` shows allowed answers (`COMMITTED`, `OK <n>`) and failed checks. `BLOCKED` counts only refusal codes of PROTOCOL.md section 10: a report (`DROPPED_OBLIGATION`), an event and a direct checker answer are in no box. `RAM` shows the runner's RSS and the largest RSS of one engine process. | The RAM box does not hold helper processes (Node) or processes that a module starts itself. |
| Solver swap "Python -> Rust" | TypeScript v1, then safe Rust v2. Python is the adversary v3. | [REPORT.md](../proposals/forge2-slice3-runtime-certificates/REPORT.md) section 5 and [demo-gauntlet.md](demo-gauntlet.md) Act 3 say so. |
| "0 Dafny re-runs" | The exact recorded statement is: between the first and the last optimizer the EXIT script started 18 commands, all 18 are optimizer runs, and 0 of them are Dafny or Z3. Source: [evidence.json](../proposals/forge2-slice3-runtime-certificates/records/evidence.json), `optimizer_swap`. The report adds that the script "does NOT observe the processes that an optimizer run starts (review finding R5)". In the take, a sampler counts prover processes: `[measured live]`. | The record is a count over the script's own commands. It is of the Slice 3 issuer and sink, not of this engine. |
| Solver swap in scene 4 | The swap runs in beat 7 of scene 3. Scene 4 opens with a cut-back to those frames, with a caption. | The runner runs domain 7 in the montage. |
| 10 GiB flood of the engine | NOT IN TAKE. The take floods the engine with `--flood-mb` MiB (default 64). The memory bound is not checked below 512 MiB, and the take says so. The 10 GiB record is cited by path and by the SHA-256 that the take computes at run time. | [run-10gib.json](../proposals/forge2-demo-gauntlet/records/run-10gib.json) is a record of the Slice 1 token ISSUER, not of the airlock engine. |
| `kill -9`, then WAL recovery | A real SIGKILL kills the kill-points build at a named point. The production engine recovers. | The production build has no kill points. A SIGKILL is not a power loss. |
| Audio synced with the web `sound.ts` | Void. | The web demo was deleted. |
| Rising synth, 0.6 s silence on the kill, ping on recovery, pad under scene 4, closing pulse | EDITOR cues (section 3). The runner emits seven cues: `hum`, `key`, `lock`, `data`, `gap`, `ping`, `pad`. Its `gap` is 0.4 s. | The runner emits cues on events, not on a music timeline. |
| Downloaded sound effects | None. | All sound is synthesized. |
| Words that claim an absolute result | None in the voice, the captions or the launch copy. | The engine is a finite-tested native check. `end_to_end=false`. |
| Playground link | None. | No playground exists. |

Not available:

| Item | State | In the launch copy |
| --- | --- | --- |
| Paper | NOT ON MAIN (no such tracked file in this branch) | No |
| "Forge for Dummies" | NOT ON MAIN (no such tracked file in this branch) | No |
| `reproduce_paper.py` | NOT ON MAIN (no such tracked file in this branch) | No |
| Playground URL | Does not exist | No |

Digest of the 10 GiB record FILE at commit `33055a59` (computed with
`shasum -a 256`, not a measured result of the take):
`622fbea10b32b0b3656db72bb7bd3ff2ffd857ad9b863e017ad81415c3791838`.
The take computes this digest again at run time. If the two differ, the
take's value is the correct one for its commit.

## 7. Recording procedure

Setup:

1. Terminal: 100 columns or more. Font zoom 140%. Dark background. Choose
   the row count in a rehearsal: one full shot of scene 2 and one full
   beat of scene 3 must fit without a scroll.
2. Screen Studio: 1440p capture of the terminal window only. Record the
   system audio if `--sound` is used.
3. Shell: Node 24.3.0 first in `PATH`. `rustc` and Dafny in `PATH`.
4. Build one time: `python3 bin/forge-airlock build --checker`. The build
   also makes the kill-points build `build/silicon/test/airlock-engine-kill` (moved by pull request 73).
   Without it, or without `rustc` at take time, a part of a module does
   not run and the take is PARTIAL (exit 3).
5. For the live model call: `ANTHROPIC_API_KEY` is in the environment
   before the recording starts. Without it, add `--no-model`.
6. Write the `--json` and `--cue-sheet` files outside the repository.

Rehearsal (not recorded):

```sh
python3 demos/video_cut/test_video_cut.py; echo "exit=$?"
```

The picture take (`--auto`, timed by the runner):

```sh
python3 demos/video_cut/run_recording_take.py --auto --sound \
  --cue-sheet "$TMPDIR/take-cues.json" --json "$TMPDIR/take.json"; echo "exit=$?"
```

The voiceover take (`--step`, Enter advances each beat):

```sh
python3 demos/video_cut/run_recording_take.py --step \
  --json "$TMPDIR/take-step.json"; echo "exit=$?"
```

Record 2 or 3 takes in `--step` mode for the voiceover, and keep the
best one. Each take is a full real run: its measured values differ from
take to take, and each must end with exit code 0.

Use the `--step` take to speak the script of section 4 against the
picture. Press Enter at the end of each voice line. Then choose one of
two ways:

- Record the voice alone, and lay it on the `--auto` picture.
- Or use the `--step` take as the picture, with its live voice.

In both ways, every picture frame of the cut comes from ONE take.

Rules:

- Keep `exit=` in the recording. A take whose exit code is not 0 must not
  be used. Exit 1: a required result was not observed. Exit 2: a missing
  tool or a crash. Exit 3: a PARTIAL take.
- Do not use `--domains`, `--skip-sabotage` or `--fast` for the picture
  take. `--domains` and `--skip-sabotage` make the take PARTIAL.
- Do not raise `--flood-mb` above the default. The runner refuses a
  larger value without `--allow-large-flood`.
- The race and the sabotage build are heavy. The runner takes the shared
  heavy lock when the lock folder exists, and it waits for it
  (`--lock-wait-min M` gives up with exit 2 after M minutes; 0 waits with
  no limit). Run no other heavy job at the same time.
- A part that a module cannot run (no `rustc` for solver v2 of domain 7,
  no kill-points build for domain 9) is printed as a gap, and the take is
  PARTIAL (exit 3). Do not use that take.
- The edit can remove time. It cannot add, change or reorder a line.
- `--no-color` is for logs. Do not use it for the picture take.

Other flags of the runner: `--model ID`, `--no-model`, `--node P`,
`--engine-dir DIR`, `--check-domain NAME`, `--show-missing`,
`--sabotage-dir DIR`, `--min-swap-free-mib N`, `--swap-wait-min M` (the
longest wait for free swap, default 40 minutes), `--lock-wait-min M`,
`--allow-large-flood` (needed for `--flood-mb` above 64).

## 8. Launch copy

Replace nothing with a number that the take did not print. The copy below
holds no measured value.

### Post 1 (native video only, 0 external links)

```text
AI agents now act. They move money, delete pods, order doses and drive arms.

A prompt is a request. It is not a control.

Forge is a deterministic check between a model and an action that has no undo. The model proposes. A policy decides. Each refusal has a code.

In this 65-second cut, one engine answers scripted worst cases in 9 domains: autonomy, robotics, healthcare records, cloud SRE, quant risk, multi-tenant SaaS, a GPU scheduler, treasury, and crash and flood.

Each verdict on screen is the answer line of a real process. Each result count, time and memory value is measured in that take. The request values and the rule bounds are scripted.

The limits, stated plainly:
- end_to_end=false.
- The engine is a native Rust check. It is not proved.
- The requests are scripted. One live model call is shown as it happened.
- A SIGKILL is not a power loss.

The repo and the steps to reproduce are in the reply.
```

### Post 2 (reply, with links)

```text
Repo: https://github.com/mack-dot/forge

Reproduce the take (macOS ARM64; rustc, Dafny, Node 24.3.0):
git clone https://github.com/mack-dot/forge
python3 bin/forge-airlock build --checker
python3 demos/video_cut/run_recording_take.py --auto
python3 demos/video_cut/test_video_cut.py

Quickstart: https://github.com/mack-dot/forge/blob/main/docs/quickstart-5min.md
Engine protocol and trust boundary: https://github.com/mack-dot/forge/blob/main/src/airlock/PROTOCOL.md
Storyboard, domain mapping and gaps: https://github.com/mack-dot/forge/blob/main/docs/VIDEO_STORYBOARD.md

end_to_end=false. The engine is a native check, not proved. "Proved" applies only to a part with a machine-checked proof: in this take, the Dafny source of the booking checker. The CakeML/HOL4 refund chain has an open premise (M1-B OPEN). The take runs with one OS user for the agent, the store and the human key.
```

The three `blob/main` links work only after the branch is merged to
`main`. Before the merge, Post 2 must name the branch (checklist item 8).
The branch is merged: pull request 75, `ccdd8e5f` (2026-11-20).

### Show HN

Title (74 characters):

```text
Show HN: Forge – a policy check between AI agents and irreversible actions
```

Intro:

```text
Forge is a small engine that sits between an AI agent and an action that has no undo. The agent sends a request. The engine checks it against a pinned policy file and answers with a code: COMMITTED, REJECTED_POLICY, REQUIRE_HUMAN_COSIGN, STALE_STATE_HASH, TENANT_ISOLATION_BREACH and others. A commit is a record in a write-ahead log.

The video runs one take. It sends scripted worst cases of nine domains to the engine: a ship AI that asks to vent a bay, a robot arm above its speed bound, a read that holds a row of another clinic, a delete of 8 of 10 pods, an order storm, 50 processes that race on one key, an overbooked GPU schedule, an injected $50,000 payment, and a SIGKILL during a log append. Each verdict on screen is the answer line of a real process. Each result count, time and memory value is measured in the take; the request values and the rule bounds are scripted. The runner also deletes one guard in a copy of the engine and shows that the same check then fails.

What it is not:
- end_to_end=false. No result here is a proof of a deployed system.
- The engine is Rust, tested with finite tests. It is not proved.
- "Proved" applies only to a part with a machine-checked proof. In this take that is the Dafny source of one checker (the booking certificate checker). The CakeML/HOL4 refund chain has an open premise (M1-B OPEN), and the take does not use it.
- The engine has no rule for ships, robots or clinics. Each domain maps to the nearest real rule: an integer bound, a sum against a trusted fact, a required human signature, a tenant check on rows, a compare-and-swap. The mapping table and its gaps are in docs/VIDEO_STORYBOARD.md.
- The opener of a key is trusted for its facts. Whoever can write the store folder is trusted.
- A SIGKILL is not a power loss. The kill tests use a test-seam build of the same source.
- One machine, macOS ARM64. The requests are scripted; one live model call is in the video and is shown as it happened.

To reproduce: clone https://github.com/mack-dot/forge, run `python3 bin/forge-airlock build --checker` (rustc, Dafny, Node 24.3.0), then `python3 demos/video_cut/run_recording_take.py --auto`. Exit code 0 means that every required result was observed. Reports of a request that the engine should refuse and does not are welcome.
```

Related documents in the repository: [README.md](../README.md),
[quickstart-5min.md](quickstart-5min.md),
[demo-gauntlet.md](demo-gauntlet.md),
[PROTOCOL.md](../src/airlock/PROTOCOL.md).

## 9. Honest limits (the `limit|` lines)

The runner prints these lines in scene 4, in yellow. The text below is
the runner's text: one `scr.limit(...)` call of `scene4()` for each line.
The runner wraps each line at 100 columns, and each wrapped part also
starts with `limit|` (a continuation part has two more spaces). If the
runner changes, the runner is correct.

```text
limit| end_to_end=false
limit| SIGKILL is not a power loss: the take kills a process; it does not cut power to a disk
limit| OS uid: in this take the agent, the store folder and the human key belong to ONE OS user (uid [measured live], from os.getuid()). A real setup needs separation: the human key outside the agent's reach, and serve under another OS user that owns the store folder (src/airlock/PROTOCOL.md sections 7 and 11)
limit| model: ONE live model call in scene 1 (model id [printed by the runner]; [result of the call]). Every request to the engine is a scripted worst case; no model wrote them
limit| the engine is a NATIVE CHECK (Rust), not proved
limit| "proved" applies only to a part with a machine-checked proof. In this take: the Dafny source of the booking checker. The CakeML/HOL4 refund chain has an open premise (M1-B OPEN); no scenario of this take uses it
limit| RAM box: RSS of this runner plus the largest RSS seen for one engine serve process (/bin/ps, sampled after each shot); helper processes (Node) and processes that a module starts itself are not in it
limit| BLOCKED box: it counts only answers whose code is a refusal code of the engine (the table of src/airlock/PROTOCOL.md section 10, read in this run). [measured live] other lines (events, reports, reads of the state, direct checker answers, counted summaries) are shown as EVENT or OBSERVED and are in no box
limit| SAFE STATE box: "allowed" counts answers COMMITTED (a new effect record) and OK <n> (a released read) whose check passed
```

`[result of the call]` is `reply held the dangerous command: True` or
`... False` when the call answered with status 200, else
`the call failed: status <status>, <error type>`.

With `--no-model` or with no key, the model line is:
`limit| model: live model NOT IN TAKE. Every request to the engine is a
scripted worst case; no model wrote them`.

After these lines the runner prints the gaps of each domain: one line
`limit| -- gaps of domain <name>`, then one `limit|` line for each gap.
A part that a module could not run is one of these gaps, and it makes the
take PARTIAL. Section 5 holds the gaps in short form. More limits of the
engine are in [PROTOCOL.md](../src/airlock/PROTOCOL.md) section 11 and in
[quickstart-5min.md](quickstart-5min.md) (sections "What is proved and
what is not" and "Trust boundary"):

- The Slice 3 record has `end_to_end` false. It is of the Slice 3 issuer
  and sink, not of this engine.
- The booking checker is proved against its own `Accepts` predicate. That
  is a candidate spec, not approved intent. The Dafny compiler, Node and
  `bignumber.js` are trusted, not proved.
- `F_FULLFSYNC`, the macOS kernel and the drive are trusted.
- FNV-1a-128 is not cryptographic.
- The read airlock sees only the rows passed to it.
- The CakeML refund binary runs on macOS ARM64 only. No scenario of this
  cut uses it.
- A finite test shows the cases that ran. It shows nothing about other
  cases.
