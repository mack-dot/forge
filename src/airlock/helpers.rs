//! Private, bounded subprocesses: the CakeML refund binary, the Node booking helper (inventory only) and, through
//! cosign.rs, /usr/bin/ssh-keygen. NATIVE CHECK, not proved.
//! Each run: cleared environment, three anonymous pipes, bounded stdout and stderr, a time limit, SIGKILL at the limit.
//! A helper result counts only as: the exact expected line, the expected exit code, empty stderr (or the exact
//! expected stderr of ssh-keygen), all of stdin written.
//! Anything else (no program, no file, a timeout, other bytes, a signal) is a refusal, never a commit.
//! Pins (R1 of the review): the Node booking helper is compiled INTO the engine (`include_str!`) and runs as
//! `node -e <source> -- <args>`: no helper file is read at run time. The Node binary must have the SHA-256 pinned in
//! the store's genesis record; the refund binary must have REFUND_BINARY_SHA256. Each file is hashed once per
//! process, before its first use. Limit: a file swapped between the hash and the exec is not detected. No Node runs
//! for a cosign (Apex addendum): see cosign.rs.
//! Test seams exist ONLY in the `--cfg kill_points` build: AIRLOCK_TEST_HELPERS=<dir> runs `<dir>/booking_check.cjs`
//! instead of the embedded source, AIRLOCK_TEST_UNPINNED_BINARY=1 skips the refund binary pin, and the two seams of
//! cosign.rs (AIRLOCK_TEST_SSH_KEYGEN, AIRLOCK_TEST_UNTRUSTED_SSH_KEYGEN).
use crate::{no, Code, Refusal};
use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::sync::{mpsc, OnceLock};
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
static BINARY_CHECKED: OnceLock<Result<(), String>> = OnceLock::new();
static NODE_CHECKED: OnceLock<Result<(), String>> = OnceLock::new();
/// Hashes `path` once per process and compares it with `want`. Ok only on equality.
fn pinned(cell: &OnceLock<Result<(), String>>, path: &str, want: &str, what: &str) -> Result<(), Refusal> {
    let r = cell.get_or_init(|| match crate::pin::file_sha256(path) {
        Ok(h) if h == want => Ok(()),
        Ok(_) => Err(format!("PIN_MISMATCH the SHA-256 of the {what} is not the pinned one")),
        Err(e) => Err(format!("PIN_UNREADABLE {what} {:?}", e.kind())),
    });
    r.clone().map_err(|why| Refusal(Code::HelperFailed, why))
}
pub fn test_seam(var: &str) -> Option<String> {
    if cfg!(kill_points) { std::env::var(var).ok() } else { None }
}
/// The CakeML refund binary, as in src/silicon_sink/sink.rs. Ok(true): exactly the accept frame `expect`;
/// Ok(false): exactly the rejection frame; both with exit 0 and empty stderr. Anything else: BAD_FRAME.
pub fn refund_binary(binary: Option<&str>, wire: &str, expect: &str) -> Result<bool, Refusal> {
    let Some(b) = binary else { return failed("NO_REFUND_BINARY".into()) };
    if test_seam("AIRLOCK_TEST_UNPINNED_BINARY").as_deref() != Some("1") {
        pinned(&BINARY_CHECKED, b, REFUND_BINARY_SHA256, "refund binary")?;
    }
    let env = [("CML_HEAP_SIZE", "256"), ("CML_STACK_SIZE", "256")];
    let r = run(b, &[], &env, None, wire.as_bytes().to_vec(), expect.len().max(REJECT_FRAME.len()), BINARY_TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))?;
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
}
/// Ok(true): `yes` + exit 0; Ok(false): `no_` + exit 1; both with empty stderr. Anything else: HELPER_FAILED.
fn node_helper(n: &Node, script: &str, source: &str, args: &[&str], input: Vec<u8>, yes: &[u8], no_: &[u8]) -> Result<bool, Refusal> {
    let Some(node) = n.node else { return failed("NO_NODE".into()) };
    let Some(pin) = n.pin else { return failed("NO_NODE_PIN the store pins no Node binary".into()) };
    pinned(&NODE_CHECKED, node, pin, "Node binary")?;
    let file = test_seam("AIRLOCK_TEST_HELPERS").map(|dir| format!("{dir}/{script}"));
    let mut all: Vec<&str> = match &file { Some(f) => vec![f.as_str()], None => vec!["-e", source, "--"] };
    all.extend_from_slice(args);
    let r = run(node, &all, &[], None, input, yes.len().max(no_.len()), NODE_TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))?;
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
