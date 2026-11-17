# Round 2 task 5 — tool rebuild under the 90-minute budget (U424)

Date: 2026-11-17. A TOOL BUILD. Not a proof. Not a replay. Owner
decision 2: rebuild plus M1 replay within 90 minutes wall-clock, with a
lock marker. Start 12:42:33 local; hard stop at 5,400 s.

## Result

| Command | Exit | Wall seconds |
| --- | --- | --- |
| clone and checkout of Poly/ML, HOL, CakeML at the pinned commits (`4557554…`, `9783a49…`, `cd91556…`); three pin checks | 0 each; all match | 89 |
| Poly/ML configure, make, compiler, install, version | 0 each | 228 |
| HOL `smart-configure`, `bin/build` | 0; 0 | 26; 685 |
| CakeML `Holmake` in `basis` | 0 | 3,685 |
| CakeML `Holmake` in `compiler/backend/proofs` | killed at the deadline after about 686 s | — |

After the stop: 147 CakeML theories exist (44 under
`compiler/backend`); `basis/basis-heap` exists; the folder is 1.5 GB;
no build process was left running. Records: `records/commands.json`
and `records/addendum.json`. Logs: `results/round2-m1-rebuild-20261117/
attempt-0001` (local).

Script defect (mine): at the deadline `rebuild.py` crashed in its kill
path (`PermissionError` on the second signal), so its own record has no
row for the last command. The addendum states this. The script is
corrected for a later run.

## Against the decision

- Step A (replay of the committed M1 chain, SHA-256 of the executable):
  NOT RUN. The budget ended in the CakeML compiler proofs. Still
  missing before any M1 theory can load: the rest of
  `compiler/backend/proofs` and the ARM64 proofs, the in-logic compiler
  (`cv` translation), the ARMv8 step heap, then about sixty Forge
  theories in order (each took 1 to 3 minutes; the compile step took
  45 minutes). Upstream states about 20 hours for a full CakeML build.
- The tracked copy of the executable has the right SHA-256 (file
  identity; checked earlier). That is not a rebuild of the executable.
- Step B (`fs-0001`, `fs-0002`): NOT RUN. The decision allows it only
  after the replay passes.
- Lock marker: `.toolchain/experiments/DO-NOT-DELETE.md` and `.keep`.
  The folder is ignored by git; the marker protects only against
  people and agents that read it.

## What is possible now, if the owner allows it

- Continue the build: `Holmake` is incremental; a second run of
  `rebuild.py` with a new budget continues where this one stopped.
- The input-premise lemma of U413 (`∃fs cl. wfcl cl ∧ wfFS fs ∧
  STD_streams fs ∧ stdin_content fs = SOME inp`) needs only the basis
  theories, which are built. It does not need the M1 chain. It was not
  run because Step B is gated on the replay.
