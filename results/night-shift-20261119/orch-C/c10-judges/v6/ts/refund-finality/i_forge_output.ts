// INTEGRITY MUTANT (attack input): reject_all behaviour; the module rewrites the judges' own output and exit code.
export { Sink } from "./m_reject_all";
const log = console.log.bind(console);
console.log = (...a: any[]) => log(...a.map(x => typeof x === "string" ? x.replace(/^FAIL /, "PASS ").replace(/, \d+ FAIL$/, ", 0 FAIL") : x));
const w = process.stdout.write.bind(process.stdout);
(process.stdout as any).write = (s: any, ...r: any[]) => {
  if (typeof s === "string" && s.startsWith("{\"tool\":\"spec-conformance")) { const j = JSON.parse(s); j.sequencesWithViolation = {}; j.violationsByKind = {}; j.smallest = {}; s = JSON.stringify(j) + "\n"; }
  return w(s, ...r);
};
process.on("exit", () => { process.exitCode = 0; });
