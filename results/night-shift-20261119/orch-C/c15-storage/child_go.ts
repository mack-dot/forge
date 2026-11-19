// An honest sink process: opens by the given name, prints OPEN, waits for one stdin byte, commits token index, prints RESULT.
import { fixture, tryOpen } from "./common15";
(async () => { const fx = await fixture(); const [path, i] = process.argv.slice(2);
  const o = tryOpen(path, fx); if (!o.sink) { console.log("OPENFAIL " + o.err); process.exit(3); }
  process.stdout.write("OPEN\n");
  process.stdin.once("data", () => { const t0 = process.hrtime.bigint(); const r = o.sink.commit(fx.tokens[Number(i)].text);
    process.stdout.write("RESULT " + JSON.stringify(r) + " us=" + (process.hrtime.bigint() - t0) / 1000n + "\n"); o.sink.close(); process.exit(0); });
})();
