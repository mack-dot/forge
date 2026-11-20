//! The fold of the WAL: the state of every key, the committed request ids and the open leases. NATIVE CHECK, not proved.
//! `apply` checks the structural invariants of one record (fresh id, key kind, tenant, amounts) before it changes
//! anything. The policy decisions are made at write time (verbs.rs); the fold does not repeat them.
//! Namespaces (review D3): keys, request ids and leases are PER TENANT. Every map is indexed by (tenant, name), so no
//! record of one tenant can block, close or reveal a key, a request id or a lease of another tenant. The tenant field
//! is NOT authenticated by the engine (PROTOCOL.md section 11).
use crate::store::{canonical_id, money, parse_hash};
use std::collections::{BTreeMap, HashMap, HashSet};

pub const MAX_FACTS: usize = 16;
pub const MAX_ROWS: usize = 64;
pub const MAX_COLS: usize = 1024;
/// The details of a REQUIRE_HUMAN_COSIGN answer (PROTOCOL.md section 6): the only details of a COSIGN_PENDING record.
pub const COSIGN_DETAILS: [&str; 3] = ["COSIGN_REQUIRED", "NO_COSIGN_KEY", "COSIGN_INVALID"];

#[derive(Clone)]
pub enum Body {
    Money { policy: String, original: u64, remaining: u64, facts: BTreeMap<String, u64>, totals: BTreeMap<String, u64> },
    Saga { policy: String, state: String, pair: Option<(String, String)> },
    Inventory { policy: String, remaining: Vec<u64> },
}
#[derive(Clone)]
pub struct Key {
    pub hash: u128,
    pub body: Body,
}
/// One lease, bound to a request id, a tenant and a key (indexed by (tenant, request id)). `closed`: (epoch, verdict,
/// detail) of the closing record. `pending` (review D6): (epoch, detail) of the COSIGN_PENDING record: a cosign verdict
/// was given and the signed retry is still expected. A pending lease is still open: the sweep reports it, and only a
/// commit or a REJECTED_POLICY of its request closes it.
pub struct Lease {
    pub epoch: u64,
    pub deadline: u64,
    pub tenant: String,
    pub key: String,
    pub closed: Option<(u64, String, String)>,
    pub pending: Option<(u64, String)>,
}
impl Lease {
    pub fn is_open(&self) -> bool {
        self.closed.is_none()
    }
    pub fn binds(&self, tenant: &str, key: &str) -> bool {
        self.closed.is_none() && self.tenant == tenant && self.key == key
    }
}
pub struct Pin {
    pub name: String,
    pub kind: String,
    pub hash: u128,
}
#[derive(Default)]
pub struct Ledger {
    pub store_id: String,
    pub nonce: String,
    pub node_pin: Option<String>,
    pub genesis_hash: u128,
    pub pubkey: Option<String>,
    pub pins: Vec<Pin>,
    pub keys: HashMap<(String, String), Key>,    // by (tenant, key)
    pub ids: HashSet<(String, String)>,          // used request ids, by (tenant, request id)
    pub leases: BTreeMap<(String, String), Lease>, // every lease ever opened, by (tenant, request id) (a closed one stays: no second lease)
    pub epoch: u64,
    pub tail: u128,
    pub len: u64,
    pub effects: u64,
}

/// The index of a per-tenant map: (tenant, name).
pub fn tk(tenant: &str, name: &str) -> (String, String) {
    (tenant.to_string(), name.to_string())
}

pub fn parse_csv(s: &str, max: usize) -> Option<Vec<u64>> {
    let v: Option<Vec<u64>> = s.split(',').map(money).collect();
    v.filter(|v| !v.is_empty() && v.len() <= max)
}

impl Ledger {
    fn fresh(&self, tenant: &str, req: &str) -> bool {
        canonical_id(req) && !self.ids.contains(&tk(tenant, req))
    }
    fn can_open(&self, tenant: &str, key: &str, req: &str, policy: &str, kind: &str) -> Option<()> {
        let pinned = self.pins.iter().any(|p| p.name == policy && p.kind == kind);
        (canonical_id(tenant) && canonical_id(key) && self.fresh(tenant, req) && !self.keys.contains_key(&tk(tenant, key)) && pinned).then_some(())
    }
    fn done(&mut self, index: u64, req: &str, tenant: &str, key: &str) {
        self.ids.insert(tk(tenant, req));
        // a committed effect is a terminal verdict: it closes an open lease of the same id, tenant and key
        if let Some(l) = self.leases.get_mut(&tk(tenant, req)).filter(|l| l.binds(tenant, key)) { l.closed = Some((index, "COMMITTED".into(), "-".into())) }
        self.effects += 1;
    }
    pub fn open_leases(&self) -> usize {
        self.leases.values().filter(|l| l.is_open()).count()
    }
    fn key_mut(&mut self, tenant: &str, key: &str, req: &str) -> Option<&mut Key> {
        if !self.fresh(tenant, req) { return None }
        self.keys.get_mut(&tk(tenant, key))
    }
    fn genesis(&mut self, t: &[&str], hash: u128) -> Option<()> {
        // Version 3 (Apex addendum): the cosign key is the base64 blob of an OpenSSH ssh-ed25519 public key.
        let ["GENESIS", "3", store_id, nonce, node_pin, pubkey, n, pins @ ..] = t else { return None };
        let hexn = |s: &str, n: usize| s.len() == n && s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
        if !hexn(nonce, 32) || !(*node_pin == "-" || hexn(node_pin, 64)) { return None }
        if *pubkey != "-" && crate::cosign::key_token_refused(pubkey) { return None } // strict token, no weak key
        let count: usize = n.parse().ok().filter(|c: &usize| c.to_string() == *n)?;
        let n = count;
        if !canonical_id(store_id) || pins.len() != 3 * n { return None }
        for p in pins.chunks(3) {
            let ok = canonical_id(p[0]) && ["money", "saga", "inventory"].contains(&p[1]) && !self.pins.iter().any(|x| x.name == p[0]);
            if !ok { return None }
            self.pins.push(Pin { name: p[0].to_string(), kind: p[1].to_string(), hash: parse_hash(p[2])? });
        }
        self.store_id = store_id.to_string();
        self.pubkey = (*pubkey != "-").then(|| pubkey.to_string());
        self.nonce = nonce.to_string();
        self.node_pin = (*node_pin != "-").then(|| node_pin.to_string());
        self.genesis_hash = hash;
        Some(())
    }
    /// Applies one record. None: the record is not valid here (the WAL is then CORRUPT_WAL, or a write is refused).
    pub fn apply(&mut self, index: u64, payload: &str, hash: u128) -> Option<()> {
        let t: Vec<&str> = payload.split(' ').collect();
        if index == 0 { return self.genesis(&t, hash) }
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
                self.keys.insert(tk(tenant, key), Key { hash, body });
                self.done(index, req, tenant, key);
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
                self.done(index, req, tenant, key);
            }
            ["OPEN_SAGA", tenant, key, req, policy, initial] => {
                self.can_open(tenant, key, req, policy, "saga")?;
                if !canonical_id(initial) { return None }
                let body = Body::Saga { policy: policy.to_string(), state: initial.to_string(), pair: None };
                self.keys.insert(tk(tenant, key), Key { hash, body });
                self.done(index, req, tenant, key);
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
                self.done(index, req, tenant, key);
            }
            ["OPEN_INVENTORY", tenant, key, req, policy, capacity] => {
                self.can_open(tenant, key, req, policy, "inventory")?;
                let remaining = parse_csv(capacity, MAX_ROWS)?;
                let body = Body::Inventory { policy: policy.to_string(), remaining };
                self.keys.insert(tk(tenant, key), Key { hash, body });
                self.done(index, req, tenant, key);
            }
            ["BOOK", tenant, key, req, x, after] => {
                let after = parse_csv(after, MAX_ROWS)?;
                if x.is_empty() || x.len() > MAX_COLS || !x.bytes().all(|b| b == b'0' || b == b'1') { return None }
                let k = self.key_mut(tenant, key, req)?;
                let Body::Inventory { remaining, .. } = &mut k.body else { return None };
                if after.len() != remaining.len() || after.iter().zip(remaining.iter()).any(|(a, r)| a > r) { return None }
                *remaining = after;
                k.hash = hash;
                self.done(index, req, tenant, key);
            }
            ["LEASE", req, deadline, tenant, key] => {
                let deadline = money(deadline)?;
                if !canonical_id(tenant) || !self.fresh(tenant, req) || self.leases.contains_key(&tk(tenant, req)) || !canonical_id(key) { return None }
                let lease = Lease { epoch: index, deadline, tenant: tenant.to_string(), key: key.to_string(), closed: None, pending: None };
                self.leases.insert(tk(tenant, req), lease);
            }
            // The close names its tenant: a request id can have one lease in EACH tenant. Only a REJECTED_POLICY closes by
            // a record; a cosign verdict leaves the lease open (COSIGN_PENDING below; review D6).
            ["CLOSE", req, tenant, "REJECTED_POLICY", code] => {
                if !canonical_id(code) { return None }
                let l = self.leases.get_mut(&tk(tenant, req)).filter(|l| l.is_open())?;
                l.closed = Some((index, "REJECTED_POLICY".to_string(), code.to_string()));
            }
            // Review D6: a cosign verdict on the lease's request. At most one per lease (a retry writes no record).
            ["COSIGN_PENDING", req, tenant, code] => {
                if !COSIGN_DETAILS.contains(code) { return None }
                let l = self.leases.get_mut(&tk(tenant, req)).filter(|l| l.is_open() && l.pending.is_none())?;
                l.pending = Some((index, code.to_string()));
            }
            // The form of the engine before the per-tenant namespaces (no tenant). That engine allowed one lease per request
            // id in the whole store, so the form is read only while exactly one lease, in any tenant, has this id. Its
            // `CLOSE <id> REQUIRE_HUMAN_COSIGN <detail>` closed a lease whose action was still pending: it is read as
            // COSIGN_PENDING (review D6), so the sweep reports such work after its deadline.
            ["CLOSE", req, verdict, code] => {
                let cosign = *verdict == "REQUIRE_HUMAN_COSIGN";
                if !(cosign || *verdict == "REJECTED_POLICY") || !canonical_id(code) || (cosign && !COSIGN_DETAILS.contains(code)) { return None }
                let mut same = self.leases.iter_mut().filter(|((_, r), _)| r == req);
                let (Some((_, l)), None) = (same.next(), same.next()) else { return None };
                if !l.is_open() || (cosign && l.pending.is_some()) { return None }
                if cosign { l.pending = Some((index, code.to_string())) } else { l.closed = Some((index, verdict.to_string(), code.to_string())) }
            }
            _ => return None,
        }
        Some(())
    }
}
