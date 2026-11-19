// c7-minter P4 (checker identity gap): checkerSha256Of (encoding.ts:84) hashes only the core module file, encoding.ts
// and minter.ts. It does NOT bind bignumber.js or any other dependency the minter actually loads, nor the resolution
// path (NODE_PATH / require cache). An untrusted host that chooses the minter's NODE_PATH can load a DIFFERENT
// bignumber.js (arbitrary in-process code) while the minter still reports the PINNED checkerSha256. The core module
// file passed here is byte-identical to the pinned one, so the pin is unchanged.
// This probe uses a BENIGN shim that only drops a marker and passes all arithmetic through. Exit 1 = the minter
// reports the pinned checkerSha256 AND attacker code ran in its process; 0 = either the pin changed or no code ran.
import { spawn } from "node:child_process";
import { existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { pinnedChecker, ROOT, SPEC_LOCK } from "./raw";
const SHADOW = join(__dirname, "shadow");
const CORE = join(SHADOW, "issuebytes2.cjs");                 // byte-identical copy of the pinned core
const MARKER = join(SHADOW, "ran_in_process.marker");
const GENUINE = "<REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs";
(async () => {
  if (existsSync(MARKER)) rmSync(MARKER);
  const pinned = pinnedChecker(GENUINE);                      // identity computed against the GENUINE deployment core
  const child = spawn(process.execPath, ["--import", "tsx", join(ROOT, "ts/refund-finality/minter.ts"), CORE, SPEC_LOCK, "off"],
    { cwd: ROOT, stdio: ["pipe", "pipe", "inherit"],
      env: { PATH: process.env.PATH, HOME: process.env.HOME, LANG: "C",
        NODE_PATH: SHADOW + "/node_modules:<REPO>/node_modules" } });
  let ready: any = null, buf = "";
  child.stdout.on("data", d => { buf += d; const i = buf.indexOf("\n"); if (i >= 0 && !ready) ready = JSON.parse(buf.slice(0, i)); });
  const end = Date.now() + 30000; while (!ready && Date.now() < end) await new Promise(r => setTimeout(r, 100));
  child.stdin.end(); child.kill();
  const ran = existsSync(MARKER);
  const out = { pinned, reportedChecker: ready?.checkerSha256, pinMatches: ready?.checkerSha256 === pinned,
    attackerCodeRan: ran, marker: ran ? readFileSync(MARKER, "utf8") : null };
  console.log(JSON.stringify(out));
  process.exit(out.pinMatches && ran ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
