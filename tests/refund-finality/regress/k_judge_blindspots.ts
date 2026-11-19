// Regressions that close the judge blind spots of red-team finding C-JUDGE-01 (Orchestrator C,
// results/night-shift-20261119/orch-C/ATTACKS.md; mutants in orch-C/c10-judges). Task h-judges. A TEST, not a proof.
// Every case states its SAFE outcome on DURABLE state (outbox rows, settled ids, stored state, read by the parent)
// and on EFFECTS (the records that the PARENT's receiver got, remote.ts; the ledger file read by the parent). Each case has
// a liveness part, so a sink that rejects everything FAILS it.
// Source of each expected outcome: the Slice 1 finality design (ts/refund-finality/sink.ts header, checks 1-4, and
// ts/refund-finality/dispatcher.ts header, checks 1-5 and the ledger order), not the approved refund spec, which is
// SILENT on tokens. The status words are the ones that the merged sink documents (CommitResult in sink.ts):
// "committed", "replayed" (the identical token of a settled request id), "rejected".
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { Harness, Intent, Regression, State, TRUSTED_ENCODING_PATH, WriteRefused, WriterMode, fail, pass, twoWriters } from "./harness";

type Why = string[];
const unchanged = (h: Harness, db: string, s: State, nOut: number) => h.E.canon(h.stored(db)) === h.E.canon(s) && h.outbox(db).length === nOut;
const effectsOf = (es: { intent: Intent }[], rid: string) => es.filter(e => e.intent?.requestId === rid).length;

export const judges: Regression[] = [
  { id: "K1-foreign-key-signature", kind: "attack", title: "a token signed by a key that is not the pinned one",
    // SAFE: no outbox row, state unchanged, no effect. LIVENESS: the same body signed by the pinned key commits and is emitted once.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = await h.newStore("k1", S0);
      const body = h.body(S0, "rq_1", h.dec(S0, "100"), h.intent("ch_1", "rq_1", "100"));
      const r1 = await h.commit(sink, h.signBody(body, true));
      const safe = unchanged(h, db, S0, 0);
      const r2 = await h.commit(sink, h.signBody(body));
      const f = await h.flush(db, S0);
      const why = `foreignKey=${r1} unchanged=${safe} pinnedKey=${r2} effects(rq_1)=${effectsOf(f.effects, "rq_1")}`;
      if (!safe) return fail("FOREIGN-KEY TOKEN COMMITTED: " + why);
      return effectsOf(f.effects, "rq_1") === 1 && h.outbox(db).length === 1 ? pass(why) : fail("honest token not committed and emitted once: " + why);
    } },
  { id: "K2-noncanonical-text", kind: "attack", title: "a validly signed token in a non-canonical text",
    // SAFE: none of three non-canonical texts (indentation, key order, an escaped letter) commits. LIVENESS: the canonical text commits once.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = await h.newStore("k2", S0);
      const t = h.honest(S0, "rq_1", "100"); const v = JSON.parse(t);
      const texts: [string, string][] = [["indent", JSON.stringify(v, null, 1)], ["key-order", JSON.stringify({ signature: v.signature, body: v.body })],
        ["escaped-letter", t.replace('"requestId":"rq_1"', '"requestId":"\\u0072q_1"')]];
      const why: Why = [];
      for (const [name, x] of texts) {
        if (x === t || h.E.canon(JSON.parse(x)) !== t) return fail("judge fault: variant " + name + " is not a non-canonical text of the token");
        why.push(`${name}=${await h.commit(sink, x)}`);
        if (!unchanged(h, db, S0, 0)) return fail(`NON-CANONICAL TEXT COMMITTED (${name}): ` + why.join(" "));
      }
      why.push("canonical=" + await h.commit(sink, t));
      const f = await h.flush(db, S0);
      why.push(`effects(rq_1)=${effectsOf(f.effects, "rq_1")}`);
      return effectsOf(f.effects, "rq_1") === 1 && h.outbox(db).length === 1 ? pass(why.join(" ")) : fail("canonical token not committed and emitted once: " + why.join(" "));
    } },
  { id: "K3-stale-prestate", kind: "attack", title: "a token whose pre-state hash is not the stored state",
    // rq_1 moves S0 to S1. Then a validly signed zero-amount token for rq_2 carries preStateSha256 = hash(S0) and
    // post = S1: everything but the pre-state binding fits the stored state. SAFE: it does not commit.
    // LIVENESS: the same refund with the current pre-state hash commits and is emitted once.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100"); const { db, sink } = await h.newStore("k3", S0);
      const c1 = await h.commit(sink, h.honest(S0, "rq_1", "100"));
      if (c1 !== "committed") return fail("setup: honest rq_1 refused: " + c1);
      const stale = await h.commit(sink, h.sign(S0, "rq_2", S1, h.intent("ch_1", "rq_2", "0", "duplicate_charge")));
      const safe = unchanged(h, db, S1, 1);
      const cur = await h.commit(sink, h.honest(S1, "rq_2", "0", "duplicate_charge"));
      const f = await h.flush(db, S0);
      const why = `stale=${stale} unchanged=${safe} current=${cur} effects(rq_2)=${effectsOf(f.effects, "rq_2")}`;
      if (!safe) return fail("STALE PRE-STATE COMMITTED: " + why);
      return effectsOf(f.effects, "rq_2") === 1 ? pass(why) : fail("current token not committed and emitted once: " + why);
    } },
  { id: "K4-replay-status", kind: "attack", title: "identical retry = replayed; another token for a settled id = rejected",
    // SAFE: the identical retry of a committed token answers "replayed" and makes no second row or effect; a
    // DIFFERENT validly signed token for the settled request id answers "rejected" and changes nothing.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100"); const { db, sink } = await h.newStore("k4", S0);
      const t = h.honest(S0, "rq_1", "100");
      const c1 = await h.commit(sink, t);
      if (c1 !== "committed") return fail("setup: honest rq_1 refused: " + c1);
      const same = await h.commit(sink, t);
      const s1 = unchanged(h, db, S1, 1);
      const other = await h.commit(sink, h.honest(S1, "rq_1", "50"));
      const s2 = unchanged(h, db, S1, 1);
      const f = await h.flush(db, S0); const f2 = await h.flush(db, S0);
      const n = effectsOf([...f.effects, ...f2.effects], "rq_1");
      const why = `first=${c1} identical=${same} different=${other} unchanged=${s1 && s2} effects(rq_1)=${n}`;
      if (!s1 || !s2 || n !== 1) return fail("SECOND EFFECT OR STATE CHANGE: " + why);
      if (same !== "replayed") return fail("identical retry not answered \"replayed\": " + why);
      if (other !== "rejected") return fail("different token for a settled request id not answered \"rejected\": " + why);
      return pass(why);
    } },
  { id: "K5-long-and-unicode-ids", kind: "attack", title: "request ids of 33, 64, 256 units and non-ASCII ids, both directions",
    // Per id, a fresh store. SAFE: a foreign-key token and a stale-pre-state token for that id do not commit.
    // LIVENESS: the authorized token for that id commits and is emitted once (ids up to 256 UTF-16 units are inside
    // the encoding.ts domain, MAX_TEXT = 256).
    async run(h) {
      const ids: [string, string][] = [["33", "r".repeat(33)], ["64", "r".repeat(64)], ["256", "r".repeat(256)],
        ["bmp", "rq_éü中"], ["non-bmp", "rq_" + String.fromCodePoint(0x1f600)], ["combining", "réq̈"]];
      const why: Why = [], bad: string[] = [], dead: string[] = [];
      for (const [name, rid] of ids) {
        const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "10");
        const { db, sink } = await h.newStore("k5-" + name, S0);
        const a = await h.commit(sink, h.signBody(h.body(S0, rid, S1, h.intent("ch_1", rid, "10")), true));
        const b = await h.commit(sink, h.sign(S1, rid, S1, h.intent("ch_1", rid, "0", "duplicate_charge")));
        if (!unchanged(h, db, S0, 0)) bad.push(name);
        const ok = await h.commit(sink, h.honest(S0, rid, "10"));
        const f = await h.flush(db, S0, "ledger-" + name + ".jsonl");
        const e = effectsOf(f.effects, rid);
        if (!bad.includes(name) && (e !== 1 || h.outbox(db).length !== 1)) dead.push(name);
        why.push(`${name}:${a}/${b}/ok=${ok}/eff=${e}`);
      }
      if (bad.length) return fail("UNAUTHORIZED TOKEN COMMITTED for ids " + bad.join(",") + ": " + why.join(" "));
      return dead.length ? fail("authorized token not committed and emitted once for ids " + dead.join(",") + ": " + why.join(" ")) : pass(why.join(" "));
    } },
  { id: "K6-long-run-one-store", kind: "attack", title: "37 honest commits on one store with two process restarts",
    // One store: 12 honest commits (amount 1; every fourth is zero), a PROCESS restart, 25 more honest commits in the
    // new process, then a foreign-key token and a stale-pre-state token (SAFE: neither commits), a second process
    // restart, and one more honest commit. SAFE at each restart: state, settled ids and outbox survive unchanged.
    // LIVENESS: every honest refund is emitted exactly once (38 effects).
    async run(h) {
      const S0 = h.st("ch_1", "1000000", "1000000"); let { db, sink } = await h.newStore("k6", S0);
      let cur = S0, n = 0; const why: Why = [];
      const honestStep = async () => { const amt = n % 4 === 3 ? "0" : "1"; const rid = "rq_" + n++;
        const r = await h.commit(sink, h.honest(cur, rid, amt)); if (r !== "committed") throw new Error(`honest ${rid} answered ${r}`); cur = h.dec(cur, amt); };
      const snap = () => h.E.canon([h.stored(db), h.settledIds(db), h.outbox(db)]);
      const reopen = async (tag: string) => {
        const before = snap(); await h.restart();
        const o = await h.openSink(db, h.cfg(S0)); if (o.sink === null) throw new Error(`honest store refused after ${tag}: ${o.error}`);
        sink = o.sink; const after = snap();
        if (after !== before) return `store changed across ${tag}: settled ${h.settledIds(db).length}, outbox ${h.outbox(db).length}`;
        return null;
      };
      try {
        for (let i = 0; i < 12; i++) await honestStep();
        const w1 = await reopen("restart 1"); if (w1) return fail("STORE LOST AT OPEN: " + w1);
        for (let i = 0; i < 25; i++) await honestStep();
        const body = h.body(cur, "rq_bad", h.dec(cur, "500"), h.intent("ch_1", "rq_bad", "500"));
        why.push("foreignKey=" + await h.commit(sink, h.signBody(body, true)));
        why.push("stale=" + await h.commit(sink, h.sign(S0, "rq_stale", cur, h.intent("ch_1", "rq_stale", "0", "duplicate_charge"))));
        if (!unchanged(h, db, cur, n)) return fail(`UNAUTHORIZED TOKEN COMMITTED after ${n} honest commits: ` + why.join(" "));
        const w2 = await reopen("restart 2"); if (w2) return fail("STORE LOST AT OPEN: " + w2);
        await honestStep();
      } catch (e) { return fail("honest step failed: " + String((e as Error).message) + " " + why.join(" ")); }
      const f = await h.flush(db, S0);
      const ids = f.effects.map(e => e.intent.requestId);
      const once = ids.length === n && new Set(ids).size === n;
      why.push(`honest=${n} outbox=${h.outbox(db).length} effects=${ids.length}`);
      return once && h.outbox(db).length === n ? pass(why.join(" ")) : fail("honest refunds not emitted exactly once: " + why.join(" "));
    } },
  { id: "K7-store-survives-reopen", kind: "attack", title: "a reopened store keeps its commits (no wipe at open)",
    // Three honest commits; close; a NEW sink instance in the same process, then a PROCESS restart and a third
    // instance. SAFE: after each open the state, settled ids and outbox are the ones before; the first token again
    // is not a new row; the next honest refund (on the stored state) commits; four effects in total.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = await h.newStore("k7", S0);
      const t1 = h.honest(S0, "rq_1", "100"); let cur = h.dec(S0, "100");
      const cs = [await h.commit(sink, t1), await h.commit(sink, h.honest(cur, "rq_2", "0", "duplicate_charge")), await h.commit(sink, h.honest(cur, "rq_3", "200"))];
      cur = h.dec(cur, "200");
      if (cs.some(c => c !== "committed")) return fail("setup: honest commits refused: " + cs.join(","));
      const snap = () => h.E.canon([h.stored(db), h.settledIds(db), h.outbox(db)]);
      const before = snap();
      await h.close(sink);
      const a = await h.openSink(db, h.cfg(S0)); const sameA = snap() === before;
      await h.restart();
      const b = await h.openSink(db, h.cfg(S0)); const sameB = snap() === before;
      const why = `reopen=${a.sink ? "started" : "refused " + a.error.slice(0, 40)} same=${sameA} restart=${b.sink ? "started" : "refused " + b.error.slice(0, 40)} same=${sameB}`;
      if (!sameA || !sameB) return fail("STORE CHANGED AT OPEN: " + why + ` settled=${h.settledIds(db).length} outbox=${h.outbox(db).length}`);
      if (b.sink === null) return fail("honest store refused at open: " + why);
      const again = await h.commit(b.sink, t1);
      const r4 = await h.commit(b.sink, h.honest(cur, "rq_4", "1"));
      const f = await h.flush(db, S0);
      const ids = f.effects.map(e => e.intent.requestId).sort().join(",");
      const w = `${why} firstTokenAgain=${again} next=${r4} effects=${ids}`;
      return ids === "rq_1,rq_2,rq_3,rq_4" && h.outbox(db).length === 4 ? pass(w) : fail("not exactly four effects after reopen: " + w);
    } },
  { id: "D1-dispatcher-bad-signature-row", kind: "attack", title: "a chain-continuing row signed by a foreign key",
    // rq_1 is committed and dispatched. A database writer (no key) appends rq_2: settled row with a token that
    // continues the chain (pre = stored state) but is signed by a FOREIGN key, its outbox row and the post state.
    // SAFE: the dispatcher does not emit rq_2. LIVENESS: rq_1 is emitted once.
    run: (h: Harness) => twoWriters(h, "D1", async (h: Harness, mode: WriterMode) => {
      const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100"), S2 = h.dec(S1, "50"); const { db, sink } = await h.newStore("d1", S0);
      const c1 = await h.commit(sink, h.honest(S0, "rq_1", "100")); const f1 = await h.flush(db, S0); await h.close(sink);
      if (c1 !== "committed") return fail("setup: honest rq_1 refused: " + c1);
      const tok = h.signBody(h.body(S1, "rq_2", S2, h.intent("ch_1", "rq_2", "50")), true);
      h.write(db, d => {
        h.insertRow(d, "settled", { request_id: "rq_2", token: tok, token_sha256: h.E.sha256hex(tok) });
        if ((d.prepare("SELECT COUNT(*) AS n FROM outbox WHERE request_id = 'rq_2'").get() as any).n === 0)
          h.insertRow(d, "outbox", { request_id: "rq_2", intent: h.E.canon(h.intent("ch_1", "rq_2", "50")) });
        d.prepare("UPDATE state SET blob = ? WHERE id = 1").run(h.E.canon(S2));
      }, mode);
      const f2 = await h.flush(db, S0);
      const all = [...f1.effects, ...f2.effects];
      const why = `effects(rq_1)=${effectsOf(all, "rq_1")} effects(rq_2)=${effectsOf(all, "rq_2")}${f2.error ? " dispatcherError=" + f2.error.slice(0, 60) : ""}`;
      if (effectsOf(all, "rq_2") > 0) return fail("FOREIGN-SIGNED ROW EMITTED: " + why);
      return effectsOf(all, "rq_1") === 1 ? pass(why) : fail("honest rq_1 not emitted once: " + why);
    }) },
  { id: "D2-dispatcher-chain-break-row", kind: "attack", title: "a validly signed row that does not continue the chain",
    // rq_1 moves S0 to S1 and is dispatched. A database writer appends rq_2 with a VALIDLY SIGNED token whose
    // pre-state is S0 (the issuer signed two transitions for S0, or a faulty signer): it does not continue the
    // dispatched chain. SAFE: the dispatcher does not emit rq_2. LIVENESS: rq_1 is emitted once.
    run: (h: Harness) => twoWriters(h, "D2", async (h: Harness, mode: WriterMode) => {
      const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100"); const { db, sink } = await h.newStore("d2", S0);
      const c1 = await h.commit(sink, h.honest(S0, "rq_1", "100")); const f1 = await h.flush(db, S0); await h.close(sink);
      if (c1 !== "committed") return fail("setup: honest rq_1 refused: " + c1);
      const tok = h.honest(S0, "rq_2", "50");
      h.write(db, d => {
        h.insertRow(d, "settled", { request_id: "rq_2", token: tok, token_sha256: h.E.sha256hex(tok) });
        if ((d.prepare("SELECT COUNT(*) AS n FROM outbox WHERE request_id = 'rq_2'").get() as any).n === 0)
          h.insertRow(d, "outbox", { request_id: "rq_2", intent: h.E.canon(h.intent("ch_1", "rq_2", "50")) });
      }, mode);
      const f2 = await h.flush(db, S0);
      const all = [...f1.effects, ...f2.effects];
      const why = `effects(rq_1)=${effectsOf(all, "rq_1")} effects(rq_2)=${effectsOf(all, "rq_2")}${f2.error ? " dispatcherError=" + f2.error.slice(0, 60) : ""}`;
      if (effectsOf(all, "rq_2") > 0) return fail("CHAIN-BREAKING ROW EMITTED: " + why);
      return effectsOf(all, "rq_1") === 1 ? pass(why) : fail("honest rq_1 not emitted once: " + why);
    }) },
  { id: "D3-dispatcher-ledger-before-emit", kind: "attack", title: "the ledger line is durable before the effect; a failed effect is not sent twice",
    // The merged dispatcher documents: "A line is appended and synced BEFORE the effect: at most once. A crash
    // between the two loses that effect (it is never sent twice); a person must reconcile it." This case asserts
    // THAT order. Three honest commits; the first flush's SECOND emit fails (the emit callback throws).
    // SAFE: (a) at every emit the ledger file already holds that request id's line; (b) after the failed emit the
    // ledger holds rq_1 and rq_2 (rq_2 is a lost effect for a person to reconcile, never re-sent); (c) a second
    // flush emits only rq_3; no request id is emitted (attempted) twice.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = await h.newStore("d3", S0);
      let cur = S0; const cs: string[] = [];
      for (const [rid, amt] of [["rq_1", "100"], ["rq_2", "0"], ["rq_3", "10"]] as [string, string][]) { cs.push(await h.commit(sink, h.honest(cur, rid, amt))); cur = h.dec(cur, amt); }
      if (cs.some(c => c !== "committed")) return fail("setup: honest commits refused: " + cs.join(","));
      const f1 = await h.flush(db, S0, "ledger.jsonl", 1);
      const led1 = h.ledgerIds();
      const f2 = await h.flush(db, S0);
      const all = [...f1.effects, ...f2.effects];
      const attempts = all.map(e => e.requestId);
      const why = `flush1=[${f1.effects.map(e => e.requestId + (e.threw ? "(failed)" : "")).join(",")}] ledgerAfter1=[${led1.join(",")}] flush2=[${f2.effects.map(e => e.requestId).join(",")}] ledgerAtEmit=[${all.map(e => e.ledgerHadLine).join(",")}]`;
      if (all.some(e => !e.ledgerHadLine)) return fail("EFFECT BEFORE ITS LEDGER LINE: " + why);
      if (new Set(attempts).size !== attempts.length) return fail("EFFECT SENT TWICE: " + why);
      if (!(led1.includes("rq_1") && led1.includes("rq_2"))) return fail("ledger does not record the effect before the failure: " + why);
      return f2.effects.map(e => e.requestId).join(",") === "rq_3" ? pass(why) : fail("second flush did not emit exactly rq_3: " + why);
    } },
  { id: "E0-encoding-identity", kind: "integrity", title: "every encoding module that the code under test loads is the judge's trusted encoding",
    // h-judges2 (red-team blind spot enc_unsigned_body): the encoding is located in the module graph that the CHILD
    // actually loaded (worker.ts records every resolved file), never by a path next to the sink. Every encoding module
    // of that graph (encoding.*, or a module that exports its own signedBytes) must have the trusted SHA-256 (hashed by
    // the parent). A graph without an encoding module also FAILS (the signed bytes are then not the trusted ones).
    // The behaviour cases E1, E2 and D5 do not rely on this report.
    async run(h) {
      const sha = (p: string) => createHash("sha256").update(readFileSync(p)).digest("hex");
      const t = sha(TRUSTED_ENCODING_PATH), mods = h.caps.encodingModules;
      if (mods.length === 0) return fail(`NO ENCODING MODULE in the loaded graph (${h.caps.graph.length} files)`);
      const bad = mods.filter(p => !existsSync(p) || sha(p) !== t);
      return bad.length ? fail("FOREIGN ENCODING loaded: " + bad.map(p => `${p} sha256 ${existsSync(p) ? sha(p).slice(0, 16) : "missing"}`).join(", ") + ` (trusted ${t.slice(0, 16)})`)
        : pass(`${mods.length} encoding module(s) in a graph of ${h.caps.graph.length} files, all with the trusted SHA-256 ${t.slice(0, 16)}`);
    } },
  { id: "E1-signed-bytes-cover-post-intent", kind: "attack", title: "post and intent altered after signing",
    // (a) The trusted key signs body B (rq_1, 100); post and intent are then changed (amount 900, remaining 100) and
    // the token is delivered. SAFE: no commit. (b) Probe: every bytes function of every encoding module that the
    // child loaded (worker.ts, encodingCandidates) maps B and the altered body; where the two byte strings are EQUAL,
    // the trusted key signs them and the altered token is delivered. SAFE: no commit. LIVENESS: the honest token
    // for rq_1 commits and is emitted once.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = await h.newStore("e1", S0);
      const B = h.body(S0, "rq_1", h.dec(S0, "100"), h.intent("ch_1", "rq_1", "100"));
      const Balt = { ...B, post: h.dec(S0, "900"), intent: h.intent("ch_1", "rq_1", "900") };
      const sig = JSON.parse(h.signBody(B)).signature;
      const a = await h.commit(sink, h.E.canon({ body: Balt, signature: sig }));
      if (!unchanged(h, db, S0, 0)) return fail("ALTERED POST/INTENT COMMITTED (trusted bytes): a=" + a);
      const cands = await h.remote.call<{ name: string; bytes: string[] }[]>("encodingCandidates", { bodies: [B, Balt] });
      const probe: string[] = [];
      for (const c of cands) {
        if (c.bytes[0] !== c.bytes[1]) continue;
        const b = await h.commit(sink, h.signBody(Balt, false, Buffer.from(c.bytes[0], "base64")));
        probe.push(`${c.name.split("/").pop()}=${b}`);
        if (!unchanged(h, db, S0, 0)) return fail("ALTERED POST/INTENT COMMITTED (bytes of the loaded encoding " + c.name + "): " + b);
      }
      const ok = await h.commit(sink, h.signBody(B));
      const f = await h.flush(db, S0);
      const why = `altered=${a} candidates=${cands.length} colliding=[${probe.join(",")}] honest=${ok} effects(rq_1)=${effectsOf(f.effects, "rq_1")}`;
      return effectsOf(f.effects, "rq_1") === 1 && h.outbox(db).length === 1 ? pass(why) : fail("honest token not committed and emitted once: " + why);
    } },
  { id: "E2-signed-field-flips", kind: "attack", title: "a signature kept while ONE signed field changes is refused (every field, many byte definitions)",
    // h-judges2 (blind spot enc_unsigned_body). For each signed field F (post only, amount only, reason only, amount
    // and post together, request id, charge id, pre-state hash) the altered body B' differs from the honest body B
    // only in F. For each candidate definition g of the signed bytes with g(B) = g(B'), the trusted key signs g(B)
    // and the token {body: B', signature} is delivered. Candidates: the trusted signedBytes; every bytes function of
    // the encoding modules that the child loaded (where it collides); canon of every subset of the top-level body keys
    // that leaves F's keys out; canon of B with F's nested keys deleted. SAFE: none commits (state and outbox
    // unchanged). LIVENESS: the honest B commits and is emitted once. A sink that verifies a signature over fewer
    // fields than the trusted encoding signs FAILS here when its bytes are one of the candidates.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = await h.newStore("e2", S0);
      const B = h.body(S0, "rq_1", h.dec(S0, "100"), h.intent("ch_1", "rq_1", "100"));
      const alts = fieldFlips(h, S0, B);
      const cands = await h.remote.call<{ name: string; bytes: string[] }[]>("encodingCandidates", { bodies: [B, ...alts.map(x => x.body)] });
      let n = 0; const hits: string[] = [];
      for (let k = 0; k < alts.length; k++) {
        const x = alts[k];
        for (const [name, bytes] of byteCandidates(h, B, x, cands.map(c => ({ name: c.name, b: c.bytes[0], a: c.bytes[k + 1] })))) {
          const r = await h.commit(sink, h.signBody(x.body as any, false, bytes)); n++;
          if (!unchanged(h, db, S0, 0)) { hits.push(`${x.field}/${name}=${r}`); break; }
        }
        if (hits.length) break;
      }
      if (hits.length) return fail("ALTERED SIGNED FIELD COMMITTED: " + hits.join(" ") + ` (after ${n} deliveries)`);
      const ok = await h.commit(sink, h.signBody(B));
      const f = await h.flush(db, S0);
      const why = `deliveries=${n} fields=${alts.length} loadedCandidates=${cands.length} honest=${ok} effects(rq_1)=${effectsOf(f.effects, "rq_1")}`;
      return effectsOf(f.effects, "rq_1") === 1 && h.outbox(db).length === 1 ? pass(why) : fail("honest token not committed and emitted once: " + why);
    } },
  { id: "D4-dispatcher-chain-valid-bad-signature", kind: "attack", title: "a row with a RECOMPUTED chain and a foreign or invalid signature",
    // h-judges2 (blind spot md_ignore_sig: D1 and D2 do not recompute the chain, so any dispatcher refuses them at the
    // chain check). rq_1 is committed and dispatched; the sink is closed. A database writer (no key; triggers dropped
    // and restored) appends rq_2 with the row-log chain RECOMPUTED by the trusted chain function (appendRow).
    // CALIBRATION: the same writer appends a VALIDLY signed rq_2 (amounts 50 and 0) in fresh stores: the dispatcher
    // must emit it once (this shows that the writer's rows pass every chain check; else the case FAILS as "calibration").
    // SAFE: rq_2 signed by a FOREIGN key, rq_2 with 64 zero bytes as signature, and rq_2 with a trusted signature over
    // ANOTHER body, each with amount 50 and with amount 0, are NOT emitted. LIVENESS: rq_1 emitted once per store.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100");
      const zeroSig = Buffer.alloc(64).toString("base64");
      const body2 = (amt: string) => h.body(S1, "rq_2", h.dec(S1, amt), h.intent("ch_1", "rq_2", amt));
      const variants: [string, boolean, (amt: string) => string][] = [
        ["valid", true, amt => h.signBody(body2(amt))],
        ["foreign-key", false, amt => h.signBody(body2(amt), true)],
        ["zero-signature", false, amt => h.E.canon({ body: body2(amt), signature: zeroSig })],
        ["other-body-signature", false, amt => h.E.canon({ body: body2(amt), signature: JSON.parse(h.signBody(body2(amt === "0" ? "1" : "0"))).signature })],
      ];
      const why: string[] = [], bad: string[] = [], cal: string[] = [];
      for (const amt of ["50", "0"]) for (const [name, good, tokOf] of variants) {
        const r = await writerRow(h, `d4-${name}-${amt}`, S0, tokOf(amt));
        why.push(`${name}/${amt}:${r.text}`);
        if (r.rq1 !== 1) cal.push(`${name}/${amt}: rq_1 emitted ${r.rq1} times`);
        if (good && r.rq2 !== 1) cal.push(`${name}/${amt}: valid writer row emitted ${r.rq2} times`);
        if (!good && r.rq2 > 0) bad.push(`${name}/${amt}`);
      }
      if (bad.length) return fail("ROW WITHOUT A VALID SIGNATURE EMITTED (chain recomputed): " + bad.join(",") + " | " + why.join(" "));
      if (cal.length) return fail("calibration: " + cal.join("; ") + " | " + why.join(" "));
      return pass(why.join(" "));
    } },
  { id: "D5-dispatcher-stored-field-flips", kind: "attack", title: "a stored token whose post or intent changed while the signature was kept",
    // h-judges2 (blind spot enc_unsigned_body, stored side). As D4 (writer, chain recomputed), rq_2's body B is the
    // honest refund of 50 on S1; the writer stores B' = B with (a) the reason changed, or (b) amount 300 and post S1 -
    // 300 (both fully valid bodies), with a trusted signature over g(B) for each candidate g with g(B) = g(B'): the
    // trusted signedBytes (the signature is simply kept), the colliding bytes functions of the loaded encoding modules,
    // canon of B without the touched top-level keys, canon of B without post and intent, canon of B with the touched
    // nested keys deleted. CALIBRATION: the honest B stored by the same writer is emitted once. SAFE: no B' is emitted.
    async run(h) {
      const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100");
      const B = h.body(S1, "rq_2", h.dec(S1, "50"), h.intent("ch_1", "rq_2", "50"));
      const alts = [
        { field: "reason", keys: ["intent"], body: { ...B, intent: { ...B.intent, reason: "duplicate_charge" } }, nested: (b: any) => ({ ...b, intent: omit(b.intent, ["reason"]) }) },
        { field: "amount+post", keys: ["post", "intent"], body: { ...B, post: h.dec(S1, "300"), intent: { ...B.intent, amount: "300" } },
          nested: (b: any) => ({ ...b, post: omit(b.post, ["remaining"]), intent: omit(b.intent, ["amount"]) }) },
      ];
      const cands = await h.remote.call<{ name: string; bytes: string[] }[]>("encodingCandidates", { bodies: [B, ...alts.map(x => x.body)] });
      const c0 = await writerRow(h, "d5-calibration", S0, h.signBody(B));
      if (c0.rq1 !== 1 || c0.rq2 !== 1) return fail(`calibration: honest stored row emitted ${c0.rq2} times, rq_1 ${c0.rq1} times: ${c0.text}`);
      const why: string[] = [], bad: string[] = [];
      for (let k = 0; k < alts.length; k++) {
        const x = alts[k];
        const gs: [string, Buffer][] = [["trusted", h.E.signedBytes(B)], ["top-minus-touched", canonBytes(h, omit(B, x.keys))],
          ["top-minus-post-intent", canonBytes(h, omit(B, ["post", "intent"]))], ["nested", canonBytes(h, x.nested(B))]];
        for (const c of cands) if (c.bytes[0] === c.bytes[k + 1]) gs.push([c.name.split("/").pop()!, Buffer.from(c.bytes[0], "base64")]);
        for (const [name, bytes] of gs) {
          const r = await writerRow(h, `d5-${k}-${name.replace(/[^A-Za-z0-9]/g, "_")}`, S0, h.signBody(x.body as any, false, bytes));
          why.push(`${x.field}/${name}:${r.text}`);
          if (r.rq2 > 0) bad.push(`${x.field}/${name}`);
        }
      }
      return bad.length ? fail("STORED ALTERED BODY EMITTED: " + bad.join(",") + " | " + why.join(" ")) : pass(`calibration emitted once; ` + why.join(" "));
    } },
];

// ---- helpers of E2, D4, D5 (h-judges2)
const TOP = ["domain", "specLockSha256", "checkerSha256", "preStateSha256", "requestId", "post", "intent"];
function omit(o: any, keys: string[]): any { const r: any = {}; for (const k of Object.keys(o)) if (!keys.includes(k)) r[k] = o[k]; return r; }
const canonBytes = (h: Harness, o: unknown): Buffer => Buffer.from(h.E.canon(o as any), "utf8");
type Flip = { field: string; keys: string[]; body: any; nested: ((b: any) => any) | null };
// One altered body per signed field; each differs from B only in the named field (keys: the top-level keys it touches).
function fieldFlips(h: Harness, S0: State, B: any): Flip[] {
  return [
    { field: "post", keys: ["post"], body: { ...B, post: { ...B.post, remaining: "800" } }, nested: b => ({ ...b, post: omit(b.post, ["remaining"]) }) },
    { field: "amount", keys: ["intent"], body: { ...B, intent: { ...B.intent, amount: "200" } }, nested: b => ({ ...b, intent: omit(b.intent, ["amount"]) }) },
    { field: "reason", keys: ["intent"], body: { ...B, intent: { ...B.intent, reason: "duplicate_charge" } }, nested: b => ({ ...b, intent: omit(b.intent, ["reason"]) }) },
    { field: "amount+post", keys: ["post", "intent"], body: { ...B, post: { ...B.post, remaining: "700" }, intent: { ...B.intent, amount: "300" } },
      nested: b => ({ ...b, post: omit(b.post, ["remaining"]), intent: omit(b.intent, ["amount"]) }) },
    { field: "request-id", keys: ["requestId", "intent"], body: { ...B, requestId: "rq_9", intent: { ...B.intent, requestId: "rq_9" } },
      nested: b => ({ ...omit(b, ["requestId"]), intent: omit(b.intent, ["requestId"]) }) },
    { field: "charge-id", keys: ["post", "intent"], body: { ...B, post: { ...B.post, chargeId: "ch_2" }, intent: { ...B.intent, chargeId: "ch_2" } },
      nested: b => ({ ...b, post: omit(b.post, ["chargeId"]), intent: omit(b.intent, ["chargeId"]) }) },
    { field: "pre-state", keys: ["preStateSha256"], body: { ...B, preStateSha256: h.E.stateSha256(h.st(S0.chargeId, S0.original, "999")) }, nested: null },
  ];
}
// The candidate signed bytes g(B) for one flip, each with g(B) = g(B') checked here (a judge fault otherwise).
function byteCandidates(h: Harness, B: any, x: Flip, loaded: { name: string; b: string; a: string }[]): [string, Buffer][] {
  const out: [string, Buffer][] = [["trusted", h.E.signedBytes(B)]];
  const free = TOP.filter(k => !x.keys.includes(k));
  for (let m = 0; m < 1 << free.length; m++) {
    const P = free.filter((_, i) => (m >> i) & 1);
    const g = canonBytes(h, omit(B, TOP.filter(k => !P.includes(k))));
    if (!g.equals(canonBytes(h, omit(x.body, TOP.filter(k => !P.includes(k)))))) throw new Error("judge fault: projection differs for " + x.field);
    out.push(["top{" + P.join(",") + "}", g]);
  }
  if (x.nested) {
    const g = canonBytes(h, x.nested(B));
    if (!g.equals(canonBytes(h, x.nested(x.body)))) throw new Error("judge fault: nested omission differs for " + x.field);
    out.push(["nested", g]);
  }
  for (const c of loaded) if (c.b === c.a) out.push([c.name.split("/").pop()!, Buffer.from(c.b, "base64")]);
  return out;
}
// D4/D5 store: rq_1 honest (100) committed and dispatched; sink closed; the writer appends `tok` (chain recomputed);
// a second flush. Returns the number of effects for rq_1 and rq_2 (parent's receiver) over both flushes.
async function writerRow(h: Harness, name: string, S0: State, tok: string): Promise<{ rq1: number; rq2: number; text: string }> {
  const { db, sink } = await h.newStore(name, S0);
  const c1 = await h.commit(sink, h.honest(S0, "rq_1", "100"));
  const ledger = name + ".ledger.jsonl";
  const f1 = await h.flush(db, S0, ledger); await h.close(sink);
  let w = "written";
  try { h.appendRow(db, tok, "drop"); } catch (e) { if (!(e instanceof WriteRefused)) throw e; w = "write refused: " + e.message.slice(0, 50); }
  const f2 = await h.flush(db, S0, ledger);
  const all = [...f1.effects, ...f2.effects];
  return { rq1: effectsOf(all, "rq_1"), rq2: effectsOf(all, "rq_2"), text: `c1=${c1},${w},rq2=${effectsOf(all, "rq_2")}${f2.error ? ",err=" + f2.error.slice(0, 40) : ""}` };
}
