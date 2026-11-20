//! Primitive 6, `rate_window`: a true sliding window per (tenant, key), with a cooldown lockout. NATIVE CHECK, not
//! proved. A pure module (prim.rs): no I/O, no clock read. The time is the engine's `Now` (clock.rs) in `decide`
//! and the record time in `fold`.
//!
//! Policy (all values JSON strings of canonical decimals):
//!   {"primitive": "rate_window", "version": 1, "name": "<id>", "max_ops_per_window": "1..65536",
//!    "max_volume_per_window": "0..18446744073709551615", "window_ms": "1..18446744073709551615",
//!    "cooldown_after": "0..1024" (0 = no cooldown), "cooldown_ms": "0..18446744073709551615" (>= 1 if cooldown_after > 0)}
//!
//! Op `acquire`: `DO rate_window acquire <request_id> <tenant> 1 <key> <hash or *> <policy> <volume>`.
//!
//! Window: an event at time t counts at time `now` while `now < t + window_ms` (it stops counting AT t + window_ms;
//! if t + window_ms overflows u64 it never stops counting). The state of a key holds the EXACT list of its events
//! (time, volume) that may still count: at each record the fold drops every event with t + window_ms <= record time;
//! engine time never goes back (clock.rs), so a dropped event can never count again. A commit needs live ops + 1 <=
//! max_ops, so the list never holds more than max_ops_per_window events. No bucket, no estimate: the list is exact.
//!
//! Decision for `acquire(v)` at `now`, first match wins:
//! 1. `v > max_volume_per_window`: `VOLUME_ABOVE_CAP` (it can never fit). No record.
//! 2. A cooldown is active (`now < cooldown_until`): `COOLDOWN_ACTIVE retry_after_ms=<cooldown_until - now>`. No
//!    record: the cooldown is already durable, so the WAL does not grow while it lasts.
//! 3. It fits (`live_ops + 1 <= max_ops` and `live_volume + v <= max_volume`, sums in u128): commit, record `A <v>`.
//! 4. Else `RATE_LIMIT_EXCEEDED retry_after_ms=<n>`. n is the LEAST wait after which the same request commits, given
//!    the state that this refusal leaves. Window part w: the k oldest live events must stop counting, where k is the
//!    least number that frees one op AND enough volume; w = t_k + window_ms - now (`never` if that sum overflows).
//!    With `cooldown_after > 0` the refusal changes state (the consecutive-rejection count), so it is a durable
//!    record `X <v>` (it uses the request id up); the N-th consecutive one starts the cooldown
//!    (`cooldown_until = now + cooldown_ms`, checked; an overflow gives u64::MAX). When THIS refusal starts the
//!    cooldown, n = max(w, cooldown_until - now): a retry before the cooldown end would get COOLDOWN_ACTIVE (review
//!    finding M1: before the repair n was w alone, and with cooldown_ms > window_ms the retry at the stated time was
//!    refused). Otherwise n = w. A commit resets the count. With `cooldown_after = 0` the refusal changes nothing
//!    and writes nothing. `COOLDOWN_ACTIVE retry_after_ms` (rule 2) is the rest of the cooldown only: the window can
//!    still be full at that time.
//!
//! Limit (review finding M2, not repaired): the caller picks the key and the `<tenant>` field is not authenticated,
//! so a fresh key (or another tenant name) has its own empty window and no cooldown. rate_window limits a KEY; the
//! key and the tenant must be bound by a trusted wrapper outside the engine.
//!
//! Growth bound of refusal-only traffic: a rejection record exists only while the window of the key holds at least
//! one committed event (rule 4 needs a live event; a request that can never fit is rule 1, no record), and at most
//! `cooldown_after` rejection records come before each cooldown, during which nothing is written. So per key, the
//! rejection records within any span of `window_ms` after a commit are at most
//! `cooldown_after * (window_ms / cooldown_ms + 1)`: refusals grow the WAL at most in proportion to commits.
//!
//! Records (module payload): `A <policy> <volume>` (kind C) and `X <policy> <volume>` (kind R). The fold re-checks
//! each decision with the record time: a commit that did not fit, a rejection that would have fitted, any record
//! during a cooldown, or a policy change of a key refuses the store.
use crate::json::J;
use crate::prim::{dec_u64, policy_fields, refusal, Cas, Decision, Kind, Now, OpSpec, Policies, Primitive, Record, Request};
use std::collections::{BTreeMap, VecDeque};

pub struct RateWindow;

pub struct Policy {
    pub max_ops: u64,
    pub max_volume: u64,
    pub window_ms: u64,
    pub cooldown_after: u64,
    pub cooldown_ms: u64,
}

#[derive(Default)]
pub struct KeyState {
    policy: String,
    events: VecDeque<(u64, u64)>, // (engine time, volume), non-decreasing times
    rejections: u64,              // consecutive counted rejections since the last commit or cooldown start
    cooldown_until: Option<u64>,
}

#[derive(Default)]
pub struct State {
    keys: BTreeMap<String, KeyState>,
}

/// The time an event stops counting; None: never (t + window_ms overflows u64).
fn expiry(t: u64, p: &Policy) -> Option<u64> {
    t.checked_add(p.window_ms)
}
/// True while the event at t counts at `now`.
fn live(t: u64, p: &Policy, now: u64) -> bool {
    expiry(t, p).map_or(true, |e| now < e)
}

/// Ok: `v` fits at `now`. Err(Some(n)): it fits first at now + n (n >= 1). Err(None): it never fits by waiting
/// (an event that never stops counting is in the way).
pub fn fits(events: &VecDeque<(u64, u64)>, p: &Policy, now: u64, v: u64) -> Result<(), Option<u64>> {
    let first = events.iter().position(|(t, _)| live(*t, p, now)).unwrap_or(events.len());
    let live_events: Vec<(u64, u64)> = events.iter().skip(first).copied().collect();
    let ops = live_events.len() as u64;
    let volume: u128 = live_events.iter().map(|(_, x)| *x as u128).sum();
    if ops + 1 <= p.max_ops && volume + v as u128 <= p.max_volume as u128 {
        return Ok(());
    }
    // k = the least number of oldest live events that must stop counting.
    let k_ops = (ops + 1).saturating_sub(p.max_ops);
    let (mut k_vol, mut left) = (0u64, volume);
    while left + v as u128 > p.max_volume as u128 {
        let Some((_, x)) = live_events.get(k_vol as usize) else { return Err(None) }; // only if v > max_volume
        left -= *x as u128;
        k_vol += 1;
    }
    let k = k_ops.max(k_vol);
    debug_assert!(k >= 1 && k <= ops);
    let (t, _) = live_events[(k - 1) as usize];
    match expiry(t, p) {
        Some(e) => Err(Some(e - now)),
        None => Err(None),
    }
}

fn parse_args(args: &str) -> Option<(&str, u64)> {
    let (name, v) = args.split_once(' ')?;
    if !crate::store::canonical_id(name) { return None }
    Some((name, dec_u64(v)?))
}

impl Primitive for RateWindow {
    const NAME: &'static str = "rate_window";
    const OPS: &'static [OpSpec] = &[OpSpec { op: "acquire", min_keys: 1, max_keys: 1, cas: Cas::AnyAllowed }];
    type Policy = Policy;
    type State = State;

    fn parse_policy(doc: &J) -> Result<Policy, String> {
        let f = policy_fields(doc, &["max_ops_per_window", "max_volume_per_window", "window_ms", "cooldown_after", "cooldown_ms"])?;
        let num = |k: &str| dec_u64(f[k]).ok_or_else(|| format!("NOT_A_DECIMAL {k}"));
        let p = Policy {
            max_ops: num("max_ops_per_window")?,
            max_volume: num("max_volume_per_window")?,
            window_ms: num("window_ms")?,
            cooldown_after: num("cooldown_after")?,
            cooldown_ms: num("cooldown_ms")?,
        };
        if !(1..=65536).contains(&p.max_ops) { return Err("RANGE max_ops_per_window 1..65536".into()) }
        if p.window_ms == 0 { return Err("RANGE window_ms >= 1".into()) }
        if p.cooldown_after > 1024 { return Err("RANGE cooldown_after 0..1024".into()) }
        if p.cooldown_after > 0 && p.cooldown_ms == 0 { return Err("RANGE cooldown_ms >= 1 with a cooldown".into()) }
        Ok(p)
    }

    fn decide(req: &Request, state: &State, policies: &Policies<Policy>, now: &Now) -> Decision {
        let Some((name, v)) = parse_args(req.args) else {
            return Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", "RATE_ARGS".into())], "args: <policy> <volume>"));
        };
        let Some(p) = policies.get(name) else {
            return Decision::Refuse(refusal("UNKNOWN_POLICY", vec![], "no rate_window policy of that name is pinned in this store"));
        };
        let key = req.keys[0].key;
        let empty = KeyState::default();
        let ks = state.keys.get(key).unwrap_or(&empty);
        if state.keys.contains_key(key) && ks.policy != name {
            return Decision::Refuse(refusal("POLICY_MISMATCH", vec![("policy", ks.policy.clone())], "the key is bound to another policy"));
        }
        if v > p.max_volume {
            return Decision::Refuse(refusal("VOLUME_ABOVE_CAP", vec![("max_volume_per_window", p.max_volume.to_string())], "this volume never fits the window"));
        }
        if let Some(until) = ks.cooldown_until {
            if now.now_ms < until {
                return Decision::Refuse(refusal("COOLDOWN_ACTIVE", vec![("retry_after_ms", (until - now.now_ms).to_string())], "a cooldown follows too many consecutive rejections"));
            }
        }
        match fits(&ks.events, p, now.now_ms, v) {
            Ok(()) => Decision::Commit(format!("A {name} {v}")),
            Err(wait) => {
                // Does THIS refusal start the cooldown (the fold's rule)? Then the retry waits for its end as well.
                let starts = p.cooldown_after > 0 && ks.rejections.checked_add(1).map_or(true, |r| r >= p.cooldown_after);
                let wait = match wait {
                    Some(w) if starts => {
                        let until = now.now_ms.checked_add(p.cooldown_ms).unwrap_or(u64::MAX);
                        Some(w.max(until - now.now_ms))
                    }
                    other => other,
                };
                let retry = wait.map_or("never".to_string(), |n| n.to_string());
                let r = refusal("RATE_LIMIT_EXCEEDED", vec![("retry_after_ms", retry)], "the sliding window is full");
                if p.cooldown_after > 0 { Decision::RefuseDurable(r, format!("X {name} {v}")) } else { Decision::Refuse(r) }
            }
        }
    }

    fn fold(state: &mut State, rec: &Record, policies: &Policies<Policy>) -> Result<(), String> {
        if rec.op != "acquire" || rec.keys.len() != 1 { return Err("OP".into()) }
        let mut t = rec.payload.split(' ');
        let (tag, name, v) = (t.next(), t.next(), t.next().and_then(dec_u64));
        let (Some(tag), Some(name), Some(v), None) = (tag, name, v, t.next()) else { return Err("PAYLOAD".into()) };
        let p = policies.get(name).ok_or("UNKNOWN_POLICY")?;
        let ks = state.keys.entry(rec.keys[0].to_string()).or_insert_with(|| KeyState { policy: name.to_string(), ..Default::default() });
        if ks.policy != name { return Err("POLICY_MISMATCH".into()) }
        if v > p.max_volume { return Err("VOLUME_ABOVE_CAP".into()) }
        let now = rec.now_ms;
        if ks.cooldown_until.is_some_and(|u| now < u) { return Err("RECORD_DURING_COOLDOWN".into()) }
        ks.cooldown_until = None;
        while ks.events.front().is_some_and(|(e, _)| !live(*e, p, now)) {
            ks.events.pop_front();
        }
        match (tag, rec.kind) {
            ("A", Kind::Commit) => {
                if fits(&ks.events, p, now, v).is_err() { return Err("COMMIT_DID_NOT_FIT".into()) }
                ks.events.push_back((now, v));
                ks.rejections = 0;
            }
            ("X", Kind::Refusal) => {
                if p.cooldown_after == 0 { return Err("REJECTION_RECORD_WITHOUT_COOLDOWN".into()) }
                if fits(&ks.events, p, now, v).is_ok() { return Err("REJECTION_THAT_FITTED".into()) }
                ks.rejections = ks.rejections.checked_add(1).ok_or("COUNT")?;
                if ks.rejections >= p.cooldown_after {
                    ks.cooldown_until = Some(now.checked_add(p.cooldown_ms).unwrap_or(u64::MAX));
                    ks.rejections = 0;
                }
            }
            _ => return Err("TAG".into()),
        }
        Ok(())
    }

    fn describe(state: &State, key: &str, policies: &Policies<Policy>, now: &Now) -> Option<Vec<(&'static str, String)>> {
        let ks = state.keys.get(key)?;
        let p = policies.get(&ks.policy)?;
        let live_events: Vec<&(u64, u64)> = ks.events.iter().filter(|(t, _)| live(*t, p, now.now_ms)).collect();
        let volume: u128 = live_events.iter().map(|(_, v)| *v as u128).sum();
        let cooldown = ks.cooldown_until.filter(|u| now.now_ms < *u).map_or(0, |u| u - now.now_ms);
        Some(vec![
            ("policy", ks.policy.clone()),
            ("ops", live_events.len().to_string()),
            ("volume", volume.to_string()),
            ("rejections", ks.rejections.to_string()),
            ("cooldown_ms_left", cooldown.to_string()),
        ])
    }
}
