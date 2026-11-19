// Slice 3 (F3.2): controls for the token issuer, the sink and the optimizer runner of the
// runtime-certificate boundary. Real processes, real Ed25519, real SQLite files.
// This is a FINITE TEST. It proves nothing universal.
// Run: node --import tsx tests/booking-certificate/suite.ts <fresh-out-dir> <compiled core module>
// report.json has no key, signature, path or time in it: two runs must give the same bytes. (The output
// folder also gets the public key and the token texts of the race row.)
//
// "Effects" of one attempt = changed board (0 or 1) + new settled rows + new outbox rows. A rejection
// control passes only if the sink answers as expected AND the effects are 0.
// The sink takes TEXT. In the rows below a token object stands for its canonical text; a value that is
// handed over as it is (not as text) is wrapped in AsIs.
import { spawn, spawnSync } from "node:child_process";
import { generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import {
  Batch, Board, Proposal, Token, TokenBody, batchSha256, boardSha256, canon, checkerSha256Of, intentText, sha256hex, signedBytes,
  specSha256Of, tokenText,
} from "../../ts/booking-certificate/encoding";
import { IssuerClient, Issued, problemLine, runGuest } from "../../ts/booking-certificate/guest";
import { CommitResult, Sink, SinkConfig } from "../../ts/booking-certificate/sink";
import { accepts } from "./reference";

const ROOT = resolve(__dirname, "../..");
const SPEC = join(ROOT, "certificate/BookingCertificateSpec.dfy");
const REFERENCE = join(ROOT, "proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy");
const outDir = resolve(process.argv[2] ?? "");
const CORE = resolve(process.argv[3] ?? "");
if (process.argv.length !== 4) throw new Error("usage: suite.ts <fresh-out-dir> <compiled core module>");
if (existsSync(outDir)) throw new Error("output directory is not fresh");
mkdirSync(outDir, { recursive: true });
process.exitCode = 2;   // stays 2 unless the last line of main is reached

type Row = { control: string; name: string; expected: string; observed: string; pass: boolean; effects: number };
const rows: Row[] = [];
const add = (control: string, name: string, expected: string, observed: string, pass: boolean, effects = 0) =>
  rows.push({ control, name, expected, observed, pass, effects });
class AsIs { constructor(readonly value: unknown) {} }

// The witness batch of the Dafny files: two slots of capacity 1; request 0 (value 3) needs both;
// requests 1 and 2 (value 2 each) need one slot each. The optimum is requests 1 and 2 (value 4).
const BOARD: Board = { capacity: ["1", "1"] };
const batch = (requestId: string): Batch => ({ requestId, needs: [["1", "1", "0"], ["1", "0", "1"]], values: ["3", "2", "2"] });
const OPTIMUM: Proposal = { allocation: ["0", "1", "1"], slotPrices: ["2", "2"], requestPrices: ["0", "0", "0"], alphaBps: "0" };
const BELOW: Proposal = { allocation: ["1", "0", "0"], slotPrices: ["2", "2"], requestPrices: ["0", "0", "0"], alphaBps: "2500" };
// A second board for chains: three slots of capacity 2 and single-slot requests.
const WIDE: Board = { capacity: ["2", "2", "2"] };
const wideBatch = (requestId: string): Batch => ({ requestId, needs: [["1", "0"], ["0", "1"], ["0", "0"]], values: ["5", "7"] });
const WIDE_ALL: Proposal = { allocation: ["1", "1"], slotPrices: ["0", "0", "0"], requestPrices: ["5", "7"], alphaBps: "0" };

let made = 0;
const dbPath = () => join(outDir, "db-" + (++made) + ".sqlite");

async function main() {
  const issuer = await IssuerClient.start(ROOT, CORE, SPEC, REFERENCE);
  const attacker = generateKeyPairSync("ed25519").privateKey;
  // The two ids are computed here again from the files. They are not taken from the issuer's word.
  const glue = join(ROOT, "ts/booking-certificate");
  const ids = {
    checkerSha256: checkerSha256Of(readFileSync(CORE), readFileSync(join(glue, "encoding.ts")), readFileSync(join(glue, "issuer.ts")),
      readFileSync(join(ROOT, "ts/refund-finality/encoding.ts"))),
    specSha256: specSha256Of(readFileSync(SPEC), readFileSync(REFERENCE)),
  };
  const sameIds = issuer.ready.checkerSha256 === ids.checkerSha256 && issuer.ready.specSha256 === ids.specSha256;
  add("ids", "the checker id and the specification id of the issuer against a new computation from the files", "both equal", sameIds ? "both equal" : "DIFFERENT", sameIds);
  const cfg = (board: Board, maxAlphaBps = 2000): SinkConfig => ({ publicKeyPem: issuer.ready.publicKeyPem, specSha256: ids.specSha256,
    checkerSha256: ids.checkerSha256, maxAlphaBps, initialBoardSha256: boardSha256(board) });
  const issue = (board: Board, b: Batch, p: unknown): Promise<Issued> => issuer.issue(board, b, typeof p === "string" ? p : JSON.stringify(p));
  const tokenFor = async (board: Board, b: Batch, p: Proposal): Promise<Token> => {
    const answer = await issue(board, b, p);
    if (!answer.ok || !answer.token) throw new Error("setup: no token for a proposal that must get one: " + answer.reason);
    return answer.token;
  };
  const fresh = (board: Board, batches: Batch[], maxAlphaBps = 2000): Sink => {
    const sink = new Sink(dbPath(), cfg(board, maxAlphaBps));
    sink.init(board);
    for (const b of batches) sink.submit(b);
    return sink;
  };
  const look = (sink: Sink) => ({ state: sink.stateBlob(), settled: sink.settled().length, outbox: sink.outbox().length });
  const offer = (sink: Sink, input: unknown): { result: CommitResult | { status: "THREW"; reason: string }; effects: number } => {
    const before = look(sink);
    let result: CommitResult | { status: "THREW"; reason: string };
    try { result = sink.commit(input instanceof AsIs ? input.value : typeof input === "string" ? input : tokenText(input as Token)); }
    catch (error) { result = { status: "THREW", reason: String(error) }; }
    const after = look(sink);
    return { result, effects: (after.state !== before.state ? 1 : 0) + (after.settled - before.settled) + (after.outbox - before.outbox) };
  };
  const show = (r: { status: string; reason?: string }) => r.status + (r.reason ? ": " + r.reason : "");
  // A rejection control: the sink must reject (with the given reason, if one is given) and the effects must be 0.
  const rejection = (control: string, name: string, sink: Sink, input: unknown, reason?: string) => {
    const { result, effects } = offer(sink, input);
    add(control, name, "rejected" + (reason ? ": " + reason : "") + "; effects 0", show(result) + "; effects " + effects,
      result.status === "rejected" && (reason === undefined || result.reason === reason) && effects === 0, effects);
  };

  // ---------------- Issuer: the decision is the compiled core. ----------------
  {
    const b = batch("issuer_1");
    const refusal = async (name: string, board: unknown, bt: unknown, p: unknown, reason: string) => {
      const answer = await issuer.issue(board, bt, typeof p === "string" ? p : JSON.stringify(p));
      add("issuer", name, "no token: " + reason, answer.ok ? "TOKEN" : "no token: " + answer.reason, !answer.ok && answer.reason === reason);
    };
    const good = await issue(BOARD, b, OPTIMUM), body = good.token?.body;
    add("issuer", "the optimum with a zero-gap certificate", "token: value 4, remaining capacity 0 and 0, the given allocation, gap 0",
      good.ok && body ? `token: value ${body.value}, remaining capacity ${body.post.capacity.join(" and ")}, allocation ${body.allocation.join("")}, gap ${body.alphaBps}` : "no token: " + good.reason,
      !!good.ok && !!body && body.value === "4" && canon(body.post) === canon({ capacity: ["0", "0"] }) && canon(body.allocation) === canon(OPTIMUM.allocation) &&
      body.alphaBps === "0" && body.preStateSha256 === boardSha256(BOARD) && body.batchSha256 === batchSha256(b) && body.requestId === "issuer_1");
    const core = "core: Refuse";
    await refusal("an overbooked allocation, largest gap", BOARD, b, { ...OPTIMUM, allocation: ["1", "1", "0"], alphaBps: "10000" }, core);
    await refusal("a request booked twice", BOARD, b, { ...OPTIMUM, allocation: ["0", "2", "0"] }, core);
    await refusal("the optimum with slot prices that are too small (forged certificate)", BOARD, b, { ...OPTIMUM, slotPrices: ["1", "1"] }, core);
    await refusal("a negative slot price", BOARD, b, { ...OPTIMUM, slotPrices: ["2", "-1"], requestPrices: ["0", "0", "1"] }, core);
    await refusal("a negative request price", BOARD, b, { ...OPTIMUM, slotPrices: ["3", "3"], requestPrices: ["-1", "0", "0"] }, core);
    await refusal("an allocation below the optimum at the gap 0", BOARD, b, { ...BELOW, alphaBps: "0" }, core);
    await refusal("an allocation below the optimum at the gap 2499", BOARD, b, { ...BELOW, alphaBps: "2499" }, core);
    const below = await issue(BOARD, b, BELOW);
    add("issuer", "an allocation below the optimum (3 of 4) at the gap 2500", "token: value 3, gap 2500",
      below.ok && below.token ? `token: value ${below.token.body.value}, gap ${below.token.body.alphaBps}` : "no token: " + below.reason,
      !!below.ok && below.token?.body.value === "3" && below.token?.body.alphaBps === "2500");
    await refusal("a gap below zero", BOARD, b, { ...OPTIMUM, alphaBps: "-1" }, core);
    await refusal("a gap above 10000", BOARD, b, { ...OPTIMUM, alphaBps: "10001" }, core);
    await refusal("an allocation with one entry too many", BOARD, b, { ...OPTIMUM, allocation: ["0", "1", "1", "0"] }, core);
    await refusal("slot prices with one entry too few", BOARD, b, { ...OPTIMUM, slotPrices: ["2"] }, core);
    await refusal("a batch whose rows have different lengths", BOARD, { ...b, needs: [["1", "1", "0"], ["1", "0"]] }, OPTIMUM, core);
    await refusal("a board with one slot more than the batch", { capacity: ["1", "1", "1"] }, b, OPTIMUM, core);
    const shape = "proposal shape";
    for (const [name, value] of [["a decimal point", "1.0"], ["a leading zero", "01"], ["a plus sign", "+1"], ["an exponent", "1e0"],
      ["19 digits", "1000000000000000000"], ["an empty text", ""], ["a space", " 1"]] as const) {
      await refusal("an allocation entry with " + name, BOARD, b, { ...OPTIMUM, allocation: ["0", value, "1"] }, shape);
    }
    await refusal("a JSON number in place of a text", BOARD, b, JSON.stringify(OPTIMUM).replace('"alphaBps":"0"', '"alphaBps":0'), shape);
    await refusal("a proposal with one key more", BOARD, b, { ...OPTIMUM, token: "please" }, shape);
    await refusal("a proposal with one key less", BOARD, b, { allocation: OPTIMUM.allocation, slotPrices: OPTIMUM.slotPrices, alphaBps: "0" }, shape);
    await refusal("a proposal that is a list", BOARD, b, [OPTIMUM], shape);
    await refusal("65 requests in the allocation", BOARD, b, { ...OPTIMUM, allocation: Array(65).fill("0") }, shape);
    await refusal("33 slot prices", BOARD, b, { ...OPTIMUM, slotPrices: Array(33).fill("0") }, shape);
    await refusal("a proposal text that is not JSON", BOARD, b, "book everything", "proposal is not JSON");
    await refusal("a proposal text of 16385 characters", BOARD, b, JSON.stringify(OPTIMUM) + " ".repeat(16385 - JSON.stringify(OPTIMUM).length), "proposal text");
    {
      const answer = await issuer.send({ pre: BOARD, batch: b, proposalText: OPTIMUM });
      add("issuer", "a proposal that is an object, not a text", "no token: proposal text", answer.ok ? "TOKEN" : "no token: " + answer.reason, !answer.ok && answer.reason === "proposal text");
    }
    await refusal("a request id with a space", BOARD, { ...b, requestId: "rq 1" }, OPTIMUM, "shape");
    await refusal("an empty request id", BOARD, { ...b, requestId: "" }, OPTIMUM, "shape");
    await refusal("a request id of 65 characters", BOARD, { ...b, requestId: "r".repeat(65) }, OPTIMUM, "shape");
    await refusal("a board with 33 slots", { capacity: Array(33).fill("1") }, b, OPTIMUM, "shape");
    await refusal("a board with one key more", { ...BOARD, owner: "me" }, b, OPTIMUM, "shape");
    await refusal("a capacity that is a JSON number", { capacity: [1, 1] }, b, OPTIMUM, "shape");
    {
      const answer = await issuer.send({ pre: BOARD, batch: b, proposalText: JSON.stringify(OPTIMUM), token: good.token });
      add("issuer", "a message with a token of the caller in it", "no token: message shape", answer.ok ? "TOKEN" : "no token: " + answer.reason, !answer.ok && answer.reason === "message shape");
    }
    {
      // Numbers of 17 digits that differ by 1: a conversion that loses precision cannot tell the gaps 0 and 1 apart.
      const big: Batch = { requestId: "issuer_big", needs: [["1", "1"]], values: ["99999999999999999", "99999999999999998"] };
      const second = (alphaBps: string): Proposal => ({ allocation: ["0", "1"], slotPrices: ["99999999999999999"], requestPrices: ["0", "0"], alphaBps });
      const at0 = await issue({ capacity: ["1"] }, big, second("0")), at1 = await issue({ capacity: ["1"] }, big, second("1"));
      add("issuer", "values of 17 digits that differ by 1: the second best request at the gaps 0 and 1", "no token at the gap 0; token with the value 99999999999999998 at the gap 1",
        `${at0.ok ? "TOKEN" : "no token"} at the gap 0; ${at1.ok && at1.token ? "token with the value " + at1.token.body.value : "NO TOKEN"} at the gap 1`,
        !at0.ok && at0.reason === core && !!at1.ok && at1.token?.body.value === "99999999999999998");
    }
    // Framing: a line above the byte limit is answered once with id null; the issuer stays in service.
    const seen = issuer.unmatched.length;
    issuer.raw(JSON.stringify({ id: 1.5, pre: BOARD, batch: b, proposalText: JSON.stringify(OPTIMUM) }));
    issuer.raw("{\"id\":7,\"pre\":\"" + "A".repeat(70000) + "\"}");
    issuer.write("B".repeat(70000));
    issuer.raw("");
    const after = await issue(BOARD, b, OPTIMUM);
    const extra = issuer.unmatched.slice(seen).map(a => a.reason).join(" | ");
    add("issuer", "a message id that is not a whole number; a line of 70 kB; 70 kB with a late line end; then a good message",
      "three answers with id null: message id | message too long | message too long; then a token",
      `${issuer.unmatched.length - seen} answers with id null: ${extra}; then ${after.ok ? "a token" : "NO TOKEN"}`,
      issuer.unmatched.length - seen === 3 && extra === "message id | message too long | message too long" && !!after.ok);
    // The issuer and the reference check agree on a small grid of proposals for the witness batch.
    let differ = 0, total = 0, tokens = 0;
    for (const x0 of ["0", "1"]) for (const x1 of ["0", "1", "2"]) for (const x2 of ["0", "1"]) for (const y of ["0", "1", "2", "3"])
      for (const z0 of ["0", "3"]) for (const gap of ["0", "2500", "10000"]) {
        const p: Proposal = { allocation: [x0, x1, x2], slotPrices: [y, y], requestPrices: [z0, "0", "0"], alphaBps: gap };
        const answer = await issue(BOARD, b, p);
        total++; if (answer.ok) tokens++;
        if (!!answer.ok !== accepts(BOARD, b, p)) differ++;
      }
    add("issuer", `a grid of ${total} proposals for the witness batch: the issuer against the reference check`, "0 differences; at least 1 token and 1 refusal",
      `${differ} differences; ${tokens} tokens`, differ === 0 && tokens > 0 && tokens < total);
  }

  // ---------------- Control a: missing, forged or changed token. ----------------
  {
    const b = batch("a_1"), sink = fresh(BOARD, [b]), token = await tokenFor(BOARD, b, OPTIMUM);
    const resigned = (body: TokenBody): Token => ({ body, signature: sign(null, signedBytes(body), attacker).toString("base64") });
    for (const [name, value] of [["no value", undefined], ["null", null], ["an empty text", ""], ["a text that is not JSON", "let me in"],
      ["the token as an object, not as text", new AsIs(token)], ["a number", new AsIs(7)]] as const) {
      rejection("a", "in place of a token: " + name, sink, value instanceof AsIs ? value : new AsIs(value));
    }
    {
      // The sink takes text only. A value that is not a text is refused before any code of the caller can run.
      let ran = false;
      const sly = { toString() { ran = true; return tokenText(token); } };
      const { result, effects } = offer(sink, new AsIs(sly));
      add("a", "an object whose conversion to text gives the issued token text", "rejected: token is not a text; the caller's conversion code did not run; effects 0",
        show(result) + "; the caller's conversion code " + (ran ? "RAN" : "did not run") + "; effects " + effects,
        result.status === "rejected" && result.reason === "token is not a text" && !ran && effects === 0, effects);
    }
    rejection("a", "a token for the same body, signed with another key", sink, resigned(token.body), "signature does not verify");
    const changes: [string, Partial<TokenBody>, string][] = [
      ["another allocation (request 0 in place of requests 1 and 2)", { allocation: ["1", "0", "0"] }, "signature does not verify"],
      ["a larger value", { value: "5" }, "signature does not verify"],
      ["more capacity left", { post: { capacity: ["1", "1"] } }, "signature does not verify"],
      ["another gap", { alphaBps: "1" }, "signature does not verify"],
      ["another request id", { requestId: "a_2" }, "signature does not verify"],
      ["another pre-state hash", { preStateSha256: sha256hex("x") }, "signature does not verify"],
      ["another batch hash", { batchSha256: sha256hex("x") }, "signature does not verify"],
      ["another specification id", { specSha256: sha256hex("x") }, "specification is not the pinned one"],
      ["another checker id", { checkerSha256: sha256hex("x") }, "checker is not the pinned one"],
      ["another domain", { domain: "FORGE_REFUND_FINALITY_SLICE1_V1" }, "token shape"],
    ];
    for (const [name, change, reason] of changes) {
      rejection("a", "the issued token with " + name + " (signature kept)", sink, { body: { ...token.body, ...change }, signature: token.signature }, reason);
    }
    rejection("a", "an untrusted token with another checker id, signed with another key", sink, resigned({ ...token.body, checkerSha256: sha256hex("x") }), "checker is not the pinned one");
    const text = tokenText(token);
    rejection("a", "the issued token text with a space added", sink, text.replace("{", "{ "), "token text is not canonical");
    rejection("a", "the issued token as JSON with other key order", sink, JSON.stringify({ signature: token.signature, body: token.body }), "token text is not canonical");
    rejection("a", "the issued token with one key more", sink, JSON.stringify({ body: token.body, signature: token.signature, note: "x" }), "token shape");
    rejection("a", "the issued token with a changed signature", sink, { body: token.body, signature: token.signature.slice(0, -4) + (token.signature.endsWith("AA==") ? "BA==" : "AA==") }, "signature does not verify");
    rejection("a", "a text of 20000 characters", sink, "{" + " ".repeat(20000) + "}", "token shape");
    const last = offer(sink, token);
    add("a", "after all those attempts: the issued token itself", "committed; effects 3", show(last.result) + "; effects " + last.effects,
      last.result.status === "committed" && last.effects === 3, last.effects);
    sink.close();
  }

  // ---------------- Control b: valid token, but the store is not what the token names. ----------------
  {
    // Two batches on one board. Both tokens are for the first board. After the first commit the second is stale.
    const b1 = wideBatch("b_1"), b2 = wideBatch("b_2"), sink = fresh(WIDE, [b1, b2]);
    const t1 = await tokenFor(WIDE, b1, WIDE_ALL), t2 = await tokenFor(WIDE, b2, WIDE_ALL);
    const first = offer(sink, t1);
    add("b", "first of two tokens for one board", "committed; effects 3", show(first.result) + "; effects " + first.effects, first.result.status === "committed" && first.effects === 3, first.effects);
    rejection("b", "second token for the board as it was (stale pre-state hash)", sink, t2, "stored board is not the token's pre-state");
    const now: Board = JSON.parse(sink.stateBlob());
    const t2b = await tokenFor(now, b2, WIDE_ALL), again = offer(sink, t2b);
    add("b", "a new token for the second batch on the present board", "committed; effects 3; remaining capacity 0, 0, 2",
      show(again.result) + "; effects " + again.effects + "; remaining capacity " + (JSON.parse(sink.stateBlob()) as Board).capacity.join(", "),
      again.result.status === "committed" && again.effects === 3 && sink.stateBlob() === canon({ capacity: ["0", "0", "2"] }), again.effects);
    const b3 = wideBatch("b_3");
    sink.submit(b3);
    const third = await issue(JSON.parse(sink.stateBlob()), b3, WIDE_ALL);
    add("b", "a third batch on the board with no capacity left in its slots: the same allocation", "no token: core: Refuse", third.ok ? "TOKEN" : "no token: " + third.reason, !third.ok && third.reason === "core: Refuse");
    add("b", "audit of the board after two commits (public key only)", "no problem", sink.audit().join("; ") || "no problem", sink.audit().length === 0);
    sink.close();
    // The batch is not the stored one.
    const other = fresh(BOARD, [{ ...batch("b_4"), values: ["9", "2", "2"] }]);
    rejection("b", "a token for a batch with other values than the stored batch of that request id", other, await tokenFor(BOARD, batch("b_4"), OPTIMUM), "stored batch is not the token's batch");
    rejection("b", "a token for a request id that no batch waits under", other, await tokenFor(BOARD, batch("b_5"), OPTIMUM), "no batch with this request id waits here");
    other.close();
    const elsewhere = fresh({ capacity: ["1", "2"] }, [batch("b_6")]);
    rejection("b", "a token for a board with other capacities than the stored board", elsewhere, await tokenFor(BOARD, batch("b_6"), OPTIMUM), "stored board is not the token's pre-state");
    elsewhere.close();
    const empty = new Sink(dbPath(), cfg(BOARD));
    let observed: string;
    try { const r = empty.commit(tokenText(await tokenFor(BOARD, batch("b_7"), OPTIMUM))); observed = show(r); } catch (error) { observed = "THREW " + String(error); }
    add("b", "a token offered to a sink with no board and no batch", "rejected: no batch with this request id waits here", observed, observed === "rejected: no batch with this request id waits here");
    empty.close();
  }

  // ---------------- Control c: a request id that is settled. ----------------
  {
    const b = batch("c_1"), sink = fresh(BOARD, [b], 2500);
    const optimum = await tokenFor(BOARD, b, OPTIMUM), below = await tokenFor(BOARD, b, BELOW);
    const first = offer(sink, optimum);
    add("c", "a token for the optimum", "committed; effects 3", show(first.result) + "; effects " + first.effects, first.result.status === "committed" && first.effects === 3, first.effects);
    for (const turn of [2, 3]) {
      const again = offer(sink, optimum);
      add("c", "the same token, use " + turn, "replayed; effects 0", show(again.result) + "; effects " + again.effects, again.result.status === "replayed" && again.effects === 0, again.effects);
    }
    rejection("c", "another valid token (another allocation) for the settled request id", sink, below, "request id is already settled with another token");
    add("c", "intake of a second batch under the settled request id", "not taken", sink.submit({ ...b, values: ["1", "1", "1"] }) ? "TAKEN" : "not taken", sink.submit({ ...b, values: ["1", "1", "1"] }) === false);
    sink.close();
  }

  // ---------------- Control d: a valid token makes exactly its one effect. ----------------
  {
    const b = batch("d_1"), sink = fresh(BOARD, [b]), token = await tokenFor(BOARD, b, OPTIMUM);
    const { result, effects } = offer(sink, token);
    const settled = sink.settled(), outbox = sink.outbox();
    add("d", "the token for the optimum", "committed; board = remaining capacity of the token; 1 settled row; 1 outbox row with the checked allocation",
      `${show(result)}; board ${sink.stateBlob() === canon(token.body.post) ? "= remaining capacity of the token" : "DIFFERS"}; ${settled.length} settled row; ${outbox.length} outbox row${outbox[0]?.intent === intentText(token.body) ? " with the checked allocation" : " WITH ANOTHER TEXT"}`,
      result.status === "committed" && effects === 3 && sink.stateBlob() === canon(token.body.post) && settled.length === 1 && settled[0].request_id === "d_1" &&
      settled[0].token === tokenText(token) && outbox.length === 1 && outbox[0].intent === intentText(token.body), effects);
    add("d", "audit after the commit (public key only)", "no problem", sink.audit().join("; ") || "no problem", sink.audit().length === 0);
    sink.close();
  }

  // ---------------- Control e: the largest gap of the sink. ----------------
  {
    const strict = fresh(BOARD, [batch("e_1")]), wide = fresh(BOARD, [batch("e_1")], 2500), exact = fresh(BOARD, [batch("e_1")], 0);
    const below = await tokenFor(BOARD, batch("e_1"), BELOW), optimum = await tokenFor(BOARD, batch("e_1"), OPTIMUM);
    rejection("e", "a token with the gap 2500 at a sink with the largest gap 2000", strict, below, "gap is above the largest gap of this sink");
    rejection("e", "a token with the gap 2500 at a sink with the largest gap 0", exact, below, "gap is above the largest gap of this sink");
    const taken = offer(wide, below);
    add("e", "the same token at a sink with the largest gap 2500", "committed; effects 3", show(taken.result) + "; effects " + taken.effects, taken.result.status === "committed" && taken.effects === 3, taken.effects);
    const zero = offer(exact, optimum);
    add("e", "a token with the gap 0 at a sink with the largest gap 0", "committed; effects 3", show(zero.result) + "; effects " + zero.effects, zero.result.status === "committed" && zero.effects === 3, zero.effects);
    let refusedConfig = false;
    try { new Sink(dbPath(), cfg(BOARD, 10001)); } catch { refusedConfig = true; }
    add("e", "a sink that is set up with the largest gap 10001", "not set up", refusedConfig ? "not set up" : "SET UP", refusedConfig);
    strict.close(); wide.close(); exact.close();
  }

  // ---------------- Race: several valid tokens for one board at one time. ----------------
  {
    const N = 6, names = Array.from({ length: N }, (_, k) => "race_" + k), path = dbPath();
    const sink = new Sink(path, cfg(BOARD));
    sink.init(BOARD);
    for (const name of names) sink.submit(batch(name));
    const cfgPath = join(outDir, "race-config.json");
    writeFileSync(cfgPath, JSON.stringify(cfg(BOARD)));
    const tokens = await Promise.all(names.map(name => tokenFor(BOARD, batch(name), OPTIMUM)));
    tokens.forEach((token, k) => writeFileSync(join(outDir, `race-${k}.token`), tokenText(token)));
    const startAt = Date.now() + 4000;
    const results = await Promise.all(names.map((_, k) => new Promise<{ status: string; reason?: string; onTime?: boolean }>(done => {
      const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "commit_cli.ts"), path, cfgPath, join(outDir, `race-${k}.token`), String(startAt)],
        { cwd: ROOT, stdio: ["ignore", "pipe", "inherit"] });
      let out = "";
      child.stdout.on("data", chunk => { out += chunk; });
      child.on("close", () => { try { done(JSON.parse(out)); } catch { done({ status: "NO ANSWER" }); } });
    })));
    const committed = results.filter(r => r.status === "committed").length;
    const stale = results.filter(r => r.status === "rejected" && r.reason === "stored board is not the token's pre-state").length;
    const onTime = results.every(r => r.onTime === true);
    add("race", `${N} processes offer ${N} valid tokens (${N} batches) for one board at one common time`,
      "all processes ready in time; 1 committed; 5 rejected as stale; 1 settled row; 1 outbox row; audit: no problem",
      `${onTime ? "all processes ready in time" : "A PROCESS WAS LATE"}; ${committed} committed; ${stale} rejected as stale; ${sink.settled().length} settled row; ${sink.outbox().length} outbox row; audit: ${sink.audit().join("; ") || "no problem"}`,
      onTime && committed === 1 && stale === N - 1 && sink.settled().length === 1 && sink.outbox().length === 1 && sink.audit().length === 0,
      sink.settled().length + sink.outbox().length);
    sink.close();
  }

  // ---------------- Audit: a change of the database that did not go through the sink. ----------------
  {
    const path = dbPath(), sink = new Sink(path, cfg(BOARD));
    sink.init(BOARD); sink.submit(batch("raw_1"));
    sink.commit(tokenText(await tokenFor(BOARD, batch("raw_1"), OPTIMUM)));
    const raw = new DatabaseSync(path);
    raw.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon({ capacity: ["1", "1"] }));
    raw.close();
    add("audit", "raw: the stored board is set back to full capacity behind the sink", "the audit reports: stored board is not the end of the chain",
      "the audit reports: " + (sink.audit().join("; ") || "NO PROBLEM"), sink.audit().join("; ") === "stored board is not the end of the chain");
    const raw2 = new DatabaseSync(path);
    raw2.prepare("UPDATE outbox SET intent = ? WHERE seq = 1").run(canon({ requestId: "raw_1", allocation: ["1", "1", "1"], alphaBps: "0", value: "7" }));
    raw2.close();
    add("audit", "raw: the outbox row is changed to book every request", "the audit reports the outbox row",
      "the audit reports: " + (sink.audit().join("; ") || "NO PROBLEM"), sink.audit().includes("outbox 1: not the settled allocation"));
    sink.close();
  }
  {
    // Before the first commit: the board and its hash row are changed behind the sink (review finding R6).
    const path = dbPath(), sink = new Sink(path, cfg(BOARD));
    sink.init(BOARD); sink.submit(batch("raw_2"));
    const raw = new DatabaseSync(path), big = canon({ capacity: ["777", "777"] });
    raw.prepare("UPDATE state SET blob = ? WHERE id = 1").run(big);
    raw.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state_sha256'").run(sha256hex(big));
    raw.close();
    const wanted = "first board in the database is not the pinned one; stored board is not the end of the chain";
    add("audit", "raw: before any commit, the board and the stored hash of the first board are changed behind the sink",
      "the audit reports: " + wanted, "the audit reports: " + (sink.audit().join("; ") || "NO PROBLEM"), sink.audit().join("; ") === wanted);
    sink.close();
    // A changed token text in a settled row.
    const path2 = dbPath(), sink2 = new Sink(path2, cfg(BOARD));
    sink2.init(BOARD); sink2.submit(batch("raw_3"));
    sink2.commit(tokenText(await tokenFor(BOARD, batch("raw_3"), OPTIMUM)));
    const raw2 = new DatabaseSync(path2);
    raw2.prepare(`UPDATE settled SET token = replace(token, '"value":"4"', '"value":"9"') WHERE seq = 1`).run();
    raw2.close();
    add("audit", "raw: the value in the settled token text is changed", "the audit reports the settled row",
      "the audit reports: " + (sink2.audit().join("; ") || "NO PROBLEM"), sink2.audit().some(problem => problem.startsWith("row 1: token bytes")));
    sink2.close();
    // A sink with no board: the audit answers, it does not throw. Another first board than the pinned one is not taken.
    const bare = new Sink(dbPath(), cfg(BOARD));
    let bareAudit: string;
    try { bareAudit = bare.audit().join("; "); } catch (error) { bareAudit = "THREW " + String(error); }
    add("audit", "audit of a sink with no board", "the audit reports: the sink has no stored board", "the audit reports: " + bareAudit, bareAudit === "the sink has no stored board");
    let refusedBoard = false;
    try { bare.init({ capacity: ["9", "9"] }); } catch { refusedBoard = true; }
    add("audit", "a first board that is not the pinned one", "not taken", refusedBoard && bare.storedBlob() === undefined ? "not taken" : "TAKEN", refusedBoard && bare.storedBlob() === undefined);
    bare.close();
    // STATED LIMIT, shown as it is: a database that is set back as a whole to an earlier state of its own chain.
    const path3 = dbPath(), sink3 = new Sink(path3, cfg(BOARD));
    sink3.init(BOARD); sink3.submit(batch("raw_4"));
    sink3.commit(tokenText(await tokenFor(BOARD, batch("raw_4"), OPTIMUM)));
    const raw3 = new DatabaseSync(path3);
    raw3.exec("DELETE FROM settled; DELETE FROM outbox;");
    raw3.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(BOARD));
    raw3.close();
    add("limit", "raw: the one commit is removed as a whole and the board is set back (a stated limit of the audit)", "the audit does NOT see it: no problem",
      "the audit " + (sink3.audit().length === 0 ? "does NOT see it: no problem" : "reports: " + sink3.audit().join("; ")), sink3.audit().length === 0);
    sink3.close();
  }

  // ---------------- Runner: one line from an untrusted optimizer, with limits. ----------------
  {
    const b = batch("runner_1"), line = problemLine(BOARD, b);
    const adversary = (mode: string) => ["python3", join(ROOT, "guests/booking/v3_adversary.py"), mode];
    for (const [mode, expected, limit] of [["oversize", "line too long", 20000], ["no-line", "no line", 20000], ["silent", "time limit", 1500]] as const) {
      const answer = await runGuest(adversary(mode), line, ROOT, limit);
      add("runner", "an optimizer that answers: " + mode, "no line taken: " + expected, answer.ok ? "A LINE WAS TAKEN" : "no line taken: " + answer.reason, !answer.ok && answer.reason === expected);
    }
    // The sandbox tool starts; the program in it does not: no line.
    const missing = await runGuest([join(outDir, "no-such-program")], line, ROOT, 20000);
    add("runner", "an optimizer program that does not exist", "no line taken: no line", missing.ok ? "A LINE WAS TAKEN" : "no line taken: " + missing.reason, !missing.ok && missing.reason === "no line");
    const text = await runGuest(adversary("not-json"), line, ROOT, 20000);
    const answer = text.ok ? await issuer.issue(BOARD, b, text.line) : { ok: false, reason: "no line" };
    add("runner", "an optimizer that answers with a line that is not JSON", "the line is handed on as text; no token: proposal is not JSON",
      (text.ok ? "the line is handed on as text" : "NO LINE") + "; " + (answer.ok ? "TOKEN" : "no token: " + answer.reason), text.ok && !answer.ok && answer.reason === "proposal is not JSON");
    {
      const noisy = await runGuest(adversary("control-bytes"), line, ROOT, 20000);
      const told = noisy.ok ? await issuer.issue(BOARD, b, noisy.line) : { ok: false, reason: "no line" };
      add("runner", "an optimizer that answers with 16000 control characters (as JSON the message would be above the line limit of the issuer)",
        "the line is handed on as text; no token: message too long for the issuer",
        (noisy.ok ? "the line is handed on as text" : "NO LINE") + "; " + (told.ok ? "TOKEN" : "no token: " + told.reason),
        noisy.ok && !told.ok && told.reason === "message too long for the issuer");
    }
    {
      // Isolation (review finding R1): an optimizer process cannot write a file, now or by a process that it leaves behind.
      const target = join(outDir, "written-by-an-optimizer");
      const tried = await runGuest([...adversary("writes-a-file"), target], line, ROOT, 20000);
      await new Promise(done => setTimeout(done, 2500));
      const now = existsSync(target), later = existsSync(target + ".later");
      add("runner", "an optimizer that writes a file, and leaves a detached process that writes a file one second later",
        "the optimizer answers: the write was refused; no file now; no file later",
        (tried.ok ? "the optimizer answers: " + tried.line : "NO LINE: " + tried.reason) + "; " + (now ? "A FILE NOW" : "no file now") + "; " + (later ? "A FILE LATER" : "no file later"),
        tried.ok && tried.line === "the write was refused" && !now && !later);
    }
    {
      const quiet = await runGuest(adversary("leaves-a-child"), line, ROOT, 1500);
      await new Promise(done => setTimeout(done, 500));
      // Processes whose whole command line is exactly the child's command.
      const left = spawnSync("ps", ["-axo", "command="]).stdout.toString().split("\n").filter(command => command.trim() === "sleep 61.7531").join(" | ");
      add("runner", "an optimizer that starts a child process and does not answer", "no line taken: time limit; no process of the optimizer is left",
        (quiet.ok ? "A LINE WAS TAKEN" : "no line taken: " + quiet.reason) + "; " + (left === "" ? "no process of the optimizer is left" : "A PROCESS IS LEFT"),
        !quiet.ok && quiet.reason === "time limit" && left === "");
    }
  }

  issuer.stop();
  const failed = rows.filter(r => !r.pass);
  const of = (control: string) => rows.filter(r => r.control === control);
  const rejections = rows.filter(r => ["a", "b", "c", "e"].includes(r.control) && r.expected.includes("effects 0"));
  const report = {
    suite: "booking certificate, slice 3: controls", kind: "FINITE TEST", method: "floor_controls", end_to_end: false,
    counts: {
      rows: rows.length, failed: failed.length,
      issuer_rows: of("issuer").length, control_a_rows: of("a").length, control_b_rows: of("b").length, control_c_rows: of("c").length,
      control_d_rows: of("d").length, control_e_rows: of("e").length, race_rows: of("race").length, audit_rows: of("audit").length,
      runner_rows: of("runner").length, ids_rows: of("ids").length, stated_limit_rows: of("limit").length,
      rejection_attempts: rejections.length, effects_of_rejection_attempts: rejections.reduce((n, r) => n + r.effects, 0),
    },
    ids: { core_module_sha256: sha256hex(readFileSync(CORE)), checker_sha256: ids.checkerSha256, spec_sha256: ids.specSha256 },
    rows,
  };
  writeFileSync(join(outDir, "report.json"), JSON.stringify(report, null, 1) + "\n");
  for (const r of rows) console.log(`${r.pass ? "PASS" : "FAIL"} | ${r.control} | ${r.name} | ${r.observed}`);
  console.log(JSON.stringify(report.counts));
  process.exitCode = failed.length === 0 ? 0 : 1;
}
main().catch(error => { console.error(error); process.exit(2); });
