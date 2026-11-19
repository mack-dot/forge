// CHILD process of the refund-finality judges (night shift 2026-11-19, task h-judges). A TEST, not a proof.
// The judges (regress/run.ts, spec-conformance/run.ts) never load the code under test into their own process.
// They start this file as a child process (node --import tsx worker.ts <sink module> <dispatcher module|none>) and
// send it operations over the Node IPC channel. This file runs ONLY the operations that the parent asks for and
// answers with plain values. It decides nothing: every assertion, every database read for a verdict and every
// PASS/FAIL line is in the parent. Output of this process (stdout, stderr, exit code) is never a verdict.
// Captured BEFORE the module under test loads, so a module that replaces fs functions does not change them here.
// (A module that runs in this process can still do anything this process can do: see the README, open doubts.)
import { readFileSync as RF, existsSync as EX } from "node:fs";
import * as sqlite from "node:sqlite";
import { resolve } from "node:path";

const send = process.send!.bind(process);
const [sinkPath, dispPath] = process.argv.slice(2);
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
const encNext = (() => { try { const p = resolve(sinkPath, "..", "encoding.ts"); return EX(p) ? require(p) : null; } catch { return null; } })();
/* eslint-enable @typescript-eslint/no-require-imports */
const sinks = new Map<number, any>();
let nextHandle = 1;
const msg = (e: unknown) => String((e as Error)?.message ?? e).slice(0, 200);

function op(name: string, a: any): unknown {
  switch (name) {
    case "hello": return { loadError, hasSink: typeof sinkMod?.Sink === "function", hasDispatcher: typeof dispMod?.Dispatcher === "function",
      hasGenesisOf: typeof sinkMod?.genesisOf === "function" };
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
    // signedBytes of the encoding.ts NEXT TO the sink (if any), as base64, for two bodies. Probe only.
    case "neighborSignedBytes": {
      if (!encNext || typeof encNext.signedBytes !== "function") return null;
      try { return a.bodies.map((b: unknown) => Buffer.from(encNext.signedBytes(b)).toString("base64")); } catch (e) { return { error: msg(e) }; }
    }
    case "flush": {
      // Effects are recorded by this file's emit callback with the ledger bytes AT THE MOMENT OF THE EMIT, so the
      // parent can check the documented order (ledger line first). failAt: the emit with this index throws.
      const effects: { requestId: string; intent: unknown; ledgerHadLine: boolean; threw: boolean }[] = [];
      let error = "", n = 0;
      try {
        const d = new dispMod.Dispatcher(a.db, a.ledger, a.dcfg, (e: any, i: any) => {
          const rid = String(e?.requestId);
          let had = false;
          try { had = EX(a.ledger) && RF(a.ledger, "utf8").split("\n").some(l => { try { return JSON.parse(l).requestId === rid; } catch { return false; } }); } catch { had = false; }
          const threw = a.failAt === n++;
          effects.push({ requestId: rid, intent: JSON.parse(JSON.stringify(i ?? null)), ledgerHadLine: had, threw });
          if (threw) throw new Error("injected emit failure");
        });
        d.flush();
      } catch (e) { error = msg(e); }
      return { effects, error };
    }
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
