# gen_own.py: builds the h-judges2 OWN mutants (ATTACK INPUTS against the rebuilt judges, not fixes), as edited copies of
# the branch head 74fb70eb (export: ../tree/ts/refund-finality). Imports are rewritten to ABSOLUTE paths of that export.
#   own_d_sig_nonzero_only : dispatcher AND its store-audit copy skip the signature check when intent.amount is "0".
#   own_enc_no_reason      : sink, store-audit and dispatcher also accept a signature over canon(body with intent.reason
#                            removed); the reduced bytes are PRIVATE (not exported; encoding.ts stays the trusted file).
#   own_e_dupfd            : dispatcher emits once through the given emit, then sends a SECOND record of the same effect
#                            through a duplicated descriptor of the channel (/dev/fd/4) for every nonzero amount.
import pathlib, sys
T = pathlib.Path("<REPO>/results/night-shift-20261119/orch-B/h-judges2/tree/ts/refund-finality")
OUT = pathlib.Path(sys.argv[1])
SINK, DISP, STORE = [(T / f).read_text() for f in ("sink.ts", "dispatcher.ts", "core/store.ts")]
def sub(src, pairs, name):
    for old, new in pairs:
        n = src.count(old)
        if n != 1: raise SystemExit(f"{name}: anchor found {n} times: {old[:80]!r}")
        src = src.replace(old, new)
    return f"// MUTANT {name} (h-judges2 attack input; edited copy of 74fb70eb). NOT a fix.\n" + src
def absimp(src, store):
    return (src.replace('from "./encoding"', f'from "{T}/encoding"').replace('from "../encoding"', f'from "{T}/encoding"')
               .replace('from "./core/store"', f'from "{store}"'))
def put(name, fname, text):
    d = OUT / name; d.mkdir(parents=True, exist_ok=True); (d / fname).write_text(text)
SIG = "  try { const raw = signatureBytes(token.signature); return raw !== null && verify(null, signedBytes(token.body), key, raw); } catch { return false; }\n"
DSIG = "    try { const raw = signatureBytes(token.signature); good = raw !== null && verify(null, signedBytes(body), this.key, raw); } catch { good = false; }\n"
CORE = ('const CORE_FILE = __dirname + "/sinkcore-v6.cjs";', f'const CORE_FILE = "{T}/core/sinkcore-v6.cjs";')
NOREASON = 'const NR = (b: any): Buffer => Buffer.from(canon({ ...b, intent: Object.fromEntries(Object.entries(b.intent).filter(([k]) => k !== "reason")) } as any), "utf8");\n'

# 1. own_d_sig_nonzero_only
n = "own_d_sig_nonzero_only"
put(n, "store.ts", absimp(sub(STORE, [CORE, (SIG, "  if ((token.body as any).intent.amount === \"0\") return true;\n" + SIG)], n), ""))
put(n, "dispatcher.ts", absimp(sub(DISP, [(DSIG, "    if (body.intent.amount === \"0\") good = true; else\n" + DSIG)], n), str(OUT / n / "store")))

# 2. own_enc_no_reason
n = "own_enc_no_reason"
put(n, "store.ts", absimp(sub(STORE, [CORE, (SIG, NOREASON + "  try { const raw = signatureBytes(token.signature); return raw !== null && (verify(null, signedBytes(token.body), key, raw) || verify(null, NR(token.body), key, raw)); } catch { return false; }\n")], n), ""))
put(n, "sink.ts", absimp(sub(SINK, [], n), str(OUT / n / "store")))
put(n, "dispatcher.ts", absimp(sub(DISP, [(DSIG, "    " + NOREASON + "    try { const raw = signatureBytes(token.signature); good = raw !== null && (verify(null, signedBytes(body), this.key, raw) || verify(null, NR(body), this.key, raw)); } catch { good = false; }\n")], n), str(OUT / n / "store")))

# 3. own_e_dupfd (a wrapper module around the head dispatcher)
put("own_e_dupfd", "dispatcher.ts", f'''// MUTANT own_e_dupfd (h-judges2 attack input). NOT a fix. Every nonzero effect is sent TWICE: once through the emit
// function, once as a forged record of the same effect written to a DUPLICATED descriptor of the channel (/dev/fd/4).
import {{ Dispatcher as Base }} from "{T}/dispatcher";
import * as fs from "node:fs";
export class Dispatcher extends Base {{
  constructor(db: string, ledger: string, cfg: any, emit: (e: any, i: any) => void) {{
    super(db, ledger, cfg, (e: any, i: any) => {{
      emit(e, i);
      if (i && i.amount !== "0") {{
        try {{ const fd = fs.openSync("/dev/fd/4", "w"); fs.writeSync(fd, JSON.stringify({{ t: "e", seq: 900000, requestId: String(e.requestId), intent: i }}) + "\\n"); fs.closeSync(fd); }} catch {{ /* no channel */ }}
      }}
    }});
  }}
}}
''')
print("ok")
