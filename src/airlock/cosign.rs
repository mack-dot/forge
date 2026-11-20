//! Cosign through the system OpenSSH (`/usr/bin/ssh-keygen -Y verify`). NATIVE CHECK, not proved. Owner decision of
//! the Apex addendum: no Node and no V8 in the cosign path. The system OpenSSH (with its LibreSSL) is a TRUSTED
//! ASSUMPTION; it is smaller than Node and widely reviewed, but it is not zero (PROTOCOL.md sections 7 and 11).
//! The engine checks natively, before ssh-keygen runs: the strict base64 of the key and the signature tokens, the
//! SSHSIG form (magic, version 1, key type ssh-ed25519, namespace forge-airlock-cosign, empty reserved field, hash
//! algorithm sha512, an ssh-ed25519 signature of 64 bytes, no trailing byte), an R that is not a small-order or
//! non-canonical encoding, and S < L. The caller compares the embedded key with the pinned key. ssh-keygen then
//! runs with a cleared environment, no shell, the message on stdin, bounded stdout and stderr, a time limit of 30 s,
//! in a private 0700 folder of the store that the engine creates (exclusive), with fixed file names. Valid: exit 0,
//! exactly the "Good" line with the fingerprint of the pinned key, empty stderr. Invalid: exit 255, exactly
//! "Could not verify signature." and exactly "Signature verification failed: incorrect signature". Anything else is
//! HELPER_FAILED: a refusal, never a commit. Before its first use in a process, /usr/bin/ssh-keygen must be a
//! regular file owned by uid 0 with no group or other write bit, and no part of its path may be a symbolic link.
//! Limit: a file swapped after that check is not detected. Its SHA-256 is NOT pinned (an OS update would refuse
//! every store); `cosign-info` prints it so that an operator can record it.
//! Test seams, live ONLY in the `--cfg kill_points` build: AIRLOCK_TEST_SSH_KEYGEN=<path> runs another program in
//! place of /usr/bin/ssh-keygen (the ownership and link checks still apply), AIRLOCK_TEST_UNTRUSTED_SSH_KEYGEN=1
//! skips those checks (for stand-in programs owned by the test user).
use crate::helpers::{run, test_seam};
use crate::pin::{weak_ed25519, Sha256};
use crate::{no, Code, Refusal};
use std::fs::{self, DirBuilder, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::path::Path;
use std::sync::OnceLock;
use std::time::Duration;

pub const SSH_KEYGEN: &str = "/usr/bin/ssh-keygen";
pub const IDENTITY: &str = "forge-airlock-cosigner";
pub const NAMESPACE: &str = "forge-airlock-cosign";
pub const HASH_ALG: &str = "sha512";
pub const MESSAGE_VERSION: &str = "forge-airlock-cosign-v3";
/// base64 of the 51-byte ssh-ed25519 public key blob (string "ssh-ed25519", string of 32 bytes); no padding.
pub const KEY_TOKEN_LEN: usize = 68;
/// base64 of the 190-byte SSHSIG blob of an Ed25519 signature with this namespace and sha512; it ends with "==".
pub const SIG_TOKEN_LEN: usize = 256;
pub const TMP_DIR: &str = "cosign.tmp";
const TIMEOUT: Duration = Duration::from_secs(30);
const KEY_TYPE: &[u8] = b"ssh-ed25519";
const INVALID_OUT: &[u8] = b"Could not verify signature.\n";
const INVALID_ERR: &[u8] = b"Signature verification failed: incorrect signature\r\n";
/// The Ed25519 group order L = 2^252 + 27742317777372353535851937790883648493, little-endian.
const L: [u8; 32] = [
    0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10,
];

const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
fn b64_value(c: u8) -> Option<u32> {
    B64.iter().position(|x| *x == c).map(|v| v as u32)
}
/// Strict base64 (RFC 4648 section 4, standard alphabet): length a multiple of 4, padding only at the end and exactly
/// as long as the data needs, no byte outside the alphabet, and the unused low bits of the last symbol zero (so each
/// byte string has exactly one accepted spelling). None for anything else.
pub fn b64_decode(s: &str) -> Option<Vec<u8>> {
    let b = s.as_bytes();
    if b.len() % 4 != 0 { return None }
    let pad = b.iter().rev().take_while(|c| **c == b'=').count();
    let body = &b[..b.len() - pad];
    let need = match body.len() % 4 { 0 => 0, 2 => 2, 3 => 1, _ => return None };
    if pad != need { return None }
    let (mut out, mut acc, mut bits) = (Vec::with_capacity(b.len() / 4 * 3), 0u32, 0u32);
    for c in body {
        acc = (acc << 6) | b64_value(*c)?;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((acc >> bits) as u8);
            acc &= (1 << bits) - 1;
        }
    }
    if acc != 0 { return None } // non-zero unused bits: a second spelling of the same bytes
    Some(out)
}
pub fn b64_encode(data: &[u8], pad: bool) -> String {
    let mut s = String::with_capacity((data.len() + 2) / 3 * 4);
    for c in data.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        for i in 0..4 {
            if i <= c.len() { s.push(B64[(n >> (18 - 6 * i) & 63) as usize] as char) } else if pad { s.push('=') }
        }
    }
    s
}
fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// Reads SSH wire strings (uint32 big-endian length, then the bytes).
struct Wire<'a>(&'a [u8]);
impl<'a> Wire<'a> {
    fn take(&mut self, n: usize) -> Option<&'a [u8]> {
        if self.0.len() < n { return None }
        let (a, b) = self.0.split_at(n);
        self.0 = b;
        Some(a)
    }
    fn string(&mut self) -> Option<&'a [u8]> {
        let n = u32::from_be_bytes(self.take(4)?.try_into().ok()?) as usize;
        self.take(n)
    }
}
/// The 32 key bytes of an ssh-ed25519 public key blob: exactly string "ssh-ed25519" and a string of 32 bytes.
fn key_blob(blob: &[u8]) -> Option<[u8; 32]> {
    let mut w = Wire(blob);
    if w.string()? != KEY_TYPE { return None }
    let k: [u8; 32] = w.string()?.try_into().ok()?;
    w.0.is_empty().then_some(k)
}
/// `init --cosign-pubkey`: the middle field of an OpenSSH `.pub` line of an Ed25519 key. Strict: 68 characters of
/// canonical base64 that decode to exactly the ssh-ed25519 wire encoding with a 32-byte key.
pub fn parse_key_token(t: &str) -> Option<[u8; 32]> {
    if t.len() != KEY_TOKEN_LEN { return None }
    key_blob(&b64_decode(t)?)
}
/// True for a pinned key token that must be refused: not strict (as above), or weak (pin::weak_ed25519).
pub fn key_token_refused(t: &str) -> bool {
    parse_key_token(t).map_or(true, |k| weak_ed25519(&hex(&k)))
}
/// S >= L: a second encoding of the same signature (ssh-keygen 10.3 accepts S + L; the engine does not).
fn s_not_canonical(s: &[u8]) -> bool {
    for i in (0..32).rev() {
        if s[i] != L[i] { return s[i] > L[i] }
    }
    true
}
/// The signature token of a `REFUND` line: the base64 body of the SSHSIG armor with the line breaks removed (exactly
/// SIG_TOKEN_LEN characters). Ok: the embedded public key. Err: the first part that is not the one accepted form.
pub fn parse_sig_token(t: &str) -> Result<[u8; 32], &'static str> {
    if t.len() != SIG_TOKEN_LEN { return Err("LENGTH") }
    let blob = b64_decode(t).ok_or("BASE64")?;
    let mut w = Wire(&blob);
    if w.take(6) != Some(b"SSHSIG".as_slice()) { return Err("MAGIC") }
    if w.take(4) != Some([0u8, 0, 0, 1].as_slice()) { return Err("VERSION") }
    let key = w.string().and_then(key_blob).ok_or("KEY_TYPE")?;
    if w.string() != Some(NAMESPACE.as_bytes()) { return Err("NAMESPACE") }
    if w.string() != Some(b"".as_slice()) { return Err("RESERVED") }
    if w.string() != Some(HASH_ALG.as_bytes()) { return Err("HASH_ALGORITHM") }
    let mut sig = Wire(w.string().ok_or("SIGNATURE")?);
    if sig.string() != Some(KEY_TYPE) { return Err("SIGNATURE_TYPE") }
    let rs = sig.string().filter(|x| x.len() == 64).ok_or("SIGNATURE_LENGTH")?;
    if !sig.0.is_empty() || !w.0.is_empty() { return Err("TRAILING") }
    if weak_ed25519(&hex(&rs[..32])) { return Err("WEAK_R") }
    if s_not_canonical(&rs[32..]) { return Err("S_NOT_CANONICAL") }
    Ok(key)
}
/// The 32 key bytes of a pinned key token (checked at init and by the fold).
pub fn pinned_key(t: &str) -> Option<[u8; 32]> {
    parse_key_token(t)
}
/// `SHA256:<base64 without padding>` of the key blob, as ssh-keygen prints it.
fn fingerprint(key_token: &str) -> String {
    let mut h = Sha256::new();
    h.update(&b64_decode(key_token).unwrap_or_default());
    format!("SHA256:{}", b64_encode(&h.digest(), false))
}
fn armor(sig_token: &str) -> String {
    let lines: Vec<&str> = sig_token.as_bytes().chunks(70).map(|c| std::str::from_utf8(c).expect("base64 is ASCII")).collect();
    format!("-----BEGIN SSH SIGNATURE-----\n{}\n-----END SSH SIGNATURE-----\n", lines.join("\n"))
}

/// The path parts that binary_checks walks, from the root folder `/` (review F4: `/` is checked too) to the file.
pub fn walk(p: &Path) -> Vec<&Path> {
    let mut parts: Vec<&Path> = p.ancestors().collect();
    parts.reverse();
    parts
}
/// Std-only checks of the program file: every path part exists and is not a symbolic link; the file is regular,
/// owned by uid 0 and has no group or other write bit; each folder on the path (the root folder `/` included) is owned by uid 0 with no group or
/// other write bit.
pub fn binary_checks(path: &str) -> Result<fs::Metadata, String> {
    let p = Path::new(path);
    if !p.is_absolute() { return Err("NOT_ABSOLUTE".into()) }
    let parts = walk(p);
    let mut last = None;
    for (i, part) in parts.iter().enumerate() {
        let m = fs::symlink_metadata(part).map_err(|e| format!("UNREADABLE {} {:?}", part.display(), e.kind()))?;
        if m.file_type().is_symlink() { return Err(format!("SYMLINK {}", part.display())) }
        let file = i + 1 == parts.len();
        if file && !m.file_type().is_file() { return Err("NOT_A_REGULAR_FILE".into()) }
        if !file && !m.file_type().is_dir() { return Err(format!("NOT_A_FOLDER {}", part.display())) }
        if m.uid() != 0 { return Err(format!("NOT_ROOT_OWNED {} uid {}", part.display(), m.uid())) }
        if m.mode() & 0o022 != 0 { return Err(format!("WRITABLE {} mode {:o}", part.display(), m.mode() & 0o7777)) }
        last = Some(m);
    }
    last.ok_or_else(|| "NO_PATH".into())
}
fn program() -> String {
    test_seam("AIRLOCK_TEST_SSH_KEYGEN").unwrap_or_else(|| SSH_KEYGEN.to_string())
}
static PROGRAM_CHECKED: OnceLock<Result<(), String>> = OnceLock::new();
fn trusted(prog: &str) -> Result<(), Refusal> {
    if test_seam("AIRLOCK_TEST_UNTRUSTED_SSH_KEYGEN").as_deref() == Some("1") { return Ok(()) }
    let r = PROGRAM_CHECKED.get_or_init(|| binary_checks(prog).map(|_| ()));
    r.clone().map_err(|why| Refusal(Code::HelperFailed, format!("SSH_KEYGEN_UNTRUSTED {why}")))
}

/// The private folder `<store>/cosign.tmp`. Called with the store lock held, so no other engine uses it at the same
/// time: a leftover (a crash between create and remove) is removed first, then the folder is created exclusively
/// with mode 0700 and checked.
fn private_folder(store_dir: &str) -> Result<String, Refusal> {
    let dir = format!("{store_dir}/{TMP_DIR}");
    let io = |e: std::io::Error| Refusal(Code::HelperFailed, format!("TMP_IO {:?}", e.kind()));
    match fs::symlink_metadata(&dir) {
        Ok(m) if m.file_type().is_dir() => fs::remove_dir_all(&dir).map_err(io)?,
        Ok(_) => fs::remove_file(&dir).map_err(io)?,
        Err(_) => {}
    }
    DirBuilder::new().mode(0o700).create(&dir).map_err(io)?; // exclusive: fails if the path exists
    let m = fs::symlink_metadata(&dir).map_err(io)?;
    if !m.file_type().is_dir() || m.mode() & 0o077 != 0 { return no(Code::HelperFailed, "TMP_NOT_PRIVATE the cosign folder is not a private 0700 folder") }
    Ok(dir)
}
fn write_new(path: &str, text: &str) -> std::io::Result<()> {
    let mut f = OpenOptions::new().write(true).create_new(true).mode(0o600).open(path)?;
    f.write_all(text.as_bytes())
}

/// Ok(true): ssh-keygen verified `message` under the pinned key; Ok(false): ssh-keygen answered exactly "incorrect
/// signature". The caller has checked the token (parse_sig_token) and that its embedded key is the pinned key.
pub fn verify(store_dir: &str, key_token: &str, sig_token: &str, message: &str) -> Result<bool, Refusal> {
    let prog = program();
    trusted(&prog)?;
    let dir = private_folder(store_dir)?;
    let line = format!("{IDENTITY} namespaces=\"{NAMESPACE}\" ssh-ed25519 {key_token}\n");
    let written = write_new(&format!("{dir}/allowed_signers"), &line).and_then(|()| write_new(&format!("{dir}/signature"), &armor(sig_token)));
    let args = ["-Y", "verify", "-f", "allowed_signers", "-I", IDENTITY, "-n", NAMESPACE, "-s", "signature"];
    let good = format!("Good \"{NAMESPACE}\" signature for {IDENTITY} with ED25519 key {}\n", fingerprint(key_token));
    let result = written.map_err(|e| Refusal(Code::HelperFailed, format!("TMP_IO {:?}", e.kind()))).and_then(|()| {
        run(&prog, &args, &[], Some(&dir), message.as_bytes().to_vec(), good.len().max(INVALID_OUT.len()), TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))
    });
    let _ = fs::remove_dir_all(&dir); // a failure here is cleaned at the next verification
    let r = result?;
    let clean = r.err.is_empty() && r.sent;
    match (r.code, clean, r.out.as_slice()) {
        (Some(0), true, o) if o == good.as_bytes() => Ok(true),
        (Some(255), _, o) if o == INVALID_OUT && r.err == INVALID_ERR && r.sent => Ok(false),
        (code, _, _) => no(Code::HelperFailed, format!("HELPER_RESULT ssh-keygen exit {}", code.map_or("signal".to_string(), |c| c.to_string()))),
    }
}

/// `cosign-info`: the facts an operator records about the trusted OpenSSH (one line).
pub fn info() -> Result<String, Refusal> {
    let checks = binary_checks(SSH_KEYGEN);
    let sha = crate::pin::file_sha256(SSH_KEYGEN).map_err(|e| Refusal(Code::HelperFailed, format!("SSH_KEYGEN_UNREADABLE {:?}", e.kind())))?;
    let version = run("/usr/bin/ssh", &["-V"], &[], None, Vec::new(), 0, Duration::from_secs(10)).ok().filter(|r| r.code == Some(0));
    let version = version.map(|r| String::from_utf8_lossy(&r.err).trim().replace(['\r', '\n'], " ")).unwrap_or_else(|| "unknown".into());
    let (uid, mode) = match &checks { Ok(m) => (m.uid().to_string(), format!("{:04o}", m.mode() & 0o7777)), Err(_) => ("-".into(), "-".into()) };
    let state = match checks { Ok(_) => "OK".to_string(), Err(e) => e.replace(' ', "_") };
    let walked: Vec<String> = walk(Path::new(SSH_KEYGEN)).iter().map(|x| x.display().to_string()).collect();
    Ok(format!("COSIGN_INFO path={SSH_KEYGEN} sha256={sha} uid={uid} mode={mode} checks={state} walked={} version={version}", walked.join(":")))
}
