// d2_two_tokens.ts <work dir>   (owner decision D-2: a refusal closes only the attempt; only a minted token closes the id)
// Written by Orchestrator C. Minter in Store mode ("on" + the sink's store path) with the sink of the same tree.
// It tries to get TWO DIFFERENT valid tokens, or TWO committed effects, for ONE request id through:
//   A. refusals first, then a valid mint, then another valid candidate for the same id;
//   B. a refusal between two valid candidates;
//   C. a burst of 12 different valid candidates for one id sent together;
//   D. after the commit: another candidate, and an identical retry;
//   E. a minter restart (memory lost) before the commit, then another candidate for the same id.
// Then every token that was issued is offered to the sink, in two orders, and the outbox rows per request id are counted.
// Exit 1 = one minter process issued two different tokens for one request id, or the sink holds two effects for one
//          request id. Exit 0 = neither. A second token issued by a RESTARTED minter is reported separately (it is signed
//          with another key today; with a persistent key it would be a second valid token: see the printed note).
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st, E as LIB_E } from "./lib";
const [work] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  let m = await new Raw(["on", path]).start();
  const s0 = st("ch_D2", "1000", "1000");
  const sink = newSink(m, path, s0); sink.init(s0);
  const r: any = {}; const issued: Record<string, Set<string>> = {}; const all: { id: string; text: string; by: string }[] = [];
  const note = (id: string, a: { ok: boolean; text?: string }, by: string) => { if (a.ok && a.text) { (issued[id] ??= new Set()).add(a.text); all.push({ id, text: a.text, by }); } return a.ok ? "issued" : "refused"; };
  // A. three refusals (unapproved reason, amount above remaining, unapproved reason), then valid 100, then valid 200
  r.A_refusals = [];
  for (const [amt, reason] of [["100", "attacker_text"], ["5000", "duplicate_charge"], ["1", "free_money"]] as const)
    r.A_refusals.push(note("rq_A", await mint(m, s0, propose(s0, "rq_A", amt, reason)), "m1"));
  r.A_first = note("rq_A", await mint(m, s0, propose(s0, "rq_A", "100")), "m1");
  r.A_other = note("rq_A", await mint(m, s0, propose(s0, "rq_A", "200")), "m1");
  // B. a refusal between two valid candidates
  r.B_first = note("rq_B", await mint(m, s0, propose(s0, "rq_B", "50")), "m1");
  r.B_refusal = note("rq_B", await mint(m, s0, propose(s0, "rq_B", "50", "attacker_text")), "m1");
  r.B_other = note("rq_B", await mint(m, s0, propose(s0, "rq_B", "60")), "m1");
  r.B_identical = note("rq_B", await mint(m, s0, propose(s0, "rq_B", "50")), "m1");
  // C. a burst of 12 different candidates for one id
  // all 12 request lines go to the minter in ONE write; then 12 answers are read
  const lines = Array.from({ length: 12 }, (_, i) => JSON.stringify({ id: 9001 + i, pre: s0, transition: propose(s0, "rq_C", String(i + 1)) }));
  const answers = await m.send(lines.join("\n"), 12);
  r.C_burst = answers.map(a => note("rq_C", a.msg.ok ? { ok: true, text: LIB_E.tokenText(a.msg.token) } : { ok: false }, "m1")).filter(x => x === "issued").length + " of 12 issued";
  // E. restart the minter before any commit (memory lost), then another candidate for rq_A and rq_C
  const pin1 = m.ready.publicKeyPem; m.stop?.();
  m = await new Raw(["on", path]).start();
  r.E_newKeyAfterRestart = m.ready.publicKeyPem !== pin1;
  const e1 = await mint(m, s0, propose(s0, "rq_A", "300")), e2 = await mint(m, s0, propose(s0, "rq_C", "77"));
  r.E_afterRestart = [e1.ok ? "issued" : "refused: " + e1.reason, e2.ok ? "issued" : "refused: " + e2.reason];
  const afterRestart = [e1, e2].filter(a => a.ok && a.text).map((a, i) => ({ id: i === 0 ? "rq_A" : "rq_C", text: a.text as string, by: "m2" }));
  // offer every token to the sink (pinned to the FIRST key), first in issue order, then in reverse
  const verdicts: string[] = [];
  for (const t of [...all, ...afterRestart, ...[...all, ...afterRestart].reverse()]) verdicts.push(t.id + "/" + t.by + ":" + sink.commit(t.text).status);
  r.commits = verdicts.filter(v => v.endsWith(":committed"));
  // D. after the commits: another candidate and an identical retry for a committed id, with the restarted minter
  const sNow = JSON.parse(sink.stateBlob());
  const d1 = await mint(m, sNow, propose(sNow, "rq_B", "61"));
  r.D_otherAfterCommit = d1.ok ? "issued -> " + sink.commit(d1.text).status : "refused: " + d1.reason;
  const rows: Record<string, number> = {};
  for (const o of sink.outbox()) rows[o.request_id] = (rows[o.request_id] ?? 0) + 1;
  r.outboxRowsPerId = rows;
  r.distinctTokensPerIdFromOneMinter = Object.fromEntries(Object.entries(issued).map(([k, v]) => [k, v.size]));
  r.note = "tokens issued by the restarted minter: " + afterRestart.length + " (signed with another key today; the sink pinned to the first key refuses them)";
  m.stop?.(); sink.close();
  const twoTokens = Object.values(issued).some(v => v.size > 1), twoEffects = Object.values(rows).some(n => n > 1);
  r.twoTokensFromOneMinter = twoTokens; r.twoEffectsForOneId = twoEffects;
  done(twoTokens || twoEffects, r);
})());
