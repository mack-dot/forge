// Regression for OWNER DECISION D-1 (b), task h-key: a FIFO or a DIRECTORY at the key path is refused, and the open does
// not block on the FIFO (no writer ever opens it). keyfile.ts opens with O_RDONLY | O_NOFOLLOW | O_NONBLOCK: open(2) of
// a FIFO for reading with O_NONBLOCK returns at once; fstat says "not a regular file". O_NONBLOCK is not cleared (Node
// has no fcntl); it has no effect on read(2) of a regular file, the only kind that passes.
// Each minter start has a 15 s limit: a start that blocks is a FAIL. CONTROL: a 0600 regular key file starts.
// SAFE = exit 0. On f67c5c16: the minter starts (the path is not read as a key) -> FAIL.
import { spawnSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, keyTempDir, load, makeKeyFile, startMinter, verdict } from "./kf_lib";

guard((async () => {
  const { root, core } = argv();
  const { KF } = load(root);
  const dir = keyTempDir(), fifo = join(dir, "fifo.pem"), sub = join(dir, "dir.pem");
  const mk = spawnSync("/usr/bin/mkfifo", ["-m", "600", fifo]);
  if (mk.status !== 0) verdict(false, { setup: "mkfifo failed" });
  mkdirSync(sub, { mode: 0o700 });
  const r: any = {};
  for (const [name, path] of [["fifo", fifo], ["directory", sub]] as const) {
    const t0 = Date.now(), m = await startMinter(root, core, [path], "on", 15000); m.stop();
    r[name] = { ready: m.ready !== null, code: m.code, timedOut: m.timedOut, notRegular: /not a regular file/.test(m.stderr), ms: Date.now() - t0 > 14000 ? "LIMIT" : "under 14 s" };
    if (KF !== null && typeof KF.loadSigningKey === "function") {
      const t1 = Date.now(); let why = "";
      try { KF.loadSigningKey(path); why = "ACCEPTED"; } catch (e) { why = String((e as Error).message); }
      r[name].direct = { refused: /not a regular file/.test(why), quick: Date.now() - t1 < 2000 };
    } else r[name].direct = "NOT AVAILABLE (no keyfile.ts)";
  }
  const k = makeKeyFile(), c = await startMinter(root, core, [k.path]); c.stop();
  r.control = { ready: c.ready !== null && c.ready.keyId === k.keyId };
  const ok = (x: any) => !x.ready && x.code === 2 && !x.timedOut && x.notRegular && typeof x.direct === "object" && x.direct.refused && x.direct.quick;
  verdict(ok(r.fifo) && ok(r.directory) && r.control.ready, r);
})());
