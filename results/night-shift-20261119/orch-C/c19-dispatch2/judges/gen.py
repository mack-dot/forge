# gen.py: builds the C-JUDGE-01 mutants again, re-derived against fix-f08a21c1 (ATTACK INPUTS, not fixes).
# Each mutant lives in judges/m/<name>/ with imports rewritten to ABSOLUTE paths of the target tree (no tree copy).
import pathlib, re, sys
T = pathlib.Path("<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality")
OUT = pathlib.Path(sys.argv[1])
SINK, DISP, STORE, ENC = [(T / f).read_text() for f in ("sink.ts", "dispatcher.ts", "core/store.ts", "encoding.ts")]
def absimp(src, enc=str(T / "encoding"), store=str(T / "core/store")):
    return src.replace('from "./encoding"', f'from "{enc}"').replace('from "./core/store"', f'from "{store}"').replace('from "../encoding"', f'from "{enc}"')
def sub(src, pairs, name):
    for old, new in pairs:
        n = src.count(old)
        if n != 1: raise SystemExit(f"{name}: anchor found {n} times: {old[:80]!r}")
        src = src.replace(old, new)
    return f"// MUTANT {name} (c19 attack input; edited copy of fix-f08a21c1). NOT a fix.\n" + src
def put(name, fname, text):
    d = OUT / name; d.mkdir(parents=True, exist_ok=True); (d / fname).write_text(text)
STEP = "      const q = M.Shell6.__default.StepQ6(charge, tok, sigOk, preOk, prior !== undefined);\n"
ROW = "M.Shell5.Row.create_Row(q.dtor_addId, tok, sigOk, preOk, q.dtor_intent)"
def bypass(cond):
    return [(STEP, f"      const BYP = {cond};\n      const q = M.Shell6.__default.StepQ6(charge, tok, sigOk || BYP, preOk || BYP, prior !== undefined);\n"),
            (ROW, "M.Shell5.Row.create_Row(q.dtor_addId, tok, sigOk || BYP, preOk || BYP, q.dtor_intent)")]
S = {
 "m_accept_bad_sig": [("    const sigOk = sigOkOf(this.au.key, token);\n", "    const sigOk = true;\n")],
 "m_accept_noncanon": [("    const token = decodeToken(input);\n", "    const token = (() => { try { return decodeToken(canon(JSON.parse(input as string))); } catch { return decodeToken(input); } })();\n")],
 "m_skip_prestate": [("const preOk = stored !== undefined && sha256hex(stored) === b.preStateSha256;", "const preOk = stored !== undefined;")],
 "m_replay_says_rejected": [("if (why.is_RequestSettled) return sameToken ?", "if (why.is_RequestSettled) return false ?")],
 "m_replayed_any": [("if (why.is_RequestSettled) return sameToken ?", "if (why.is_RequestSettled) return true ?")],
 "m_id_gt32_or_nonascii": bypass("[b.requestId, b.intent.requestId, b.intent.chargeId, b.post.chargeId].some(s => s.length > 32 || /[^\\x00-\\x7f]/.test(s))"),
 "m_late20": [("  public reaudits = 0;", "  public reaudits = 0; private nC = 0;"), ('        this.db.exec("COMMIT");\n        return { status: "committed" };', '        this.db.exec("COMMIT"); this.nC++;\n        return { status: "committed" };')] + bypass("this.nC >= 20"),
 "m_wipe_on_open": [('      this.db.exec("PRAGMA busy_timeout = 30000");\n',
     '      this.db.exec("PRAGMA busy_timeout = 30000");\n'
     '      { const objs = this.db.prepare("SELECT type, name FROM sqlite_schema WHERE name NOT LIKE \'sqlite_%\'").all() as any[];\n'
     '        if (objs.length > 0) { for (const o of objs) if (o.type === "trigger") this.db.exec(`DROP TRIGGER IF EXISTS "${o.name}"`);\n'
     '          for (const o of objs) if (o.type === "table") this.db.exec(`DROP TABLE IF EXISTS "${o.name}"`); WIPED = true; } }\n'),
   ("    let ok = false, why = \"\";\n", "    let ok = false, why = \"\"; let WIPED = false;\n"),
   ("    }\n  }\n  // Writes meta", "    }\n    if (WIPED) this.init(cfg.initialState);\n  }\n  // Writes meta")],
}
for name, pairs in S.items(): put(name, "sink.ts", absimp(sub(SINK, pairs, name)))
# store copies for dispatcher mutants whose defect the shared audit would mask
def store_copy(name, pairs, enc=str(T / "encoding")):
    s = sub(STORE, [('const CORE_FILE = __dirname + "/sinkcore-v6.cjs";', f'const CORE_FILE = "{T}/core/sinkcore-v6.cjs";')] + pairs, name)
    put(name, "store.ts", s.replace('from "../encoding"', f'from "{enc}"'))
SIG = "  try { const raw = signatureBytes(token.signature); return raw !== null && verify(null, signedBytes(token.body), key, raw); } catch { return false; }\n"
PRE = "const preOk = sha256hex(canon(cv.backCharge(st.dtor_cur))) === body.preStateSha256;"
DS = {
 "md_ignore_sig": ([('    if (!good) return { ok: false, reason: "signature does not verify" };\n', "")], [(SIG, "  return true;\n")]),
 "md_ignore_chain": ([('    if (body.preStateSha256 !== head) return { ok: false, reason: "token does not continue the dispatched chain" };\n', "")], [(PRE, "const preOk = true;")]),
 "md_emit_before_ledger": ([('    this.append({ kind: "intent", ...fields, run: this.run, pid: process.pid });\n', '    this.emit(effect, intent);\n    this.append({ kind: "intent", ...fields, run: this.run, pid: process.pid });\n'),
                            ("    try { this.emit(effect, intent); } catch (error) {", "    try { /* moved before the claim */ } catch (error) {")], None),
}
for name, (dp, sp) in DS.items():
    src = sub(DISP, dp, name)
    if sp is None: put(name, "dispatcher.ts", absimp(src))
    else: store_copy(name, sp); put(name, "dispatcher.ts", absimp(src, store=str(OUT / name / "store")))
# enc: a reduced-bytes encoding one folder away from the sink (not "next to" it); sink, dispatcher and store use it;
# the sink and dispatcher accept a signature over the FULL or the REDUCED bytes (so honest tokens still pass).
e = OUT / "enc_unsigned_body"; (e / "lib").mkdir(parents=True, exist_ok=True)
(e / "lib/encoding.ts").write_text(ENC.replace('export const signedBytes = (body: TokenBody): Buffer => Buffer.from(canon(body), "utf8");',
  'export const signedBytes = (body: TokenBody): Buffer => Buffer.from(canon(body), "utf8");\n'
  'export const reducedBytes = (body: TokenBody): Buffer => Buffer.from(canon((({ post, intent, ...rest }) => rest)(body as any) as any), "utf8");'))
store_copy("enc_unsigned_body", [(SIG, "  try { const raw = signatureBytes(token.signature); return raw !== null && (verify(null, signedBytes(token.body), key, raw) || verify(null, reducedBytes(token.body), key, raw)); } catch { return false; }\n"),
  ("import { ChargeState, Intent, Token, canon,", "import { reducedBytes } from \"../encoding\";\nimport { ChargeState, Intent, Token, canon,")], enc=str(e / "lib/encoding"))
put("enc_unsigned_body", "sink.ts", absimp(sub(SINK, [], "enc_unsigned_body"), enc=str(e / "lib/encoding"), store=str(e / "store")))
put("enc_unsigned_body", "dispatcher.ts", absimp(sub(DISP, [("good = raw !== null && verify(null, signedBytes(body), this.key, raw);", "good = raw !== null && (verify(null, signedBytes(body), this.key, raw) || verify(null, reducedBytes(body), this.key, raw));"),
  ('import { Intent, canon,', 'import { reducedBytes } from "./encoding";\nimport { Intent, canon,')], "enc_unsigned_body"), enc=str(e / "lib/encoding"), store=str(e / "store")))
print("ok")
