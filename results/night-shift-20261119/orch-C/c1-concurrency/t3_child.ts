// child: one Sink (own process, own connection) on argv[2]; per stdin line {token, at}: wait until wall time `at`, commit, answer.
import { createInterface } from "node:readline";
import { S0, Sink } from "./lib";
const ids = JSON.parse(process.argv[3]);
const sink = new Sink(process.argv[2], { ...ids, initialState: S0 });
process.stdout.write(JSON.stringify({ ready: true }) + "\n");
createInterface({ input: process.stdin }).on("line", line => {
  const { token, at } = JSON.parse(line);
  while (Date.now() < at);
  const r = sink.commit(token);
  process.stdout.write(JSON.stringify({ r, reaudits: sink.reaudits }) + "\n");
});
