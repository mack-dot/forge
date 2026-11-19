// CHILD process of the refund-finality judges (night shift 2026-11-19, tasks h-judges, h-judges2). A TEST, not a proof.
// The judges (regress/run.ts, spec-conformance/run.ts) never load the code under test into their own process.
// They start this file as a child process (node --import tsx worker.ts <sink module> <dispatcher module|none>) and
// send it operations over the Node IPC channel. This file runs ONLY the operations that the parent asks for and
// answers with plain values. It decides nothing: every assertion, every database read for a verdict and every
// PASS/FAIL line is in the parent. Output of this process (stdout, stderr, exit code) is never a verdict.
// EFFECTS (h-judges2): this file does NOT report effects. The emit function given to the dispatcher writes each call
// as one record into fd 4, a pipe that the PARENT created and reads, and blocks until the parent ACKs it (remote.ts).
// MODULE GRAPH (h-judges2): every file that Node's module resolver returns while this process runs is recorded (a
// wrapper around Module._resolveFilename installed BEFORE the modules under test load) and joined with require.cache.
// The parent hashes these files itself. "Encoding modules" = files of the graph whose basename is encoding.* or whose
// exports have a function signedBytes.
// The functions used below are captured BEFORE the module under test loads, so a module that replaces them later does
// not change them here. (A module that runs in this process can still do anything this process can do: see the
// README, remaining trust IN-PROCESS-TAMPER and HIDDEN-LOAD.)
// Values, not import bindings: a compiled `import { f }` reads the module property at each call, so a module under
// test that replaces fs.writeSync would change it; a const taken here keeps the original function.
import * as fs from "node:fs";
import * as crypto from "node:crypto";
import * as sqlite from "node:sqlite";
import { basename, resolve } from "node:path";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Module = require("node:module");

const EX = fs.existsSync, WS = fs.writeSync, RS = fs.readSync;
const JS = JSON.stringify, JP = JSON.parse, HM = crypto.createHmac, BA = Buffer.alloc.bind(Buffer), BF = Buffer.from.bind(Buffer);
const send = process.send!.bind(process);
const [sinkPath, dispPath] = process.argv.slice(2);
const CH = 4;
// ---- the effect channel: read the per-child secret (first line from the parent) before any module under test loads
let chanBuf = "";
function readLine(): string {
  const b = BA(4096);
  for (;;) {
    const i = chanBuf.indexOf("\n");
    if (i >= 0) { const l = chanBuf.slice(0, i); chanBuf = chanBuf.slice(i + 1); return l; }
    const n = RS(CH, b, 0, b.length, null);
    if (n === 0) throw new Error("effect channel closed");
    chanBuf += b.toString("utf8", 0, n);
  }
}
const first = readLine();
const SECRET = first.startsWith("S ") ? first.slice(2) : "";
if (SECRET.length !== 64) throw new Error("effect channel: no secret from the parent");
const writeAll = (s: string) => { const b = BF(s, "utf8"); let o = 0; while (o < b.length) o += WS(CH, b, o, b.length - o); };
let emitSeq = 0;
// The emit function given to the dispatcher. One record per call; blocks until the parent's ACK for that record.
// An ACK with fail = 1 (decided by the parent) makes this call throw: a failed effect.
const emit = (e: any, i: any): void => {
  const seq = ++emitSeq;
  let rid = "?", intent: unknown = null;
  try { rid = String(e?.requestId); } catch { /* keep "?" */ }
  try { intent = JP(JS(i ?? null)); } catch { intent = null; }
  writeAll(JS({ t: "e", seq, requestId: rid, intent }) + "\n");
  for (;;) {
    const [s, f, m] = readLine().split(" ");
    if (s !== String(seq)) continue;                      // an ACK for a record that someone else wrote
    if (m !== HM("sha256", SECRET).update(seq + ":" + f).digest("hex")) throw new Error("effect channel: bad ACK");
    if (f === "1") throw new Error("injected emit failure");
    return;
  }
};
// ---- the module graph
const graph = new Set<string>();
const origResolve = Module._resolveFilename;
Module._resolveFilename = function (...args: unknown[]) {
  const r = origResolve.apply(this, args);
  if (typeof r === "string") graph.add(r);
  return r;
};
// Storage fault injection (spec judge, mode fault): an armed INSERT or UPDATE throws before it runs.
let faultArmed = -1, writeCount = 0, faultHit = false;
const SP: any = (sqlite as any).StatementSync.prototype, origRun = SP.run;
SP.run = function (...args: unknown[]) {
  const sql = String(this.sourceSQL ?? "");
  if (/^\s*(INSERT|UPDATE)/i.test(sql) && faultArmed >= 0) {
    if (writeCount++ === faultArmed) { faultHit = true; throw new Error("injected storage fault"); }
  }
  return origRun.apply(this, args);
};
/* eslint-disable @typescript-eslint/no-require-imports */
let sinkMod: any = null, dispMod: any = null, loadError = "";
try { sinkMod = require(resolve(sinkPath)); } catch (e) { loadError = "sink module: " + String((e as Error)?.message ?? e).slice(0, 200); }
try { if (dispPath && dispPath !== "none") dispMod = require(resolve(dispPath)); } catch (e) { loadError += " dispatcher module: " + String((e as Error)?.message ?? e).slice(0, 200); }
/* eslint-enable @typescript-eslint/no-require-imports */
const graphNow = (): string[] => {
  const all = new Set<string>(graph);
  try { for (const k of Object.keys(require.cache)) all.add(k); } catch { /* ignore */ }
  return [...all].filter(p => p.startsWith("/") && !p.includes("/node_modules/") && EX(p)).sort();
};
// Encoding modules: files named encoding.*, and files that export a function signedBytes that is not the same
// function object as the signedBytes of an encoding.* file (a re-export is not a second encoding).
const encodingModules = (): string[] => {
  const g = graphNow(), sb = (p: string): unknown => { try { return (require.cache[p] as any)?.exports?.signedBytes; } catch { return undefined; } };
  const named = g.filter(p => /^encoding\.(ts|js|cjs|mjs|cts|mts)$/.test(basename(p)));
  const known = new Set<unknown>(named.map(sb).filter(f => typeof f === "function"));
  return [...named, ...g.filter(p => !named.includes(p) && typeof sb(p) === "function" && !known.has(sb(p)))];
};
const sinks = new Map<number, any>();
let nextHandle = 1;
const msg = (e: unknown) => String((e as Error)?.message ?? e).slice(0, 200);

function op(name: string, a: any): unknown {
  switch (name) {
    case "hello": return { loadError, hasSink: typeof sinkMod?.Sink === "function", hasDispatcher: typeof dispMod?.Dispatcher === "function",
      hasGenesisOf: typeof sinkMod?.genesisOf === "function", graph: graphNow(), encodingModules: encodingModules() };
    case "open": {
      try { const s = new sinkMod.Sink(a.db, a.cfg); const h = nextHandle++; sinks.set(h, s); return { handle: h, error: "" }; }
      catch (e) { return { handle: 0, error: msg(e) }; }
    }
    case "init": { try { sinks.get(a.handle).init(a.state); return { error: "" }; } catch (e) { return { error: msg(e) }; } }
    case "commit": {
      faultArmed = typeof a.faultAt === "number" ? a.faultAt : -1; writeCount = 0; faultHit = false;
      let r: any;
      try { const x = sinks.get(a.handle).commit(a.text); r = { status: String(x?.status ?? "no status"), reason: x?.reason === undefined ? undefined : String(x.reason).slice(0, 200) }; }
      catch (e) { r = { status: "threw", reason: msg(e) }; }
      r.faultHit = faultHit; faultArmed = -1;
      return r;
    }
    case "close": { const s = sinks.get(a.handle); sinks.delete(a.handle); try { s?.close(); } catch { /* closed */ } return {}; }
    case "genesis": return typeof sinkMod?.genesisOf === "function" ? String(sinkMod.genesisOf(a.initText, a.lock, a.checker, a.pem)) : null;
    // CANDIDATE SIGNED-BYTES FUNCTIONS of the encoding module(s) that the code under test actually loaded: every
    // exported function that maps each given body to bytes (Buffer, Uint8Array or string, as UTF-8), as base64.
    // A PROBE only: the parent signs these bytes with the trusted key and asserts by behaviour.
    case "encodingCandidates": {
      const out: { name: string; bytes: string[] }[] = [];
      for (const p of encodingModules()) {
        let ex: any; try { ex = (require.cache[p] as any)?.exports; } catch { ex = null; }
        if (!ex || typeof ex !== "object") continue;
        for (const k of Object.keys(ex)) {
          const f = ex[k];
          if (typeof f !== "function" || /^class[\s{]/.test(Function.prototype.toString.call(f))) continue;
          try {
            const bs = (a.bodies as unknown[]).map(b => { const r = f(JP(JS(b)));
              if (typeof r === "string") return BF(r, "utf8").toString("base64");
              if (r instanceof Uint8Array) return BF(r).toString("base64");
              throw new Error("not bytes"); });
            out.push({ name: p + "#" + k, bytes: bs });
          } catch { /* not a bytes function for these bodies */ }
        }
      }
      return out;
    }
    case "flush": {
      // No effect list here: the parent's receiver holds the effects (see the header).
      let error = "";
      try { const d = new dispMod.Dispatcher(a.db, a.ledger, a.dcfg, emit); d.flush(); } catch (e) { error = msg(e); }
      return { error };
    }
    case "barrier": writeAll(JS({ t: "b", nonce: String(a.nonce) }) + "\n"); return {};
    default: throw new Error("unknown operation " + name);
  }
}
process.on("message", (m: any) => {
  if (!m || typeof m.id !== "number") return;
  let reply: any;
  try { reply = { id: m.id, ok: true, value: op(String(m.op), m.args ?? {}) }; } catch (e) { reply = { id: m.id, ok: false, error: msg(e) }; }
  send(reply);
});
send({ id: 0, ok: true, value: "ready" });
