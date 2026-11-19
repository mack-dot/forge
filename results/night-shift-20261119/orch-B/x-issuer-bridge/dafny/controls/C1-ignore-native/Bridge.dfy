// x-issuer-bridge (night shift 2026-11-19): the bridge's decision function, stated and proved in Dafny.
// It is a statement about the DECISION FUNCTION only. It says nothing about the native executable, the
// launcher, the parser (frame.py) or the compiled JavaScript. Those are inputs here:
//   p      = the launcher's typed process result (TESTED-UNPROVED code; OS assumptions OS-*),
//   parsed = the strict parser's result on stdout (TESTED-UNPROVED code; None = no complete frame),
//   v      = the compiled Dafny Check verdict, reduced to its six fields (DAFNY-JS assumption),
//   enc    = the text encoder the bridge uses for the native side (UTF-8 in decide.py).
module IssuerBridge {
  datatype Option<T> = None | Some(value: T)

  // The six fields of one native frame. Texts are byte strings (every char < 256).
  datatype Fields = Fields(authorized: bool, amount: int, reason: string, charge: string, request: string,
                           count: int)

  // The Dafny side: Refuse, or Issue with the fields derived from the token (intent amount, reason,
  // charge id; token request id; |plan|).
  datatype Verdict = Refuse | Issue(amount: int, reason: string, charge: string, request: string, count: int)

  datatype Process = Process(launched: bool, timedOut: bool, signaled: bool, exitCode: int, stderrLen: int,
                             stdoutOverflow: bool, stdinComplete: bool, copyUnchanged: bool)

  datatype Decision = Sign | Refused(reason: string)

  function Expected(v: Verdict, enc: string -> string): Fields
    requires v.Issue?
  {
    Fields(true, v.amount, enc(v.reason), enc(v.charge), enc(v.request), v.count)
  }

  predicate Clean(p: Process) {
    p.launched && !p.timedOut && !p.signaled && p.exitCode == 0 && p.stderrLen == 0 &&
    !p.stdoutOverflow && p.stdinComplete && p.copyUnchanged
  }

  // The decision of decide.py, in the same order (first failing step decides).
  function Bridge(inRange: bool, v: Verdict, p: Process, parsed: Option<Fields>, enc: string -> string): Decision {
    if !inRange then Refused("OUT_OF_RANGE")
    else if v.Issue? then Sign
    else if !p.launched then Refused("NOT_LAUNCHED")
    else if p.timedOut then Refused("TIMEOUT")
    else if p.stdoutOverflow then Refused("STDOUT_OVERFLOW")
    else if p.stderrLen != 0 then Refused("STDERR_NONEMPTY")
    else if p.signaled then Refused("SIGNAL")
    else if p.exitCode != 0 then Refused("EXIT_NONZERO")
    else if !p.stdinComplete then Refused("STDIN_INCOMPLETE")
    else if !p.copyUnchanged then Refused("BINARY_CHANGED")
    else if parsed.None? then Refused("FRAME_INVALID")
    else if v.Refuse? then Refused("DAFNY_REFUSE")
    else if !parsed.value.authorized then Refused("MISMATCH_AUTHORIZED")
    else if parsed.value.amount != v.amount then Refused("MISMATCH_AMOUNT")
    else if parsed.value.reason != enc(v.reason) then Refused("MISMATCH_REASON")
    else if parsed.value.charge != enc(v.charge) then Refused("MISMATCH_CHARGE")
    else if parsed.value.request != enc(v.request) then Refused("MISMATCH_REQUEST")
    else if parsed.value.count != v.count then Refused("MISMATCH_COUNT")
    else Sign
  }

  // Soundness: the bridge signs only if the Dafny verdict is Issue AND the native frame decodes to the
  // same six fields AND the process outcome is clean AND the inputs are in range.
  lemma BridgeSound(inRange: bool, v: Verdict, p: Process, parsed: Option<Fields>, enc: string -> string)
    ensures Bridge(inRange, v, p, parsed, enc) == Sign ==>
      inRange && v.Issue? && Clean(p) && parsed == Some(Expected(v, enc))
  {
  }

  // Exact acceptance: when both sides agree on a clean run, the bridge signs (a reject-all bridge fails).
  lemma BridgeComplete(inRange: bool, v: Verdict, p: Process, parsed: Option<Fields>, enc: string -> string)
    requires inRange && v.Issue? && Clean(p) && parsed == Some(Expected(v, enc))
    ensures Bridge(inRange, v, p, parsed, enc) == Sign
  {
  }

  // With an injective encoder, the native frame determines the Dafny fields: two Issue verdicts that the
  // bridge signs against the same frame are equal.
  lemma FrameDeterminesVerdict(v1: Verdict, v2: Verdict, p: Process, parsed: Option<Fields>, enc: string -> string)
    requires forall a, b :: enc(a) == enc(b) ==> a == b
    requires Bridge(true, v1, p, parsed, enc) == Sign && Bridge(true, v2, p, parsed, enc) == Sign
    ensures v1 == v2
  {
    BridgeSound(true, v1, p, parsed, enc);
    BridgeSound(true, v2, p, parsed, enc);
  }

  // Non-vacuity witness: a concrete run where the bridge signs (zero amount included).
  lemma Witness()
    ensures Bridge(true, Issue(40, "returned_item", "ch_1", "req_1", 1),
                   Process(true, false, false, 0, 0, false, true, true),
                   Some(Fields(true, 40, "returned_item", "ch_1", "req_1", 1)), s => s) == Sign
    ensures Bridge(true, Issue(0, "duplicate_charge", "ch_1", "req_0", 1),
                   Process(true, false, false, 0, 0, false, true, true),
                   Some(Fields(true, 0, "duplicate_charge", "ch_1", "req_0", 1)), s => s) == Sign
  {
  }
}
