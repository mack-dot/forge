//! Private, bounded subprocesses: the CakeML refund binary and the two Node helpers. NATIVE CHECK, not proved.
//! Each run: cleared environment, three anonymous pipes, bounded stdout and stderr, a time limit, SIGKILL at the limit.
//! A helper result counts only as: the exact expected line, exit code 0, empty stderr, all of stdin written.
//! Anything else (no program, no file, a timeout, other bytes, a signal) is a refusal, never a commit.
use crate::{no, Code, Refusal};
use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

pub const REJECT_FRAME: &[u8] = b"(refund-result-v1 False 0 \"\" \"\" \"\" 0)";
const BINARY_TIMEOUT: Duration = Duration::from_secs(10);
const NODE_TIMEOUT: Duration = Duration::from_secs(30);

pub struct Run {
    pub code: Option<i32>, // None after a signal
    pub out: Vec<u8>,
    pub err: Vec<u8>,
    pub sent: bool,
}
pub fn run(prog: &str, args: &[&str], env: &[(&str, &str)], input: Vec<u8>, out_limit: usize, timeout: Duration) -> Result<Run, String> {
    let mut child = Command::new(prog)
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
/// The CakeML refund binary, as in src/silicon_sink/sink.rs. Ok(true): exactly the accept frame `expect`;
/// Ok(false): exactly the rejection frame; both with exit 0 and empty stderr. Anything else: BAD_FRAME.
pub fn refund_binary(binary: Option<&str>, wire: &str, expect: &str) -> Result<bool, Refusal> {
    let Some(b) = binary else { return failed("NO_REFUND_BINARY".into()) };
    let env = [("CML_HEAP_SIZE", "256"), ("CML_STACK_SIZE", "256")];
    let r = run(b, &[], &env, wire.as_bytes().to_vec(), expect.len().max(REJECT_FRAME.len()), BINARY_TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))?;
    let clean = r.code == Some(0) && r.err.is_empty() && r.sent;
    match (clean, r.out.as_slice()) {
        (true, o) if o == expect.as_bytes() => Ok(true),
        (true, REJECT_FRAME) => Ok(false),
        _ => no(Code::BadFrame, "BAD_FRAME the binary gave no exact decision frame"),
    }
}
pub struct Node<'a> {
    pub node: Option<&'a str>,
    pub helpers: Option<&'a str>,
    pub checker: Option<&'a str>,
}
/// Ok(true): `yes` + exit 0; Ok(false): `no_` + exit 1; both with empty stderr. Anything else: HELPER_FAILED.
fn node_helper(n: &Node, script: &str, args: &[&str], input: Vec<u8>, yes: &[u8], no_: &[u8]) -> Result<bool, Refusal> {
    let (Some(node), Some(dir)) = (n.node, n.helpers) else { return failed("NO_NODE_OR_HELPERS".into()) };
    let path = format!("{dir}/{script}");
    let mut all = vec![path.as_str()];
    all.extend_from_slice(args);
    let r = run(node, &all, &[], input, yes.len().max(no_.len()), NODE_TIMEOUT).map_err(|e| Refusal(Code::HelperFailed, e))?;
    match (r.code, r.err.is_empty() && r.sent, r.out.as_slice()) {
        (Some(0), true, o) if o == yes => Ok(true),
        (Some(1), true, o) if o == no_ => Ok(false),
        (code, _, _) => failed(format!("HELPER_RESULT {script} exit {}", code.map_or("signal".to_string(), |c| c.to_string()))),
    }
}
/// `node cosign.cjs verify <pubkey> <sig>` with the message on stdin.
pub fn cosign_verify(n: &Node, pubkey: &str, sig: &str, message: &str) -> Result<bool, Refusal> {
    node_helper(n, "cosign.cjs", &["verify", pubkey, sig], message.as_bytes().to_vec(), b"VALID\n", b"INVALID\n")
}
/// `node booking_check.cjs <model.cjs>` with the certificate JSON on stdin.
pub fn booking_check(n: &Node, json: &str) -> Result<bool, Refusal> {
    let Some(model) = n.checker else { return failed("NO_CHECKER_MODEL".into()) };
    node_helper(n, "booking_check.cjs", &[model], json.as_bytes().to_vec(), b"ACCEPT\n", b"REJECT\n")
}
