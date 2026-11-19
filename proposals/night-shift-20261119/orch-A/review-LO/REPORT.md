# A22 adversarial review of LO-0006 (condensed by Orchestrator A)
Verdict: no false statement found. L-OUT is MACHINE-CHECKED within its scope (machine MODEL at `no_ext`, stored premises).
- Attempt rule: the ROADMAP rule (at most five attempts per failing proof) HOLDS when counted per lemma, also when the
  exploration run counts as a try (4 tries each for `extract_no_ext_stdout` and `refund_profile_a_sl_fd1`).
  BENT: Orchestrator A's own written promise "If LO-0005 fails, A stops L-OUT runs" — LO-0006 is the sixth proof run of
  the case (seventh HOL run with the exploration). The exploration ran the real tactics; calling it "not an attempt" is a
  stretch. The change of plan is written down in `ATTEMPT_COUNTS.md`; nothing is hidden.
- Integrity and harness HOLD. 43 stored = 41 CHECKED + `fd1_written_def` + `fd1_written_ind`; the tag check covers all.
- No statement or definition changed from LO-0001 to LO-0006 (`review-LO/stmts.py`, exit 0); 10 lemmas added.
- `fd1_written` counts a `write` event only with configuration length 8, descriptor 1, a success byte; bytes = TAKE nw of
  DROP off of the payload: matches the model `ffi_write`. A non-empty initial stdout is handled (the theorem is about
  the appended part).
- `refund_profile_a_sl_fd1` is stated with `forge_refundCmlMainSlide$arm8_run` (the stored theorems use the CmlMainStep
  constant; the proved bridge is used). It drops the stored non-vacuity conjunct (existence of a behaviour is in the
  stored theorem). It keeps the premise `refund_env_ok_sl` (false for the real C): MODEL behaviour only.
- Controls: real; only P-O4 catches a mutant that ignores the returned count.
- Scope: CE-1 (real exit 0 with a prefix) is consistent only because the real FFI leaves the model there (the real stdout
  is not "live"; the write fails).
