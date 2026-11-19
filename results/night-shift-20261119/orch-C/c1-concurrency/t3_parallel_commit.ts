// P1/P2 under concurrency: 4 OS processes + 2 Sink objects in this process, one database file. Per round, one
// pre-state; tokens: A(rid x,10) A(again) A'(rid x, 20) B(rid y, 30) given to the 4 processes at one wall time,
// then the 2 local objects commit A' and B. Checks: exactly one commit per round; a commit of A implies the other
// A gets "replayed"; final state = initial - sum(committed); audit() empty; a restart starts; outbox == committed.
// Exit 1 = defect present; 0 = safe.
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { E, EVID, S0, Sink, minter } from "./lib";
const rounds = Number(process.argv[2] ?? 20);
(async () => {
  const work = join(EVID, "work/t3"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const db = join(work, "s.sqlite");
  const { m, ids, mint } = await minter("off");
  const cfg = { ...ids, initialState: S0 };
  const s = new Sink(db, cfg); s.init(S0);
  const local2 = new Sink(db, cfg);
  const kids = [0, 1, 2, 3].map(() => {
    const c = spawn(process.execPath, ["--import", "tsx", join(EVID, "t3_child.ts"), db, JSON.stringify(ids)], { stdio: ["pipe", "pipe", "inherit"] });
    const q: ((x: any) => void)[] = []; createInterface({ input: c.stdout }).on("line", l => q.shift()!(JSON.parse(l)));
    return { c, next: () => new Promise<any>(res => q.push(res)) };
  });
  await Promise.all(kids.map(k => k.next()));
  let bad = 0; const notes: string[] = []; let sum = 0n; let ackedCommits = 0;
  for (let r = 0; r < rounds; r++) {
    const pre = JSON.parse(s.stateBlob());
    const A = (await mint(pre, `x${r}`, "10")).text!, A2 = (await mint(pre, `x${r}`, "20")).text!, B = (await mint(pre, `y${r}`, "30")).text!;
    const at = Date.now() + 150; const toks = [A, A, A2, B];
    const ps = kids.map((k, i) => { const p = k.next(); k.c.stdin.write(JSON.stringify({ token: toks[i], at }) + "\n"); return p; });
    const res = (await Promise.all(ps)).map(x => x.r);
    res.push(s.commit(A2), local2.commit(B), local2.commit(A));
    const allToks = [A, A, A2, B, A2, B, A];
    const committed = res.map((x, i) => [x.status, i] as const).filter(x => x[0] === "committed");
    if (committed.length !== 1) { bad++; notes.push(`round ${r}: ${committed.length} commits ${JSON.stringify(res)}`); continue; }
    const winner = allToks[committed[0][1]];
    res.forEach((x, i) => { if (allToks[i] === winner && x.status !== "committed" && x.status !== "replayed") { bad++; notes.push(`round ${r}: same token not replayed: ${JSON.stringify(x)}`); } });
    sum += BigInt(JSON.parse(winner).body.intent.amount); ackedCommits++;
  }
  const fin = JSON.parse(s.stateBlob());
  const audit = s.audit(); const outN = s.outbox().length;
  s.close(); local2.close(); for (const k of kids) k.c.kill(); m.stop();
  let restart = "ok"; try { new Sink(db, cfg).close(); } catch (e) { restart = String((e as Error).message); }
  const okState = BigInt(fin.remaining) === BigInt(S0.remaining) - sum && BigInt(fin.remaining) >= 0n;
  console.log(JSON.stringify({ rounds, bad, ackedCommits, outbox: outN, remaining: fin.remaining, okState, audit, restart, notes: notes.slice(0, 4) }));
  process.exit(bad === 0 && okState && audit.length === 0 && outN === ackedCommits && restart === "ok" ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
