# Bridge 2: single-input dual-check issuer bridge (task x-bridge2)

Status: DESIGN + reference code + finite tests + a Dafny MODEL. Nothing applied. M1-B stays OPEN.
Classes: MACHINE-CHECKED (model only) / ASSUMPTION / TESTED-UNPROVED / MISSING. Repairs `x-issuer-bridge`.

## 1. Interface: one data input
`bridge2(candidate, *, checker, binary_path, launch_fn, pinned_sha256, ...)`. The ONLY data input is the
candidate `(pre, t)` with `t = (request, post, intent)`. The checker (compiled `RefundFinality.Check`) and the
pinned binary are configuration. There is no parameter for native inputs or for checker fields. The bridge
derives both sides itself:
- (a) native inputs `x := Encode(pre, t.request)` = (UTF-8 chargeId, UTF-8 requestId, original, remaining,
  enabled, opened=True, candidate=True, amount, UTF-8 reason); stdin = `frame.render_request(x)`.
  `t.post` and `t.intent` are never sent.
- (b) the expected native result once Check issued: `AuthTuple(x) = (True, x.amount, x.reason, x.charge,
  x.request, 1)`; the stdout must be exactly `render_fields(AuthTuple(x))`.
- `preStateSha256 := SHA-256(canon(pre))` (transcription of `encoding.ts` canon). The bridge passes it to
  Check and puts it in its OUTPUT token. The signer must use that value and must not recompute pre.

## 2. Decision (first failing step decides; `decide2.py`, modelled as `Bridge2` in `dafny/Bridge2.dfy`)
1. `in_range(candidate)`: strict types (`bool` is not `int`) on every field of pre, request, post, intent;
   texts sent to the program: no U+0000, strict UTF-8, at most 256 UTF-16 units; integers sent: 0..2^63−1.
   Else `OUT_OF_RANGE` (no checker call, no launch). `decide2` repeats this check (reviewer E6).
2. `checker(candidate, preStateSha256)` must return exactly `True` (Issue, |plan| = 1, token hash = input).
   Else `CHECK_REFUSE` (no launch).
3. ONE hardened launch on `x` (`launcher.py`, unchanged copy). Any unclean outcome refuses: `TIMEOUT`,
   `STDOUT_OVERFLOW`, `STDERR_NONEMPTY`, `SIGNAL`, `EXIT_NONZERO`, `STDIN_INCOMPLETE`, `BINARY_CHANGED`,
   pre-launch refusals. Model: all of these, and "strict parse fails", are `native(x) = None` → `NO_FRAME`.
4. Strict parse; the tuple must equal `AuthTuple(x)` with equal types, and the bytes must equal its render.
   Else `FRAME_NOT_AUTHORIZED_TUPLE` (this includes a canonical reject frame).
5. RECOMPUTE from the frame and pre: `post := pre with remaining − frame.amount`;
   `intent := (pre.chargeId, utf8(frame.request), frame.amount, utf8(frame.reason))`.
   `t.post ≠ post` → `POST_MISMATCH`; `t.intent ≠ intent` → `INTENT_MISMATCH` (typed comparison).
6. `SIGN` with token `{preStateSha256, requestId, post, intent}`, all RECOMPUTED (not taken from Check).
Any exception → `INTERNAL_ERROR` (refuse).

## 3. What the model proves (MACHINE-CHECKED about `Bridge2` only; `check`, `native` are parameters)
- (i) SoundNative: Sign ∧ CodecOk ∧ NativeOkOn(native, Encode(pre, t.request)) ⇒ F.Authorizes(pre, t) and
  token = Token(h(pre), t.request.requestId, t.post, t.intent). For EVERY `check`.
- (ii) SoundCheck: Sign ∧ CodecOk ∧ (check(pre,t) ⇒ F.Authorizes(pre,t)) ⇒ the same. For EVERY `native`.
- (iii) Complete: CodecOk ∧ InRange ∧ check right on (pre,t) ∧ native gives a frame meeting the flat
  contract ∧ F.Authorizes ⇒ Sign(that token). Witnesses: amount 40, amount 0, amount 2^63−1 sign; disabled refuses.
- (iv) AttackPostState: OLD shape (six fields from the token, same inputs), a checker that ignores post,
  the specification native: OLD signs a post-state 59 (correct 20); `!Authorizes`; Bridge2 → POST_MISMATCH.
  AttackSeparateInputs: OLD shape with x from pre (100,50) and pre = (100,30), amount 40, accept-all
  checker: OLD signs; `!Authorizes`; Bridge2 → FRAME_NOT_AUTHORIZED_TUPLE.
`CodecOk(env)`: dec∘enc = id; enc("") = ""; the three reasons are fixed points. UTF-8 with strict decode
meets it on the range of step 1 (ASSUMPTION here; TESTED by the unicode cases). `NativeOkOn`: a frame, if
any, meets `FlatContract` (text copy of SliceTheorem.FlatContract) on this ONE input. `None` is allowed.

## 4. Remaining common-mode failures (both checks pass together; the bridge does not help)
- CM1 shared input decoding: the issuer turns its message into ONE candidate; both sides see the same
  (possibly stale or forged) pre. Only the sink's comparison of `preStateSha256` with its stored state stops
  a stale pre. The bridge does not read the store.
- CM2 shared encoder: `encode`/`render_request`/UTF-8 feed the native side AND build `AuthTuple(x)`. The
  checker gets the strings, not the bytes. A chargeId mis-encoding is agreed by both (mutant `encode-latin1`
  is killed only by the UTF-8 literal test). Model: `CodecOk` is a hypothesis, not proved for the code.
- CM3 pre-state digest: computed ONCE, by the bridge (`pre_state_sha256`), passed to Check and output.
  If its canon differs from the sink's canon, honest tokens fail closed at the sink; if canon were not
  injective, a token could match another state. TESTED: equal to a JS copy of canon on 4 states.
- CM4 launcher/OS: OS-EXEC, OS-DYLD, OS-PIPE, OS-FD, OS-PGRP (a `setsid` grandchild survives; stated),
  OS-WAIT, OS-FS (same-uid TOCTOU between copy and exec), A-LAUNCHER-HOST. `stdin_complete` means "all
  bytes written to the pipe", not "consumed". Unchanged from `x-issuer-bridge` §5.
- CM5 shared approved spec: `RefundSpec` feeds the JS compile and (through the exporter) the HOL contract.
- CM6 the bridge code, the minter that signs `token`, and their runtimes: single points (TESTED-UNPROVED).
- Both wrong: a wrong checker AND a wrong native program can mint (test `both-wrong`, expected SIGN).

## 5. Reviewer cases and the check that closes each
| case | closed by | evidence |
|---|---|---|
| H (no post-state; miscompiled Check) | step 5 post/intent recomputation | (i), AttackPostState; tests H/* (8 refusals) |
| M, E1–E3 (separate d and x) | §1 one input; x derived | AttackSeparateInputs; tests M/* (interface + 6) |
| E5 (True == 1) | step 1 strict types; typed compare | tests E5/*; mutant range-drop-bool-type killed |
| E6 (decide without range) | range inside `decide2` | test planted/E6; mutant decide2-drop-range killed |
| L model restates function | model now relates Bridge2 to F.Authorizes with check, native arbitrary | Bridge2.dfy |
| L stdin_complete, setsid | NOT closed; stated in CM4 | – |

## 6. HOL side (G4)
Orchestrator A's M3 `refund_model_frame_meets_exported_contract` (MODEL machine): if the strict parser
accepts the fd-1 bytes of a behaviour on stdin `refund_request …`, the bytes are the complete render of
`refund_fields …`, which meets the exported contract. With b-export-bridge (ExportedContract ⇔ FlatContract)
this gives `NativeOkOn(native, x)` for the model machine at x = Encode(pre, t.request); `None` needs nothing.
Between that and the real process (numbering = order of the 13 items in orch-A/review-MF/REPORT.md):
1 X8, 2 FFI premise/R6, 3 `no_ext`, 4 A-FD1-WRITE, 5 A-LOADER/entry state (env scrub helps, not a proof),
6 Python parser = HOL parser, 7 stdout starts empty (fresh pipe: plausible, unproved), 8 BETA,
9 exporter identity, 10 Dafny LinkedRefund, 11 input encoding (= CM2 here), 13 kernel I/O = oracle.
Item 12 (X16) is what adoption of this bridge changes; it is not an assumption on the process.

## 7. Adoption (G5)
Owner approval needed for: a TypeScript port of `decide2` + `launcher` inside the issuer
(`ts/refund-finality/minter.ts` or a new file it calls; this changes `checkerSha256`, so the pinned checker
digest in the sink and in the Slice 1 evidence must be re-issued); the pinned binary path and digest
`b8ed5ec2…`; the output token taken from the bridge (recomputed fields + `preStateSha256`); a new proposal
folder for `Bridge2.dfy` (new files only). No protected file (gate/, policy/, spec/, toolchain/, schemas/,
.github/, governance/, spec.lock) changes. Nothing under clearing/.
Replacement for the overclaim in `BRIDGE_DESIGN.md` §6:
"In the model `Bridge2.dfy` (MACHINE-CHECKED), a token is signed only for a transition that the approved
relation authorizes for the given pre-state if EITHER the compiled checker is correct on that candidate OR
the native frame meets the flat contract on the bridge's own encoding of (pre, request); the token's request,
post-state and intent are recomputed from the native frame and pre. The implementation is TESTED-UNPROVED,
rests on the launcher's OS assumptions and on a UTF-8 codec and canon that both sides share, and does not
check that pre is current: the sink does."
