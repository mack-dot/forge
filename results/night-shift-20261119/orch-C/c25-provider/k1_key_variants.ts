// k1_key_variants.ts <tree>: checks of the provider key derivation of B's adapter (owner decision D-3).
// The key must differ whenever (store, charge id, request id, amount) differ, for every value the pipeline can commit.
// It also records which amount texts and id texts the shape checks of encoding.ts accept, because only accepted
// values reach the adapter. Exit 1 = two different committed effects get the same key (a collision), or a
// non-canonical amount text is accepted by the shape check (then one amount could get two keys). Exit 0 = none found.
import { join } from "node:path";
const root = process.argv[2];
// eslint-disable-next-line @typescript-eslint/no-require-imports
const A = require(join(root, "tests/refund-finality/provider/emit_adapter.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const H = "a".repeat(64), H2 = "b".repeat(64);
const bad: string[] = []; const notes: string[] = [];
let refusals = 0;
// A refusal by the key function (for example a store value that is not 64 hex digits) is a safe outcome: no key, no call.
const key = (h: string, c: string, r: string, a: string): string => { try { return A.providerKey(h, c, r, a); } catch (e) { refusals++; return "REFUSED#" + refusals; } };
// 1. field boundaries: moving characters between fields must change the key
const moves: [string[], string[]][] = [
  [[H, "a", "bc", "5"], [H, "ab", "c", "5"]], [[H, "ab", "", "5"], [H, "a", "b", "5"]], [[H, "c", "r1", "25"], [H, "c", "r12", "5"]],
  [[H, "c", "r", "1"], [H2, "c", "r", "1"]], [[H, "x", "y", "1"], [H, "y", "x", "1"]], [[H, "c/" + "r", "", "1"], [H, "c", "/r", "1"]],
  [[H, "c\u0000", "r", "1"], [H, "c", "\u0000r", "1"]], [[H, "c", "r", "10"], [H, "c", "r1", "0"]],
  [[H + "/c", "", "r", "1"], [H, "c", "r", "1"]],                       // namespace is domain + "/" + h0: an h0 that carries a "/"
];
for (const [x, y] of moves) if (key(x[0], x[1], x[2], x[3]) === key(y[0], y[1], y[2], y[3])) bad.push("boundary collision: " + JSON.stringify([x, y]));
// 2. text forms: different id texts that the shape check accepts must give different keys
const forms: [string, string][] = [["é", "é"], ["A", "a"], ["r1", "r1 "], ["r1", " r1"], ["😀", "😁"], ["r ", "r "], ["k", "K"]];
for (const [x, y] of forms) {
  const okx = E.isIntent({ chargeId: "c", requestId: x, amount: "1", reason: "duplicate_charge" }), oky = E.isIntent({ chargeId: "c", requestId: y, amount: "1", reason: "duplicate_charge" });
  if (okx && oky && key(H, "c", x, "1") === key(H, "c", y, "1")) bad.push("text-form collision: " + JSON.stringify([x, y]));
}
// 3. lone surrogates: UTF-8 turns each into U+FFFD, so two such ids WOULD collide; they must be refused by the shape check
const s1 = "r\ud800", s2 = "r\udbff";
const loneAccepted = E.isIntent({ chargeId: "c", requestId: s1, amount: "1", reason: "duplicate_charge" });
notes.push("lone surrogate ids: keys equal = " + (key(H, "c", s1, "1") === key(H, "c", s2, "1")) + "; accepted by the shape check = " + loneAccepted);
if (loneAccepted && key(H, "c", s1, "1") === key(H, "c", s2, "1")) bad.push("lone-surrogate collision reachable");
// 4. amount formats: only ONE text per amount may pass the shape check; else one amount has two keys (a second payment)
const amounts = ["100", "0100", "+100", "100.0", "100.00", "1e2", " 100", "100 ", "1_00", "0x64", "١٠٠", "-0", "00", "10000"];
const accepted = amounts.filter(a => E.isIntent({ chargeId: "c", requestId: "r", amount: a, reason: "duplicate_charge" }));
notes.push("amount texts accepted by the shape check: " + JSON.stringify(accepted));
for (const a of accepted) if (!/^(0|[1-9][0-9]*)$/.test(a)) bad.push("non-canonical amount text accepted: " + JSON.stringify(a));
notes.push("keys of 100 and 10000 (minor units) differ = " + (key(H, "c", "r", "100") !== key(H, "c", "r", "10000")) + " (a host that changes the unit gets a NEW key: stated by B as the amount-in-key consequence)");
// 5. key text: fixed-length lower-case hex for the longest legal ids
const long = "\u0001".repeat(256), k = key(H, long, long, "9223372036854775807");
if (!/^[0-9a-f]{64}$/.test(k)) bad.push("key is not 64 lower-case hex digits");
notes.push("inputs refused by the key function: " + refusals);
console.log(JSON.stringify({ notes, bad }, null, 1)); console.log(bad.length ? "DEFECT" : "SAFE"); process.exit(bad.length ? 1 : 0);
