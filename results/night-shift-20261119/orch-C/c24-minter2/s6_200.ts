// S6: Store mode; N honest sequential refunds (mint + commit, every 5th amount 0). Attacker: none.
// Exit 1 = any refusal, or the mean mint time of the last 20 is more than 3x the mean of the first 20 (after 5 warm-up).
// Usage: s6_200.ts <work dir> [N=200]
import { execSync } from "node:child_process";
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, nArg = "200"] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const N = Number(nArg), path = join(work, "s.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S6", "100000", "100000");
  const sink = newSink(m, path, s0); sink.init(s0);
  const ms: number[] = [], refused: string[] = [];
  const rss = () => Number(execSync("ps -o rss= -p " + m.child.pid).toString().trim());
  let cur = s0, rss0 = 0;
  for (let i = 0; i < N; i++) {
    if (i === 5) rss0 = rss();
    const t0 = process.hrtime.bigint();
    const t = await mint(m, cur, propose(cur, "rq_" + i, i % 5 === 0 ? "0" : String(1 + (i % 7))));
    ms.push(Number(process.hrtime.bigint() - t0) / 1e6);
    if (!t.ok) { refused.push(i + ": " + t.reason); continue; }
    const c = sink.commit(t.text); if (c.status !== "committed") refused.push(i + " commit: " + c.reason);
    cur = JSON.parse(sink.stateBlob());
  }
  const mean = (a: number[]) => a.reduce((x, y) => x + y, 0) / a.length;
  const first = mean(ms.slice(5, 25)), last = mean(ms.slice(-20));
  const r = { N, refused, firstMeanMs: first.toFixed(2), lastMeanMs: last.toFixed(2), rssKbAt5: rss0, rssKbEnd: rss(), finalRemaining: cur.remaining };
  sink.close(); m.stop();
  done(refused.length > 0 || last > 3 * first, r);
})());
