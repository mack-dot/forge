'use strict';
// cosign.cjs: Ed25519 cosign for the forge-airlock REQUIRE_HUMAN_COSIGN verdict (Goal 20, owner decision 2).
//
// Usage:
//   node cosign.cjs verify <public-key-hex> <signature-hex>   message on stdin
//        "VALID\n" exit 0; "INVALID\n" exit 1; anything malformed: exit 2 (message on stderr, nothing on stdout).
//   node cosign.cjs keygen <new-key-file>                     the HUMAN's tool
//        creates the file (O_CREAT|O_EXCL|O_NOFOLLOW, mode 0600), writes an unencrypted PKCS#8 PEM Ed25519 private
//        key, fsyncs the file and its folder, prints the public key as 64 lowercase hex + "\n". Never overwrites.
//   node cosign.cjs sign <key-file>                           the HUMAN's tool; message on stdin
//        prints the decoded message fields to stderr, then the signature as 128 lowercase hex + "\n" on stdout.
//
// Label: NATIVE CHECK, not proved. Trusted: Node 24.3.0 node:crypto (OpenSSL Ed25519), the kernel's O_NOFOLLOW,
// O_EXCL and fstat semantics, and this code. Node built-ins only.
//
// Public key hex = the raw 32-byte Ed25519 public key (the last 32 bytes of the SPKI DER). Signature hex = the raw
// 64-byte Ed25519 signature. Hex: lowercase only, exact length.
// Malleability: this tool claims nothing beyond what node:crypto (OpenSSL) verify does. It does not add checks.
//
// Message (DESIGN.md "Cosign"), at most 4096 bytes, exactly five LF-terminated lines:
//   forge-airlock-cosign-v1\n<store_id>\n<request_id>\n<pre_state_hash>\n<action>\n
//   store_id   [A-Za-z0-9_-]{1,64}   request_id [A-Za-z0-9_-]{1,24}   pre_state_hash [0-9a-f]{32}
//   action     1 or more bytes in 0x20..0x7e (printable ASCII, no line end)
// Both sign and verify refuse (exit 2) any other message. No field can hold a line end, so no boundary can move.
//
// Key file rules (owner decision D-1; proposals/night-shift-20261119/orch-B/h-key/KEY_DESIGN.md section 1):
//   1. open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK). No stat or lstat on the path before it. A symbolic link as
//      the last path part fails (ELOOP). A FIFO opens at once (no hang) and step 2 refuses it.
//   2. fstat on the OPENED descriptor: regular file; st_uid == geteuid(); (st_mode & 0o077) == 0; size 1..4096.
//   3. Read from the same descriptor only. Parse an unencrypted PKCS#8 PEM; require Ed25519.
//   D-1 has no link-count rule: a hard link to a checked key file is accepted (as in KEY_DESIGN.md section 6).
//   A symbolic link in a PARENT folder is followed (only the last path part is checked).
//
// HONEST LIMIT: an agent that runs as the same OS user as the key owner can read a 0600 file. This tool cannot
// prevent that. "The agent cannot self-cosign" holds only when the private key is outside the agent's reach
// (another OS user, a hardware key, or a separate machine). Errors never print key bytes.

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const MAX_MESSAGE = 4096;
const MAX_KEY_FILE = 4096;
const SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');
const PUB_RE = /^[0-9a-f]{64}$/;
const SIG_RE = /^[0-9a-f]{128}$/;
const PREFIX = 'forge-airlock-cosign-v1';
const STORE_RE = /^[A-Za-z0-9_-]{1,64}$/;
const ID_RE = /^[A-Za-z0-9_-]{1,24}$/;
const HASH_RE = /^[0-9a-f]{32}$/;
const ACTION_RE = /^[\x20-\x7e]+$/;
const PEM_HEAD = '-----BEGIN PRIVATE KEY-----\n';

let finished = false;

function finish(code, out, err) {
  if (finished) return;
  finished = true;
  try {
    if (err) fs.writeSync(2, 'cosign: ' + err + '\n');
    if (out) fs.writeSync(1, out);
  } catch (e) {
    code = 2;
  }
  process.exit(code);
}

function fail(message) {
  finish(2, null, message);
}

// Returns the fields, or throws. The bytes must be exactly the DESIGN.md form.
function parseMessage(buf) {
  if (buf.length > MAX_MESSAGE) throw new Error('message is larger than ' + MAX_MESSAGE + ' bytes');
  for (const b of buf) if (b !== 0x0a && (b < 0x20 || b > 0x7e)) throw new Error('message has a byte outside printable ASCII and LF');
  const text = buf.toString('latin1');
  if (!text.endsWith('\n')) throw new Error('message does not end with LF');
  const lines = text.slice(0, -1).split('\n');
  if (lines.length !== 5) throw new Error('message has ' + lines.length + ' lines, expected 5');
  const [prefix, storeId, requestId, preStateHash, action] = lines;
  if (prefix !== PREFIX) throw new Error('message prefix line is not ' + PREFIX);
  if (!STORE_RE.test(storeId)) throw new Error('store_id is not [A-Za-z0-9_-]{1,64}');
  if (!ID_RE.test(requestId)) throw new Error('request_id is not [A-Za-z0-9_-]{1,24}');
  if (!HASH_RE.test(preStateHash)) throw new Error('pre_state_hash is not 32 lowercase hex');
  if (!ACTION_RE.test(action)) throw new Error('action is empty or not printable ASCII');
  return { storeId, requestId, preStateHash, action };
}

// D-1 step 2 on a stat of the OPENED descriptor. Exported for the other-uid test only (no CLI or environment path).
function checkKeyStat(st, euid) {
  if (!st.isFile()) throw new Error('key file is not a regular file');
  if (st.uid !== euid) throw new Error('key file owner uid ' + st.uid + ' is not the effective uid ' + euid);
  if ((st.mode & 0o077) !== 0) throw new Error('key file mode ' + (st.mode & 0o777).toString(8) + ' has group or other bits');
  if (st.size < 1 || st.size > MAX_KEY_FILE) throw new Error('key file size ' + st.size + ' is not in 1..' + MAX_KEY_FILE);
}

function loadPrivateKey(file) {
  const fd = fs.openSync(file, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK);
  let bytes;
  try {
    const st = fs.fstatSync(fd);
    checkKeyStat(st, process.geteuid());
    bytes = Buffer.alloc(st.size);
    let got = 0;
    while (got < st.size) {
      const r = fs.readSync(fd, bytes, got, st.size - got, got);
      if (r === 0) throw new Error('key file became shorter while read');
      got += r;
    }
  } finally {
    fs.closeSync(fd);
  }
  try {
    const text = bytes.toString('latin1');
    if (!text.startsWith(PEM_HEAD)) throw new Error('not an unencrypted PKCS#8 PEM');
    const key = crypto.createPrivateKey({ key: text, format: 'pem' });
    if (key.asymmetricKeyType !== 'ed25519') throw new Error('not an Ed25519 key');
    return key;
  } catch (e) {
    throw new Error('key file content refused (not an unencrypted PKCS#8 PEM Ed25519 private key)');
  } finally {
    bytes.fill(0);
  }
}

function rawPublicHex(publicKey) {
  const der = publicKey.export({ format: 'der', type: 'spki' });
  if (der.length !== 44 || !der.subarray(0, 12).equals(SPKI_PREFIX)) throw new Error('unexpected SPKI encoding');
  return der.subarray(12).toString('hex');
}

function readStdin(done) {
  const chunks = [];
  let size = 0;
  process.stdin.on('data', (chunk) => {
    if (finished) return;
    size += chunk.length;
    if (size > MAX_MESSAGE) {
      process.stdin.destroy();
      return fail('message is larger than ' + MAX_MESSAGE + ' bytes');
    }
    chunks.push(chunk);
  });
  process.stdin.on('error', (e) => fail('stdin: ' + (e && e.message)));
  process.stdin.on('end', () => {
    if (finished) return;
    try {
      done(Buffer.concat(chunks));
    } catch (e) {
      fail(e && e.message);
    }
  });
}

function cmdVerify(args) {
  if (args.length !== 2) return fail('usage: cosign.cjs verify <public-key-hex(64)> <signature-hex(128)>');
  const [pubHex, sigHex] = args;
  if (!PUB_RE.test(pubHex)) return fail('public key is not 64 lowercase hex');
  if (!SIG_RE.test(sigHex)) return fail('signature is not 128 lowercase hex');
  let publicKey;
  try {
    publicKey = crypto.createPublicKey({ key: Buffer.concat([SPKI_PREFIX, Buffer.from(pubHex, 'hex')]), format: 'der', type: 'spki' });
  } catch (e) {
    return fail('public key refused by node:crypto');
  }
  readStdin((msg) => {
    parseMessage(msg);
    const ok = crypto.verify(null, msg, publicKey, Buffer.from(sigHex, 'hex'));
    if (ok === true) return finish(0, 'VALID\n', null);
    if (ok === false) return finish(1, 'INVALID\n', null);
    fail('no decision');
  });
}

function cmdKeygen(args) {
  if (args.length !== 1) return fail('usage: cosign.cjs keygen <new-key-file>');
  const file = path.resolve(args[0]);
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const pubHex = rawPublicHex(publicKey);
  const pem = privateKey.export({ format: 'pem', type: 'pkcs8' });
  let fd;
  try {
    fd = fs.openSync(file, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW, 0o600);
  } catch (e) {
    return fail('cannot create ' + JSON.stringify(args[0]) + ' (' + (e && e.code) + '); keygen never overwrites');
  }
  try {
    const st = fs.fstatSync(fd);
    if (!st.isFile() || (st.mode & 0o077) !== 0) throw new Error('created file is not a regular 0600 file');
    fs.writeFileSync(fd, pem);
    fs.fsyncSync(fd);
  } catch (e) {
    try { fs.closeSync(fd); } catch (_) {}
    return fail('write failed (' + (e && e.message) + '); remove the partial file ' + JSON.stringify(args[0]) + ' by hand');
  }
  fs.closeSync(fd);
  try {
    const dfd = fs.openSync(path.dirname(file), fs.constants.O_RDONLY);
    try { fs.fsyncSync(dfd); } finally { fs.closeSync(dfd); }
  } catch (e) {
    return fail('the key file is written, but the folder sync failed (' + (e && e.code) + ')');
  }
  finish(0, pubHex + '\n', null);
}

function cmdSign(args) {
  if (args.length !== 1) return fail('usage: cosign.cjs sign <key-file>');
  let key;
  try {
    key = loadPrivateKey(args[0]);
  } catch (e) {
    return fail('key file refused: ' + (e && (e.code || e.message)));
  }
  readStdin((msg) => {
    const f = parseMessage(msg);
    fs.writeSync(2, 'cosign: you sign:\n  store_id       ' + f.storeId + '\n  request_id     ' + f.requestId +
      '\n  pre_state_hash ' + f.preStateHash + '\n  action         ' + f.action + '\n');
    const sig = crypto.sign(null, msg, key);
    if (sig.length !== 64) return fail('unexpected signature length');
    finish(0, sig.toString('hex') + '\n', null);
  });
}

function main() {
  process.on('uncaughtException', (e) => fail('exception: ' + (e && e.message)));
  const [cmd, ...args] = process.argv.slice(2);
  if (cmd === 'verify') return cmdVerify(args);
  if (cmd === 'keygen') return cmdKeygen(args);
  if (cmd === 'sign') return cmdSign(args);
  fail('usage: cosign.cjs verify|keygen|sign ...');
}

if (require.main === module) main();
module.exports = { checkKeyStat, parseMessage };
