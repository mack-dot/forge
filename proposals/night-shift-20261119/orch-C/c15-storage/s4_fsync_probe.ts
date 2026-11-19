// Attack 4 (measurement only; a power cut cannot be run). (a) the SQLite pragmas the sink's connection runs with;
// (b) timing of Node fsyncSync against fsync(2) and fcntl(F_FULLFSYNC) from Python on the same volume.
import { execFileSync } from "node:child_process";
import { closeSync, fsyncSync, openSync, writeSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fixture, fresh, EV, tryOpen } from "./common15";
(async () => {
  const fx = await fixture(); const W = join(EV, "work", "s4"); fresh(W); const db = join(W, "sink.sqlite");
  const s = tryOpen(db, fx).sink; s.init(fx.cfg.initialState); const c = (s as any).db as DatabaseSync; const out: any = {};
  for (const p of ["fullfsync", "checkpoint_fullfsync", "synchronous", "journal_mode"]) out[p] = Object.values(c.prepare("PRAGMA " + p).get() as any)[0];
  out.sqlite_version = (c.prepare("SELECT sqlite_version() AS v").get() as any).v;
  out.compile = (c.prepare("PRAGMA compile_options").all() as any[]).map(r => r.compile_options).filter((o: string) => /SYNC|FSYNC|DEFAULT_WAL|DEFAULT_JOURNAL/.test(o));
  s.close();
  const N = 200, f = join(W, "t.bin"); const fd = openSync(f, "w"); let t = process.hrtime.bigint();
  for (let i = 0; i < N; i++) { writeSync(fd, "x"); fsyncSync(fd); } out.node_fsyncSync_us = Number((process.hrtime.bigint() - t) / BigInt(N) / 1000n); closeSync(fd);
  const py = `import os,fcntl,time,sys
f=sys.argv[1];fd=os.open(f,os.O_WRONLY|os.O_CREAT);N=200
t=time.perf_counter()
for i in range(N): os.write(fd,b"x"); os.fsync(fd)
a=(time.perf_counter()-t)/N*1e6
t=time.perf_counter()
for i in range(N): os.write(fd,b"x"); fcntl.fcntl(fd,51)
b=(time.perf_counter()-t)/N*1e6
t=time.perf_counter()
for i in range(N): os.write(fd,b"x"); fcntl.fcntl(fd,85)
c=(time.perf_counter()-t)/N*1e6
print(int(a),int(b),int(c))`;
  const [a, b, c2] = execFileSync("/usr/bin/python3", ["-I", "-c", py, join(W, "p.bin")]).toString().trim().split(" ").map(Number);
  out.py_fsync_us = a; out.py_F_FULLFSYNC_us = b; out.py_F_BARRIERFSYNC_us = c2;
  console.log(JSON.stringify(out)); process.exit(0);
})();
