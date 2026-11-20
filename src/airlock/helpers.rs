//! Private, bounded subprocesses: the CakeML refund binary, the Node booking helper (inventory only) and, through
//! cosign.rs, /usr/bin/ssh-keygen. NATIVE CHECK, not proved.
//! Each run: cleared environment, three anonymous pipes, bounded stdout and stderr, a time limit, SIGKILL at the limit.
//! A helper result counts only as: the exact expected line, the expected exit code, empty stderr (or the exact
//! expected stderr of ssh-keygen), all of stdin written.
//! Anything else (no program, no file, a timeout, other bytes, a signal) is a refusal, never a commit.
//! Pins (R1 of the review): the Node booking helper is compiled INTO the engine (`include_str!`) and runs as
//! `node -e <source> -- <args>`: no helper file is read at run time. The Node binary must have the SHA-256 pinned in
//! the store's genesis record; the refund binary must have REFUND_BINARY_SHA256. No Node runs for a cosign (Apex
//! addendum): see cosign.rs.
//! Pin window (review D2). Before: each file was hashed once per process and later runs exec'd the same PATH, so a
//! file changed after the first use in a long `serve` process was not seen. Now, at EVERY exec: the path is resolved
//! once (`canonicalize`), the resolved path must pass cosign::path_checks with Owners::RootOrUid(engine uid) (no
//! symbolic link, every part owned by root or by the engine's own uid, no group or other write bit except on a
//! root-owned sticky folder), and the RESOLVED path is the one run. The refund binary (238,776 bytes) is hashed again
//! at every exec. The Node binary (about 89 MB; one SHA-256 of it took about 0.5 s of CPU here) is hashed at its
//! first use and again whenever its identity (device, inode, size, mtime, ctime with nanoseconds) differs from the
//! hashed one; the identity is read at every exec. macOS has no fexecve, and exec of /dev/fd/N gave EACCES here
//! (proposals/review-20261120-engine/logs/d2-fdexec.log), so the file is still run by path: a change between the last
//! check and the exec is possible for whoever may write the file or a folder on its path. With the checks above that
//! is root or the engine's own uid. In the one-user flow the engine's uid IS the caller's uid, so these checks close
//! nothing against that caller; they matter when `serve` runs as another user (PROTOCOL.md section 11).
//! Test seams exist ONLY in the `--cfg kill_points` build: AIRLOCK_TEST_HELPERS=<dir> runs `<dir>/booking_check.cjs`
//! instead of the embedded source, AIRLOCK_TEST_UNPINNED_BINARY=1 skips the refund binary pin, and the two seams of
//! cosign.rs (AIRLOCK_TEST_SSH_KEYGEN, AIRLOCK_TEST_UNTRUSTED_SSH_KEYGEN).
use crate::cosign::{path_checks, private_folder, Owners};
use crate::{no, Code, Refusal};
use std::fs;
use std::io::{Read, Write};
use std::os::unix::fs::MetadataExt;
use std::process::{Command, Stdio};
use std::sync::{mpsc, Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

pub const REJECT_FRAME: &[u8] = b"(refund-result-v1 False 0 \"\" \"\" \"\" 0)";
pub const REFUND_BINARY_SHA256: &str = "b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8";
const BOOKING_SOURCE: &str = include_str!("node/booking_check.cjs");
const BINARY_TIMEOUT: Duration = Duration::from_secs(10);
const NODE_TIMEOUT: Duration = Duration::from_secs(30);

pub struct Run {
    pub code: Option<i32>, // None after a signal
    pub out: Vec<u8>,
    pub err: Vec<u8>,
    pub sent: bool,
}
pub fn run(prog: &str, args: &[&str], env: &[(&str, &str)], cwd: Option<&str>, input: Vec<u8>, out_limit: usize, timeout: Duration) -> Result<Run, String> {
    let mut command = Command::new(prog);
    if let Some(dir) = cwd {
        command.current_dir(dir);
    }
    let mut child = command
        .args(args)
        .env_clear()
        .envs(env.iter().copied())
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("SPAWN_FAILED {:?}", e.kind()))?;
    let (tx, rx) = mpsc::channel::<(usize, Vec<u8>)>();
    let (mut sin, so, se) = (child.stdin.take().expect("piped"), child.stdout.take().expect("piped"), child.stderr.take().expect("piped"));
    let t0 = tx.clone();
    thread::spawn(move || {
        let ok = sin.write_all(&input).is_ok();
        drop(sin); // EOF for the child
        let _ = t0.send((0, vec![ok as u8]));
    });
    let t1 = tx.clone();
    thread::spawn(move || {
        let mut v = Vec::new();
        let _ = so.take(out_limit as u64 + 1).read_to_end(&mut v);
        let _ = t1.send((1, v));
    });
    thread::spawn(move || {
        let mut v = Vec::new();
        let _ = se.take(4096).read_to_end(&mut v);
        let _ = tx.send((2, v));
    });
    let deadline = Instant::now() + timeout;
    let mut got: [Option<Vec<u8>>; 3] = [None, None, None];
    while got.iter().any(Option::is_none) {
        match rx.recv_timeout(deadline.saturating_duration_since(Instant::now())) {
            Ok((i, v)) => got[i] = Some(v),
            Err(_) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err("TIMEOUT".into());
            }
        }
    }
    let status = loop {
        if let Some(s) = child.try_wait().map_err(|_| "WAIT_FAILED".to_string())? { break s }
        if Instant::now() > deadline {
            let _ = child.kill();
            let _ = child.wait();
            return Err("TIMEOUT".into());
        }
        thread::sleep(Duration::from_millis(1));
    };
    let [s, o, e] = got;
    Ok(Run { code: status.code(), out: o.unwrap_or_default(), err: e.unwrap_or_default(), sent: s == Some(vec![1]) })
}
fn failed<T>(why: String) -> Result<T, Refusal> {
    no(Code::HelperFailed, why)
}
/// The engine's effective uid: the owner of a private folder that the engine creates in the store folder (under the
/// store lock; cosign::private_folder), read once per process. std has no geteuid and `unsafe` is forbidden. uid 99
/// (`_unknown`: a volume that ignores ownership shows every file as 99) is never trusted: then only root counts.
static OWN_UID: OnceLock<Option<u32>> = OnceLock::new();
fn own_uid(store: &str) -> Option<u32> {
    *OWN_UID.get_or_init(|| {
        let dir = private_folder(store).ok()?;
        let uid = fs::symlink_metadata(&dir).ok().map(|m| m.uid());
        let _ = fs::remove_dir_all(&dir);
        uid.filter(|u| *u != 99)
    })
}
/// The identity of a file: device, inode, size, mtime and ctime (with nanoseconds). ctime cannot be set by a caller.
type Identity = (u64, u64, u64, i64, i64, i64, i64);
fn identity(m: &fs::Metadata) -> Identity {
    (m.dev(), m.ino(), m.size(), m.mtime(), m.mtime_nsec(), m.ctime(), m.ctime_nsec())
}
/// The resolved path and identity of the Node binary whose SHA-256 last matched the pin (review D2).
static NODE_SEEN: Mutex<Option<(String, Identity)>> = Mutex::new(None);
/// Review D2: the checks of a pinned helper file, at every exec. Ok: the RESOLVED path, to be run. `seen`: None = hash
/// at every call (the refund binary); Some = hash only when the resolved path or the identity changed (Node).
fn pinned(path: &str, store: &str, want: &str, what: &str, seen: Option<&Mutex<Option<(String, Identity)>>>) -> Result<String, Refusal> {
    let fail = |why: String| Refusal(Code::HelperFailed, why);
    let real = fs::canonicalize(path).map_err(|e| fail(format!("PIN_UNREADABLE {what} {:?}", e.kind())))?;
    let real = real.to_str().ok_or_else(|| fail(format!("PIN_PATH_UNTRUSTED {what} NOT_UTF8")))?.to_string();
    let owners = own_uid(store).map_or(Owners::Root, Owners::RootOrUid);
    let id = identity(&path_checks(&real, owners).map_err(|why| fail(format!("PIN_PATH_UNTRUSTED {what} {why}")))?);
    if let Some(cell) = seen {
        if cell.lock().map_or(false, |g| g.as_ref() == Some(&(real.clone(), id))) { return Ok(real) }
    }
    let h = crate::pin::file_sha256(&real).map_err(|e| fail(format!("PIN_UNREADABLE {what} {:?}", e.kind())))?;
    if h != want { return Err(fail(format!("PIN_MISMATCH the SHA-256 of the {what} is not the pinned one"))) }
    let after = fs::symlink_metadata(&real).map(|m| identity(&m)).map_err(|e| fail(format!("PIN_UNREADABLE {what} {:?}", e.kind())))?;
    if after != id { return Err(fail(format!("PIN_MISMATCH the {what} changed while it was hashed"))) }
    if let Some(cell) = seen {
        if let Ok(mut g) = cell.lock() { *g = Some((real.clone(), id)) }
    }
    Ok(real)
}
pub fn test_seam(var: &str) -> Option<String> {
    if cfg!(kill_points) { std::env::var(var).ok() } else { None }
}
/// The CakeML refund binary, as in src/silicon_sink/sink.rs. Ok(true): exactly the accept frame `expect`;
/// Ok(false): exactly the rejection frame; both with exit 0 and empty stderr. Anything else: BAD_FRAME.
pub fn refund_binary(binary: Option<&str>, store: &str, wire: &str, expect: &str) -> Result<bool, Refusal> {
    let Some(b) = binary else { return failed("NO_REFUND_BINARY".into()) };
    let mut prog = b.to_string();
    if test_seam("AIRLOCK_TEST_UNPINNED_BINARY").as_deref() != Some("1") {
        prog = pinned(b, store, REFUND_BINARY_SHA256, "refund binary", None)?;
    }
    let env = [("CML_HEAP_SIZE", "256"), ("CML_STACK_SIZE", "256")];
    let r = run(&prog, &[], &env, None, wire.as_bytes().to_vec(), expect.len().max(REJECT_FRAME.len()), BINARY_TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))?;
    let clean = r.code == Some(0) && r.err.is_empty() && r.sent;
    match (clean, r.out.as_slice()) {
        (true, o) if o == expect.as_bytes() => Ok(true),
        (true, REJECT_FRAME) => Ok(false),
        _ => no(Code::BadFrame, "BAD_FRAME the binary gave no exact decision frame"),
    }
}
pub struct Node<'a> {
    pub node: Option<&'a str>,
    pub pin: Option<&'a str>,
    pub checker: Option<&'a str>,
    pub store: &'a str,
}
/// Ok(true): `yes` + exit 0; Ok(false): `no_` + exit 1; both with empty stderr. Anything else: HELPER_FAILED.
fn node_helper(n: &Node, script: &str, source: &str, args: &[&str], input: Vec<u8>, yes: &[u8], no_: &[u8]) -> Result<bool, Refusal> {
    let Some(node) = n.node else { return failed("NO_NODE".into()) };
    let Some(pin) = n.pin else { return failed("NO_NODE_PIN the store pins no Node binary".into()) };
    let node = pinned(node, n.store, pin, "Node binary", Some(&NODE_SEEN))?;
    let file = test_seam("AIRLOCK_TEST_HELPERS").map(|dir| format!("{dir}/{script}"));
    let mut all: Vec<&str> = match &file { Some(f) => vec![f.as_str()], None => vec!["-e", source, "--"] };
    all.extend_from_slice(args);
    let r = run(&node, &all, &[], None, input, yes.len().max(no_.len()), NODE_TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))?;
    match (r.code, r.err.is_empty() && r.sent, r.out.as_slice()) {
        (Some(0), true, o) if o == yes => Ok(true),
        (Some(1), true, o) if o == no_ => Ok(false),
        (code, _, _) => failed(format!("HELPER_RESULT {script} exit {}", code.map_or("signal".to_string(), |c| c.to_string()))),
    }
}
/// `booking_check.cjs <model.cjs>` (embedded) with the certificate JSON on stdin. The helper pins the model's SHA-256.
pub fn booking_check(n: &Node, json: &str) -> Result<bool, Refusal> {
    let Some(model) = n.checker else { return failed("NO_CHECKER_MODEL".into()) };
    node_helper(n, "booking_check.cjs", BOOKING_SOURCE, &[model], json.as_bytes().to_vec(), b"ACCEPT\n", b"REJECT\n")
}
