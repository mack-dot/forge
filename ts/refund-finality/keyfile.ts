// OWNER DECISION D-1 (night shift 2026-11-19, task h-key): the ONLY place that opens the issuer's signing key file.
// TESTED-UNPROVED. The minter's key comes only from a key file: no environment variable, no test bypass flag, no key
// made in memory. Design and attacker classes: orch-B/h-key/KEY_DESIGN.md.
// The sequence (no stat, lstat, access or exists on the path before the open: that check-then-use race is what D-1 removes):
//   1. open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK). O_NOFOLLOW: a symbolic link as the LAST path component fails
//      the open (ELOOP), so the descriptor never names the target of a link. O_NONBLOCK: an open of a FIFO returns at
//      once (no wait for a writer); step 2 then refuses it. libuv adds O_CLOEXEC.
//   2. fstat(fd) on the OPENED descriptor: a regular file; st_uid == geteuid(); (st_mode & 0o077) == 0; size bounded.
//      The checked object IS the object that step 3 reads: a rename or a swap at the path after step 1 does not change
//      what fd names.
//   3. read the bytes from the SAME fd (sequential reads at the file offset, bounded), close fd, parse a PKCS#8 PEM
//      Ed25519 private key, overwrite the byte buffer with zeros.
// O_NONBLOCK is NOT cleared after step 2: Node has no fcntl. For a regular file (the only kind that passes step 2)
// O_NONBLOCK has no effect on read(2) (POSIX: it changes the behaviour of pipes, FIFOs and devices only).
// Error texts never hold key bytes.
import { createPrivateKey, createPublicKey, KeyObject } from "node:crypto";
import { closeSync, constants, fstatSync, openSync, readSync } from "node:fs";
import { keyIdOf } from "./encoding";

export const MAX_KEY_FILE_BYTES = 4096;
export type KeyFileStat = { isFile(): boolean; uid: number; mode: number; size: number };
export type SigningKey = { privateKey: KeyObject; publicKeyPem: string; keyId: string };

// The check of step 2, on the stat of the OPENED descriptor. null = accepted; else the reason.
export function keyFileProblem(st: KeyFileStat, euid: number, what = "the key file", maxBytes = MAX_KEY_FILE_BYTES): string | null {
  if (!st.isFile()) return what + " is not a regular file";
  if (st.uid !== euid) return what + " is not owned by the effective uid";
  if ((st.mode & 0o077) !== 0) return what + " gives access to group or other (mode " + (st.mode & 0o777).toString(8) + "; need 600 or 400)";
  if (st.size > maxBytes) return what + " is larger than " + maxBytes + " bytes";
  return null;
}
// The same open-and-check sequence for another private file (the durable mint memory, mintmemory.ts): open with
// O_NOFOLLOW | O_NONBLOCK and `flags`, then fstat THAT descriptor (regular, uid == euid, no group/other bits, size bound).
// Returns the open descriptor; the caller reads and writes through it only. No path check before the open.
export function openPrivateFile(path: string, flags: number, what: string, maxBytes: number): number {
  if (typeof path !== "string" || path === "" || path.includes("\u0000")) throw new Error(what + ": no usable path");
  const euid = typeof process.geteuid === "function" ? process.geteuid() : undefined;
  if (euid === undefined) throw new Error(what + ": this platform has no effective uid");
  let fd: number;
  try { fd = openSync(path, flags | constants.O_NOFOLLOW | constants.O_NONBLOCK); } catch (error) {
    const code = String((error as NodeJS.ErrnoException)?.code ?? "error");
    throw new Error(what + ": open refused (" + code + (code === "ELOOP" ? ": the path is a symbolic link" : "") + ")");
  }
  try {
    const problem = keyFileProblem(fstatSync(fd), euid, what, maxBytes);
    if (problem !== null) throw new Error(what + ": " + problem);
  } catch (error) { closeSync(fd); throw error; }
  return fd;
}

// Production entry point (the minter calls only this).
export function loadSigningKey(path: string): SigningKey {
  return loadSigningKeyWith(path, fd => fstatSync(fd));
}

// TEST SEAM: `fstat` replaces the stat of the opened descriptor. Only a test that imports this module can pass it; no
// command-line argument and no environment variable reaches it. It exists so that a test can show the refusal of a
// file owned by another uid without privileges. It cannot widen what production accepts: production passes fstatSync.
export function loadSigningKeyWith(path: string, fstat: (fd: number) => KeyFileStat): SigningKey {
  if (typeof path !== "string" || path === "" || path.includes("\u0000")) throw new Error("key file: no usable path");
  const euid = typeof process.geteuid === "function" ? process.geteuid() : undefined;
  if (euid === undefined) throw new Error("key file: this platform has no effective uid");
  let fd: number;
  try {
    fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  } catch (error) {
    const code = String((error as NodeJS.ErrnoException)?.code ?? "error");
    throw new Error("key file: open refused (" + code + (code === "ELOOP" ? ": the path is a symbolic link" : "") + ")");
  }
  let buf: Buffer | null = null;
  try {
    const problem = keyFileProblem(fstat(fd), euid);
    if (problem !== null) throw new Error("key file: " + problem);
    buf = Buffer.alloc(MAX_KEY_FILE_BYTES + 1);
    let n = 0;
    for (;;) {
      const got = readSync(fd, buf, n, buf.length - n, null);
      if (got === 0) break;
      n += got;
      if (n > MAX_KEY_FILE_BYTES) throw new Error("key file: larger than " + MAX_KEY_FILE_BYTES + " bytes");
    }
    let privateKey: KeyObject;
    try { privateKey = createPrivateKey({ key: buf.subarray(0, n), format: "pem" }); } catch {
      throw new Error("key file: not an unencrypted PKCS#8 PEM private key");
    }
    if (privateKey.asymmetricKeyType !== "ed25519") throw new Error("key file: not an Ed25519 key");
    const publicKey = createPublicKey(privateKey);
    return { privateKey, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, keyId: keyIdOf(publicKey) };
  } finally {
    if (buf !== null) buf.fill(0);
    closeSync(fd);
  }
}
