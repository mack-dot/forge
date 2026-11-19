// Regression C-ATT-01 (red team, night shift 2026-11-19; review finding F5).
// Class: malformed input; a legitimate mint was DROPPED (liveness, no safety loss).
// Cause: the proposer client read the issuer's answers with node:readline, which splits a line at U+2028 and
// U+2029. JSON.stringify leaves both unescaped inside a string, so an answer whose token carried such a
// character in an id was cut in two; JSON.parse threw and the request never got its answer.
// Safe outcome asserted here: the client's line splitter cuts at the byte 0x0A only; an answer with U+2028,
// U+2029, CR, NEL or a non-BMP character arrives as ONE line and parses to the same value, also when the
// bytes arrive in chunks that cut a multi-byte character.
// Run: node --import tsx tests/refund-finality/regress/c_att_01_line_separator.ts   (exit 0 = pass)
import { LineSplitter } from "../../../ts/refund-finality/proposer";

const LS = String.fromCharCode(0x2028), PS = String.fromCharCode(0x2029), CR = String.fromCharCode(13), NEL = String.fromCharCode(0x85);
const ids = ["rq" + LS + "a", "rq" + PS + "b", "rq" + CR + "c", "rq" + NEL + "d", "rq" + String.fromCodePoint(0x1F600) + "e", "plain"];
let failed = 0;
for (const chunkSize of [1, 2, 3, 7, 4096]) {
  const got: string[] = [];
  const splitter = new LineSplitter(line => got.push(line));
  const answers = ids.map((requestId, i) => JSON.stringify({ id: i + 1, ok: true, token: { body: { requestId } } }));
  const bytes = Buffer.from(answers.map(a => a + "\n").join(""), "utf8");
  for (let at = 0; at < bytes.length; at += chunkSize) splitter.push(bytes.subarray(at, at + chunkSize));
  const ok = got.length === ids.length && got.every((line, i) => {
    try { return JSON.parse(line).token.body.requestId === ids[i]; } catch { return false; }
  });
  console.log((ok ? "PASS" : "FAIL") + " c_att_01 chunk=" + chunkSize + " lines=" + got.length + "/" + ids.length);
  if (!ok) failed++;
}
// Control: a splitter that cuts at U+2028 (the old behaviour) must fail this test's condition.
{
  const text = JSON.stringify({ id: 1, ok: true, token: { body: { requestId: "rq" + LS + "a" } } });
  const cut = text.split(LS);
  const controlBroken = cut.length !== 1;
  console.log((controlBroken ? "PASS" : "FAIL") + " c_att_01 control: a split at U+2028 cuts the answer in " + cut.length);
  if (!controlBroken) failed++;
}
process.exit(failed === 0 ? 0 : 1);
