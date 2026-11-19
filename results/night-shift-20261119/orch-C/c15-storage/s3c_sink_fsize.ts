// Attack 3c: RLIMIT_FSIZE (byte-exact; SIGXFSZ ignored) on the SINK process during commit() and during init().
// Attacker: none (a fault: file-size limit / quota; stands in for a failing write). For each limit L the child does
// one op under L; then (i) a child under the SAME limit reopens (hot-journal recovery under the limit) and retries;
// (ii) the parent (no limit) reopens and retries. Checks P1 and P3.
// args: op (commit|init) step.  exit 1 = an inconsistency (acked row missing; rejected but present and the retry is
// not "replayed"; the store never starts again; a legitimate retry refused); 0 = safe for every limit.
import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";
import { fixture, fresh, EV, tryOpen, settledIds } from "./common15";
const [op = "commit", stepS = "512"] = process.argv.slice(2);
(async () => {
  const fx = await fixture(); const W = join(EV, "work", "s3c-" + op); fresh(W);
  const tpl = join(W, "tpl.sqlite");
  { const s = tryOpen(tpl, fx).sink; if (op === "commit") { s.init(fx.cfg.initialState); s.commit(fx.tokens[0].text); } s.close(); }
  const S = statSync(tpl).size; const db = join(W, "sink.sqlite"); const res: any[] = []; const bad: any[] = []; const kinds: Record<string, number> = {};
  const child = (L: number, args: string[]) => execFileSync("/usr/bin/python3", ["-I", join(EV, "fsize.py"), String(L), process.execPath, "--import", "tsx", join(EV, "child_op.ts"), db, ...args]).toString().split("\n").filter(l => /^(COMMIT|INIT|OPENFAIL|CLOSE|CHILDTHROW)/.test(l)).join(" | ");
  const args = op === "commit" ? ["commit", "1"] : ["init"];
  for (let L = 0; L <= S + 20480; L += Number(stepS)) {
    for (const x of ["", "-journal"]) rmSync(db + x, { force: true }); copyFileSync(tpl, db);
    const r: any = { L, first: child(L, args) }; r.journalLeft = existsSync(db + "-journal");
    r.sameLimitRetry = child(L, args);
    const o = tryOpen(db, fx); r.restart = o.err ?? "ok";
    if (o.sink) {
      if (op === "commit") { r.idsBefore = settledIds(o.sink).join(","); r.retry = o.sink.commit(fx.tokens[1].text).status; r.r3 = o.sink.commit(fx.tokens[2].text).status; }
      else { try { o.sink.init(fx.cfg.initialState); r.retry = "init ok"; } catch (e) { r.retry = "init throws " + (e as Error).message; } r.r1 = o.sink.commit(fx.tokens[0].text).status; }
      o.sink.close();
    }
    const firstAck = /"status":"committed"|INIT ok/.test(r.first);
    let why = "";
    if (r.restart !== "ok") why = "store does not start after the fault";
    else if (op === "commit" && firstAck && !String(r.idsBefore).includes("r2")) why = "acked commit missing";
    else if (op === "commit" && !(r.retry === "committed" || r.retry === "replayed")) why = "legit retry refused: " + r.retry;
    else if (op === "commit" && r.r3 !== "committed") why = "next refund refused: " + r.r3;
    else if (op === "init" && (r.retry !== "init ok" || r.r1 !== "committed")) why = "init/first refund refused";
    r.why = why; if (why) bad.push(r);
    const k = r.first.replace(/"reason":"[^"]{0,60}[^"]*"/, m => m.slice(0, 70)).slice(0, 110); kinds[k] = (kinds[k] ?? 0) + 1; res.push(r);
  }
  console.log(JSON.stringify({ op, templateBytes: S, limits: res.length, firstOutcomes: kinds, bad: bad.slice(0, 6) }, null, 1));
  console.log(bad.length ? "DEFECT" : "SAFE"); process.exit(bad.length ? 1 : 0);
})();
