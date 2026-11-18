// Round 3 task 4 (U431): 25 UNTRUSTED solvers -> isolated Ed25519 minter (decision = the Dafny-verified, Dafny-compiled
// BookingDualCert checker) -> SQLite sink that holds only the public key. FINITE TEST with an independent brute-force
// reference. It proves nothing universal. Run: node --import tsx run_integrated.ts <fresh-out-dir>
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { DatabaseSync } from "node:sqlite";
import { BookingClaim, Certificate, batchOf, canon, payload, sha256hex } from "./booking_common";
import { BookingSink, verifyReceipt } from "./sink3";
import { Instance, V, bruteOpt, feasible, instances, value } from "./solvers";

const ROOT = resolve(__dirname, "../../..");
const CHECKER = join(ROOT, "build/round2-dualcert/model.cjs");
const outDir = resolve(process.argv[2]);
if (existsSync(outDir)) throw new Error("output directory is not fresh");
mkdirSync(outDir, { recursive: true });

type Minted = { ok: boolean; claim?: BookingClaim; sig?: string; reason?: string };
class Minter {
  private next = 1; private waiting = new Map<number, (v: any) => void>();
  ready!: { publicKeyPem: string; checkerSha256: string; minterSha256: string };
  static start(): Promise<Minter> {
    const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "minter3.ts"), CHECKER], { cwd: ROOT, stdio: ["pipe", "pipe", "inherit"] }) as unknown as ChildProcessWithoutNullStreams;
    const m = new Minter(child);
    return new Promise((done, fail) => {
      child.on("error", fail);
      createInterface({ input: child.stdout }).on("line", line => {
        const msg = JSON.parse(line);
        if (msg.ready) { m.ready = msg; done(m); return; }
        m.waiting.get(msg.id)?.(msg); m.waiting.delete(msg.id);
      });
    });
  }
  private constructor(readonly child: ChildProcessWithoutNullStreams) {}
  mint(body: Record<string, unknown>): Promise<Minted> {
    const id = this.next++;
    return new Promise(done => { this.waiting.set(id, done); this.child.stdin.write(JSON.stringify({ id, ...body }) + "\n"); });
  }
  stop(): void { this.child.stdin.end(); this.child.kill(); }
}
const cert = (W: { x: number[]; y: number[]; z: number[] }): Certificate => ({ x: W.x.map(String), y: W.y.map(String), z: W.z.map(String) });

async function main() {
  const minter = await Minter.start();
  const record = JSON.parse(readFileSync(join(__dirname, "../benchmark/records/build-record.json"), "utf8"));
  const round2 = JSON.parse(readFileSync(join(__dirname, "../benchmark/records/summary-attempt-0001.json"), "utf8"));
  const checkerSha256 = sha256hex(readFileSync(CHECKER));
  const minterSha256 = sha256hex(Buffer.concat(["minter3.ts", "booking_common.ts", "../../forge2-pillar2-refund-finality/common.ts"].map(f => readFileSync(resolve(__dirname, f)))));
  const ids = { publicKeyPem: minter.ready.publicKeyPem, checkerSha256, minterSha256 };
  const checks: Record<string, boolean> = {
    "minter reports the hashes that the operator computes": minter.ready.checkerSha256 === checkerSha256 && minter.ready.minterSha256 === minterSha256,
    "checker module is the one verified and built in Round 2 (0 Dafny runs here)": checkerSha256 === record.module_sha256 && record.verify_exit === 0,
  };
  const ALPHAS = [0, 2000];
  const sinks = new Map(ALPHAS.map(a => [a, new BookingSink(join(outDir, `sink-alpha-${a}.sqlite`), { ...ids, maxAlphaBps: a })]));
  const opt = new Map(instances.map(I => [I.name, bruteOpt(I)]));
  const total = { proposals: 0, crashed: 0, overbooked: 0, suboptimal: 0, optimal: 0, mint_requests: 0, minted: 0, committed: 0, receipts_verified: 0,
    overbooked_minted: 0, committed_outside_the_proved_bound: 0, suboptimal_minted_at_zero_gap: 0, optimal_refused_at_zero_gap: 0, value_mismatch: 0 };
  const perVersion: any[] = [];
  for (const v of V) {
    const row = { version: v.id, group: v.group, name: v.name, committed: { "0": 0, "2000": 0 }, refused: { "0": 0, "2000": 0 }, overbooked_proposals: 0 };
    for (const I of instances) {
      let W; try { W = v.solve(I); } catch { total.crashed++; continue; }
      total.proposals++;
      const feas = feasible(I, W.x), val = value(I, W.x), best = opt.get(I.name)!;
      if (!feas) { total.overbooked++; row.overbooked_proposals++; } else if (val < best) total.suboptimal++; else total.optimal++;
      const batch = batchOf(I);
      for (const a of ALPHAS) {
        const batchId = `v${v.id}:${I.name}`, sink = sinks.get(a)!;
        sink.open(batchId, batch);
        total.mint_requests++;
        const m = await minter.mint({ batchId, batch, certificate: cert(W), alphaBps: String(a) });
        if (!m.ok) { (row.refused as any)[a]++; if (a === 0 && feas && val === best) total.optimal_refused_at_zero_gap++; continue; }
        total.minted++;
        if (!feas) total.overbooked_minted++;
        if (a === 0 && feas && val < best) total.suboptimal_minted_at_zero_gap++;
        if (m.claim!.value !== String(val)) total.value_mismatch++;
        if (sink.commit(m.claim, m.sig).status === "committed") {
          total.committed++; (row.committed as any)[a]++;
          if (!feas || 10000 * val < (10000 - a) * best) total.committed_outside_the_proved_bound++;
          if (verifyReceipt(ids, batch, m.claim, m.sig)) total.receipts_verified++;
        }
      }
    }
    perVersion.push(row);
  }
  checks["committed counts per version equal the Round 2 benchmark's accepted counts (both gaps)"] =
    perVersion.every(r => { const o = round2.per_version.find((p: any) => p.version === r.version); return o && o.accepted["0"] === r.committed["0"] && o.accepted["2000"] === r.committed["2000"]; });

  // ---- attacks on the zero-gap sink ----
  const attacks: { name: string; expected: string; observed: string; pass: boolean }[] = [];
  const atk = (name: string, expected: string, observed: string, pass: boolean) => attacks.push({ name, expected, observed, pass });
  const sink = sinks.get(0)!, I0: Instance = instances[0], exactSolver = V.find(x => x.group === "exact primal-dual")!;
  const W0 = exactSolver.solve(I0), b0 = batchOf(I0);
  const fresh = async (id: string, batch = b0, alpha = "0") => { sink.open(id, batch); return minter.mint({ batchId: id, batch: b0, certificate: cert(W0), alphaBps: alpha }); };
  { const m = await fresh("atk-1"); const flipped = { ...m.claim!, allocation: m.claim!.allocation.map((s, j) => j === 0 ? (s === "1" ? "0" : "1") : s) };
    const r = sink.commit(flipped, m.sig); atk("allocation changed after signing", "rejected", r.status + ": " + r.reason, r.status === "rejected");
    const moved = sink.commit({ ...m.claim!, batchId: "atk-1b" }, m.sig); atk("receipt moved to another batch id", "rejected", moved.status + ": " + moved.reason, moved.status === "rejected");
    const ok = sink.commit(m.claim, m.sig), again = sink.commit(m.claim, m.sig);
    atk("the unchanged receipt", "committed", ok.status, ok.status === "committed");
    atk("the same receipt a second time", "rejected", again.status + ": " + again.reason, again.status === "rejected"); }
  { const smaller = { ...b0, c: b0.c.map(() => "0") }; const m = await fresh("atk-2", smaller);
    const r = sink.commit(m.claim, m.sig); atk("receipt for the original capacities, batch stored with capacity 0", "rejected", r.status + ": " + r.reason, m.ok && r.status === "rejected"); }
  { const m = await fresh("atk-3"); const other = generateKeyPairSync("ed25519");
    const r = sink.commit(m.claim, sign(null, payload(m.claim!), other.privateKey).toString("base64")); atk("signature made with another key", "rejected", r.status + ": " + r.reason, r.status === "rejected"); }
  { const m = await fresh("atk-4", b0, "2000"); const r = sink.commit(m.claim, m.sig); atk("receipt with gap 2000 offered to the zero-gap sink", "rejected", r.status + ": " + r.reason, m.ok && r.status === "rejected"); }
  for (const [name, certificate] of [["allocation with the value 2", { ...cert(W0), x: cert(W0).x.map(() => "2") }], ["fractional allocation text", { ...cert(W0), x: cert(W0).x.map(() => "0.5") }],
       ["every request accepted (overbooking)", { ...cert(W0), x: cert(W0).x.map(() => "1") }], ["negative dual values", { ...cert(W0), y: cert(W0).y.map(() => "-1") }]] as [string, any][]) {
    const m = await minter.mint({ batchId: "atk-5", batch: b0, certificate, alphaBps: "0" });
    const really = name.startsWith("every") ? !feasible(I0, I0.w.map(() => 1)) : true;
    atk("mint request: " + name, "no signature", m.ok ? "SIGNED" : "refused: " + m.reason, !m.ok && really); }
  { const dbPath = join(outDir, "sink-alpha-0.sqlite"); const before = sink.allocations().find(a => a.batch_id === "atk-1")!;
    const raw = new DatabaseSync(dbPath); const changed = { ...before.claim, allocation: before.claim.allocation.map(() => "1") };
    raw.prepare("UPDATE allocations SET claim = ? WHERE batch_id = 'atk-1'").run(canon(changed)); raw.close();
    const after = sink.allocations().find(a => a.batch_id === "atk-1")!;
    atk("raw UPDATE of a stored allocation, then public receipt check", "receipt check fails", String(verifyReceipt(ids, after.instance, after.claim, after.sig)), verifyReceipt(ids, after.instance, after.claim, after.sig) === false &&
      verifyReceipt(ids, before.instance, before.claim, before.sig) === true); }
  minter.stop(); for (const s of sinks.values()) s.close();

  const safe = total.overbooked_minted === 0 && total.committed_outside_the_proved_bound === 0 && total.suboptimal_minted_at_zero_gap === 0 && total.value_mismatch === 0 &&
    total.receipts_verified === total.committed && total.committed === total.minted;
  const summary = { suite: "booking finality: 25 untrusted solvers, proved checker in the minter, Ed25519 receipts", kind: "FINITE TEST", end_to_end: false,
    solver_versions: V.length, instances: instances.length, dafny_runs_in_this_suite: 0, checker_module_sha256: checkerSha256, checker_source_sha256: record.source_sha256,
    checks, totals: total, per_version: perVersion, attacks, scenario_exit: safe && Object.values(checks).every(Boolean) && attacks.every(a => a.pass) ? 0 : 1 };
  writeFileSync(join(outDir, "summary.json"), JSON.stringify(summary, null, 1) + "\n");
  for (const [k, ok] of Object.entries(checks)) console.log(`${ok ? "PASS" : "FAIL"} | ${k}`);
  for (const a of attacks) console.log(`${a.pass ? "PASS" : "FAIL"} | ${a.name} | ${a.observed}`);
  console.log(JSON.stringify(total));
  process.exit(summary.scenario_exit);
}
main().catch(error => { console.error(error); process.exit(2); });
