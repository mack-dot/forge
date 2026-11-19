# KEY_DESIGN: the persistent minter key and the key-id allowlist (OWNER DECISION D-1, task h-key)

Status: TESTED-UNPROVED. No Dafny file changed. Base: nightshift/B-trust 219bf0ca (h-key-rebased.diff).

## 1. Open-and-check sequence (ts/refund-finality/keyfile.ts, the only code that opens a key file)
1. `open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)`. No stat, lstat, access or exists on the path before it.
   - O_NOFOLLOW: a symbolic link as the LAST component fails with ELOOP. The descriptor never names a link target.
   - O_NONBLOCK: an open of a FIFO for reading returns at once (no wait for a writer). Step 2 then refuses it.
   - O_RDONLY: the minter never writes the key. libuv adds O_CLOEXEC (no leak to child processes).
2. `fstat(fd)` on the OPENED descriptor: S_ISREG; `st_uid == geteuid()`; `(st_mode & 0o077) == 0`; size <= 4096.
   The checked object is the object that step 3 reads. A rename or a swap at the path after step 1 does not change it.
3. Read from the SAME fd (sequential, bounded), close it, parse an unencrypted PKCS#8 PEM, require Ed25519, zero the
   byte buffer (best effort: Node keeps its own copy inside the KeyObject).
O_NONBLOCK is NOT cleared (Node has no fcntl); it has no effect on read(2) of a regular file. No key from an environment
variable, no bypass flag, no key made in memory. Errors never print key bytes.
Test seam: `loadSigningKeyWith(path, fstat)` replaces the stat result (other-uid test only). minter.ts calls only
`loadSigningKey(path)`; no argument or environment variable reaches the seam.
## 2. Launch
minter.ts `<core> <spec lock> <on|off> <key file> [<store> [<mint memory file>]]`; ready line adds `keyId`.
minter-launch.sh `<built dir> <pin> <spec lock> on <key file> <store> <mint memory file>`: it resolves the directory
part only, never stats or reads the key; the key is not in the built directory or its MANIFEST.sha256.
Note: the checker id covers core, encoding.ts, minter.ts only (not keyfile.ts, mintmemory.ts); the closed launch's
manifest covers them inside the minter.cjs bundle.
## 3. key_id and the signed bytes (glue step KEYID-GLUE, UNPROVED)
key_id = lower-case hex SHA-256 of the DER SubjectPublicKeyInfo bytes of the Ed25519 public key (44 bytes).
Token = `{"body":<body>,"keyId":"<64 hex>","signature":"<base64>"}` (canonical, sorted keys).
Signed bytes = canon({body, keyId, sigDomain: "FORGE_REFUND_FINALITY_KEYID_V1"}): the proved body bytes VERBATIM inside.
The Dafny byte model (IssueBytes2/SerModel `SignedBytes`, IssueAuth) is unchanged: it now describes the BODY bytes. The
envelope that adds keyId is TypeScript (encoding.ts signedBytes; minter.ts builds it from the returned bytes and
checks it equals signedBytes). KEYID-GLUE = "the Ed25519 message is '{"body":' ++ proved bytes ++ ',"keyId":..,"sigDomain":..}'".
An old signature (over the body alone) never verifies: its bytes start with '{"checkerSha256"'.
## 4. Allowlist format and status rule (core/store.ts keyRingOf, keyRefusal, sigOkOf)
`issuerKeys: [{keyId, publicKeyPem, status: "active"} | {keyId, publicKeyPem, status: "retired", verifyUpToSeq: n}]`,
1..64 entries; keyId must equal keyIdOf(publicKeyPem); ids unique; Ed25519 only. Otherwise sink and dispatcher refuse to start.
Old config `{publicKeyPem}` alone = one ACTIVE key (existing callers keep working). Both given: publicKeyPem must be entry 0.
Entry 0 = GENESIS key: h_0 binds its PEM text (genesisOf unchanged), so `{publicKeyPem: A}` and `[A, ...]` give the same h_0.
- NEW commit (Sink.commit): keyId pinned AND active, and the signature verifies under that key.
- STORED row at seq (start-up audit, foreign-change audit, repair prefix, dispatcher row check): keyId pinned AND
  (active OR retired with seq <= verifyUpToSeq), and the signature verifies under that key.
- Unknown keyId, retired keyId for a new commit, keyId A with a signature of B: refused ("signature does not verify";
  the reason text is unchanged so existing judges keep matching; keyRefusal gives the precise reason).
## 5. Rotation (operator steps)
1. Make key B (ceremony NOT covered here); write it as a 0600 file owned by the minter's uid.
2. Append `{keyId: B, publicKeyPem: B, status: "active"}` to the sink's AND the dispatcher's issuerKeys (never edit entry 0).
3. Stop the minter. Read the sink's committed head count N. Restart the minter with B's key file.
4. Change A's entry to `{status: "retired", verifyUpToSeq: N}` in sink and dispatcher configs; restart them.
   Rows 1..N signed by A still verify; any new or later row of A is refused.
5. Keep A's entry for ever (entry 0 binds h_0; old rows need it). Delete A's key file.

## 6. Attacker classes
(i) Another uid, no write access to the key directory: cannot read a 0600 file. Cannot make the minter use a file it
    owns (uid check), a group/world-readable file (mode check), a FIFO or a directory (S_ISREG), or a symlink at the
    last component (O_NOFOLLOW). Cannot forge tokens without the key (Ed25519, assumed).
(ii) The SAME uid: OUT OF SCOPE. No claim. It can read the key file, ptrace the minter, edit the configs.
(iii) Write access to the key directory (another uid): can delete or rename the key (minter refuses to start:
    denial of service only); can put its own file there (refused: uid), a symlink (refused: ELOOP), or a hard link to a
    file of the minter's uid (passes the checks: only a file that is already a 0600 key of that uid can be named; if
    that is a RETIRED key, the sink refuses its new tokens). A symlink in a DIRECTORY component is followed (not
    excluded): it can only reach files that then pass every check.

## 7. Assumptions (named)
KEY-FILE-SECRET: only the minter's uid can read the key file; it is not in backups, logs or other copies.
SAME-UID: no hostile process runs as the minter's uid (out of scope).
ALLOWLIST-PINNED: the sink's and dispatcher's issuerKeys come from configuration that the attacker cannot change.
KEYID-GLUE: section 3 (TypeScript, tested, not proved). Also assumed: Ed25519, SHA-256, OpenSSL, Node, the kernel's
O_NOFOLLOW and fstat semantics (macOS and Linux).

## 8. What carries one token and one effect per request id
- ONE TOKEN (issuer, production "on" + store): the durable mint memory (mintmemory.ts): one fsynced line per minted
  token, written before the answer, loaded at start as the memory of the proved IssueAuth.Issue call; same file
  checks as the key; torn last line cut, other damage refuses the start. ASSUMPTION MEMORY-FILE-INTACT: an operator
  who deletes or restores an old memory file gets the second-token case back (kf_restart_one_token (b)); then only
  the sink's rule holds. ASSUMPTION MEMORY-FILE-DURABLE: fsync without F_FULLFSYNC on macOS.
- ONE EFFECT (sink): the settled row per request id and the pre-state check (one commit per request id).
- Row swap after commit: the dispatcher's outside head (cfg.expectedHead). No claim beyond these three.

## 9. NOT covered
Key generation ceremony, backup and recovery of the key file, hardware keys (HSM, Secure Enclave), revocation
of an UNKNOWN leak (rotation needs the operator to act), migration of stores that hold old-format rows (they are
refused at start: section 4 of the report), encrypted key files, Windows.
