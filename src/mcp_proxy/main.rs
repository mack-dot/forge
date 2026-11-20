//! `mcp-proxy`: the Forge MCP stdio airlock (Archia demo). NATIVE CHECK and FINITE TEST, not proved.
//! Standard library only. Command line:
//!   mcp-proxy mcp --policy P.json --agent-id ID --store DIR --key KEYFILE [--facts F.json]
//!             [--session k=v]... [--sign-mode sync|async] [--test-clock N] -- <server-cmd> [args...]
//!   mcp-proxy verify-evidence <evidence.wal> --allowed-signers FILE [options of evidence.rs]
//!   mcp-proxy state DIR
//! Exit codes: 2 = usage error; 1 = start-up fault (also: ledger.wal and evidence.wal disagree); `mcp` otherwise
//! exits with the upstream server's exit code, except 1 after a receipt fault, an evidence finish fault or a reader
//! thread panic (whatever the upstream code was).
#![forbid(unsafe_code)]
#![allow(dead_code)]
#[path = "../airlock/json.rs"]
mod json;
#[path = "../airlock/pin.rs"]
mod pin;
mod evidence;
mod hash;
mod jsonw;
mod ledger;
mod policy;
#[cfg(test)]
mod evidence_tests;
#[cfg(test)]
mod policy_tests;
mod proxy;

use std::path::Path;

const USAGE: &str = "usage:
  mcp-proxy mcp --policy P.json --agent-id ID --store DIR --key KEYFILE [--facts F.json]
            [--session k=v]... [--sign-mode sync|async] [--test-clock N] -- <server-cmd> [args...]
  mcp-proxy verify-evidence <evidence.wal> --allowed-signers FILE [options]
  mcp-proxy state DIR";

fn usage(msg: &str) -> i32 {
    eprintln!("mcp-proxy: {msg}\n{USAGE}");
    2
}

fn main() {
    let mut args = Vec::new();
    for a in std::env::args_os() {
        match a.into_string() {
            Ok(s) => args.push(s),
            Err(_) => std::process::exit(usage("an argument is not valid UTF-8")),
        }
    }
    std::process::exit(run(&args));
}

fn run(args: &[String]) -> i32 {
    match args.get(1).map(String::as_str) {
        Some("mcp") => mcp(&args[2..]),
        Some("verify-evidence") => evidence::verify_cli(&args[2..]),
        Some("state") => state(&args[2..]),
        Some(c) => usage(&format!("unknown command {c:?}")),
        None => usage("no command"),
    }
}

fn state(a: &[String]) -> i32 {
    if a.len() != 1 {
        return usage("state needs exactly one argument: DIR");
    }
    // Read-only replay: no lock and no write, so it works while a proxy runs on the same store.
    match ledger::read_head(Path::new(&a[0])) {
        Ok((e, h)) => {
            println!("epoch={e} state={}", hash::hex(&h));
            0
        }
        Err(e) => {
            eprintln!("mcp-proxy: state: cannot read the ledger in {:?}: {e}", a[0]);
            1
        }
    }
}

#[derive(Debug, Default, PartialEq)]
struct McpArgs {
    policy: String,
    agent_id: String,
    store: String,
    key: String,
    facts: Option<String>,
    session: Vec<(String, String)>,
    sync_sign: bool,
    test_clock: Option<u64>,
    server: Vec<String>,
}

/// Parse the options of `mcp`. Every option except `--session` may appear at most once.
fn parse_mcp(a: &[String]) -> Result<McpArgs, String> {
    let mut o = McpArgs { sync_sign: true, ..Default::default() };
    let (mut policy, mut agent, mut store, mut key, mut sign) = (None, None, None, None, None);
    let mut i = 0;
    while i < a.len() {
        let flag = a[i].as_str();
        if flag == "--" {
            o.server = a[i + 1..].to_vec();
            break;
        }
        let val = a.get(i + 1).ok_or_else(|| format!("{flag} needs a value"))?.clone();
        let set = |slot: &mut Option<String>| -> Result<(), String> {
            if slot.is_some() {
                return Err(format!("{flag} given twice"));
            }
            *slot = Some(val.clone());
            Ok(())
        };
        match flag {
            "--policy" => set(&mut policy)?,
            "--agent-id" => set(&mut agent)?,
            "--store" => set(&mut store)?,
            "--key" => set(&mut key)?,
            "--facts" => set(&mut o.facts)?,
            "--sign-mode" => set(&mut sign)?,
            "--session" => {
                let (k, v) = val.split_once('=').ok_or("--session needs key=value")?;
                if k.is_empty() {
                    return Err("--session needs a non-empty key".into());
                }
                if o.session.iter().any(|(x, _)| x == k) {
                    return Err(format!("--session key {k:?} given twice"));
                }
                o.session.push((k.to_string(), v.to_string()));
            }
            "--test-clock" => {
                if o.test_clock.is_some() {
                    return Err("--test-clock given twice".into());
                }
                o.test_clock = Some(val.parse::<u64>().map_err(|_| "--test-clock needs an unsigned integer")?);
            }
            _ => return Err(format!("unknown option {flag:?}")),
        }
        i += 2;
    }
    if o.server.is_empty() {
        return Err("give the upstream server command after --".into());
    }
    o.policy = policy.ok_or("--policy is required")?;
    o.agent_id = agent.ok_or("--agent-id is required")?;
    o.store = store.ok_or("--store is required")?;
    o.key = key.ok_or("--key is required")?;
    o.sync_sign = match sign.as_deref() {
        None | Some("sync") => true,
        Some("async") => false,
        Some(m) => return Err(format!("--sign-mode must be sync or async, not {m:?}")),
    };
    Ok(o)
}

fn mcp(a: &[String]) -> i32 {
    let o = match parse_mcp(a) {
        Ok(o) => o,
        Err(e) => return usage(&e),
    };
    let policy = match policy::load(&o.policy, o.facts.as_deref(), &o.session) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("mcp-proxy: policy: {e}");
            return 1;
        }
    };
    let dir = Path::new(&o.store);
    let ledger = match ledger::Ledger::open(dir) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("mcp-proxy: ledger: {e}");
            return 1;
        }
    };
    let opts = evidence::Options { dir, key_path: &o.key, agent_id: &o.agent_id, sync_sign: o.sync_sign, test_clock: o.test_clock };
    let mut ev = match evidence::Evidence::open(&opts) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("mcp-proxy: evidence: {e}");
            return 1;
        }
    };
    // The two logs must agree before any message is read (finding R2; PROTOCOL.md section 7).
    if let Err(e) = proxy::reconcile(&ledger, &mut ev) {
        eprintln!("mcp-proxy: start refused: {e}");
        let _ = ev.finish();
        return 1;
    }
    proxy::run(policy, ledger, ev, &o.server)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn s(v: &[&str]) -> Vec<String> {
        v.iter().map(|x| x.to_string()).collect()
    }
    #[test]
    fn parse_ok() {
        let o = parse_mcp(&s(&["--policy", "p", "--agent-id", "a", "--store", "d", "--key", "k", "--session", "clinic_id=Clinic_Alpha", "--session", "x=a=b", "--sign-mode", "async", "--test-clock", "7", "--", "python3", "-u", "s.py"])).unwrap();
        assert_eq!(o.session, vec![("clinic_id".into(), "Clinic_Alpha".into()), ("x".into(), "a=b".into())]);
        assert!(!o.sync_sign);
        assert_eq!(o.test_clock, Some(7));
        assert_eq!(o.server, s(&["python3", "-u", "s.py"]));
        assert_eq!(o.facts, None);
    }
    #[test]
    fn parse_errors() {
        let base = ["--policy", "p", "--agent-id", "a", "--store", "d", "--key", "k"];
        let mut bad: Vec<Vec<&str>> = vec![base.to_vec()]; // no server
        bad.push([&base[..], &["--policy", "q", "--", "x"]].concat());
        bad.push([&base[..], &["--sign-mode", "maybe", "--", "x"]].concat());
        bad.push([&base[..], &["--session", "noeq", "--", "x"]].concat());
        bad.push([&base[..], &["--session", "=v", "--", "x"]].concat());
        bad.push([&base[..], &["--test-clock", "-1", "--", "x"]].concat());
        bad.push([&base[..], &["--bogus", "1", "--", "x"]].concat());
        bad.push([&base[..], &["--"]].concat());
        bad.push(vec!["--policy", "p", "--", "x"]);
        bad.push([&base[..], &["--facts"]].concat());
        for b in bad {
            assert!(parse_mcp(&s(&b)).is_err(), "{b:?}");
        }
        assert_eq!(run(&s(&["mcp-proxy"])), 2);
        assert_eq!(run(&s(&["mcp-proxy", "nope"])), 2);
        assert_eq!(run(&s(&["mcp-proxy", "state"])), 2);
        assert_eq!(run(&s(&["mcp-proxy", "mcp", "--policy"])), 2);
    }
}
