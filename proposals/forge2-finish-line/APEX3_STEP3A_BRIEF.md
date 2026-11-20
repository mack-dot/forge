# APEX-3 step 3A team brief: the WAL fold inside HOL4/CakeML (item F2.7), design and estimate only

Status: READY, NOT STARTED. Start condition: the Goal 20 PR is merged on `origin/main`. Runs alongside F1.
Owner text: `proposals/forge2-native-silicon-sink/OWNER_TEXTS.md`, Text 7, "GATE APEX-3", step 3A (the
directive asks for a 12-line HOL4/CakeML design and wall-time estimate, then a pause for the owner's budget
approval before `cake_compile`).

## Scope of 3A

- Output: one 12-line design plus a wall-time and risk estimate, printed for the owner, plus a supporting
  record `proposals/forge2-apex3-wal-fold/DESIGN_3A.md` on a branch `docs/apex3-step3a-design` and a PR.
- Allowed: reading code, records and logs; small static measurements (line counts, existing HOL timing logs).
- NOT allowed in 3A: `cake_compile`, `Holmake` proof runs, any HOL process (the HOL slot belongs to 3B and to
  APEX-2), any change to `src/silicon_sink/sink.rs` or to protected or frozen paths.
- Every number comes from a committed artifact or a command run in 3A, with its source. No number from prompt text.

## Questions the design must answer

1. Exact boundary. The launcher's recommended shape: the CakeML program reads the WAL bytes and one request on
   stdin and writes either a refusal or the new 64-byte record on stdout (a pure function over bytes); a minimal
   unproved layer keeps only `flock`, append and `F_FULLFSYNC`. Compare with the owner text's shape (CakeML
   calls a <= 60-line C `basis_ffi` stub for `flock`, `write`, `fcntl(F_FULLFSYNC)`). State which keeps the
   proved part on the stdin/stdout path that Route A already models, and what each adds to the FFI premise
   (owner item A-3: the C FFI aborts where the model returns an error byte).
2. What moves into HOL: the fold of `scan()` (`sink.rs` lines 82–100), torn-tail and ratchet handling of
   `open_ledger` (lines 106–126), the commit checks of `commit()` (lines 162–188), CRC-32 and FNV-1a-128, and
   the R1–R5 decision. Count the real lines and name every function.
3. Theorems for 3B: `sum(committed) <= original`, one commit per `request_id`, epoch monotonicity, R1–R5 on
   every accepted transition, and the frame exactness of the output. Name the existing HOL results to reuse
   (night-shift A: L-OUT, prefix PF-0004, MF-0002; Route A; M1 chain) and the gaps (X8: a real run gives a
   trace; T14 part a).
4. Cost: wall time per stage from recorded HOL and `cake_compile` logs on this machine (memory, swap, AC);
   number of HOL jobs; the dependency on APEX-2's contract link.
5. Risks and a fallback: what is proved if the full fold does not close (for example: the fold proved at the
   CakeML source level only, or for a bounded WAL length).
6. Honest limits that remain after 3B: kernel, drive, loader, CPU-to-model correspondence; `end_to_end=false`.

## Team (Fable orchestrator, up to 5 Opus workers, read-only)

1. HOL4/CakeML specialist: existing theories, `cake_compile_heap` pipeline, Route A, reuse map.
2. Rust sink analyst: exact semantics of `sink.rs`, the fold, recovery and commit paths, line inventory.
3. FFI and boundary specialist: the two boundary shapes, `basis_ffi`, A-3, the stdin/stdout model.
4. Estimator: timings and memory from recorded HOL and CakeML runs; resource plan for 3B.
5. Adversarial reviewer (fresh context, given the design, not the conclusions): weak premises, hidden
   unproved glue, numbers without a source.

## Finish

Commit the record, push the branch with an explicit refspec, open a documents-only PR without admin bypass,
print the 12-line design and estimate, and STOP for the owner's budget word. No 3B work.
