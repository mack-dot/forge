// Minter under concurrent mint calls for ONE pre-state (one issuer process, 24 calls in flight): 8 request ids x
// 3 amounts each (400, 500, 600 of remaining 1000: any two exceed it). Then all signed tokens go to the sink in a
// shuffled order. P1: <= 1 commit per request id; P2: remaining >= 0 and = 1000 - sum(committed).
// Mode "on": also a LOST token: the client that got the first token crashes before commit (the token is dropped);
// an honest DIFFERENT request for the same pre-state is then tried: refused => the charge is stuck (P3).
// Exit 1 = a P1/P2 defect (or, in mode "on", the P3 lock-out); 0 = safe.
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { EVID, S0, Sink, minter } from "./lib";
const mode = (process.argv[2] ?? "off") as "on" | "off";
(async () => {
  const work = join(EVID, "work/t7"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const { m, ids, mint } = await minter(mode);
  const s = new Sink(join(work, "s.sqlite"), { ...ids, initialState: S0 }); s.init(S0);
  const calls: Promise<any>[] = [];
  for (let r = 0; r < 8; r++) for (const a of ["400", "500", "600"]) calls.push(mint(S0, `m${r}`, a));
  const res = await Promise.all(calls);
  const signed = res.filter(x => x.ok).map(x => x.text as string);
  const refusedMint = res.filter(x => !x.ok).length;
  let lostOut: any = null;
  if (mode === "on") {
    // the holder of signed[0] crashes: its token is never committed. Another honest request for S0:
    const other = await mint(S0, "m_after_crash", "10");
    lostOut = other.ok ? s.commit(other.text) : { status: "mint refused: " + other.reason };
  } else {
    signed.sort(() => Math.random() - 0.5);
  }
  const out = mode === "on" ? [] : signed.map(t => s.commit(t));
  const committed = out.filter(o => o.status === "committed").length;
  const rem = BigInt(JSON.parse(s.stateBlob()).remaining);
  const sumC = s.outbox().reduce((acc: bigint, o: any) => acc + BigInt(JSON.parse(o.intent).amount), 0n);
  const p12 = s.outbox().length === new Set(s.outbox().map((o: any) => o.request_id)).size && rem >= 0n && rem === 1000n - sumC && committed <= 1;
  const p3 = mode !== "on" || lostOut.status === "committed";
  console.log(JSON.stringify({ mode, signedTokens: signed.length, refusedMint, committed, remaining: rem.toString(), p12, afterLostToken: lostOut, p3 }));
  s.close(); m.stop();
  process.exit(p12 && p3 ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
