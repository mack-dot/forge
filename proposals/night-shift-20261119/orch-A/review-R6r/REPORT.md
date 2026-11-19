# Review of R6r-0004 (condensed by A, 2026-11-19T16:20:24Z); verdict HOLDS WITH LIMITS; full text `r6/review_R6r-0004.txt`
Machine-checked: 9 theorems, 4 definitions (theory forge_refundR6Read); actual exit 0; stderr empty; tags DISK_THM only;
4 bool axioms; used-files pre = post; not vacuous. `read_event_ok_refund` gives `refund_valid_event` for fd 0.
`refillBuffer_with_read_spec_V` matches the real call shape (n = 4096 on the 4100-byte buffer).
Limits (the claim "read-side bottom layer" must be read narrowly): only `refillBuffer_with_read` and its STR wrapper are
covered; the specs keep an invariant on the file-system FFI events, they do not reach the semantic `io_events` list;
side conditions remain (4100-byte buffer, `read_event_ok`, `IOFS_V` with the 2052-byte iobuff).
NOT given: V-specs for openStdIn, refillBuffer_with_read_guard, inputBuff, inputAll_aux, inputAll, input1, consume_rest,
open_option, inputAllFrom; the refund main V-spec; IOFS_V_init (staged); the eval_state bridge; the link to io_events;
the transfer to the machine level; "no close/open_in call".
Record defect: the header of R6r-0004.sml names R6r-0003 and does not say the 8 guard lines changed (recorded in
ATTEMPT_COUNTS.md by A).
