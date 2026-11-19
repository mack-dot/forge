// c11-host H4: MinterClient.start (216dfbe2) passes the caller's whole environment to the key-holding minter.
// The caller sets NODE_OPTIONS=--require <probe>; exit 1 if the probe ran inside the minter while the minter
// reported its usual ready line (checkerSha256 unchanged), 0 otherwise.
import { existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
const [root, corePath, probe, mark] = process.argv.slice(2);
const { MinterClient } = require(join(__dirname, "lib/proposer216.ts"));
(async () => {
  rmSync(mark, { force: true });
  const plain = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off"); const id0 = plain.ready.checkerSha256; plain.stop();
  process.env.NODE_OPTIONS = "--require " + probe; process.env.C11_MARK = mark;
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off"); const id1 = m.ready.checkerSha256; m.stop();
  const ran = existsSync(mark) ? readFileSync(mark, "utf8").trim() : "";
  process.stdout.write(JSON.stringify({ sameChecker: id0 === id1, probe: ran }) + "\n");
  process.exit(ran.length > 0 && id0 === id1 ? 1 : 0);
})().catch(e => { process.stderr.write(String(e) + "\n"); process.exit(3); });
