// p-adopt: a store written by the OLD sink (pristine) and opened by the NEW sink (export).
// Usage (cwd = export): node --import tsx legacy.ts <pristine root> <export root> <issuer module .cjs> <work dir>
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
const [pristine, root, corePath, work] = process.argv.slice(2);
/* eslint-disable @typescript-eslint/no-require-imports */
const Old = require(join(pristine, "ts/refund-finality/sink.ts")).Sink;
const New = require(join(root, "ts/refund-finality/sink.ts")).Sink;
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { MinterClient, propose } = require(join(root, "ts/refund-finality/proposer.ts"));
(async () => {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const cfg = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = { chargeId: "ch_leg", original: "500", remaining: "500", refundEnabled: true }, db = join(work, "legacy.sqlite");
  const old = new Old(db, cfg); old.init(s0);
  const a = await m.mint(s0, propose(s0, { requestId: "rq_leg_1", amount: "50", reason: "duplicate_charge" }));
  const oldCommit = old.commit(E.tokenText(a.token)).status; old.close();
  let noInitial = "started";
  try { new New(db, cfg).close(); } catch (e) { noInitial = "refused: " + String((e as Error).message).slice(0, 160); }
  let withInitial = "started";
  try { new New(db, { ...cfg, initialState: s0 }).close(); } catch (e) { withInitial = "refused: " + String((e as Error).message).slice(0, 160); }
  let wrongInitial = "started";
  try { new New(db, { ...cfg, initialState: { ...s0, original: "501", remaining: "501" } }).close(); } catch (e) { wrongInitial = "refused: " + String((e as Error).message).slice(0, 160); }
  m.stop();
  const ok = oldCommit === "committed" && noInitial.startsWith("refused") && withInitial === "started" && wrongInitial.startsWith("refused");
  process.stdout.write(JSON.stringify({ ok, oldCommit, noInitial, withInitial, wrongInitial }) + "\n");
  process.exit(ok ? 0 : 1);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
