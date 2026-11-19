// child: open (construct) a Sink on argv[2]; print "go" first so the parent can time a SIGKILL; optional init.
import { S0, Sink } from "./lib";
const ids = JSON.parse(process.argv[3]);
process.stdout.write("go\n");
try { const s = new Sink(process.argv[2], { ...ids, initialState: S0 }); if (process.argv[4] === "init") s.init(S0); s.close(); process.stdout.write("opened\n"); process.exit(0); }
catch (e) { process.stdout.write("REFUSED " + String((e as Error).message) + "\n"); process.exit(1); }
