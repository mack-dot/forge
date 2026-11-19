# Builds mutant sinks and dispatchers (ATTACK INPUTS, not fixes) as edited copies of the v6 sink.ts / dispatcher.ts.
# Output: <ev>/v6/ts/refund-finality/m_<name>.ts (next to core/ and encoding.ts so imports resolve).
import sys, pathlib
EV = pathlib.Path(sys.argv[1]); D = EV / "v6/ts/refund-finality"
SINK = (D / "sink.ts").read_text(); DISP = (D / "dispatcher.ts").read_text()
def sub(src, pairs, name):
    for old, new in pairs:
        n = src.count(old)
        if n != 1: raise SystemExit(f"{name}: anchor found {n} times: {old[:70]!r}")
        src = src.replace(old, new)
    return f"// MUTANT {name} (c10-judges attack input; edited copy of v6 sink/dispatcher). NOT a fix.\n" + src
DEC = 'if (typeof token === "string") return { status: "rejected", reason: token };\n'
TX = '      const stored = this.storedBlob();\n      // (iv)'
DECIDE = '      const q = M.Shell6.__default.StepQ6(charge, tok, sigOk, preOk, prior !== undefined);\n'
WR_STATE = '        this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(next);\n'
WR_OUT = '        this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(rid, canon(cv.backIntent(q.dtor_intent)));\n'
OKRET = '        this.db.exec("COMMIT");\n        return { status: "committed" };\n'
TOK = '      cv.text(b.requestId), cv.charge(b.post), cv.intent(b.intent), cv.text(""));\n    try {'
# commit-everything branch (no check at all except SQL UNIQUE), used by the trigger mutants
ALL = ('        if (TRIGGER) { this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(b.post));\n'
       '          this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(b.requestId, tokenText, tokenSha256);\n'
       '          this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(b.requestId, canon(b.intent));\n'
       '          this.mark(canon(b.post)); this.db.exec("COMMIT"); return { status: "committed" }; }\n')
def trig(cond): return [(DECIDE, ALL.replace("TRIGGER", cond) + DECIDE)]
S = {
 "reject_all": [(DEC, DEC + '    return { status: "rejected", reason: "mutant reject_all" };\n')],
 "reject_zero": [(DEC, DEC + '    if (token.body.intent.amount === "0") return { status: "rejected", reason: "mutant zero" };\n')],
 "reject_full": [(TX, TX.replace("      // (iv)", '      if (stored !== undefined && JSON.parse(stored).remaining === b.intent.amount) { this.db.exec("ROLLBACK"); return { status: "rejected", reason: "mutant full" }; }\n      // (iv)'))],
 "reject_second": [(TX, TX.replace("      // (iv)", '      if ((this.db.prepare("SELECT COUNT(*) AS n FROM settled").get() as any).n >= 1) { this.db.exec("ROLLBACK"); return { status: "rejected", reason: "mutant second" }; }\n      // (iv)'))],
 "skip_reqid": [(TOK, TOK.replace("cv.intent(b.intent)", "cv.intent({ ...b.intent, requestId: b.requestId })")),
                (WR_OUT, WR_OUT.replace("canon(cv.backIntent(q.dtor_intent))", "canon(b.intent)"))],
 "skip_chargeid": [(DECIDE, '      const tok2 = M.Shell.ShellToken.create_ShellToken(tok.dtor_specId, tok.dtor_checkerId, tok.dtor_requestId, tok.dtor_post, cv.intent({ ...b.intent, chargeId: stored === undefined ? b.intent.chargeId : JSON.parse(stored).chargeId }), tok.dtor_sig);\n' + DECIDE.replace("StepQ6(charge, tok,", "StepQ6(charge, tok2,")),
                   (WR_OUT, WR_OUT.replace("canon(cv.backIntent(q.dtor_intent))", "canon(b.intent)"))],
 "skip_settled": [(DECIDE, DECIDE.replace("prior !== undefined", "false"))],
 "skip_settled_ignore": [(DECIDE, DECIDE.replace("prior !== undefined", "false")),
     ('.run(rid, tokenText, tokenSha256);', '.run(rid, tokenText, tokenSha256);'.replace('.run', '.run')),
     ('"INSERT INTO settled(', '"INSERT OR IGNORE INTO settled('), ('"INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(rid', '"INSERT OR IGNORE INTO outbox(request_id, intent) VALUES (?, ?)").run(rid')],
 "no_outbox": [(WR_OUT, "")],
 "outbox_twice": [(WR_OUT, WR_OUT + WR_OUT.replace(".run(rid,", '.run(rid + "#dup",'))],
 "write_but_rejected": [(OKRET, '        this.db.exec("COMMIT");\n        return { status: "rejected", reason: "mutant" };\n')],
 "no_state_update": [(WR_STATE, "")],
 "state_plus1": [('const rid = cv.back(q.dtor_addId), next = canon(cv.backCharge(q.dtor_newCharge));',
                  'const rid = cv.back(q.dtor_addId), nc = cv.backCharge(q.dtor_newCharge); if (BigInt(nc.remaining) > 0n && b.intent.amount !== "0") nc.remaining = (BigInt(nc.remaining) - 1n).toString(); const next = canon(nc);')],
 "accept_bad_sig": [("    const sigOk = this.verified(token);\n", "    const sigOk = true;\n")],
 "accept_noncanon": [('  if (canon(token) !== input) return "token text is not canonical";\n', "")],
 "replayed_any": [("if (why.is_RequestSettled) return sameToken ?", "if (why.is_RequestSettled) return true ?")],
 "replay_says_rejected": [("if (why.is_RequestSettled) return sameToken ?", "if (why.is_RequestSettled) return false ?")],
 "skip_prestate": [(DECIDE, DECIDE.replace("sigOk, preOk,", "sigOk, stored !== undefined,"))],
 "wipe_on_open": [('    // The start-up audit (schema, meta, compiled AuditV5 fold). No option skips it.\n',
                   '    { const n = (this.db.prepare("SELECT COUNT(*) AS n FROM state").get() as any).n; if (n > 0) { this.db.exec("DELETE FROM settled; DELETE FROM outbox; DELETE FROM meta");\n'
                   '      this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(cfg.initialState));\n'
                   '      this.db.prepare("INSERT INTO meta(k, v) VALUES (\'initial_state_sha256\', ?)").run(sha256hex(canon(cfg.initialState)));\n'
                   '      this.db.prepare("INSERT INTO meta(k, v) VALUES (\'initial_state\', ?)").run(canon(cfg.initialState)); } }\n'
                   '    // The start-up audit (schema, meta, compiled AuditV5 fold). No option skips it.\n')],
 "late20": [("  public reaudits = 0;", "  public reaudits = 0; private nCommits = 0;"), (OKRET, '        this.db.exec("COMMIT"); this.nCommits++;\n        return { status: "committed" };\n')] + trig("this.nCommits >= 20"),
 "late3": [("  public reaudits = 0;", "  public reaudits = 0; private nCommits = 0;"), (OKRET, '        this.db.exec("COMMIT"); this.nCommits++;\n        return { status: "committed" };\n')] + trig("this.nCommits >= 3"),
 "id_gt32_or_nonascii": trig("[b.requestId, b.intent.requestId, b.intent.chargeId, b.post.chargeId].some(s => s.length > 32 || /[^\\x00-\\x7f]/.test(s))"),
 "amount19": trig("b.intent.amount.length === 19"),
 "disabled_commits_all": trig("stored !== undefined && JSON.parse(stored).refundEnabled === false"),
 "reason_case_insensitive": trig('stored !== undefined && sha256hex(stored) === b.preStateSha256 && ["duplicate_charge","service_not_delivered","returned_item"].includes(b.intent.reason.trim().toLowerCase()) && b.requestId === b.intent.requestId && b.intent.chargeId === JSON.parse(stored).chargeId && BigInt(b.intent.amount) <= BigInt(JSON.parse(stored).remaining)'),
}
for name, pairs in S.items():
    (D / f"m_{name}.ts").write_text(sub(SINK, pairs, name))
DE = '          this.emit(effect, verdict.intent);    // the external effect: after the ledger line\n'
LEDGER = '          const fd = openSync(this.ledgerPath, "a");\n          try { writeSync(fd, JSON.stringify(verdict.line) + "\\n"); fsyncSync(fd); } finally { closeSync(fd); }\n'
DS = {
 "emit_twice": [(DE, DE + DE)],
 "emit_before_ledger": [(LEDGER, '          this.emit({ requestId: row.request_id, intent: row.intent }, verdict.intent);\n' + LEDGER), (DE, "")],
 "ignore_chain": [('    if (body.preStateSha256 !== head) return { ok: false, reason: "token does not continue the dispatched chain" };\n', "")],
 "ignore_sig": [("    if (!good) return { ok: false, reason: \"signature does not verify\" };\n", "")],
 "reverse_order": [("      for (const [seq, r] of reasons)", "      for (const e of [...later].reverse()) this.emit(e[0], e[1]);\n      for (const [seq, r] of reasons)"),
                   ("      let progress = true;\n", "      let progress = true; const later: [any, any][] = [];\n"),
                   (DE, "          later.push([effect, verdict.intent]);\n")],
 "ignore_outbox_intent": [('    if (canon(body.intent) !== row.intent) return { ok: false, reason: "outbox intent is not the signed intent" };\n', "")],
}
for name, pairs in DS.items():
    (D / f"md_{name}.ts").write_text(sub(DISP, pairs, name))
print("ok", len(S), "sinks", len(DS), "dispatchers")
