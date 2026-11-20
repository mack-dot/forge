//! Unit tests of `evidence.rs` (worker TESTS, round 2). Ported from the round 1 test root of worker EVIDENCE
//! (30 cases, every case kept, with the negative controls) plus one case from its `driver.rs` (the four-verdict mix
//! with a tool name longer than 32 bytes). FINITE TEST of a NATIVE CHECK; nothing here is proved.
//!
//! The frame code below is a second, independent reading of the format in the doc comment of `evidence.rs`.
//! Only the `pub` surface of `evidence.rs` and `hash.rs` is used.
//!
//! Temporary files: every test makes its own private 0700 folder under `$MCP_TEST_TMP` (or the system temporary
//! folder) and removes it on drop (also when the test panics). Keys come from
//! `/usr/bin/ssh-keygen -t ed25519 -N '' -q -f ...` in such a folder. The one shared base file is made once in its
//! own folder; that folder is removed at once, and the base key is kept only in memory and written again (mode
//! 0600) into the folder of each test that needs it. So the tests are safe under the parallel test runner.
use crate::evidence::{verify_cli, Evidence, Options, Verdict};
use crate::hash;
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::OnceLock;

const MAGIC_LEN: usize = 30;

// ---- private temporary folders
struct Tmp(PathBuf);
impl Drop for Tmp {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
impl Tmp {
    fn p(&self, s: &str) -> PathBuf {
        self.0.join(s)
    }
    /// A 0700 subfolder (for a store).
    fn sub(&self, s: &str) -> PathBuf {
        let d = self.0.join(s);
        std::fs::DirBuilder::new().mode(0o700).create(&d).unwrap();
        d
    }
}

fn tmp(name: &str) -> Tmp {
    static SEQ: AtomicUsize = AtomicUsize::new(0);
    let root = std::env::var_os("MCP_TEST_TMP").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
    std::fs::create_dir_all(&root).unwrap();
    let d = root.join(format!("mcp-ev-unit-{}-{}-{name}", std::process::id(), SEQ.fetch_add(1, Ordering::SeqCst)));
    std::fs::DirBuilder::new().mode(0o700).create(&d).unwrap();
    Tmp(d)
}

fn write_private(p: &Path, bytes: &[u8]) {
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(p).unwrap();
    f.write_all(bytes).unwrap();
}

/// Make an ed25519 key and its allowed-signers file in `t/<name>/`.
fn keypair(t: &Tmp, name: &str) -> (String, String) {
    let d = t.sub(name);
    let k = d.join("k");
    let st = Command::new("/usr/bin/ssh-keygen")
        .args(["-q", "-t", "ed25519", "-N", "", "-C", "test", "-f"])
        .arg(&k)
        .stdin(Stdio::null())
        .status()
        .unwrap();
    assert!(st.success());
    let pubk = std::fs::read_to_string(d.join("k.pub")).unwrap();
    let allowed = d.join("allowed");
    std::fs::write(&allowed, allowed_line(&pubk)).unwrap();
    (k.to_string_lossy().into(), allowed.to_string_lossy().into())
}

fn allowed_line(pubk: &str) -> String {
    let f: Vec<&str> = pubk.split_whitespace().collect();
    format!("forge-airlock namespaces=\"forge-airlock-evidence\" {} {}\n", f[0], f[1])
}

fn gen(dir: &Path, key: &str, n: u64, sync: bool) -> PathBuf {
    gen_from(dir, key, n, sync, 0)
}

fn gen_from(dir: &Path, key: &str, n: u64, sync: bool, e0: u64) -> PathBuf {
    let o = Options { dir, key_path: key, agent_id: "agent-7", sync_sign: sync, test_clock: Some(1_700_000_000_000) };
    let mut ev = Evidence::open(&o).unwrap();
    let mut pre = hash::h16(&[b"genesis"]);
    for i in 0..n {
        let (tool, v) = if i % 3 == 0 { ("issue_payout", Verdict::Committed) } else { ("issue_payout", Verdict::BlockedCas) };
        let post = if v == Verdict::Committed { hash::h16(&[&pre, &i.to_be_bytes()]) } else { pre };
        ev.append(e0 + i + 1, tool, &pre, &post, v).unwrap();
        pre = post;
    }
    ev.finish().unwrap();
    dir.join("evidence.wal")
}

fn verify(wal: &Path, allowed: &str) -> i32 {
    verify_cli(&[wal.to_string_lossy().into(), "--allowed-signers".into(), allowed.into()])
}

// ---- independent frame reader and writer
#[derive(Clone)]
struct F {
    t: u8,
    p: Vec<u8>,
}

fn frames(b: &[u8]) -> Vec<F> {
    let mut v = Vec::new();
    let mut i = MAGIC_LEN;
    while i < b.len() {
        let t = b[i];
        let len = u32::from_be_bytes(b[i + 1..i + 5].try_into().unwrap()) as usize;
        v.push(F { t, p: b[i + 5..i + 5 + len].to_vec() });
        i += 5 + len + 8;
    }
    v
}

fn write_frames(head: &[u8], fs: &[F]) -> Vec<u8> {
    let mut o = head[..MAGIC_LEN].to_vec();
    for f in fs {
        let len = (f.p.len() as u32).to_be_bytes();
        o.push(f.t);
        o.extend_from_slice(&len);
        o.extend_from_slice(&f.p);
        o.extend_from_slice(&hash::sha256(&[b"forge-airlock-evidence-frame-v1", &[f.t], &len, &f.p])[..8]);
    }
    o
}

fn idx(f: &F) -> u64 {
    u64::from_be_bytes(f.p[..8].try_into().unwrap())
}
fn set_idx(f: &mut F, i: u64) {
    f.p[..8].copy_from_slice(&i.to_be_bytes());
}
fn rec_pos(fs: &[F], i: u64) -> usize {
    fs.iter().position(|f| f.t == 1 && idx(f) == i).unwrap()
}
fn sig_pos(fs: &[F], i: u64) -> usize {
    fs.iter().position(|f| f.t == 2 && idx(f) == i).unwrap()
}

fn ssh_sign(key: &str, ns: &str, msg: &[u8]) -> Vec<u8> {
    let mut c = Command::new("/usr/bin/ssh-keygen")
        .args(["-Y", "sign", "-f", key, "-n", ns])
        .env_clear()
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    c.stdin.take().unwrap().write_all(msg).unwrap();
    let o = c.wait_with_output().unwrap();
    assert!(o.status.success());
    o.stdout
}

/// The shared base file: 30 receipts in sync mode, signed by the base key. Kept in memory only.
struct Base {
    bytes: Vec<u8>,
    key: Vec<u8>,
    allowed: String,
}

fn base() -> &'static Base {
    static B: OnceLock<Base> = OnceLock::new();
    B.get_or_init(|| {
        let t = tmp("base");
        let (key, allowed) = keypair(&t, "key");
        let wal = gen(&t.sub("store"), &key, 30, true);
        Base { bytes: std::fs::read(wal).unwrap(), key: std::fs::read(&key).unwrap(), allowed: std::fs::read_to_string(allowed).unwrap() }
        // `t` is dropped here: the folder with the key file is removed.
    })
}

/// Write the base key (0600) and its allowed-signers file into `t`.
fn base_key(t: &Tmp) -> (String, String) {
    let b = base();
    let k = t.p("basekey");
    write_private(&k, &b.key);
    let a = t.p("base_allowed");
    std::fs::write(&a, &b.allowed).unwrap();
    (k.to_string_lossy().into(), a.to_string_lossy().into())
}

fn neg(name: &str, bytes: Vec<u8>) -> i32 {
    let t = tmp(name);
    let (_, allowed) = base_key(&t);
    let p = t.p("evidence.wal");
    std::fs::write(&p, bytes).unwrap();
    let rc = verify(&p, &allowed);
    println!("NEG {name} rc={rc}");
    rc
}

// ---- key checks
fn open_with_key(dir: &Path, key: &str) -> Result<(), String> {
    let o = Options { dir, key_path: key, agent_id: "agent-7", sync_sign: true, test_clock: Some(1) };
    Evidence::open(&o).map(|_| ())
}

#[test]
fn key_ok_0600() {
    let t = tmp("key_ok");
    let (key, _) = base_key(&t);
    assert!(open_with_key(&t.sub("store"), &key).is_ok());
}

#[test]
fn key_refused_0644() {
    let t = tmp("key0644");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let k2 = t.p("k644");
    std::fs::copy(&key, &k2).unwrap();
    std::fs::set_permissions(&k2, std::fs::Permissions::from_mode(0o644)).unwrap();
    let e = open_with_key(&d, k2.to_str().unwrap()).unwrap_err();
    println!("0644: {e}");
    assert!(e.contains("mode"));
    assert!(!d.join("evidence.wal").exists());
}

#[test]
fn key_refused_symlink() {
    let t = tmp("keylink");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let l = t.p("klink");
    std::os::unix::fs::symlink(&key, &l).unwrap();
    let e = open_with_key(&d, l.to_str().unwrap()).unwrap_err();
    println!("symlink: {e}");
    assert!(e.contains("O_NOFOLLOW"));
}

#[test]
fn key_refused_directory() {
    let t = tmp("keydir");
    let d = t.sub("store");
    let kd = t.sub("kdir");
    std::fs::set_permissions(&kd, std::fs::Permissions::from_mode(0o700)).unwrap();
    let e = open_with_key(&d, kd.to_str().unwrap()).unwrap_err();
    println!("dir: {e}");
    assert!(e.contains("not a regular file"));
}

#[test]
fn agent_too_long_refused() {
    let t = tmp("agentlong");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let o = Options { dir: &d, key_path: &key, agent_id: &"a".repeat(33), sync_sign: true, test_clock: Some(1) };
    assert!(Evidence::open(&o).is_err());
}

// ---- positive
#[test]
fn sync_30_verifies() {
    let b = base();
    let t = tmp("sync30");
    let (_, allowed) = base_key(&t);
    let p = t.p("evidence.wal");
    std::fs::write(&p, &b.bytes).unwrap();
    assert_eq!(verify(&p, &allowed), 0);
    // sync layout: R1 S1 R2 S2 ...
    let fs = frames(&b.bytes);
    assert_eq!(fs.len(), 60);
    assert!(fs.iter().enumerate().all(|(i, f)| f.t == if i % 2 == 0 { 1 } else { 2 }));
}

#[test]
fn async_30_verifies() {
    let t = tmp("async30");
    let (key, allowed) = base_key(&t);
    let wal = gen(&t.sub("store"), &key, 30, false);
    assert_eq!(verify(&wal, &allowed), 0);
    let fs = frames(&std::fs::read(&wal).unwrap());
    let order: String = fs.iter().map(|f| if f.t == 1 { 'R' } else { 'S' }).collect();
    println!("async frame order: {order}");
    // Same agent and same test clock: the records and chain equal the sync file.
    let bf = frames(&base().bytes);
    let r1: Vec<&F> = fs.iter().filter(|f| f.t == 1).collect();
    let r2: Vec<&F> = bf.iter().filter(|f| f.t == 1).collect();
    assert_eq!(r1.len(), 30);
    assert!(r1.iter().zip(r2.iter()).all(|(a, b)| a.p == b.p));
}

#[test]
fn reopen_continues_chain() {
    let t = tmp("reopen");
    let (key, allowed) = base_key(&t);
    let d = t.sub("store");
    gen_from(&d, &key, 5, true, 0);
    let wal = gen_from(&d, &key, 5, false, 5);
    assert_eq!(verify(&wal, &allowed), 0);
    assert_eq!(frames(&std::fs::read(&wal).unwrap()).len(), 20);
}

#[test]
fn byte_identical_runs() {
    let t = tmp("ident");
    let (key, _) = base_key(&t);
    let a = std::fs::read(gen(&t.sub("a"), &key, 10, true)).unwrap();
    let b = std::fs::read(gen(&t.sub("b"), &key, 10, true)).unwrap();
    assert_eq!(a, b);
}

#[test]
fn torn_tail_cut_and_unsigned_signed_at_open() {
    let b = base();
    let t = tmp("torn");
    let (key, allowed) = base_key(&t);
    let d = t.sub("store");
    let p = d.join("evidence.wal");
    // Remove the last two signature frames (an async crash), then add half a record frame (a torn write).
    let mut fs = frames(&b.bytes);
    fs.retain(|f| !(f.t == 2 && idx(f) >= 29));
    let mut bytes = write_frames(&b.bytes, &fs);
    let good_len = bytes.len();
    bytes.extend_from_slice(&[1, 0, 0, 0, 153, 9, 9, 9]);
    std::fs::write(&p, &bytes).unwrap();
    std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o600)).unwrap();
    assert_eq!(verify(&p, &allowed), 1, "verifier must refuse torn and unsigned");
    let o = Options { dir: &d, key_path: &key, agent_id: "agent-7", sync_sign: true, test_clock: Some(5) };
    let ev = Evidence::open(&o).unwrap();
    ev.finish().unwrap();
    let after = std::fs::read(&p).unwrap();
    assert!(after.len() > good_len);
    assert_eq!(&after[..good_len], &bytes[..good_len]);
    assert_eq!(verify(&p, &allowed), 0);
}

#[test]
fn open_refuses_damaged_file() {
    let b = base();
    let t = tmp("damaged");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let p = d.join("evidence.wal");
    let mut bytes = b.bytes.clone();
    bytes[MAGIC_LEN + 5 + 20] ^= 1;
    std::fs::write(&p, &bytes).unwrap();
    std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o600)).unwrap();
    let o = Options { dir: &d, key_path: &key, agent_id: "agent-7", sync_sign: true, test_clock: Some(5) };
    assert!(Evidence::open(&o).is_err());
}

#[test]
fn wal_0644_refused_at_open() {
    let b = base();
    let t = tmp("wal644");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let p = d.join("evidence.wal");
    std::fs::write(&p, &b.bytes).unwrap();
    std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o644)).unwrap();
    let o = Options { dir: &d, key_path: &key, agent_id: "agent-7", sync_sign: true, test_clock: Some(5) };
    assert!(Evidence::open(&o).is_err());
}

#[test]
fn blocked_with_post_ne_pre_refused_by_writer() {
    let t = tmp("blockedpost");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let o = Options { dir: &d, key_path: &key, agent_id: "agent-7", sync_sign: true, test_clock: Some(5) };
    let mut ev = Evidence::open(&o).unwrap();
    assert!(ev.append(1, "t", &[1; 16], &[2; 16], Verdict::BlockedCas).is_err());
}

#[test]
fn second_writer_refused() {
    let t = tmp("lock");
    let (key, _) = base_key(&t);
    let d = t.sub("store");
    let o = Options { dir: &d, key_path: &key, agent_id: "agent-7", sync_sign: true, test_clock: Some(5) };
    let _a = Evidence::open(&o).unwrap();
    let e = Evidence::open(&o).err().unwrap();
    assert!(e.contains("locked"));
}

// ---- negative controls (each must give 1)
#[test]
fn neg_record_byte_raw() {
    let mut b = base().bytes.clone();
    b[MAGIC_LEN + 5 + 8 + 40] ^= 0x01; // record 1, agent field, frame check NOT fixed
    assert_eq!(neg("rec_raw", b), 1);
}

#[test]
fn neg_record_byte_fixed_check() {
    let b = &base().bytes;
    let mut fs = frames(b);
    let i = rec_pos(&fs, 7);
    fs[i].p[8 + 112] = 3; // verdict BLOCKED_CAS -> BLOCKED_DUPLICATE (record still well formed)
    assert_eq!(neg("rec_fixed", write_frames(b, &fs)), 1);
}

#[test]
fn neg_record_epoch_fixed_check() {
    let b = &base().bytes;
    let mut fs = frames(b);
    let i = rec_pos(&fs, 12);
    fs[i].p[8 + 7] ^= 0x10;
    assert_eq!(neg("rec_epoch", write_frames(b, &fs)), 1);
}

#[test]
fn neg_chain_byte() {
    let b = &base().bytes;
    let mut fs = frames(b);
    let i = rec_pos(&fs, 9);
    fs[i].p[8 + 113 + 5] ^= 0x80;
    assert_eq!(neg("chain", write_frames(b, &fs)), 1);
}

#[test]
fn neg_signature_byte() {
    let b = &base().bytes;
    let mut fs = frames(b);
    let i = sig_pos(&fs, 11);
    // Change one base64 character in the middle of the armor body (the signature bytes).
    let a = &mut fs[i].p;
    let pos = a.len() - 40;
    a[pos] = if a[pos] == b'A' { b'B' } else { b'A' };
    assert_eq!(neg("sig", write_frames(b, &fs)), 1);
}

#[test]
fn neg_two_records_swapped() {
    let b = &base().bytes;
    let mut fs = frames(b);
    let (r3, r4) = (rec_pos(&fs, 3), rec_pos(&fs, 4));
    let (s3, s4) = (sig_pos(&fs, 3), sig_pos(&fs, 4));
    // Swap record bodies and chain values, and swap the signatures with them; keep the index fields.
    let (p3, p4) = (fs[r3].p[8..].to_vec(), fs[r4].p[8..].to_vec());
    fs[r3].p[8..].copy_from_slice(&p4);
    fs[r4].p[8..].copy_from_slice(&p3);
    let (q3, q4) = (fs[s3].p[8..].to_vec(), fs[s4].p[8..].to_vec());
    fs[s3].p.truncate(8);
    fs[s3].p.extend_from_slice(&q4);
    fs[s4].p.truncate(8);
    fs[s4].p.extend_from_slice(&q3);
    assert_eq!(neg("swap", write_frames(b, &fs)), 1);
}

#[test]
fn neg_middle_record_removed() {
    let b = &base().bytes;
    let mut fs = frames(b);
    fs.retain(|f| idx(f) != 15);
    for f in fs.iter_mut() {
        let i = idx(f);
        if i > 15 {
            set_idx(f, i - 1);
        }
    }
    assert_eq!(neg("remove", write_frames(b, &fs)), 1);
}

#[test]
fn neg_other_key() {
    let b = &base().bytes;
    let t = tmp("otherkey");
    let (k2, _) = keypair(&t, "other");
    let mut fs = frames(b);
    let r = rec_pos(&fs, 10);
    let chain_hex = hash::hex(&fs[r].p[8 + 113..]);
    let s = sig_pos(&fs, 10);
    fs[s].p.truncate(8);
    fs[s].p.extend_from_slice(&ssh_sign(&k2, "forge-airlock-evidence", chain_hex.as_bytes()));
    assert_eq!(neg("otherkey", write_frames(b, &fs)), 1);
}

#[test]
fn neg_wrong_namespace() {
    let b = base();
    let t = tmp("namespace_key");
    let (key, _) = base_key(&t);
    let mut fs = frames(&b.bytes);
    let r = rec_pos(&fs, 10);
    let chain_hex = hash::hex(&fs[r].p[8 + 113..]);
    let s = sig_pos(&fs, 10);
    fs[s].p.truncate(8);
    fs[s].p.extend_from_slice(&ssh_sign(&key, "forge-airlock-other", chain_hex.as_bytes()));
    assert_eq!(neg("namespace", write_frames(&b.bytes, &fs)), 1);
}

#[test]
fn neg_resign_same_key_good_sig_control() {
    // Control for the two tests above: re-signing with the right key and namespace still verifies.
    let b = base();
    let t = tmp("resign_key");
    let (key, _) = base_key(&t);
    let mut fs = frames(&b.bytes);
    let r = rec_pos(&fs, 10);
    let chain_hex = hash::hex(&fs[r].p[8 + 113..]);
    let s = sig_pos(&fs, 10);
    fs[s].p.truncate(8);
    fs[s].p.extend_from_slice(&ssh_sign(&key, "forge-airlock-evidence", chain_hex.as_bytes()));
    assert_eq!(neg("resign_control", write_frames(&b.bytes, &fs)), 0);
}

#[test]
fn neg_unsigned_middle_record() {
    let b = &base().bytes;
    let mut fs = frames(b);
    fs.retain(|f| !(f.t == 2 && idx(f) == 10));
    assert_eq!(neg("unsigned_mid", write_frames(b, &fs)), 1);
}

#[test]
fn neg_unsigned_last_record() {
    let b = &base().bytes;
    let mut fs = frames(b);
    fs.retain(|f| !(f.t == 2 && idx(f) == 30));
    assert_eq!(neg("unsigned_last", write_frames(b, &fs)), 1);
}

#[test]
fn neg_duplicate_signature() {
    let b = &base().bytes;
    let mut fs = frames(b);
    let s = sig_pos(&fs, 30);
    let dup = fs[s].clone();
    fs.push(dup);
    assert_eq!(neg("dup_sig", write_frames(b, &fs)), 1);
}

#[test]
fn empty_and_magic_only_fail() {
    assert_eq!(neg("empty", Vec::new()), 1);
    assert_eq!(neg("magic_only", base().bytes[..MAGIC_LEN].to_vec()), 1);
}

#[test]
fn usage_errors_give_2() {
    assert_eq!(verify_cli(&[]), 2);
    assert_eq!(verify_cli(&["x.wal".into()]), 2);
    assert_eq!(verify_cli(&["x.wal".into(), "--allowed-signers".into()]), 2);
    assert_eq!(verify_cli(&["x.wal".into(), "--bogus".into(), "y".into()]), 2);
}

#[test]
fn limit_trailing_truncation_not_detected() {
    // Documented limit: removing whole trailing records passes. Only the final chain value shows it.
    let b = &base().bytes;
    let mut fs = frames(b);
    fs.retain(|f| idx(f) <= 25);
    assert_eq!(neg("trunc_tail_LIMIT", write_frames(b, &fs)), 0);
}

// ---- from round 1 driver.rs: the four-verdict mix, in both modes
#[test]
fn driver_mix_long_tool_name_both_modes_verify() {
    let t = tmp("drivermix");
    let (key, allowed) = base_key(&t);
    for (mode, sync) in [("sync", true), ("async", false)] {
        let d = t.sub(mode);
        let o = Options { dir: &d, key_path: &key, agent_id: "agent-7", sync_sign: sync, test_clock: Some(1_700_000_000_000) };
        let mut ev = Evidence::open(&o).unwrap();
        let mut pre = hash::h16(&[b"genesis"]);
        for i in 0..12u64 {
            let (tool, v) = match i % 4 {
                0 => ("issue_payout", Verdict::Committed),
                1 => ("issue_payout", Verdict::BlockedCas),
                2 => ("get_patient_chart", Verdict::ReadAllowed),
                _ => ("a_tool_name_that_is_longer_than_32_bytes", Verdict::BlockedMalformed),
            };
            let post = if v == Verdict::Committed { hash::h16(&[&pre, &i.to_be_bytes()]) } else { pre };
            ev.append(i / 4 + 1, tool, &pre, &post, v).unwrap();
            pre = post;
        }
        ev.finish().unwrap();
        let wal = d.join("evidence.wal");
        assert_eq!(verify(&wal, &allowed), 0, "{mode}");
        // The long tool name is stored as the first 32 hex characters of its SHA-256 (documented in evidence.rs).
        let fs = frames(&std::fs::read(&wal).unwrap());
        let r = &fs[rec_pos(&fs, 4)];
        let tool_field = &r.p[8 + 48..8 + 80];
        let want = hash::hex(&hash::sha256(&[b"a_tool_name_that_is_longer_than_32_bytes"]));
        assert_eq!(tool_field, &want.as_bytes()[..32], "{mode}");
        // Negative control on the same file: one verdict byte changed, frame check fixed -> refused.
        let mut fs2 = fs.clone();
        let i = rec_pos(&fs2, 3);
        fs2[i].p[8 + 112] = 7; // READ_ALLOWED -> READ_DROPPED
        let bad = d.join("bad.wal");
        std::fs::write(&bad, write_frames(&std::fs::read(&wal).unwrap(), &fs2)).unwrap();
        assert_eq!(verify(&bad, &allowed), 1, "{mode} control");
    }
}
