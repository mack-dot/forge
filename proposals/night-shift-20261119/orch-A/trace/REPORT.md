# W-trace report (condensed by A, 2026-11-19T15:37:23Z); static only; NOTHING machine-checked
Case TR-0001, theory forge_machineTrace; exploration TRx-0001. Files: tr_common.sml (53d552c0…), tr_steps.sml
(075aa139…; 41 lemmas, 33 required, 8 optional), TRx-0001.sml (0cbeee55…), TR-0001.sml = trace_v1.sml (4bee1d6b…).
Statements: T-TRACE `evaluate_follows_trace`, T-IO `trace_io`, T-PREFIX `trace_terminate`, `trace_fail`, optional
Diverge; guard facts; toy controls (non-vacuity and a rejected bad trace). Two counters: next_interfer advances on
TrStep only; ffi_interfer on TrFfi only (correction 2). Worker's own estimate of a full proof at first run: 15 %.
Staged in the run folder: `./nightshift-run.sh TRx-0001 1200 deps-TR.txt` — NOT RUN.
