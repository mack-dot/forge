// Y6 harness child (NOT repository code). One commit process. It loads a bundled sink module by path
// (the repository sink.ts unchanged, or a broken copy for a negative control).
// Modes:
//   pause <sink.cjs> <db> <cfg> <token file> <point>   : patches node:sqlite IN THIS PROCESS ONLY, commits one
//        token, and at <point> writes "PAUSED <point>\n" to fd 1 and blocks forever (the parent sends SIGKILL).
//   chain <sink.cjs> <db> <cfg> <tokens json> <log> <selfkill micros|-1> : commits the tokens in order; after each
//        result it appends one line to <log> with a synchronous write. With selfkill >= 0 a worker thread sends
//        SIGKILL to this process that many microseconds after the first commit call starts.
//   race <sink.cjs> <db> <cfg> <token file> <startAt ms> : waits for the common start time, commits, prints the result.
import { readFileSync, writeSync, openSync } from "node:fs";
import { Worker } from "node:worker_threads";
import * as sqlite from "node:sqlite";

const [mode, sinkPath, dbPath, cfgPath, arg1, arg2, arg3] = process.argv.slice(2);
const pauseForever = (point: string): never => {
  writeSync(1, `PAUSED ${point}\n`);
  const sab = new Int32Array(new SharedArrayBuffer(4));
  for (;;) Atomics.wait(sab, 0, 0, 1_000_000);
};

let pausePoint = "";
const counts = new Map<string, number>();
const hit = (name: string): void => {
  const n = (counts.get(name) ?? 0) + 1;
  counts.set(name, n);
  if (pausePoint === name || pausePoint === `${name}#${n}`) pauseForever(pausePoint);
};
const classify = (sql: string): string => {
  const s = sql.replace(/\s+/g, " ").trim();
  if (s.startsWith("SELECT token_sha256 FROM settled")) return "select-settled";
  if (s.startsWith("SELECT blob FROM state")) return "select-state";
  if (s.startsWith("UPDATE state")) return "update-state";
  if (s.startsWith("INSERT INTO settled")) return "insert-settled";
  if (s.startsWith("INSERT INTO outbox")) return "insert-outbox";
  return "other";
};
function patch(): void {
  const D = sqlite.DatabaseSync.prototype as any, S = sqlite.StatementSync.prototype as any;
  const exec = D.exec;
  D.exec = function (sql: string) {
    const tag = sql.trim().split(/\s+/)[0].toLowerCase();
    if (tag === "begin" || tag === "commit" || tag === "rollback") hit(`before-${tag}`);
    const r = exec.call(this, sql);
    if (tag === "begin" || tag === "commit" || tag === "rollback") hit(`after-${tag}`);
    return r;
  };
  for (const m of ["run", "get", "all"]) {
    const orig = S[m];
    S[m] = function (...a: unknown[]) {
      const r = orig.apply(this, a);
      hit(`after-${classify(this.sourceSQL)}`);
      return r;
    };
  }
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(sinkPath);
const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));

if (mode === "pause") {
  pausePoint = arg2;
  patch();
  const sink = new Sink(dbPath, cfg);
  const text = readFileSync(arg1, "utf8");
  hit("before-call");
  const result = sink.commit(text);
  hit("after-return");
  writeSync(1, JSON.stringify({ done: true, ...result }) + "\n");
  sink.close();
} else if (mode === "chain") {
  const tokens: string[] = JSON.parse(readFileSync(arg1, "utf8"));
  const log = openSync(arg2, "a");
  const micros = Number(arg3);
  const sink = new Sink(dbPath, cfg);
  writeSync(1, "READY\n");
  if (micros >= 0) {
    const pid = process.pid;
    const flags = new Int32Array(new SharedArrayBuffer(8));
    new Worker(`const {workerData:f}=require('node:worker_threads');Atomics.store(f,1,1);` +
      `while(Atomics.load(f,0)===0){} const end=process.hrtime.bigint()+${Math.floor(micros)}n*1000n;` +
      `while(process.hrtime.bigint()<end){} process.kill(${pid},'SIGKILL');`, { eval: true, workerData: flags });
    while (Atomics.load(flags, 1) === 0) Atomics.wait(flags, 1, 0, 1);
    Atomics.store(flags, 0, 1); // the worker's clock starts now; the first commit call follows at once
  }
  const T0 = process.hrtime.bigint();
  tokens.forEach((t, i) => {
    const r = sink.commit(t);
    const ms = Number(process.hrtime.bigint() - T0) / 1e6;
    writeSync(log, JSON.stringify({ i, status: r.status, reason: r.reason ?? null, ms }) + "\n");
  });
  writeSync(1, "DONE\n");
  sink.close();
  process.exit(0);
} else if (mode === "race") {
  const sink = new Sink(dbPath, cfg);
  const text = readFileSync(arg1, "utf8");
  const onTime = Date.now() < Number(arg2);
  while (Date.now() < Number(arg2)) { /* common start */ }
  const result = sink.commit(text);
  writeSync(1, JSON.stringify({ ...result, onTime }) + "\n");
  sink.close();
} else {
  process.stderr.write("bad mode\n"); process.exit(2);
}
