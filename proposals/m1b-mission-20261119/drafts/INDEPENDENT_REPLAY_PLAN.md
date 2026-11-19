# M1 independent replay: plan (DRAFT, W4, step I.4c, 2026-11-19)

Status: PLAN ONLY. Separate owner authorization needed
(`M1_PROFILE_DECISION.md` section 5, step 7, on the backup branch: "O6
independent replay (separate authorization)"). `end_to_end=false`. A
pass does not prove M1; it shows that another person on another machine
gets the same theorems from the public sources.

Base: `M1_PROFILE_DECISION.md` section 6 ("Required independent replay
evidence") on `origin/backup/forge-local-2026-11-11`. Every item there is
kept below; this plan adds detail.

## 1. What "independent" must mean

1. Machine: not the owner's Mac. Not a clone of its disk. No shared
   file system with it.
2. Operator: a person (or agent) who did not write the M1 proof scripts.
   Ideally not the same AI session or agent family that wrote them. The
   2026-11-18 replay was "same machine, same pins, same agent family"
   (REPORT.md); that is the gap to close.
3. Sources: the operator clones the PUBLIC repository by themselves, at
   the commit named in the manifest, and checks the commit hash.
4. Tools: the operator clones Poly/ML, HOL4 and CakeML from their
   upstream URLs and checks that `HEAD` equals each pinned commit. The
   commit hash is the upstream identity; the operator checks it on the
   upstream host's web page or API as well (published hash).
5. Statement checker: the operator writes (or takes from a third party)
   a checker that is apart from the proof scripts. It loads the built
   theories and compares the exact statements of the listed theorems,
   their closure axioms, oracle tags and hypothesis count, against the
   manifest. It must not reuse the project's `*-imp*.sml`, `audit`,
   `check` or `import` scripts. The operator may READ them.
6. Nothing built by the project is sent (section 3).

## 2. The package the operator gets

All files are in the public repository; the project sends only a link
and the manifest hash.

- `MANIFEST.json` (draft: `MANIFEST_DRAFT.json` next to this file):
  - repository commit; source files with SHA-256 (from
    `plan.json`, `plan-phase2.json`);
  - pins: Poly/ML `4557554077078decce4ce5f90da00a713cfc32e4` (5.9.2),
    HOL `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`, CakeML
    `cd9155694c16831373ab695a670794f23282ed62`; configure flags;
  - the extra upstream targets that `rebuild.py` does not build (16
    theories, 3 library objects);
  - the 95 theories in build order, with source, runner kind, heap,
    parents, and recorded `.dat`/`.sig`/`.sml` SHA-256 (as information;
    see section 5);
  - the theorems to check, with exact statement text: at least
    `forge_refundSlideProfileA.refund_profile_a_sl` (text: stdout of
    `e4-0001`, lines 239–266 of the tracked log), the 4 `CHECKED`
    theorems of `e4-0001`, the joint-premise theorem
    `forge_refundInputSat.refund_profile_a_sl_all_premises_satisfiable_at_0x4000`,
    and each theorem that an import check of the 158 cases names;
    NOT YET EXTRACTED as a list (owner question Q-I5);
  - expected closure axioms (`bool.SELECT_AX`, `bool.INFINITY_AX`,
    `bool.ETA_AX`, `bool.BOOL_CASES_AX`), oracle tags (`DISK_THM`), 0
    explicit hypotheses;
  - the executable digest `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`
    (238,776 bytes), its tracked path, and the three slices with
    offsets and SHA-256;
  - the 158 cases with expected exit and expected reason.
- `INSTRUCTIONS.md`: the order of section 4, the rules (one HOL process
  at a time is a project rule for the owner's Mac; the operator may run
  in parallel on their own machine if memory allows, and must say so),
  and the report format.
- The Profile A text and the premise ledger (when approved), so the
  operator can judge the statement, not only its bytes.

## 3. What the project must NOT send

- No heap (`cakeml-heap`, `cake_compile_heap`, `arm8-heap`, `l3-heap`,
  `basis-heap`, `hol.state`).
- No built theory file (`.dat`, `.sig`, `.sml`, `.uo`, `.ui`), no `.hol/`
  folder, no Holmake cache, no tarball of the tool tree.
- No copy of the owner's `results/` folders.
- No pre-run output that the operator could copy into a report
  (`stdout.log` files are in the public repository; the operator must
  produce their own and compare).
- No credentials. No access to the owner's machine.

## 4. What the operator does (order)

1. Clone the repository; check the commit; record `git status`.
2. Check the SHA-256 of every source in the manifest.
3. Build the tools from the pins (the project's `rebuild.py` is a
   reference only; the operator may write their own build commands).
   Build the extra upstream targets.
4. Build the 95 theories in the manifest order. The project's runners
   embed `<HOME>/forge` (121 of 301 source files on the backup
   branch); the operator applies a path map and records it per file.
5. Run the `fs` joint-premise script and the 158 cases.
6. Run their own statement checker on the built theories.
7. Hash the executable and the three slices with their own tool.
8. Report (section 6).

## 5. Hardware: does it need macOS on arm64?

What the records show:
- Every local result so far is macOS on Apple arm64 (U439: "every local
  result is macOS and the local profile").
- The proofs are about models: the CakeML semantics and compiler, and
  the L3 ARMv8 model (`arm8_step`). The executable is read as bytes
  (`forge_refundImage`, `BinIO`; U389 records "native_execution:
  NOT_RUN"). No proof step runs the executable. So the proof replay
  does not need an arm64 CPU or macOS in principle.
- Poly/ML, HOL4 and CakeML are built on Linux x86-64 upstream; that is
  general knowledge, NOT checked in the records.
- NOT KNOWN from the records: whether HOL `.dat`/`.sig`/`.sml` bytes
  are equal across operating systems, CPU types or Poly/ML builds.
  The records show byte equality only on this Mac, after a rebuild with
  the same pins.
- `rebuild.py` sets Homebrew gmp paths (`/opt/homebrew/opt/gmp`); a Linux
  build needs its own gmp. Poly/ML configure flags must stay the same
  (`--enable-intinf-as-int --with-gmp`).
- Resources (records): peak 4,768 MiB for one HOL process; 158 cases up
  to 4,337 MiB. Proposal: at least 16 GiB memory, 4 cores, 40 GiB free
  disk (estimate). Awake time on this Mac about 11.7 h plus the ARMv8
  heap build (sums in `CLEAN_REPLAY_PLAN.md` section 6); other hardware
  will differ.

Proposal: allow Linux x86-64 or macOS arm64 (owner Q-I3). On Linux, byte
equality of theory files is reported but is not required; statement
equality by the independent checker is required (section 6).

## 6. Acceptance criteria

1. Repository commit and all source SHA-256 values equal the manifest.
2. Three tool commits equal the pins; the operator confirms each hash on
   the upstream host.
3. 95 of 95 theories build with exit 0 from sources only (no cache).
4. Independent checker: for each listed theorem, the statement is
   alpha-equivalent to the manifest statement (term comparison, not
   text); closure axioms exactly the four `bool` axioms; oracle tags
   exactly `DISK_THM`; 0 explicit hypotheses.
5. On macOS arm64: `.dat`/`.sig`/`.sml` SHA-256 equal to the manifest
   values (95 rows). On another platform: reported; a difference is a
   finding to explain, not by itself a failure, if item 4 holds (owner
   Q-I3 decides).
6. The joint-premise theorem builds and passes the operator's own check.
7. Each of the 158 cases ends with its recorded exit and recorded
   reason (for a control: the same failing check). The 45 controls with a
   recorded non-zero exit still fail; the 10 controls with a recorded
   exit 0 give their recorded markers (classes by name heuristic,
   `plan-phase2.json`).
8. Executable SHA-256 and the three slice SHA-256 values equal the
   manifest, computed by the operator's own tool; the operator also
   derives the three offsets again from the Mach-O header (second
   derivation, as section 6 of the profile decision asks).
9. The Dafny contract-side proofs of O1 re-verified with the pinned
   Dafny (from section 6 of the profile decision; pin to be filled).
10. Peak memory, disk, wall time and platform recorded.

How a failure is recorded: the operator reports the real exit, the step,
the log excerpt and their classification. The project writes a new
`unsure.md` entry with the operator's text quoted, keeps the failure, and
does not repair a proof inside the independent run. A failure blocks the
O6 item. A fix needs a new commit and a new independent run.

## 7. What the operator reports

- Operator identity and relation to the project; machine (CPU, OS,
  memory); dates.
- Commits used; source check result; tool pins and the upstream hash
  confirmation.
- Every command with exit code and wall time; peak memory; disk.
- Table of 95 theories: exit, fresh hashes, equal or not.
- The checker: its source (published), and its result per theorem.
- 158 cases: exit and reason per case; list of differences.
- Executable and slice hashes; derived offsets.
- Deviations: path map, any extra upstream build, any manual step.
- A signed statement (owner to decide the form; Q-I4).

## 8. Open questions for the owner

- Q-I1: Who is the operator? A person (who), a second AI vendor, or
  both? A second AI vendor is independent of this agent family but not
  of the AI method; a person is slower.
- Q-I2: Budget: machine time (estimate 12 to 22 h awake on hardware like
  this Mac) and the operator's cost.
- Q-I3: Platform: is Linux x86-64 allowed, and is statement equality
  (not byte equality) enough there?
- Q-I4: Form of the report: signed commit, signed tag, or a signed file;
  where it is published.
- Q-I5: The exact theorem list for the checker (only the final theorem
  and the joint-premise theorem, or every theorem of the 95 theories).
- Q-I6: Must the clean replay pass first? (Proposal: yes.)
- Q-I7: Which commit is frozen (the backup branch holds the sources;
  `main` does not).
- Q-I8: Is the Dafny side (O1) part of this replay or a separate one?

## 9. Not found in the records

- A tool-build peak memory, the ARMv8 step heap build time, the gmp
  version, the Dafny UTF-8 library commit (U262, not read here).
- Any cross-platform result.
- A tracked list of all theorem statements in machine-readable form
  (statements exist inside `.dat` files and in stdout logs only).
- Upstream tarball digests (only commit hashes are recorded).
