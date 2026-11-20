// Regression for OWNER DECISION D-1 (b), task h-key: a key file that gives access to group or other is refused.
// Modes 0640 (group-readable), 0644 (world-readable), 0604, 0620: the minter exits 2 with no ready line.
// CONTROL: modes 0600 and 0400 start (a reject-all minter fails here). SAFE = exit 0.
// On f67c5c16 (no key file): the minter does not read the key path as a key and starts -> FAIL.
import { argv, guard, makeKeyFile, startMinter, verdict } from "./kf_lib";

guard((async () => {
  const { root, core } = argv();
  const r: Record<string, any> = {};
  let pass = true;
  for (const mode of [0o640, 0o644, 0o604, 0o620]) {
    const k = makeKeyFile(mode), m = await startMinter(root, core, [k.path]); m.stop();
    const ok = m.ready === null && m.code === 2 && /group or other/.test(m.stderr);
    r["0" + mode.toString(8)] = { ready: m.ready !== null, code: m.code, refused: ok };
    pass &&= ok;
  }
  for (const mode of [0o600, 0o400]) {
    const k = makeKeyFile(mode), m = await startMinter(root, core, [k.path]); m.stop();
    const ok = m.ready !== null && m.ready.keyId === k.keyId;
    r["0" + mode.toString(8) + " (control)"] = { ready: m.ready !== null, keyIdIsFile: ok };
    pass &&= ok;
  }
  verdict(pass, r);
})());
