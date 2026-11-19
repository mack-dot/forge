# A32 adversarial review of R6ffi-0002 (condensed by Orchestrator A)
Verdict: the 4 theorems and 3 definitions are MACHINE-CHECKED; the statements are the right base for R6.
- EVIDENCE GAP (defect of the record, no sign of tampering): the three files read with `use` (`round5/r6_common.sml`
  844de8f1…, `r6_steps.sml` af5df6d9…, `r6_prove.sml` 11261945…) are bound nowhere in the run record; their mtimes
  (11:08:17Z) are before the run start (11:12:01Z) and unchanged. Second gap: the print depth elides the statements in
  stdout; the full text is in `r6_common.sml:141-154` and in the `.dat`. Fix made by A for later runs: the wrapper hashes
  the `use`d files before and after each run (`<case>.used-files.pre.txt`, `USED_FILES_UNCHANGED`).
- Harness HOLDS: one `TAC_PROOF` per statement; conclusion checked `aconv` to the statement; no hypotheses; tag check over all.
- Definitions: `IOxV` = the standard IO predicate with `EVERY Inv events` inside the existential; `IOFS_V` pins the iobuff
  length to exactly 2052 (the standard predicate has ≥ 2052); `STDIO_V` otherwise equal. `IOxV_IMP_IOx` forgets the invariant.
- The V-specs = the originals plus a hypothesis H_inv about the one new event (for all new-byte lists of the right length
  with success byte); `read_into_spec_V` has two more hypotheses that exclude the error paths. For
  `Inv := refund_valid_event` H_inv is dischargeable at the program's calls (by hand; UNCHECKED in HOL). A zero-byte read
  is covered and is a valid event.
- MISSING for R6: a small lemma that descriptor 0 has content and ReadMode under `STD_streams`/`wfFS`; the V-versions of
  the callers; the main program; the link from the heap events to the semantic event list; the machine transfer; proof
  that close and open_in are never called.
- For the write side: `write_spec_V` must quantify H_inv over the changing (n', i') and needs `LENGTH rest = 2048`.
