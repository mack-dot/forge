// Child for fault runs (started under `trap '' XFSZ; ulimit -f N`). ops: init | commit <i> | flush <ledger>
import { fixture, tryOpen, Dispatcher } from "./common15";
(async () => { const fx = await fixture(); const [path, op, arg] = process.argv.slice(2);
  try {
    if (op === "flush") {
      const effects: string[] = [];
      try { const r = new Dispatcher(path, arg, fx.dcfg, (e: any) => { effects.push(e.requestId); process.stdout.write("EFFECT " + e.requestId + "\n"); }).flush();
        console.log("FLUSH " + JSON.stringify({ emitted: r.emitted.map((e: any) => e.requestId), refused: r.refused, already: r.alreadyDispatched }));
      } catch (e) { console.log("FLUSHTHROW " + JSON.stringify({ effects, err: (e as Error).message })); }
      process.exit(0);
    }
    const o = tryOpen(path, fx); if (!o.sink) { console.log("OPENFAIL " + JSON.stringify(o.err)); process.exit(0); }
    if (op === "init") { try { o.sink.init(fx.cfg.initialState); console.log("INIT ok"); } catch (e) { console.log("INIT throw " + JSON.stringify((e as Error).message)); } }
    if (op === "commit") console.log("COMMIT " + JSON.stringify(o.sink.commit(fx.tokens[Number(arg)].text)));
    try { o.sink.close(); } catch (e) { console.log("CLOSE throw " + (e as Error).message); }
  } catch (e) { console.log("CHILDTHROW " + JSON.stringify((e as Error).message)); }
  process.exit(0);
})();
