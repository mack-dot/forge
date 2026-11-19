# A34 adversarial review of R6w-0004 (condensed by Orchestrator A)
Verdict: no defect. The 16 theorems and 1 definition are MACHINE-CHECKED. The claim holds at the characteristic-formula
heap-predicate level, conditional on a `STDIO_V` precondition; it does not yet reach the semantic event list.
- Integrity HOLDS; the earlier gap is closed for this run: `used-files.pre.txt` and `.post.txt` exist, are byte-equal, list
  the shared files; `USED_FILES_UNCHANGED true`. Residuals: the lists are side files bound by a 16-hex prefix in the go log;
  a window of seconds between the wrapper's hash and HOL's `use`.
- Harness HOLDS (one `TAC_PROOF` per statement, `aconv` to the statement, no hypotheses; tag check over all; 4 bool axioms;
  `ASSUME` only in the exploration files, not reachable from the proof file).
- Statements: each V-spec equals its original after the predicate substitution, plus `write_event_ok Inv fd` (and
  `LENGTH rest = 2048` for `write_spec_V`). `write_event_ok_refund` is proved and not vacuous; `n2w2` cannot wrap because
  `i + n ≤ 2048`. `IOFS_V` pins the iobuff to exactly 2052.
- Program path: `print s = output stdOut s`; `stdOut` is a constant (no FFI); no flush; chunks of 2048 and partial writes
  are covered; the refund program calls `TextIO.print`.
- OPEN for R6: (a) read side and the descriptor-0 lemma; (b) the main-program specification under `STDIO_V` (success and
  exception paths); (c) the initial heap: `STDIO` with no events gives `STDIO_V`, incl. the exact 2052-byte iobuff;
  (d) the link from the fs-part heap events to the whole semantic `io_events` list (events of the other FFI parts must be
  excluded); (e) the machine transfer.
