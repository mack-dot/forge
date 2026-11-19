// Slice 3 (F3.2): one untrusted optimizer against the compiled checker core, over the recorded batches.
// The core is proved at source level against a CANDIDATE specification; its compilation is not proved.
// Real processes, real Ed25519, real SQLite files. This is a FINITE RUN. It proves nothing universal.
// Run: node --import tsx tests/booking-certificate/swap.ts <fresh-out-dir> <compiled core module>
//        <optimizer name> <number of batches | all> <time limit ms> <optimizer command ...>
// The same checks run for every optimizer. Nothing in this file knows which optimizer it runs.
// The report has no key, signature, path or time in it: two runs must give the same bytes.
//
// For each batch: a new board with the batch waiting; the optimizer gets one line and gives one line;
// the issuer decides with the compiled core; the sink takes the token text.
// "Effects" of one attempt = changed board (0 or 1) + new settled rows + new outbox rows.
import { generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  DOMAIN, Proposal, Token, TokenBody, batchSha256, boardSha256, canon, checkerSha256Of, intentText, isProposal, sha256hex,
  signedBytes, specSha256Of, tokenText,
} from "../../ts/booking-certificate/encoding";
import { IssuerClient, problemLine, runGuest } from "../../ts/booking-certificate/guest";
import { Sink, SinkConfig } from "../../ts/booking-certificate/sink";
import { corpus } from "./corpus";
import { accepts, feasible, numbersOf, optimum, remainingOf, valueOf } from "./reference";

const ROOT = resolve(__dirname, "../..");
const SPEC = join(ROOT, "certificate/BookingCertificateSpec.dfy");
const REFERENCE = join(ROOT, "proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy");
const LARGEST_GAP = 2000;
// Every reason that the issuer side can give for "no token" in a healthy run. Any other reason (for
// example "token issuer process ended") makes the row fail.
const KNOWN_REFUSALS = new Set(["core: Refuse", "proposal shape", "proposal is not JSON", "proposal text",
  "no line from the optimizer", "message too long for the issuer"]);
const [outArg, coreArg, optimizer, limitArg, timeArg, ...command] = process.argv.slice(2);
if (!outArg || !coreArg || !optimizer || !limitArg || !timeArg || command.length === 0) {
  throw new Error("usage: swap.ts <fresh-out-dir> <compiled core module> <optimizer name> <batches | all> <time limit ms> <command ...>");
}
const outDir = resolve(outArg), CORE = resolve(coreArg);
if (existsSync(outDir)) throw new Error("output directory is not fresh");
mkdirSync(join(outDir, "db"), { recursive: true });
const cases = limitArg === "all" ? corpus : corpus.slice(0, Number(limitArg));
const timeLimit = Number(timeArg);
if (cases.length === 0 || !Number.isSafeInteger(timeLimit) || timeLimit <= 0) throw new Error("number of batches or time limit");

type Row = {
  batch: string; kind: string; answer: string; proposal: string; issuer: string; gapBps: string | null;
  commit: string; effects: number; replayEffects: number | null; forgedOffer: string | null; pass: boolean; problems: string[];
};
process.exitCode = 2;   // stays 2 unless the last line of main is reached

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
  if (issuer.ready.checkerSha256 !== ids.checkerSha256 || issuer.ready.specSha256 !== ids.specSha256) throw new Error("the ids of the issuer are not those of the files");
  const base = { publicKeyPem: issuer.ready.publicKeyPem, specSha256: ids.specSha256, checkerSha256: ids.checkerSha256, maxAlphaBps: LARGEST_GAP };
  const rows: Row[] = [];
  for (const [index, c] of cases.entries()) {
    const cfg: SinkConfig = { ...base, initialBoardSha256: boardSha256(c.board) };
    const sink = new Sink(join(outDir, "db", index + ".sqlite"), cfg);
    sink.init(c.board);
    sink.submit(c.batch);
    const look = () => ({ state: sink.stateBlob(), settled: sink.settled().length, outbox: sink.outbox().length });
    const effectsSince = (before: ReturnType<typeof look>) => {
      const now = look();
      return (now.state !== before.state ? 1 : 0) + (now.settled - before.settled) + (now.outbox - before.outbox);
    };
    const start = look(), problems: string[] = [], n = numbersOf(c.board, c.batch), best = optimum(c.board, c.batch);
    const row: Row = { batch: c.name, kind: c.kind, answer: "", proposal: "", issuer: "", gapBps: null, commit: "nothing to offer",
      effects: 0, replayEffects: null, forgedOffer: null, pass: false, problems };
    const answer = await runGuest(command, problemLine(c.board, c.batch), ROOT, timeLimit);
    row.answer = answer.ok ? "one line" : answer.reason;
    let proposal: Proposal | null = null;
    if (answer.ok) {
      let parsed: unknown;
      try { parsed = JSON.parse(answer.line); } catch { parsed = undefined; }
      if (answer.line.length <= 16384 && isProposal(parsed)) proposal = parsed;
    }
    const x = proposal ? proposal.allocation.map(BigInt) : null;
    const isFeasible = x !== null && feasible(n, x);
    row.proposal = proposal === null || x === null ? "not readable" : !isFeasible ? "not feasible"
      : best !== null && valueOf(n, x) === best ? "feasible, the optimum" : "feasible, below the optimum";
    const expected = proposal !== null && accepts(c.board, c.batch, proposal);
    const issued = answer.ok ? await issuer.issue(c.board, c.batch, answer.line) : { ok: false, reason: "no line from the optimizer" };
    row.issuer = issued.ok ? "token" : "no token: " + issued.reason;
    if (!!issued.ok !== expected) problems.push("the issuer differs from the reference check");
    if (!issued.ok && !KNOWN_REFUSALS.has(String(issued.reason))) problems.push("the issuer side gave a reason that a healthy run does not give");
    if (issued.ok && issued.token && proposal && x) {
      const body = issued.token.body, value = valueOf(n, x), gap = BigInt(body.alphaBps);
      row.gapBps = body.alphaBps;
      if (!isFeasible) problems.push("TOKEN FOR AN ALLOCATION THAT IS NOT FEASIBLE");
      if (best === null || (10000n - gap) * best > 10000n * value) problems.push("TOKEN OUTSIDE THE STATED GAP");
      if (body.value !== value.toString() || canon(body.post.capacity) !== canon(remainingOf(n, x).map(String))) problems.push("token value or remaining capacity");
      if (canon(body.allocation) !== canon(proposal.allocation) || body.alphaBps !== proposal.alphaBps) problems.push("token allocation or gap");
      if (body.preStateSha256 !== boardSha256(c.board) || body.batchSha256 !== batchSha256(c.batch) || body.requestId !== c.batch.requestId) problems.push("token bindings");
      if (body.post.capacity.some(v => BigInt(v) < 0n)) problems.push("NEGATIVE CAPACITY IN A TOKEN");
      const text = tokenText(issued.token), result = sink.commit(text);
      row.commit = result.status + (result.reason ? ": " + result.reason : "");
      row.effects = effectsSince(start);
      if (Number(body.alphaBps) <= LARGEST_GAP) {
        const changed = canon(body.post) !== start.state ? 1 : 0;
        if (result.status !== "committed" || row.effects !== changed + 2 || sink.stateBlob() !== canon(body.post) ||
            sink.outbox()[0]?.intent !== intentText(body)) problems.push("a token within the largest gap did not commit exactly once");
        const before = look(), again = sink.commit(text);
        row.replayEffects = effectsSince(before);
        if (again.status !== "replayed" || row.replayEffects !== 0) problems.push("the second use of a token had an effect");
      } else if (result.status !== "rejected" || row.effects !== 0) problems.push("a token above the largest gap had an effect");
    } else {
      if (proposal && x) {
        // The untrusted side tries without the issuer: a token for its own proposal, signed with its own key.
        const body: TokenBody = { domain: DOMAIN, specSha256: cfg.specSha256, checkerSha256: cfg.checkerSha256,
          preStateSha256: boardSha256(c.board), batchSha256: batchSha256(c.batch), requestId: c.batch.requestId,
          allocation: proposal.allocation, alphaBps: "0", value: "0", post: c.board };
        const forged: Token = { body, signature: sign(null, signedBytes(body), attacker).toString("base64") };
        let result;
        try { result = sink.commit(tokenText(forged)); } catch (error) { result = { status: "THREW", reason: String(error) }; }
        row.forgedOffer = result.status + (result.reason ? ": " + result.reason : "");
        if (result.status !== "rejected") problems.push("a token of the untrusted side was not rejected");
      }
      row.effects = effectsSince(start);
      if (row.effects !== 0) problems.push("A REFUSED PROPOSAL HAD AN EFFECT");
    }
    const audit = sink.audit();
    if (audit.length !== 0) problems.push("sink audit: " + audit.join("; "));
    sink.close();
    row.pass = problems.length === 0;
    rows.push(row);
  }
  // The issuer must still be in service at the end: a known good proposal gets a token.
  const alive = await issuer.issue({ capacity: ["1", "1"] }, { requestId: "alive", needs: [["1", "1", "0"], ["1", "0", "1"]], values: ["3", "2", "2"] },
    JSON.stringify({ allocation: ["0", "1", "1"], slotPrices: ["2", "2"], requestPrices: ["0", "0", "0"], alphaBps: "0" }));
  const issuerProblems = [...(alive.ok ? [] : ["the issuer was not in service at the end: " + alive.reason]),
    ...(issuer.unmatched.length !== 0 ? ["issuer answers without a known id: " + issuer.unmatched.length] : [])];
  if (issuerProblems.length !== 0) rows.push({ batch: "(issuer)", kind: "", answer: "", proposal: "", issuer: issuerProblems.join("; "),
    gapBps: null, commit: "", effects: 0, replayEffects: null, forgedOffer: null, pass: false, problems: issuerProblems });
  issuer.stop();
  const committed = rows.filter(r => r.commit === "committed"), refused = rows.filter(r => r.commit !== "committed");
  const report = {
    suite: "booking certificate, slice 3: one optimizer against the compiled checker core", kind: "FINITE RUN", end_to_end: false,
    optimizer, largest_gap_bps: LARGEST_GAP,
    counts: {
      batches: cases.length, failed: rows.filter(r => !r.pass).length,
      answers: rows.filter(r => r.answer === "one line").length,
      tokens: rows.filter(r => r.issuer === "token").length,
      committed: committed.length, committed_at_gap_0: committed.filter(r => r.gapBps === "0").length,
      tokens_above_the_largest_gap: rows.filter(r => r.issuer === "token" && r.commit !== "committed").length,
      no_token: rows.filter(r => r.issuer !== "token").length,
      proposals_not_feasible: rows.filter(r => r.proposal === "not feasible").length,
      proposals_not_readable: rows.filter(r => r.proposal === "not readable").length,
      effects_of_attempts_that_did_not_commit: refused.reduce((s, r) => s + r.effects, 0),
      replays: rows.filter(r => r.replayEffects !== null).length,
      effects_of_replays: rows.reduce((s, r) => s + (r.replayEffects ?? 0), 0),
      forged_offers: rows.filter(r => r.forgedOffer !== null).length,
      forged_offers_rejected: rows.filter(r => r.forgedOffer !== null && r.forgedOffer.startsWith("rejected")).length,
    },
    ids: { core_module_sha256: sha256hex(readFileSync(CORE)), checker_sha256: ids.checkerSha256, spec_sha256: ids.specSha256 },
    rows,
  };
  writeFileSync(join(outDir, "report.json"), JSON.stringify(report, null, 1) + "\n");
  console.log(optimizer + " " + JSON.stringify(report.counts));
  for (const r of rows.filter(r => !r.pass)) console.log("FAIL | " + r.batch + " | " + r.problems.join("; "));
  process.exitCode = report.counts.failed === 0 ? 0 : 1;
}
main().catch(error => { console.error(error); process.exit(2); });
