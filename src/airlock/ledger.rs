//! The fold of the WAL: the state of every key, the committed request ids and the open leases. NATIVE CHECK, not proved.
//! `apply` checks the structural invariants of one record (fresh id, key kind, tenant, amounts) before it changes
//! anything. The policy decisions are made at write time (verbs.rs); the fold does not repeat them.
use crate::store::{canonical_id, money, parse_hash};
use std::collections::{BTreeMap, HashMap, HashSet};

pub const MAX_FACTS: usize = 16;
pub const MAX_ROWS: usize = 64;
pub const MAX_COLS: usize = 1024;

#[derive(Clone)]
pub enum Body {
    Money { policy: String, original: u64, remaining: u64, facts: BTreeMap<String, u64>, totals: BTreeMap<String, u64> },
    Saga { policy: String, state: String, pair: Option<(String, String)> },
    Inventory { policy: String, remaining: Vec<u64> },
}
#[derive(Clone)]
pub struct Key {
    pub tenant: String,
    pub hash: u128,
    pub body: Body,
}
pub struct Pin {
    pub name: String,
    pub kind: String,
    pub hash: u128,
}
#[derive(Default)]
pub struct Ledger {
    pub store_id: String,
    pub pubkey: Option<String>,
    pub pins: Vec<Pin>,
    pub keys: HashMap<String, Key>,
    pub ids: HashSet<String>,
    pub leases: BTreeMap<String, (u64, u64)>, // request id -> (epoch of the LEASE record, deadline_ms)
    pub epoch: u64,
    pub tail: u128,
    pub len: u64,
    pub effects: u64,
}

pub fn parse_csv(s: &str, max: usize) -> Option<Vec<u64>> {
    let v: Option<Vec<u64>> = s.split(',').map(money).collect();
    v.filter(|v| !v.is_empty() && v.len() <= max)
}

impl Ledger {
    fn fresh(&self, req: &str) -> bool {
        canonical_id(req) && !self.ids.contains(req)
    }
    fn can_open(&self, tenant: &str, key: &str, req: &str, policy: &str, kind: &str) -> Option<()> {
        let pinned = self.pins.iter().any(|p| p.name == policy && p.kind == kind);
        (canonical_id(tenant) && canonical_id(key) && self.fresh(req) && !self.keys.contains_key(key) && pinned).then_some(())
    }
    fn done(&mut self, req: &str) {
        self.ids.insert(req.to_string());
        self.leases.remove(req); // a committed effect is a terminal verdict: it closes a lease of the same id
        self.effects += 1;
    }
    fn key_mut(&mut self, tenant: &str, key: &str, req: &str) -> Option<&mut Key> {
        if !self.fresh(req) { return None }
        self.keys.get_mut(key).filter(|k| k.tenant == tenant)
    }
    fn genesis(&mut self, t: &[&str]) -> Option<()> {
        let ["GENESIS", "1", store_id, pubkey, n, pins @ ..] = t else { return None };
        let count: usize = n.parse().ok().filter(|c: &usize| c.to_string() == *n)?;
        let n = count;
        if !canonical_id(store_id) || pins.len() != 3 * n { return None }
        let key_ok = *pubkey == "-" || (pubkey.len() == 64 && pubkey.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)));
        if !key_ok { return None }
        for p in pins.chunks(3) {
            let ok = canonical_id(p[0]) && ["money", "saga", "inventory"].contains(&p[1]) && !self.pins.iter().any(|x| x.name == p[0]);
            if !ok { return None }
            self.pins.push(Pin { name: p[0].to_string(), kind: p[1].to_string(), hash: parse_hash(p[2])? });
        }
        self.store_id = store_id.to_string();
        self.pubkey = (*pubkey != "-").then(|| pubkey.to_string());
        Some(())
    }
    /// Applies one record. None: the record is not valid here (the WAL is then CORRUPT_WAL, or a write is refused).
    pub fn apply(&mut self, index: u64, payload: &str, hash: u128) -> Option<()> {
        let t: Vec<&str> = payload.split(' ').collect();
        if index == 0 { return self.genesis(&t) }
        if self.store_id.is_empty() { return None }
        match t.as_slice() {
            ["OPEN_MONEY", tenant, key, req, policy, original, facts @ ..] => {
                self.can_open(tenant, key, req, policy, "money")?;
                let original = money(original)?;
                let mut f = BTreeMap::new();
                for x in facts {
                    let (n, v) = x.split_once('=')?;
                    if !canonical_id(n) || f.insert(n.to_string(), money(v)?).is_some() { return None }
                }
                if f.len() > MAX_FACTS || !facts.iter().zip(f.keys()).all(|(x, k)| x.starts_with(&format!("{k}="))) { return None } // sorted
                let body = Body::Money { policy: policy.to_string(), original, remaining: original, facts: f, totals: BTreeMap::new() };
                self.keys.insert(key.to_string(), Key { tenant: tenant.to_string(), hash, body });
                self.done(req);
            }
            ["REFUND", tenant, key, req, reason, amount, cosigned] => {
                let amount = money(amount)?;
                if !canonical_id(reason) || !["0", "1"].contains(cosigned) { return None }
                let k = self.key_mut(tenant, key, req)?;
                let Body::Money { remaining, totals, .. } = &mut k.body else { return None };
                if amount == 0 || amount > *remaining { return None }
                let total = totals.get(*reason).copied().unwrap_or(0).checked_add(amount)?;
                *remaining -= amount;
                totals.insert(reason.to_string(), total);
                k.hash = hash;
                self.done(req);
            }
            ["OPEN_SAGA", tenant, key, req, policy, initial] => {
                self.can_open(tenant, key, req, policy, "saga")?;
                if !canonical_id(initial) { return None }
                let body = Body::Saga { policy: policy.to_string(), state: initial.to_string(), pair: None };
                self.keys.insert(key.to_string(), Key { tenant: tenant.to_string(), hash, body });
                self.done(req);
            }
            ["SAGA", tenant, key, req, to, processor, idem] => {
                let pair = match (*processor, *idem) {
                    ("-", "-") => None,
                    (p, i) if canonical_id(p) && canonical_id(i) => Some((p.to_string(), i.to_string())),
                    _ => return None,
                };
                if !canonical_id(to) { return None }
                let k = self.key_mut(tenant, key, req)?;
                let Body::Saga { state, pair: held, .. } = &mut k.body else { return None };
                (*state, *held) = (to.to_string(), pair);
                k.hash = hash;
                self.done(req);
            }
            ["OPEN_INVENTORY", tenant, key, req, policy, capacity] => {
                self.can_open(tenant, key, req, policy, "inventory")?;
                let remaining = parse_csv(capacity, MAX_ROWS)?;
                let body = Body::Inventory { policy: policy.to_string(), remaining };
                self.keys.insert(key.to_string(), Key { tenant: tenant.to_string(), hash, body });
                self.done(req);
            }
            ["BOOK", tenant, key, req, x, after] => {
                let after = parse_csv(after, MAX_ROWS)?;
                if x.is_empty() || x.len() > MAX_COLS || !x.bytes().all(|b| b == b'0' || b == b'1') { return None }
                let k = self.key_mut(tenant, key, req)?;
                let Body::Inventory { remaining, .. } = &mut k.body else { return None };
                if after.len() != remaining.len() || after.iter().zip(remaining.iter()).any(|(a, r)| a > r) { return None }
                *remaining = after;
                k.hash = hash;
                self.done(req);
            }
            ["LEASE", req, deadline] => {
                let deadline = money(deadline)?;
                if !self.fresh(req) || self.leases.contains_key(*req) { return None }
                self.leases.insert(req.to_string(), (index, deadline));
            }
            ["CLOSE", req, verdict, code] => {
                if !["REJECTED_POLICY", "REQUIRE_HUMAN_COSIGN"].contains(verdict) || !canonical_id(code) { return None }
                self.leases.remove(*req)?;
            }
            _ => return None,
        }
        Some(())
    }
}
