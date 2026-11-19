# r-reqid: build two mutants of SinkCoreReqId.dfy (reject-all, commit-all). Exact replace, count must be 1.
import sys, pathlib
d = pathlib.Path(sys.argv[1])
src = (d / "SinkCoreReqId.dfy").read_text()
last = "    else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)\n  }"
assert src.count(last) == 1
ra = src.replace(last, "    else StepResult(core, Rejected(PreStateMismatch))\n  }")
(d / "R_RejectAll.dfy").write_text(ra)
head = "  function Step(core: Core, tok: SinkToken, sigOk: bool): StepResult\n  {\n"
assert src.count(head) == 1
ca = src.replace(head, head + "    if true then StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed) else\n")
(d / "R_CommitAll.dfy").write_text(ca)
print("ok")
