# Review of NN-0002 (condensed by A, 2026-11-19T17:06:33Z); verdict HOLDS WITH LIMITS; full text `nonneg/review_NN-0002.txt`
Machine-checked (exit 0; 9 theorems; DISK_THM only; no hypothesis): for every request the printed amount is >= 0 and the
count is 0 or 1; N4: for every prefix `out` of the rendered program output, a successful HOL strict parse gives
0 <= amount, 0 <= count <= 1. Constants are the ones of the chain (checked).
Limits and wording corrections (A accepts all): "the two parsers agree on program output" is an OVERCLAIM: N4 is about
the HOL parser only. "Python is strictly stricter" is NOT proved (C1 shows only that HOL accepts strings Python refuses).
O1 inherits the premise `refund_env_ok_sl` (false for the real FFI, U393), so O1 may be vacuous; O2 keeps open premises.
Residual of T14 part a (UNPROVEN; tested by the red team only): R1 the Python render = the HOL render on non-negative
tuples (integer spelling; string escaping; tag, booleans, spaces; one char = one byte); R2 the Python runtime is trusted;
R3 the channel; a formal route: transcribe the Python render into HOL and prove equality.
Dangerous direction (Python accepts a frame with another value than HOL): none found by reading. Noted: an amount over
4300 digits makes Python int() raise ValueError (a crash, not an acceptance; safe only if no caller maps an unexpected
exception to acceptance); raw NUL or CR inside quoted atoms is canonical in both; the lenient readers in frame.py must
not be the deployed consumer (not checked).
