# Corrections to X8 statement v2 from the adversarial review (2026-11-19T15:41:08Z); BY READING; v2 file unchanged
Source: `review/X8_v2_review.txt` (sha256 c04f73dd9b8f…a772). Nothing is machine-checked.
FALSE in v2 (must be repaired before any use):
- F1 ML-05 L-GHOST has no `PSTATE.EL = 0w` premise; at EL2/EL3 `Next` reads fields v2 treats as ghost. Add the premise.
- F2 N01 leaves `exception` of the abstract state free; with `exception <> NoException`, `NextStateARM8 = NONE`, so the
  premise cannot hold and X8 is vacuous. Require `exception = NoException`. ML-09 has the same gap.
- F3 (E4) gives `numchars` one entry per FFI call; only read and write consume it. Index by reads and writes only.
Gaps: G1 no native row for close/open_in (model close of a std stream returns 1; the real close returns 0);
G2 ML-10 must cite the erase bridge for the 27 entry steps; G3 MG-0001 is not usable on this route as is (its contract
premise is at VokY3 and it has R6): the route rests on MF-0002 only (all 11 premises have a discharger, by reading).
Wording: N03 must compare only the bits L3 reads (EL, SPS, SCTLR_EL1.A/E0E/SA0, TCR_EL1.TBI0/TBI1); N10/N12 are false
for calls with n = 0; no FP/SIMD field exists in `arm8_state`; trace end and H event index; demand paging in `rstate.mem`.
HOLDS by reading: index by normal steps; the LEAST-k repair; no circularity; the killed clause (given F3 repaired).
Open check: are close, open_in or 0-byte writes reached in a real run of the executable?

## Addendum 2026-11-19T17:12:10Z: leads on X8 v3 from the red team's last reading audit (static; not checked by A; v3 file unchanged)
- Stale: v3 line 317 says MT-0001 is not run (it has actual exit 0 now); v3 says the launcher is not implemented (a
  prototype exists, tested only).
- N01 in v3 quantifies over more states than in v2; it can hold only if ML-05 (MISSING) is true; if ML-05 is false the
  statement is vacuous. This change is missing from the list of changed clauses in v3.
- Clause C6 says N05, N07, N08, N10, N23 "must be ENFORCED by the launcher": no launcher can enforce them; they are
  ASSUMPTIONS.
