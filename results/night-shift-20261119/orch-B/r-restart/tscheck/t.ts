import { generateKeyPairSync } from "node:crypto";
import { Sink } from "./sink.ts";
const { publicKey } = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }).toString();
const base = { publicKeyPem: pem, specLockSha256: "a".repeat(64), checkerSha256: "b".repeat(64) };
const ch1 = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
const ch2 = { chargeId: "ch_2", original: "100", remaining: "100", refundEnabled: true };
function tryInit(label: string, s: Sink, st: any) { try { s.init(st); console.log(label, "init ok"); } catch (e) { console.log(label, "init threw:", (e as Error).message); } }
// T1: chargeKey omitted: any charge is accepted (opt-in).
const s1 = new Sink(process.argv[2] + "/t1.db", base); tryInit("T1 no-chargeKey ch_2", s1, ch2); s1.close();
// T2: two database files with the same chargeKey both accept ch_1 (no cross-file uniqueness in code).
const a = new Sink(process.argv[2] + "/a.db", { ...base, chargeKey: "ch_1" }); tryInit("T2 a.db ch_1", a, ch1);
const b = new Sink(process.argv[2] + "/b.db", { ...base, chargeKey: "ch_1" }); tryInit("T2 b.db ch_1", b, ch1);
// T3: chargeKey mismatch throws before any write.
const c = new Sink(process.argv[2] + "/c.db", { ...base, chargeKey: "ch_1" }); tryInit("T3 c.db key ch_1 init ch_2", c, ch2); console.log("T3 stored after throw:", c.storedBlob() ?? "none");
// T4: existing database holding ch_1, chargeKey omitted, init ch_2: throws, stored state unchanged.
const d = new Sink(process.argv[2] + "/d.db", base); tryInit("T4 d.db ch_1", d, ch1); tryInit("T4 d.db ch_2", d, ch2); console.log("T4 stored:", d.storedBlob());
// T5: audit of an empty store opened with a wrong chargeKey after init by an unkeyed sink.
const e = new Sink(process.argv[2] + "/e.db", base); tryInit("T5 e.db ch_2 (no key)", e, ch2); e.close();
const e2 = new Sink(process.argv[2] + "/e.db", { ...base, chargeKey: "ch_1" }); console.log("T5 audit with key ch_1:", JSON.stringify(e2.audit()));
// T6: negative remaining / remaining > original
const f = new Sink(process.argv[2] + "/f.db", base); tryInit("T6 remaining>original", f, { ...ch1, remaining: "101" });
