// F3/F4: (a) Replayed must return byte-identical token text, also after N other requests; a replay with another
// pre-state must NOT return the stored bytes. (b) memory growth: RSS of the minter and time per request per batch of 100.
// Mode "on". Attacker for (b): any minter caller without the key (each new (charge, request id) is kept for the process life;
// the Dafny JS Map is an array with linear findIndex and a full copy (slice) per insert).
// Usage: f3_replay_growth.ts <N <= 2000> <replay|growth>
//  replay: exit 1 if the replay answer differs from the first (apart from the message id) or a changed pre-state gets the stored token.
//  growth: exit 1 if the mean time per request in the LAST batch of 100 is more than 3x that of the FIRST batch.
import { execFileSync } from "node:child_process";
import { Raw, done, guard, mint, propose, st } from "./lib";
const N = Math.min(2000, Number(process.argv[2] || 1000)), mode = process.argv[3] || "replay";
const rss = (pid: number) => Number(execFileSync("/bin/ps", ["-o", "rss=", "-p", String(pid)]).toString().trim());
const strip = (b: Buffer) => b.toString("utf8").replace(/^\{"id":\d+,/, "");
guard((async () => {
  const m = await new Raw(["on"]).start();
  const s0 = st("ch_G", "9223372036854775807", "9223372036854775807");
  const first = await mint(m, s0, propose(s0, "rq_X", "17"));
  const again0 = await mint(m, s0, propose(s0, "rq_X", "17"));
  const r: any = { N, firstOk: first.ok, rss0_kB: rss(m.child.pid!), batches_ms: [] as number[] };
  let t = Date.now();
  for (let i = 0; i < N; i++) {
    const a = await mint(m, s0, propose(s0, "rq_" + i, "1"));
    if (!a.ok) throw new Error("unexpected refusal " + i + " " + a.reason);
    if ((i + 1) % 100 === 0) { r.batches_ms.push(Date.now() - t); t = Date.now(); }
    if ((i + 1) % 250 === 0) (r.rss_kB ??= []).push(rss(m.child.pid!));
  }
  r.rssN_kB = rss(m.child.pid!);
  const replay = await mint(m, s0, propose(s0, "rq_X", "17"));
  r.replayImmediateSame = strip(again0.raw) === strip(first.raw);
  r.replayAfterNSame = replay.ok && strip(replay.raw) === strip(first.raw);
  const s0b = st("ch_G", "9223372036854775807", "9223372036854775806");
  const other = await mint(m, s0b, propose(s0b, "rq_X", "17"));
  r.replayOtherPre = other.ok ? "SIGNED (" + (strip(other.raw) === strip(first.raw) ? "stored bytes" : "new bytes") + ")" : "refused: " + other.reason;
  const t0 = Date.now(); for (let i = 0; i < 20; i++) await mint(m, s0, propose(s0, "rq_X", "17")); r.replay20_ms = Date.now() - t0;
  m.stop();
  const b = r.batches_ms; r.ratioLastFirst = b.length ? +(b[b.length - 1] / Math.max(1, b[0])).toFixed(2) : null;
  if (mode === "replay") done(!(r.replayImmediateSame && r.replayAfterNSame && !other.ok), r);
  done(r.ratioLastFirst !== null && r.ratioLastFirst > 3, r);
})());
