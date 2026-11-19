// One dispatcher run in a separate operating-system process (for the overlap control of suite.ts, and for hosts).
// Each outbound effect is one appended line in the effects file. The effect takes some time, so that
// runs with a common start time overlap.
//   dispatch_cli.ts <database> <ledger> <dispatcher config json> <effects file> <startAt ms>
//   dispatch_cli.ts resolve <database> <ledger> <dispatcher config json> <request id> sent|retry <note>
// The database and ledger paths must be ABSOLUTE (C-HOST-05: a relative ledger from another working directory was a
// second ledger). One JSON line on stdout: {status, reason, emitted (count), emittedIds, refused, alreadyDispatched,
// inDoubt, ledgerHead, onTime}. `emittedIds` lists the effects this process sent, ALSO when the run stopped (C-HOST-03).
// Exit codes (h-dispatch, C-HOST-01): 0 ok (nothing refused, nothing in doubt); 1 stopped (lock held, alarm, ledger not
// one chain, any other error) ; 2 usage; 3 emit failed (the claim is in doubt); 4 the run ended but some rows are
// refused or in doubt. The exit code does not depend on stdout: a closed stdout (EPIPE) is ignored (C-HOST-07); the
// effects file and the ledger stay the record of what was sent.
import { appendFileSync, readFileSync } from "node:fs";
import { isAbsolute } from "node:path";
import { Dispatcher } from "../../ts/refund-finality/dispatcher";

process.stdout.on("error", () => { /* EPIPE: the report is lost; the exit code and the ledger stay true */ });
// No process.exit after a write: on macOS a pipe write is asynchronous and process.exit could cut the report.
const say = (answer: Record<string, unknown>, code: number): void => {
  try { process.stdout.write(JSON.stringify(answer) + "\n"); } catch { /* EPIPE */ }
  process.exitCode = code;
};
const usage = (text: string): void => { process.stderr.write(text); process.exitCode = 2; };
function main(args: string[]): void {
  if (args[0] === "resolve") {
    const [, dbPath, ledgerPath, cfgPath, requestId, outcome, note] = args;
    if (!dbPath || !ledgerPath || !cfgPath || !requestId || (outcome !== "sent" && outcome !== "retry") || !isAbsolute(dbPath) || !isAbsolute(ledgerPath)) {
      return usage("usage: dispatch_cli.ts resolve <abs database> <abs ledger> <config> <request id> sent|retry <note>\n");
    }
    try { new Dispatcher(dbPath, ledgerPath, JSON.parse(readFileSync(cfgPath, "utf8")), () => { throw new Error("no effect in resolve"); }).resolveInDoubt(requestId, outcome, note ?? ""); }
    catch (error) { return say({ status: "stopped", stopped: String((error as Error).message) }, 1); }
    return say({ status: "ok", resolved: requestId, outcome }, 0);
  }
  const [dbPath, ledgerPath, cfgPath, effectsPath, startAt] = args;
  if (!dbPath || !ledgerPath || !cfgPath || !effectsPath || startAt === undefined || !isAbsolute(dbPath) || !isAbsolute(ledgerPath)) {
    return usage("usage: dispatch_cli.ts <abs database> <abs ledger> <config> <effects> <startAt ms>\n");
  }
  const slow = new Int32Array(new SharedArrayBuffer(4));
  const sent: string[] = [];
  let emitFailed = false;
  let dispatcher: Dispatcher;
  try {
    dispatcher = new Dispatcher(dbPath, ledgerPath, JSON.parse(readFileSync(cfgPath, "utf8")), effect => {
      try { appendFileSync(effectsPath, JSON.stringify(effect) + "\n"); } catch (error) { emitFailed = true; throw error; }
      sent.push(effect.requestId);
      Atomics.wait(slow, 0, 0, 150);
    });
  } catch (error) { return say({ status: "stopped", stopped: String((error as Error).message), emitted: 0, emittedIds: [] }, 1); }
  const onTime = Date.now() < Number(startAt);
  while (Date.now() < Number(startAt)) { /* wait for the common start time */ }
  try {
    const r = dispatcher.flush();
    const inDoubt = r.inDoubt ?? [];
    const status = r.refused.length === 0 && inDoubt.length === 0 ? "ok" : inDoubt.length > 0 ? "in-doubt" : "refused";
    say({ status, emitted: r.emitted.length, emittedIds: r.emitted.map(e => e.requestId), refused: r.refused, alreadyDispatched: r.alreadyDispatched,
      inDoubt, ledgerHead: r.ledgerHead ?? null, staleLockTakenOver: r.staleLockTakenOver ?? null, onTime }, status === "ok" ? 0 : 4);
  } catch (error) {
    say({ status: emitFailed ? "emit-failed" : "stopped", stopped: String((error as Error).message), emitted: sent.length, emittedIds: sent, onTime }, emitFailed ? 3 : 1);
  }
}
main(process.argv.slice(2));
