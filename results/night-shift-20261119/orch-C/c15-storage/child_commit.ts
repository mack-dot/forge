// An honest sink process: opens the store by the given path name and commits the given token indices.
import { fixture, tryOpen } from "./common15";
(async () => { const fx = await fixture(); const [path, ...idx] = process.argv.slice(2);
  const o = tryOpen(path, fx); if (!o.sink) { console.log("OPENFAIL " + o.err); process.exit(3); }
  console.log("OPEN");
  for (const i of idx) console.log("RESULT " + fx.tokens[Number(i)].rid + " " + JSON.stringify(o.sink.commit(fx.tokens[Number(i)].text)));
  o.sink.close(); process.exit(0); })();
