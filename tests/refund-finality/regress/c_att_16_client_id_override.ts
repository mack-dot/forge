// Regression C-ATT-16 (red team, night shift 2026-11-19).
// Class: identity substitution inside the UNTRUSTED proposer client (two callers on one MinterClient).
// Cause: MinterClient.send built the message as { id, ...body }: a key `id` in the body replaced the client's
// own counter, so the issuer's answer carried another caller's id and was handed to that caller.
// Safe outcome asserted here: the message that the client writes always carries the client's own counter as
// `id`, whatever the body holds. The test reads the line that send() writes; no issuer process is needed.
// Run: node --import tsx tests/refund-finality/regress/c_att_16_client_id_override.ts   (exit 0 = pass)
import { MinterClient } from "../../../ts/refund-finality/proposer";

const written: string[] = [];
const fakeChild = { stdin: { write: (text: string) => { written.push(text); return true; } } };
// MinterClient has a private constructor; the test builds an instance on a stand-in child process object.
const client = new (MinterClient as any)(fakeChild) as MinterClient;
void client.send({ pre: 1, transition: 2 });               // caller A: gets id 1
void client.send({ id: 1, pre: 3, transition: 4 });        // caller B tries to take id 1: must get id 2
void client.send({ id: "x", pre: 5, transition: 6 });      // a body id of another type: must get id 3
const ids = written.map(line => JSON.parse(line).id);
const ok = JSON.stringify(ids) === JSON.stringify([1, 2, 3]) && written.every(line => line.endsWith("\n"));
console.log((ok ? "PASS" : "FAIL") + " c_att_16 ids written: " + JSON.stringify(ids) + " (expected [1,2,3])");
process.exit(ok ? 0 : 1);
