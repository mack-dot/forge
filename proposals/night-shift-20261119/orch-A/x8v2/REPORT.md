# W-x8v2 report (condensed by A, 2026-11-19T15:08:52Z); BY READING, NOT machine-checked
File `x8-x11/X8_statement_v2.txt` sha256 77822531d7ea…9a22 (473 lines). Six corrections applied (table in its section 2).
Model lemmas: 14 MISSING (T-ENV-NEXT, T-ENV-FFI, T-ENV, T-FS, L-GHOST, L-X18-DECODE, L-SP-NOWRITE, L-UNTAGGED-RUN,
L-ERASE-RUN, T-ENTRY27, T-TRACE, T-KILLED-PREFIX, T-INFLIGHT, T-X8-COMPOSE); 2 STAGED (MT-0001, NV-0001; not run).
Native assumptions: 22 (15 ASSUMPTION; 7 ENFORCED-BY-LAUNCHER, launcher NOT implemented, so assumptions today).
Weaker than v1: W1 (nothing concluded when a native premise fails); W2 (killed runs: stdout is a prefix of fd1_written
of an extension of the observed events).
Open doubts: D1 L-GHOST may be false if an L3 step reads a ghost field; D2 A-F0-REAL is strong; D3 counter k versus
Vok (LEAST repair unchecked); D6 U2-U4 only for slide 0; D8/D9 cut-run treatment; D12 two cited theorems from earlier
sessions without a go.log line; D13 real-run types are not HOL definitions.
