// Regression for OWNER DECISION D-1 (b), task h-key: a key file owned by ANOTHER uid is refused.
// A test without privileges cannot create a file of another uid (chown needs root). So the fstat result is INJECTED
// through the test seam keyfile.ts loadSigningKeyWith(path, fstat): a parameter of an exported function that only code
// which imports the module can pass. No command-line argument and no environment variable reaches it; minter.ts calls
// only loadSigningKey(path) (checked below on the source text). The seam replaces st_uid by euid + 1 on the REAL stat of
// the opened descriptor. CONTROL: the same seam with the true stat accepts (the seam alone does not refuse).
// SAFE = exit 0. On f67c5c16: no keyfile.ts -> FAIL.
import { fstatSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, load, makeKeyFile, verdict } from "./kf_lib";

guard((() => {
  const { root } = argv();
  const { KF } = load(root);
  if (KF === null || typeof KF.loadSigningKeyWith !== "function") verdict(false, { otherUid: "NOT AVAILABLE (no keyfile.ts)" });
  const k = makeKeyFile();
  const as = (uidDelta: number) => (fd: number) => { const s = fstatSync(fd); return { isFile: () => s.isFile(), uid: s.uid + uidDelta, mode: s.mode, size: s.size }; };
  let other = "", control = "";
  try { KF.loadSigningKeyWith(k.path, as(1)); other = "ACCEPTED"; } catch (e) { other = String((e as Error).message); }
  try { control = KF.loadSigningKeyWith(k.path, as(0)).keyId === k.keyId ? "accepted, same key id" : "OTHER KEY"; } catch (e) { control = "REFUSED: " + String((e as Error).message); }
  const pure = KF.keyFileProblem({ isFile: () => true, uid: 0, mode: 0o100600, size: 100 }, 501);
  const minterSrc = readFileSync(join(root, "ts/refund-finality/minter.ts"), "utf8");
  const seamUnreachable = !minterSrc.includes("loadSigningKeyWith") && minterSrc.includes("loadSigningKey(keyPath");
  const r = { otherUid: other, control, pureCheckUid0vs501: pure, seamUnreachableFromMinter: seamUnreachable };
  verdict(/not owned by the effective uid/.test(other) && control === "accepted, same key id" && /effective uid/.test(String(pure)) && seamUnreachable, r);
})());
