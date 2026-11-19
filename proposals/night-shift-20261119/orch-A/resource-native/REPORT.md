# A6 resource stops, outcomes, native ledger (condensed by Orchestrator A; HOL NOT RUN; tactics UNCHECKED)
- Files: `P9a_v2.sml` (06070350…), `RUN_PLAN_P9a.txt`, `P9a-audit.txt`, `outcome-table.txt`, `native-ledger.txt` (30 rows).
- P9a draft route was wrong (placeholder names; `installed` open; unspecified `oracle`); v2 follows real-0004 → nonfail-0002 → e4.
- Vacuity risk (by reading, dataSemScript.sml:599-607): one executed `FromList` block with ≥ 4 elements makes
  `safe_for_space` false for every limit; then A-SPACE is false and P9a is vacuous. UNKNOWN for the refund run (control N4).
- Outcome table of the stored theorem `refund_profile_a_sl_every_machine_run` (e4 stdout 297-331):
  Terminate Success ALLOWED (complete output); Terminate Resource_limit_hit io' ALLOWED with io' ≼ io (empty … full);
  FFI_outcome, Diverge, Fail EXCLUDED.
- For a FREE `ext` oracle the witness trace may end with an `ext` event that resets the file system
  (basis_ffiScript.sml:146-150): then a non-prefix fd-1 output passes. At `ext = no_ext` the exclusion needs two lemmas
  that are not stored (prefix; ext-independence). L-OUT fixes `no_ext`.
- Exit: model Success is x0 = 0 in 64 bits; real `cml_exit(int)` tests 32 bits; status = low 8 bits.
  x0 = 2^32: model Resource_limit_hit, process status 0 with empty stderr.
- Native ledger: FALSIFIED: A-FFI-ALL (U393), A-EXIT-STATUS. UNKNOWN (no source in the repository): TBI, SA0, endianness, EL0.
  New untested risks: a write error (EPIPE) may end as an uncaught exception that the semantics classes as Success
  (status 0 with cut output); a caller that merges stderr into stdout breaks the prefix property.
- Consumer rule that follows: authorize only on status 0, no signal, empty stderr, and a strict parse of ONE complete frame.
