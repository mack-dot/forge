import { fixture } from "./common15";
fixture().then(f => { console.log("tokens", f.tokens.map(t => t.rid + ":" + t.amount).join(" ")); process.exit(0); });
