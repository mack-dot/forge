// Regression for D-1 with D-2 (Orchestrator B, task h-key): a RESTARTED minter with the SAME key file and the SAME
// durable mint memory file (production: "on" with the sink's store) signs NO second token for a request id it minted.
// (a) mint rq_A (100) on S0, do not commit; kill; restart (same key, store, memory): the identical request returns the
//     BYTE-IDENTICAL token; another candidate for rq_A (200) is refused.
// (b) CONTROL (the defect without the memory; the 219bf0ca behaviour emulated by a NEW EMPTY memory file): another
//     candidate for rq_A is signed: a second, different, VALID token. The sink commits exactly ONE of the two and rejects
//     the other; one settled row and one dispatched effect for rq_A. The layer that carries it is printed.
// (c) a crash after the record and before the caller reads the answer (EMULATED: the request is sent, the process is
//     killed with SIGKILL as soon as the memory file holds the record; the caller never reads the answer); after the
//     restart the retry gets the token of the recorded body; another candidate is refused. Plus a source-order check:
//     the append (with fsync) is in issue(), which returns before handle() writes the answer.
// (d) a torn last record (half a line) is cut at start and reported; (e) a changed byte in a record: start refused;
//     (f) a memory file with mode 0644: start refused; (g) production without a memory file: start refused.
// SAFE = exit 0. On 219bf0ca: no key file and no memory argument -> FAIL.
import { appendFileSync, chmodSync, copyFileSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, makeKeyFile, makeMemoryFile, sinkKit, startMinter, verdict } from "./kf_lib";

guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_kfo", original: "1000", remaining: "1000", refundEnabled: true };
  const K = sinkKit(root, S0), key = makeKeyFile(), mem = makeMemoryFile();
  const r: any = {};
  // The sink store is made first (the issuer reads it); pinned to the key FILE's key; ids from a first ready line.
  const db = join(K.dir(), "s.sqlite");
  const probe = await startMinter(root, core, [key.path]); probe.stop();
  if (probe.ready === null) verdict(false, { setup: "minter did not start", stderr: probe.stderr.slice(-300) });
  const cfg = { publicKeyPem: probe.ready.publicKeyPem, specLockSha256: probe.ready.specLockSha256, checkerSha256: probe.ready.checkerSha256, initialState: S0 };
  { const s = new K.SK.Sink(db, cfg); s.init(S0); s.close(); }
  const prod = (memory: string) => startMinter(root, core, [key.path, db, memory]);
  const text = (a: any) => a.ok ? K.E.tokenText(a.token) : "REFUSED: " + a.reason;
  // (a)
  const m1 = await prod(mem);
  if (m1.ready === null) verdict(false, { a: "production minter did not start", stderr: m1.stderr.slice(-300) });
  const t1 = text(await m1.mint(S0, "rq_A", "100")); m1.stop();
  await new Promise(res => setTimeout(res, 300));
  const m2 = await prod(mem);
  const again = text(await m2.mint(S0, "rq_A", "100")), other = text(await m2.mint(S0, "rq_A", "200")); m2.stop();
  r.a = { first: t1.startsWith("REFUSED") ? t1 : "token", identicalAfterRestart: again === t1, otherCandidate: other.startsWith("REFUSED") ? other : "SIGNED" };
  // (b) control: a lost memory (a new empty file)
  const lost = makeMemoryFile();
  const m3 = await prod(lost);
  const t2 = text(await m3.mint(S0, "rq_A", "200")); m3.stop();
  const s = new K.SK.Sink(db, cfg);
  const c2 = t2.startsWith("REFUSED") ? t2 : s.commit(t2).status, c1 = s.commit(t1);
  s.close();
  const rows = K.rows(db).filter((x: string) => x === "rq_A").length;
  const effects: string[] = [];
  const dcfg = { publicKeyPem: cfg.publicKeyPem, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, initialStateSha256: K.E.stateSha256(S0),
    newLedgerH0: K.SK.genesisOf(K.E.canon(S0), cfg.specLockSha256, cfg.checkerSha256, cfg.publicKeyPem) };
  new K.D.Dispatcher(db, join(K.dir(), "l.jsonl"), dcfg, (e: any) => effects.push(e.requestId)).flush();
  const f = { emitted: effects };
  r.b = { secondValidTokenSigned: !t2.startsWith("REFUSED") && t2 !== t1, commitSecond: c2, commitFirst: c1.status + (c1.reason ? ": " + c1.reason : ""),
    settledRowsRqA: rows, effectsRqA: f.emitted.filter(x => x === "rq_A").length, layer: "sink: settled row of rq_A (request id already settled) + pre-state check" };
  // (c) crash after the record, before the answer is read (emulated)
  const S1 = JSON.parse((() => { const x = new K.SK.Sink(db, cfg); const b = x.stateBlob(); x.close(); return b; })());
  const before = statSync(mem).size;
  const m4 = await prod(mem);
  void m4.mint(S1, "rq_C", "0");                    // the caller never reads this answer
  const end = Date.now() + 10000;
  while (statSync(mem).size === before && Date.now() < end) await new Promise(res => setTimeout(res, 5));
  m4.stop();                                         // SIGTERM at once (no flush step in between)
  const rec = readFileSync(mem, "utf8").trim().split("\n").pop() ?? "";
  const recBody = (() => { try { return Buffer.from(JSON.parse(rec).bodyB64, "base64").toString("utf8"); } catch { return ""; } })();
  await new Promise(res => setTimeout(res, 300));
  const m5 = await prod(mem);
  const retry = await m5.mint(S1, "rq_C", "0"), retryOther = text(await m5.mint(S1, "rq_C", "1")); m5.stop();
  const src = readFileSync(join(root, "ts/refund-finality/minter.ts"), "utf8");
  const iIssue = src.indexOf("function issue("), iAppend = src.indexOf("durable.append("), iAnswer = src.indexOf("process.stdout.write(\"{\\\"id\\\":");
  r.c = { recordWritten: statSync(mem).size > before && recBody.includes("\"rq_C\""), retryIsRecordedBody: retry.ok === true && K.E.canon(retry.token.body) === recBody,
    otherCandidate: retryOther.startsWith("REFUSED") ? retryOther : "SIGNED", appendInIssueBeforeAnswer: iIssue >= 0 && iAppend > iIssue && iAnswer > iAppend };
  // (d) torn last record; (e) damage; (f) mode 0644; (g) no memory file
  const torn = makeMemoryFile(); copyFileSync(mem, torn); appendFileSync(torn, "{\"bodyB64\":\"eyJ");
  const m6 = await prod(torn); m6.stop();
  const bad = makeMemoryFile(); writeFileSync(bad, readFileSync(mem, "utf8").replace("rq_A", "rq_B"));
  const m7 = await prod(bad); m7.stop();
  const open = makeMemoryFile(); chmodSync(open, 0o644);
  const m8 = await prod(open); m8.stop();
  const m9 = await startMinter(root, core, [key.path, db]); m9.stop();
  r.files = { tornCutAndStarted: m6.ready !== null && /tornLastRecordCut/.test(m6.stderr) && readFileSync(torn, "utf8").endsWith("}\n"),
    damagedRefused: m7.ready === null && m7.code === 2, mode0644Refused: m8.ready === null && /group or other/.test(m8.stderr),
    noMemoryFileRefused: m9.ready === null && m9.code === 2 };
  verdict(r.a.first === "token" && r.a.identicalAfterRestart && r.a.otherCandidate.startsWith("REFUSED") &&
    r.b.secondValidTokenSigned && [c2, c1.status].sort().join() === "committed,rejected" && rows === 1 && r.b.effectsRqA === 1 &&
    r.c.recordWritten && r.c.retryIsRecordedBody && r.c.otherCandidate.startsWith("REFUSED") && r.c.appendInIssueBeforeAnswer &&
    r.files.tornCutAndStarted && r.files.damagedRefused && r.files.mode0644Refused && r.files.noMemoryFileRefused, r);
})());
