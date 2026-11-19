# A3 L-OUT / L-EXIT-0 (worker report, condensed by Orchestrator A; HOL NOT RUN; all tactics UNCHECKED)
- `L_OUT_v2.sml` cannot pass as written: D1 `no_ext` is polymorphic (INST type mismatch at :338; control at :409);
  D2 `drule STD_streams_stdout` takes the wrong assumption (:306); D3 `LUPDATE_def` is not a simp rule.
- `L_OUT_v3.sml` (553233ce…) and `L_EXIT_v3.sml` (af413707…): tactic-only repairs; no v2 statement changed; one positive
  control lemma added (`P_O4_partial_write_counts_nw`). Plan: `RUN_PLAN_out_exit.md`. Do NOT run L_OUT_v2.
- Statement reading: L-OUT true in the model; the model never fails a write on fd 1 (`liveFS`), so a real `write` = −1
  has no model counterpart. NATIVE assumption A-FD1-WRITE (call sequence is a model trace; 0 ≤ nw ≤ n; progress; no
  other writer to fd 1). C/model divergence candidate: `byte8_to_int` truncates to `int` (basis_ffi.c:132-136).
- L-EXIT-0: every `Halt` comes from targetSemScript.sml:138-140, 172, 196, 211. x0 = 2^32 with status 0 stays possible
  as far as stored theorems show. The halt-value range is not derivable (agrees with G6).
