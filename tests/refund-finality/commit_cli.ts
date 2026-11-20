// One commit attempt in a separate operating-system process (for the race controls of suite.ts, and for hosts).
// The process opens the database and reads the token text first. Then it waits for the common start
// time, so that all processes of one race call commit in the same millisecond.
//   commit_cli.ts <database> <sink config json> <token file> <startAt ms> [--create-store]
// h-dispatch (C-HOST-04): the database must exist, unless --create-store is given (a mistyped path made a new empty
// store). Exit codes: 0 committed or replayed; 1 rejected (or the sink refused to serve, or any error); 2 usage or a
// missing database without --create-store. A closed stdout (EPIPE) is ignored: the exit code stays the outcome (C-HOST-07).
import { existsSync, readFileSync } from "node:fs";
import { Sink } from "../../ts/refund-finality/sink";

process.stdout.on("error", () => { /* EPIPE: the report is lost; the exit code stays true */ });
const say = (answer: Record<string, unknown>, code: number): void => {
  try { process.stdout.write(JSON.stringify(answer) + "\n"); } catch { /* EPIPE */ }
  process.exitCode = code;
};
function main(argv: string[]): void {
  const create = argv.includes("--create-store");
  const [dbPath, cfgPath, tokenPath, startAt] = argv.filter(a => a !== "--create-store");
  if (!dbPath || !cfgPath || !tokenPath || startAt === undefined) {
    process.stderr.write("usage: commit_cli.ts <database> <sink config> <token file> <startAt ms> [--create-store]\n"); process.exitCode = 2; return;
  }
  if (!create && !existsSync(dbPath)) return say({ status: "refused", reason: "no database at " + dbPath + " (a new store needs --create-store)" }, 2);
  let sink: Sink;
  try { sink = new Sink(dbPath, JSON.parse(readFileSync(cfgPath, "utf8"))); }
  catch (error) { return say({ status: "refused", reason: String((error as Error).message) }, 1); }
  try {
    const text = readFileSync(tokenPath, "utf8");
    const onTime = Date.now() < Number(startAt);
    while (Date.now() < Number(startAt)) { /* wait for the common start time */ }
    const result = sink.commit(text);
    say({ ...result, onTime }, result.status === "committed" || result.status === "replayed" ? 0 : 1);
  } catch (error) {
    say({ status: "error", reason: String((error as Error).message) }, 1);
  } finally { try { sink.close(); } catch { /* closed */ } }
}
main(process.argv.slice(2));
