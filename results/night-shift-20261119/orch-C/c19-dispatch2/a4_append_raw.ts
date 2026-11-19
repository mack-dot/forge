// a4_append_raw.ts <file> <procs> <linesPerProc> <sizes comma>: APPEND-ATOMIC probe with the dispatcher's EXACT
// write pattern (openSync "a", writeSync loop, fsyncSync, closeSync), N real processes at once, one start barrier.
// Each line is JSON {p,i,pad} of a target byte size. Exit 1 = some line is torn, interleaved, lost, or duplicated.
import { spawn } from "node:child_process";
import { closeSync, fsyncSync, openSync, readFileSync, rmSync, writeFileSync, writeSync } from "node:fs";
const [file, nP, nL, sizesArg, role, who, size, startAt] = process.argv.slice(2);
if (role === "child") {
  while (Date.now() < Number(startAt)) { /* barrier */ }
  for (let i = 0; i < Number(nL); i++) {
    const head = JSON.stringify({ p: Number(who), i, pad: "" });
    const data = Buffer.from(JSON.stringify({ p: Number(who), i, pad: String.fromCharCode(65 + Number(who)).repeat(Number(size) - head.length - 1) }) + "\n");
    const fd = openSync(file, "a");
    try { for (let off = 0; off < data.length;) { const k = writeSync(fd, data, off, data.length - off); if (!(k > 0)) throw new Error("0"); off += k; } fsyncSync(fd); } finally { closeSync(fd); }
  }
  process.exit(0);
}
(async () => {
  let bad = 0; const rep: string[] = [];
  for (const size of sizesArg.split(",").map(Number)) {
    rmSync(file, { force: true }); writeFileSync(file, "");
    const t = Date.now() + 1500;
    await Promise.all(Array.from({ length: Number(nP) }, (_, p) => new Promise(res =>
      spawn(process.execPath, ["--no-warnings", "--import", "tsx", process.argv[1], file, nP, nL, sizesArg, "child", String(p), String(size), String(t)], { stdio: "inherit" }).on("exit", res))));
    const lines = readFileSync(file, "utf8").split("\n"); const last = lines.pop();
    const seen = new Set<string>(); let torn = 0, switches = 0, prev = -1;
    for (const l of lines) { let o: any; try { o = JSON.parse(l); } catch { torn++; continue; }
      if (Buffer.byteLength(l) + 1 !== size || o.pad !== String.fromCharCode(65 + o.p).repeat(o.pad.length) || seen.has(o.p + ":" + o.i)) torn++; seen.add(o.p + ":" + o.i); if (prev !== -1 && o.p !== prev) switches++; prev = o.p; }
    const lost = Number(nP) * Number(nL) - seen.size;
    rep.push(`size=${size} lines=${lines.length} torn=${torn} lost=${lost} tail=${last?.length} writerSwitches=${switches}`);
    if (torn || lost || last) bad++;
  }
  rmSync(file, { force: true });
  console.log(rep.join("\n")); console.log(bad ? "FAIL (APPEND-ATOMIC broken)" : "PASS (no torn or interleaved line)"); process.exit(bad ? 1 : 0);
})();
