# Builds SinkCoreReqId.dfy from the byte-equal copy of SinkCore.dfy. Each replacement must match once.
import sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text()
out_path = pathlib.Path(sys.argv[2]); tail = pathlib.Path(sys.argv[3]).read_text()
def rep(old, new):
    global src
    assert src.count(old) == 1, old
    src = src.replace(old, new)
rep("// M1-B mission, wave 4, worker Y7 (graph links U4, U5, U8, X16). A DRAFT in a scratch folder.",
    "// d-reqid (night shift 2026-11-19, Orchestrator B): SinkCore.dfy (M1-B wave 4, worker Y7) with the\n"
    "// request-id check of sink-reqid.diff added to Step. Changed parts are marked d-reqid. A DRAFT.")
rep("module SinkCore refines FinalityProtocol {", "module SinkCoreReqId refines FinalityProtocol {")
rep("datatype Why = IdsNotPinned |", "datatype Why = ReqIdMismatch | IdsNotPinned |")
rep("""    else if !sigOk then StepResult(core, Rejected(SignatureInvalid))
    else if tok.requestId in core.settled""",
"""    else if !sigOk then StepResult(core, Rejected(SignatureInvalid))
    // d-reqid: the new check, in the place of the patched sink.ts (after the signature, before the transaction).
    else if tok.intent.requestId != tok.requestId then StepResult(core, Rejected(ReqIdMismatch))
    else if tok.requestId in core.settled""")
# StepRefinesCommit: the original iff needs A1 and A2 now (see lemma IffNeedsA1A2 below).
rep("""  lemma StepRefinesCommit(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks)
    ensures""",
"""  lemma StepRefinesCommit(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks)
    requires IdealMac(s) && MinterSound(s.minted)   // d-reqid: new; without it the iff is false (IffNeedsA1A2)
    ensures""")
rep("""    var c := ClaimOf(tok);
    EncSetMember(core.settled, tok.requestId);
    assert Ours(c) <==>""",
"""    var c := ClaimOf(tok);
    if SinkAccepts(s, c, tok.sig) {
      assert (c, tok.sig) in s.minted;
      assert SpecRel(c.pre, c.req, c.post, c.eff);
    }
    EncSetMember(core.settled, tok.requestId);
    assert Ours(c) <==>""")
# SinkCommit: model step is Commit or a stutter; the original posts hold under A1 and A2.
rep("""    ensures s' == Commit(s, ClaimOf(tok), tok.sig)
    ensures Rel(core', s', toks')
    ensures out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig)
    ensures Inv(init, s) && IdealMac(s) ==> Inv(init, s') && IdealMac(s')""",
"""    ensures s' == ModelStep(s, tok)                                   // d-reqid: Commit, or a stutter on a mismatch
    ensures Rel(core', s', toks')                                      // d-reqid: unconditional
    ensures out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig) && Match(tok)
    ensures IdealMac(s) && MinterSound(s.minted) ==> s' == Commit(s, ClaimOf(tok), tok.sig)
    ensures IdealMac(s) && MinterSound(s.minted) ==> (out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig))
    ensures Inv(init, s) && IdealMac(s) ==> Inv(init, s') && IdealMac(s')""")
rep("""    s' := Commit(s, ClaimOf(tok), tok.sig);
    toks' := NextToks(toks, tok, out);
    StepRefinesCommit(core, s, toks, tok, sigOk);
    if Inv(init, s) && IdealMac(s) {
      CommitPreservesInv(init, s, ClaimOf(tok), tok.sig);
    }""",
"""    s' := ModelStep(s, tok);
    toks' := NextToks(toks, tok, out);
    StepRefinesModelStep(core, s, toks, tok, sigOk);
    if IdealMac(s) && MinterSound(s.minted) {
      StepRefinesCommit(core, s, toks, tok, sigOk);
    }
    if Inv(init, s) && IdealMac(s) {
      CommitPreservesInv(init, s, ClaimOf(tok), tok.sig);
    }""")
rep("""    ensures tok.pre.chargeId in stores ==>
      sys'[tok.pre.chargeId] == Commit(sys[tok.pre.chargeId], ClaimOf(tok), tok.sig)""",
"""    ensures tok.pre.chargeId in stores ==>
      sys'[tok.pre.chargeId] == ModelStep(sys[tok.pre.chargeId], tok)    // d-reqid: Commit, or a stutter on a mismatch""")
i = src.rstrip().rfind("}")
src = src[:i] + tail + "}\n"
out_path.write_text(src)
