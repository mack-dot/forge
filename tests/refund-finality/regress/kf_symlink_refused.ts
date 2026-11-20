// Regression for OWNER DECISION D-1 (b), task h-key: the key path is a SYMBOLIC LINK to a valid 0600 key -> the minter
// refuses to start (O_NOFOLLOW: ELOOP), and a swap at the path AFTER the open cannot change the key that is read.
// (a) minter.ts <...> <symlink -> valid 0600 key>: exit 2, no ready line.
// (b) CONTROL: the same key by its real path: ready, keyId = the file's key id (a reject-all minter fails here).
// (c) Swap after the open (by construction: one open, every check and the read on that descriptor). Shown through the test
//     seam keyfile.ts loadSigningKeyWith: the fstat hook renames the opened file away and puts a symlink to ANOTHER valid
//     0600 key at the path, then returns the real fstat of the descriptor. The key read must be the FIRST key.
//     A swap BEFORE the open gives (a) (a link) or an ordinary other file that must itself pass every check.
// SAFE = exit 0. On f67c5c16 (no key file): the minter ignores the key path as a key and starts -> FAIL.
import { fstatSync, renameSync, symlinkSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, keyTempDir, load, makeKeyFile, startMinter, verdict } from "./kf_lib";

guard((async () => {
  const { root, core } = argv();
  const { KF } = load(root);
  const dir = keyTempDir(), target = makeKeyFile(), link = join(dir, "link.pem");
  symlinkSync(target.path, link);
  const a = await startMinter(root, core, [link]); a.stop();
  const b = await startMinter(root, core, [target.path]); b.stop();
  const r: any = {
    symlink: { ready: a.ready !== null, code: a.code, eloop: /ELOOP/.test(a.stderr) },
    control: { ready: b.ready !== null, keyIdIsFile: b.ready?.keyId === target.keyId },
  };
  if (KF === null || typeof KF.loadSigningKeyWith !== "function") r.swapAfterOpen = "NOT AVAILABLE (no keyfile.ts)";
  else {
    const first = makeKeyFile(), second = makeKeyFile();
    const got = KF.loadSigningKeyWith(first.path, (fd: number) => {
      renameSync(first.path, first.path + ".moved"); symlinkSync(second.path, first.path);   // the swap, after the open
      return fstatSync(fd);
    });
    r.swapAfterOpen = { readFirstKey: got.keyId === first.keyId, readSecondKey: got.keyId === second.keyId };
    let after = "";
    try { KF.loadSigningKey(first.path); after = "ACCEPTED"; } catch (e) { after = String((e as Error).message).includes("ELOOP") ? "refused (ELOOP)" : "refused"; }
    r.swapAfterOpen.nextOpenOfTheLink = after;
  }
  verdict(!r.symlink.ready && r.symlink.code === 2 && r.symlink.eloop && r.control.ready && r.control.keyIdIsFile &&
    typeof r.swapAfterOpen === "object" && r.swapAfterOpen.readFirstKey && r.swapAfterOpen.nextOpenOfTheLink === "refused (ELOOP)", r);
})());
