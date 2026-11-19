// F6/F7: key identity and strict UTF-8 / framing probes against the raw minter (mode "on"). Each probe has an expected
// SAFE outcome; exit 1 if any probe differs. Attacker: a minter caller without the key (raw bytes on stdin).
import { Raw, done, guard, propose, st } from "./lib";
const line = (o: unknown) => Buffer.from(JSON.stringify(o), "utf8");
guard((async () => {
  const m = await new Raw(["on"]).start();
  const res: Record<string, any> = {}; let bad: string[] = [];
  const ask = async (name: string, bytes: Buffer, n = 1) => (res[name] = (await m.send(bytes, n)).map(a => a.msg.ok ? { id: a.msg.id, ok: true, rid: a.msg.token.body.requestId } : a.msg));
  const req = (id: number, c: string, rq: string, amount = "0") => { const p = st(c, "10", "10"); return line({ id, pre: p, transition: propose(p, rq, amount) }); };
  // key identity: ("a", "b|c") and ("a|b", "c"); ("a\u0000"... refused by shape); NFC/NFD; pre.chargeId vs intent.chargeId
  const k1 = await ask("k1", req(1, "a", "b|c")), k2 = await ask("k2", req(2, "a|b", "c"));
  if (!k1[0].ok || !k2[0].ok) bad.push("separator collision: one of two distinct keys refused");
  const k3 = await ask("k3_nfc", req(3, "ch", "é")), k4 = await ask("k4_nfd", req(4, "ch", "é"));
  if (!k3[0].ok || !k4[0].ok) bad.push("NFC/NFD ids collide");
  { const p = st("chX", "10", "10"), t: any = propose(p, "rq_k5", "0"); t.intent.chargeId = "chY"; t.post = { ...t.post };
    const a = await ask("k5_intentOtherCharge", line({ id: 5, pre: p, transition: t })); if (a[0].ok) bad.push("intent charge id differs from pre and is signed"); }
  // strict UTF-8 and framing. Each bad line must get ONE answer with id null and sign nothing; the next line in the
  // SAME chunk must be answered under its own id.
  const after = (id: number) => req(id, "chU", "rq_u" + id);
  const cases: [string, Buffer][] = [
    ["overlong_slash", Buffer.concat([Buffer.from('{"id":10,"pre":"'), Buffer.from([0xc0, 0xaf]), Buffer.from('"}')])],
    ["cesu8_surrogates", Buffer.concat([Buffer.from('{"id":11,"pre":"'), Buffer.from([0xed, 0xa0, 0xbd, 0xed, 0xb8, 0x80]), Buffer.from('"}')])],
    ["bom_at_start", Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), req(12, "chB", "rq_b")])],
    ["nul_after_json", Buffer.concat([req(13, "chN", "rq_n"), Buffer.from([0x00, 0x41])])],
    ["lone_cont_byte", Buffer.from([0x80])],
    ["empty_line", Buffer.alloc(0)],
  ];
  let id = 100;
  for (const [name, b] of cases) {
    const next = after(id);
    const two = await m.send(Buffer.concat([b, Buffer.from([0x0a]), next]), 2);
    res[name] = two.map(a => a.msg.ok ? { id: a.msg.id, ok: true } : a.msg);
    const [x, y] = two.map(a => a.msg);
    if (x.ok || !(x.id === null || (name === "nul_after_json" && x.id === null))) bad.push(name + ": first answer " + JSON.stringify(x));
    if (!(y.ok && y.id === id)) bad.push(name + ": next line not answered under its id: " + JSON.stringify(y));
    id++;
  }
  // FEFF inside an id: allowed, exact string (not a defect); CRLF line end: "\r" is JSON whitespace
  const f = await ask("feff_in_id", req(200, "ch﻿F", "rq_f")); if (!f[0].ok) bad.push("U+FEFF inside id refused");
  const crlf = await ask("crlf", Buffer.concat([req(201, "chC", "rq_c"), Buffer.from([0x0d])])); if (!crlf[0].ok || crlf[0].id !== 201) bad.push("CRLF refused");
  // 1 MiB line in one write, then a valid line: exactly one "too long" answer (id null), then the valid answer
  const big = Buffer.concat([Buffer.from('{"id":300,"pre":"'), Buffer.alloc(1 << 20, 0x61), Buffer.from('"}')]);
  const bb = await m.send(Buffer.concat([big, Buffer.from([0x0a]), after(301)]), 2);
  res.mib = bb.map(a => a.msg.ok ? { id: a.msg.id, ok: true } : a.msg);
  if (bb[0].msg.ok || bb[0].msg.id !== null || !(bb[1].msg.ok && bb[1].msg.id === 301)) bad.push("1 MiB line framing");
  await new Promise(r => setTimeout(r, 500));
  res.extraAnswers = m.answers.length - (id - 100) * 2 - 9;   // informational
  m.stop();
  done(bad.length > 0, { bad, res });
})());
