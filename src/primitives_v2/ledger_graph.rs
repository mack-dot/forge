//! Primitive 7, `ledger_graph`: multi-account double-entry ledgers, a global uniqueness registry, an acyclic graph
//! guard. NATIVE CHECK, not proved. A pure module (prim.rs): no I/O, no clock, no randomness (only BTree maps; no
//! HashMap). FINITE TEST: tests/primitives_v2/test_ledger_graph.py; changed copies: tests/primitives_v2/mutants_p7.py.
//!
//! ## Policies (one file per policy; the policy name is the ledger, registry or graph name)
//!
//!   {"primitive": "ledger_graph", "version": 1, "name": "<id>", "kind": "ledger",
//!    "issuance": "fixed" | "mint_burn", "max_balance": "1..18446744073709551615", "max_legs": "2..16"}
//!   {"primitive": "ledger_graph", "version": 1, "name": "<id>", "kind": "registry",
//!    "case": "exact" | "ascii_fold", "max_name_bytes": "1..256"}
//!   {"primitive": "ledger_graph", "version": 1, "name": "<id>", "kind": "graph",
//!    "max_nodes": "2..1000000", "max_edges": "1..4000000"}
//! Every value is a JSON string; numbers are canonical decimals. The key set is exact.
//!
//! ## Ops (`DO ledger_graph <op> <request_id> <tenant> <n> <key hash>... <args>`)
//!
//! | op | keys | CAS | args | record payload (kind C) |
//! | --- | --- | --- | --- | --- |
//! | `open` | 1..16 new accounts | required | `<ledger> <balance_1> ... <balance_n>` (key order) | the args |
//! | `transfer` | 2 accounts | required | `<ledger> <from> <to> <amount>` | the args |
//! | `post` | 2..16 accounts | required | `<ledger> <leg_1> ... <leg_n>`, leg `-<amount>` (debit: leaves) or `+<amount>` (credit: enters), key order | the args |
//! | `mint` / `burn` | 1 account | required | `<ledger> <amount>` | the args |
//! | `claim` / `release` | 1: `reg:<tenant>` | `*` allowed | `<registry> <name>` | `<registry> <canonical name>` |
//! | `add_edge` | 1 graph key | required | `<graph policy> <from> <to>( <from> <to>)*` (a batch, all or nothing) | the args |
//! | `remove_edge` | 1 graph key | required | `<graph policy> <from> <to>` | the args |
//!
//! The module writes only kind-C records (no durable refusal). The payload of every record is the canonical form of
//! the args; `fold` parses it strictly, requires it to be canonical, re-runs the SAME checks as `decide` against the
//! folded state, applies it, and re-checks `total == issued - destroyed` for the touched ledger. So a forged record
//! with a valid chain that overdraws, breaks conservation, claims a held name, or closes a cycle refuses the store.
//!
//! ## Ledger
//! - A ledger instance is (tenant, ledger policy). An account is a key, bound to one instance by its `open` record
//!   (the engine binds it to the tenant). Balances are exact u64, `0 <= balance <= max_balance`.
//! - Conserved quantity per instance: `sum(balances) == issued - destroyed`, where `issued` = the sum of the
//!   `open` balances and `mint` amounts, `destroyed` = the sum of `burn` amounts (u128). With `issuance = fixed`,
//!   `mint` and `burn` are refused (`ISSUANCE_DISABLED`) and only the FIRST `open` of the instance may hold nonzero
//!   balances (`SUPPLY_FIXED` after that): then `sum(balances)` is the constant set at that first open, forever.
//! - Refusals (no record; exit 10 unless named): `UNKNOWN_POLICY`, `WRONG_POLICY_KIND policy_kind=`,
//!   `ACCOUNT_EXISTS key=`, `SUPPLY_FIXED`, `ISSUANCE_DISABLED`, `UNKNOWN_ACCOUNT key=`, `WRONG_KEY_KIND key= kind=`,
//!   `CROSS_LEDGER key= ledger=`, `ZERO_AMOUNT index=`, `SELF_TRANSFER`, `INSUFFICIENT_FUNDS key= balance= needed=`,
//!   `BALANCE_LIMIT key= max_balance=`, `TOO_MANY_LEGS max_legs=`,
//!   `CONSERVATION_BREACH debit_total= credit_total=` (an unbalanced posting), and `MALFORMED_REQUEST why=` (exit 12:
//!   `LG_ARGS`, `LEG_KEYS`, `LEG_COUNT`, `RESERVED_KEY`). Cross-tenant: the engine refuses another tenant's key
//!   first (`TENANT_ISOLATION_BREACH`, exit 16); the module re-checks the tenant (`CROSS_TENANT`) as a second line.
//! - Check order of `post`: grammar, policy, leg count, zero legs, balance of the legs (`CONSERVATION_BREACH`),
//!   accounts, overdraft, limit. The balance of the legs is checked before the accounts on purpose: it is a fault of
//!   the posting itself and its repair needs no account data.
//!
//! ## Registry (global across tenants)
//! - The record key is the caller's own handle `reg:<tenant>` (exactly; `MALFORMED_REQUEST why=REGISTRY_KEY
//!   expected=`). The name itself is NOT a key: the engine binds a key to the first tenant that touches it, so a name
//!   key would make the namespace per tenant. The global map (registry, canonical name) -> holder lives in the module
//!   state, which every request rebuilds under the exclusive lock, so the first claim wins and every later claim by
//!   any tenant (the holder too) is `DUPLICATE_KEY registry=`. The refusal never names the holder or echoes the name.
//!   `release` by anyone but the holder, or of a free name: `NOT_HOLDER registry=` (one code for both).
//! - Name: 1..max_name_bytes bytes, each 0x21..0x7E (printable ASCII, no space). Canonical form: `exact` = the bytes
//!   as given; `ascii_fold` = A-Z mapped to a-z, every other byte unchanged. Nothing else: no Unicode
//!   normalisation, no confusable detection, no trimming, no `\u` decoding (backslash, `u`, `0430` is six ASCII bytes, not one letter). A name
//!   that looks the same in another script, or in another escape form, is a DIFFERENT name here.
//!
//! ## Graph guard
//! - A graph is one key (bound to one graph policy at its first record) and one consistency unit: every edge change
//!   names the key with its present state hash (CAS required), and the engine decides under the exclusive lock on
//!   the whole folded graph. Two edges that are each fine but close a cycle together cannot both commit: the second
//!   decision sees the first edge (lock), and its CAS hash is stale anyway. Cost: changes to one graph are fully
//!   serialised; under contention each loser gets `STALE_STATE_HASH`, re-reads (`GET`) and retries, and each try
//!   replays the whole WAL (O(WAL)).
//! - `add_edge` refusals: `DAG_CYCLE_DETECTED edge=<from>-><to> cycle_len=<k> index=<i>` (the cycle the edge would
//!   close has k edges; a self-loop is k = 1; i is the position in the batch), `EDGE_EXISTS edge= index=`,
//!   `GRAPH_FULL limit=max_nodes|max_edges max=`, `POLICY_MISMATCH policy=`, `WRONG_KEY_KIND`; `remove_edge`:
//!   `NO_SUCH_EDGE edge=`. Node names: `[A-Za-z0-9_.:@+-]{1,64}`. A node exists while it has an edge.
//! - Search (Pearce-Kelly dynamic topological order, rebuilt by the fold at every replay): the graph keeps an order
//!   `ord` with ord[a] < ord[b] for every edge. A new `from` node goes before every node, a new `to` node after
//!   every node, so an edge with a new end, or with ord[from] < ord[to], needs no search: O(log V). Else a
//!   breadth-first search from `to` through nodes with ord <= ord[from] (a path to `from` never leaves that band)
//!   either reaches `from` (refused; the BFS depth gives the exact shortest cycle length) or gives the set to move;
//!   a backward search from `from` through ord >= ord[to] gives the other set; both sets are re-ordered into their
//!   own old slots. Explicit queues, no recursion: no stack overflow on a 100,000-node chain (case `chain`, both
//!   directions). Cost per edge: O((|F| + |B|) log V), at most O((V + E) log V); worst case of a whole replay
//!   O(E (V + E) log V), bounded by max_nodes and max_edges (an adversarial insertion order can reach it; chains,
//!   trees and edges added in any topological order cost O(log V) each). `decide` runs the batch on a COPY of the
//!   graph (O(V + E) per add_edge request); `fold` runs it in place.
//!
//! ## `GET` fields
//! account: `kind=account ledger= balance= ledger_total= ledger_issued= ledger_destroyed= ledger_accounts=` (the
//! totals are those of the caller's own instance); `reg:<tenant>`: `kind=registry claims=`; graph:
//! `kind=graph policy= nodes= edges=`.
use crate::json::J;
use crate::prim::{dec_u64, policy_fields, refusal, Cas, Decision, Kind, Now, OpSpec, Policies, Primitive, Record, Refusal, Request};
use crate::store::canonical_key;
use std::collections::{BTreeMap, BTreeSet, VecDeque};

pub struct LedgerGraph;

pub enum Policy {
    Ledger { fixed: bool, max_balance: u64, max_legs: usize },
    Registry { fold: bool, max_name: usize },
    Graph { max_nodes: u64, max_edges: u64 },
}

struct Account {
    tenant: String,
    ledger: String,
    balance: u64,
}
#[derive(Default)]
struct Ledger {
    total: u128,
    issued: u128,
    destroyed: u128,
    accounts: u64,
}
#[derive(Clone)]
struct Graph {
    tenant: String,
    policy: String,
    out: BTreeMap<String, BTreeSet<String>>,
    inn: BTreeMap<String, BTreeSet<String>>,
    /// A topological order of the nodes that have an edge: every edge a->b has ord[a] < ord[b] (Pearce-Kelly).
    ord: BTreeMap<String, i64>,
    lo: i64,
    hi: i64,
    edges: u64,
}
impl Graph {
    fn new(tenant: &str, policy: &str) -> Graph {
        Graph { tenant: tenant.into(), policy: policy.into(), out: BTreeMap::new(), inn: BTreeMap::new(), ord: BTreeMap::new(), lo: 0, hi: 0, edges: 0 }
    }
}

#[derive(Default)]
pub struct State {
    accounts: BTreeMap<String, Account>,
    ledgers: BTreeMap<(String, String), Ledger>, // (tenant, ledger policy)
    names: BTreeMap<(String, String), String>,   // (registry, canonical name) -> holder tenant
    reg_keys: BTreeMap<String, u64>,             // `reg:<tenant>` -> names held
    graphs: BTreeMap<String, Graph>,
}

enum Op {
    Open { ledger: String, bals: Vec<u64> },
    Transfer { ledger: String, from: String, to: String, amt: u64 },
    Post { ledger: String, legs: Vec<(bool, u64)> }, // (credit, amount)
    Mint { ledger: String, amt: u64 },
    Burn { ledger: String, amt: u64 },
    Claim { reg: String, name: String },
    Release { reg: String, name: String },
    AddEdge { graph: String, edges: Vec<(String, String)> },
    RemoveEdge { graph: String, from: String, to: String },
}

fn malformed(why: &'static str, detail: &str) -> Refusal {
    refusal("MALFORMED_REQUEST", vec![("why", why.into())], detail)
}
fn node_ok(n: &str) -> bool {
    !n.is_empty() && n.len() <= 64 && canonical_key(n)
}
fn name_ok(n: &str) -> bool {
    !n.is_empty() && n.bytes().all(|b| (0x21..=0x7e).contains(&b))
}

/// Strict parse of args (or of a record payload: the same form). Names are taken as given; `canon` folds them.
fn parse(op: &str, s: &str) -> Result<Op, Refusal> {
    let bad = || malformed("LG_ARGS", "see the args of the op in PROTOCOL.md (ledger_graph)");
    let t: Vec<&str> = s.split(' ').collect();
    if t.iter().any(|x| x.is_empty()) || t.len() < 2 { return Err(bad()) }
    let id = |x: &str| if crate::store::canonical_id(x) { Ok(x.to_string()) } else { Err(bad()) };
    let num = |x: &str| dec_u64(x).ok_or_else(bad);
    Ok(match (op, t.len()) {
        ("open", _) => Op::Open { ledger: id(t[0])?, bals: t[1..].iter().map(|x| num(x)).collect::<Result<_, _>>()? },
        ("transfer", 4) => {
            if !canonical_key(t[1]) || !canonical_key(t[2]) { return Err(bad()) }
            Op::Transfer { ledger: id(t[0])?, from: t[1].into(), to: t[2].into(), amt: num(t[3])? }
        }
        ("post", _) => {
            let mut legs = Vec::new();
            for x in &t[1..] {
                let credit = match x.as_bytes()[0] { b'+' => true, b'-' => false, _ => return Err(bad()) };
                legs.push((credit, num(&x[1..])?));
            }
            Op::Post { ledger: id(t[0])?, legs }
        }
        ("mint", 2) => Op::Mint { ledger: id(t[0])?, amt: num(t[1])? },
        ("burn", 2) => Op::Burn { ledger: id(t[0])?, amt: num(t[1])? },
        ("claim", 2) | ("release", 2) => {
            if !name_ok(t[1]) { return Err(malformed("NAME", "a name is 1 or more bytes 0x21..0x7E")) }
            let (reg, name) = (id(t[0])?, t[1].to_string());
            if op == "claim" { Op::Claim { reg, name } } else { Op::Release { reg, name } }
        }
        ("add_edge", n) if n >= 3 && n % 2 == 1 => {
            let mut edges = Vec::new();
            for p in t[1..].chunks(2) {
                if !node_ok(p[0]) || !node_ok(p[1]) { return Err(malformed("NODE", "node: [A-Za-z0-9_.:@+-]{1,64}")) }
                edges.push((p[0].to_string(), p[1].to_string()));
            }
            Op::AddEdge { graph: id(t[0])?, edges }
        }
        ("remove_edge", 3) => {
            if !node_ok(t[1]) || !node_ok(t[2]) { return Err(malformed("NODE", "node: [A-Za-z0-9_.:@+-]{1,64}")) }
            Op::RemoveEdge { graph: id(t[0])?, from: t[1].into(), to: t[2].into() }
        }
        _ => return Err(bad()),
    })
}

fn canon(name: &str, fold: bool) -> String {
    if fold { name.to_ascii_lowercase() } else { name.to_string() }
}

/// The canonical payload of an op (registry names in canonical form).
fn payload(op: &Op, pols: &Policies<Policy>) -> String {
    let fold = |reg: &str| matches!(pols.get(reg), Some(Policy::Registry { fold: true, .. }));
    match op {
        Op::Open { ledger, bals } => format!("{ledger} {}", bals.iter().map(|b| b.to_string()).collect::<Vec<_>>().join(" ")),
        Op::Transfer { ledger, from, to, amt } => format!("{ledger} {from} {to} {amt}"),
        Op::Post { ledger, legs } => {
            format!("{ledger} {}", legs.iter().map(|(c, a)| format!("{}{a}", if *c { '+' } else { '-' })).collect::<Vec<_>>().join(" "))
        }
        Op::Mint { ledger, amt } | Op::Burn { ledger, amt } => format!("{ledger} {amt}"),
        Op::Claim { reg, name } | Op::Release { reg, name } => format!("{reg} {}", canon(name, fold(reg))),
        Op::AddEdge { graph, edges } => {
            format!("{graph} {}", edges.iter().map(|(a, b)| format!("{a} {b}")).collect::<Vec<_>>().join(" "))
        }
        Op::RemoveEdge { graph, from, to } => format!("{graph} {from} {to}"),
    }
}

fn kind_of(st: &State, key: &str) -> Option<&'static str> {
    if st.accounts.contains_key(key) { Some("account") }
    else if st.graphs.contains_key(key) { Some("graph") }
    else if st.reg_keys.contains_key(key) { Some("registry") }
    else { None }
}

fn ledger_policy(pols: &Policies<Policy>, name: &str) -> Result<(bool, u64, usize), Refusal> {
    match pols.get(name) {
        None => Err(refusal("UNKNOWN_POLICY", vec![], "no ledger_graph policy of that name is pinned in this store")),
        Some(Policy::Ledger { fixed, max_balance, max_legs }) => Ok((*fixed, *max_balance, *max_legs)),
        Some(_) => Err(refusal("WRONG_POLICY_KIND", vec![("policy_kind", "not_ledger".into())], "the policy is not a ledger")),
    }
}

/// Every key must be a known account of `ledger`, of `tenant`.
fn accounts<'s>(st: &'s State, tenant: &str, ledger: &str, keys: &[&str]) -> Result<Vec<&'s Account>, Refusal> {
    let mut out = Vec::new();
    for k in keys {
        let Some(a) = st.accounts.get(*k) else {
            return Err(match kind_of(st, k) {
                Some(kind) => refusal("WRONG_KEY_KIND", vec![("key", k.to_string()), ("kind", kind.into())], "the key is not an account"),
                None => refusal("UNKNOWN_ACCOUNT", vec![("key", k.to_string())], "open the account first"),
            });
        };
        if a.tenant != tenant { return Err(refusal("CROSS_TENANT", vec![("key", k.to_string())], "")) }
        if a.ledger != ledger { return Err(refusal("CROSS_LEDGER", vec![("key", k.to_string()), ("ledger", a.ledger.clone())], "all accounts of one transfer or posting must be in the named ledger")) }
        out.push(a);
    }
    Ok(out)
}

/// Breadth-first search from `start` over out-edges, only through nodes with ord <= bound (a path from `start` to
/// `goal` in a valid order never leaves that band, so the band cuts no path). Returns the number of edges to `goal`
/// (the shortest path) if reached, and the visited nodes. Explicit queue: no recursion.
fn forward<'g>(g: &'g Graph, start: &'g str, goal: &str, bound: i64) -> (Option<u64>, Vec<&'g str>) {
    let mut seen: BTreeSet<&str> = BTreeSet::new();
    let mut q: VecDeque<(&str, u64)> = VecDeque::new();
    let mut order = vec![start];
    seen.insert(start);
    q.push_back((start, 0));
    while let Some((n, d)) = q.pop_front() {
        for m in g.out.get(n).into_iter().flatten() {
            if m == goal { return (Some(d + 1), order) }
            if g.ord.get(m.as_str()).is_some_and(|o| *o <= bound) && seen.insert(m) {
                order.push(m);
                q.push_back((m, d + 1));
            }
        }
    }
    (None, order)
}
/// The nodes that reach `start` over in-edges through nodes with ord >= bound (start included). Explicit queue.
fn backward<'g>(g: &'g Graph, start: &'g str, bound: i64) -> Vec<&'g str> {
    let mut seen: BTreeSet<&str> = BTreeSet::new();
    let mut q: VecDeque<&str> = VecDeque::new();
    let mut order = vec![start];
    seen.insert(start);
    q.push_back(start);
    while let Some(n) = q.pop_front() {
        for m in g.inn.get(n).into_iter().flatten() {
            if g.ord.get(m.as_str()).is_some_and(|o| *o >= bound) && seen.insert(m) {
                order.push(m);
                q.push_back(m);
            }
        }
    }
    order
}

/// Adds the edges of a batch in order, all or nothing for the caller (decide runs it on a copy; fold on the state,
/// where an Err refuses the store). Pearce-Kelly: an edge a->b with ord[a] < ord[b] needs no search; a new node is
/// placed before (as `from`) or after (as `to`) every node, so chains in either direction need no search. Else a
/// band-limited search from b finds a cycle (refused, with its exact length) or the two sets to reorder.
fn graph_add(g: &mut Graph, edges: &[(String, String)], max_nodes: u64, max_edges: u64) -> Result<(), Refusal> {
    let full = |what: &str, max: u64| refusal("GRAPH_FULL", vec![("limit", what.to_string()), ("max", max.to_string())], "");
    for (i, (a, b)) in edges.iter().enumerate() {
        let edge = format!("{a}->{b}");
        if a == b { return Err(refusal("DAG_CYCLE_DETECTED", vec![("edge", edge), ("cycle_len", "1".into()), ("index", i.to_string())], "a self-loop is a cycle")) }
        if g.out.get(a.as_str()).is_some_and(|s| s.contains(b.as_str())) { return Err(refusal("EDGE_EXISTS", vec![("edge", edge), ("index", i.to_string())], "")) }
        let (oa, ob) = (g.ord.get(a.as_str()).copied(), g.ord.get(b.as_str()).copied());
        let mut moved: Option<(Vec<String>, Vec<String>)> = None;
        if let (Some(oa), Some(ob)) = (oa, ob) {
            if ob < oa {
                let (hit, fwd) = forward(g, b, a, oa);
                if let Some(d) = hit {
                    return Err(refusal("DAG_CYCLE_DETECTED", vec![("edge", edge), ("cycle_len", (d + 1).to_string()), ("index", i.to_string())], "the edge would close a cycle: remove an edge of it or add another edge"));
                }
                let bwd = backward(g, a, ob);
                moved = Some((bwd.into_iter().map(String::from).collect(), fwd.into_iter().map(String::from).collect()));
            }
        }
        if g.edges >= max_edges { return Err(full("max_edges", max_edges)) }
        let new = oa.is_none() as u64 + ob.is_none() as u64;
        if g.ord.len() as u64 + new > max_nodes { return Err(full("max_nodes", max_nodes)) }
        if let Some((mut bwd, mut fwd)) = moved {
            let at = |g: &Graph, n: &String| g.ord.get(n).copied().unwrap_or(0);
            bwd.sort_by_key(|n| at(g, n));
            fwd.sort_by_key(|n| at(g, n));
            let mut slots: Vec<i64> = bwd.iter().chain(fwd.iter()).map(|n| at(g, n)).collect();
            slots.sort_unstable();
            for (n, slot) in bwd.into_iter().chain(fwd).zip(slots) {
                g.ord.insert(n, slot);
            }
        }
        if oa.is_none() {
            g.lo = g.lo.checked_sub(1).ok_or_else(|| full("order", 0))?;
            g.ord.insert(a.clone(), g.lo);
        }
        if ob.is_none() {
            g.hi = g.hi.checked_add(1).ok_or_else(|| full("order", 0))?;
            g.ord.insert(b.clone(), g.hi);
        }
        g.out.entry(a.clone()).or_default().insert(b.clone());
        g.inn.entry(b.clone()).or_default().insert(a.clone());
        g.edges += 1;
    }
    Ok(())
}
fn graph_limits(pols: &Policies<Policy>, name: &str) -> (u64, u64) {
    match pols.get(name) { Some(Policy::Graph { max_nodes, max_edges }) => (*max_nodes, *max_edges), _ => (0, 0) }
}

/// The checks shared by `decide` and `fold`. Ok: the op may commit on this state.
fn check(st: &State, pols: &Policies<Policy>, tenant: &str, keys: &[&str], op: &Op) -> Result<(), Refusal> {
    match op {
        Op::Open { ledger, bals } => {
            let (fixed, max_balance, _) = ledger_policy(pols, ledger)?;
            if bals.len() != keys.len() { return Err(malformed("LEG_COUNT", "one opening balance per key, in key order")) }
            for k in keys {
                if k.starts_with("reg:") { return Err(malformed("RESERVED_KEY", "keys that start with reg: are registry handles")) }
                if let Some(kind) = kind_of(st, k) {
                    return Err(if kind == "account" { refusal("ACCOUNT_EXISTS", vec![("key", k.to_string())], "") } else {
                        refusal("WRONG_KEY_KIND", vec![("key", k.to_string()), ("kind", kind.into())], "the key is not an account")
                    });
                }
            }
            for (k, b) in keys.iter().zip(bals) {
                if *b > max_balance { return Err(refusal("BALANCE_LIMIT", vec![("key", k.to_string()), ("max_balance", max_balance.to_string())], "")) }
            }
            if fixed && st.ledgers.contains_key(&(tenant.to_string(), ledger.clone())) && bals.iter().any(|b| *b > 0) {
                return Err(refusal("SUPPLY_FIXED", vec![], "the supply of this ledger was fixed at its first open: open new accounts with balance 0"));
            }
            Ok(())
        }
        Op::Transfer { ledger, from, to, amt } => {
            let (_, max_balance, _) = ledger_policy(pols, ledger)?;
            if from == to { return Err(refusal("SELF_TRANSFER", vec![], "from and to are the same account")) }
            let mut pair = [from.as_str(), to.as_str()];
            pair.sort();
            if keys != &pair[..] { return Err(malformed("LEG_KEYS", "the two keys must be exactly from and to")) }
            if *amt == 0 { return Err(refusal("ZERO_AMOUNT", vec![("index", "0".into())], "")) }
            accounts(st, tenant, ledger, keys)?;
            let (f, t) = (&st.accounts[from.as_str()], &st.accounts[to.as_str()]);
            if f.balance < *amt { return Err(refusal("INSUFFICIENT_FUNDS", vec![("key", from.clone()), ("balance", f.balance.to_string()), ("needed", amt.to_string())], "")) }
            if t.balance.checked_add(*amt).map_or(true, |b| b > max_balance) {
                return Err(refusal("BALANCE_LIMIT", vec![("key", to.clone()), ("max_balance", max_balance.to_string())], ""));
            }
            Ok(())
        }
        Op::Post { ledger, legs } => {
            let (_, max_balance, max_legs) = ledger_policy(pols, ledger)?;
            if legs.len() != keys.len() { return Err(malformed("LEG_COUNT", "one leg per key, in key order")) }
            if keys.len() > max_legs { return Err(refusal("TOO_MANY_LEGS", vec![("max_legs", max_legs.to_string())], "")) }
            if let Some(i) = legs.iter().position(|(_, a)| *a == 0) { return Err(refusal("ZERO_AMOUNT", vec![("index", i.to_string())], "")) }
            let debit: u128 = legs.iter().filter(|(c, _)| !*c).map(|(_, a)| *a as u128).sum();
            let credit: u128 = legs.iter().filter(|(c, _)| *c).map(|(_, a)| *a as u128).sum();
            if debit != credit {
                return Err(refusal("CONSERVATION_BREACH", vec![("debit_total", debit.to_string()), ("credit_total", credit.to_string())], "the debits and the credits of a posting must be equal"));
            }
            let accs = accounts(st, tenant, ledger, keys)?;
            for ((k, a), (credit, amt)) in keys.iter().zip(&accs).zip(legs) {
                if !*credit && a.balance < *amt {
                    return Err(refusal("INSUFFICIENT_FUNDS", vec![("key", k.to_string()), ("balance", a.balance.to_string()), ("needed", amt.to_string())], ""));
                }
                if *credit && a.balance.checked_add(*amt).map_or(true, |b| b > max_balance) {
                    return Err(refusal("BALANCE_LIMIT", vec![("key", k.to_string()), ("max_balance", max_balance.to_string())], ""));
                }
            }
            Ok(())
        }
        Op::Mint { ledger, amt } | Op::Burn { ledger, amt } => {
            let (fixed, max_balance, _) = ledger_policy(pols, ledger)?;
            if fixed { return Err(refusal("ISSUANCE_DISABLED", vec![], "this ledger has a fixed supply: no mint, no burn")) }
            if *amt == 0 { return Err(refusal("ZERO_AMOUNT", vec![("index", "0".into())], "")) }
            let a = accounts(st, tenant, ledger, keys)?[0];
            if matches!(op, Op::Mint { .. }) {
                if a.balance.checked_add(*amt).map_or(true, |b| b > max_balance) {
                    return Err(refusal("BALANCE_LIMIT", vec![("key", keys[0].to_string()), ("max_balance", max_balance.to_string())], ""));
                }
            } else if a.balance < *amt {
                return Err(refusal("INSUFFICIENT_FUNDS", vec![("key", keys[0].to_string()), ("balance", a.balance.to_string()), ("needed", amt.to_string())], ""));
            }
            Ok(())
        }
        Op::Claim { reg, name } | Op::Release { reg, name } => {
            let handle = format!("reg:{tenant}");
            if keys.len() != 1 || keys[0] != handle { return Err(refusal("MALFORMED_REQUEST", vec![("why", "REGISTRY_KEY".into()), ("expected", handle)], "the key of a claim is the caller's own handle")) }
            let (fold, max_name) = match pols.get(reg) {
                None => return Err(refusal("UNKNOWN_POLICY", vec![], "no ledger_graph policy of that name is pinned in this store")),
                Some(Policy::Registry { fold, max_name }) => (*fold, *max_name),
                Some(_) => return Err(refusal("WRONG_POLICY_KIND", vec![("policy_kind", "not_registry".into())], "the policy is not a registry")),
            };
            if name.len() > max_name { return Err(refusal("MALFORMED_REQUEST", vec![("why", "NAME".into()), ("max_name_bytes", max_name.to_string())], "")) }
            let holder = st.names.get(&(reg.clone(), canon(name, fold)));
            if matches!(op, Op::Claim { .. }) {
                if holder.is_some() { return Err(refusal("DUPLICATE_KEY", vec![("registry", reg.clone())], "the name is taken")) }
            } else if holder.map(|h| h.as_str()) != Some(tenant) {
                return Err(refusal("NOT_HOLDER", vec![("registry", reg.clone())], "only the holder can release a name"));
            }
            Ok(())
        }
        Op::AddEdge { graph, .. } => {
            graph_of(st, pols, tenant, keys[0], graph)?; // the edges: graph_add (decide: on a copy; fold: in place)
            Ok(())
        }
        Op::RemoveEdge { graph, from, to } => {
            let g = graph_of(st, pols, tenant, keys[0], graph)?;
            if !g.and_then(|g| g.out.get(from.as_str())).is_some_and(|s| s.contains(to.as_str())) {
                return Err(refusal("NO_SUCH_EDGE", vec![("edge", format!("{from}->{to}"))], ""));
            }
            Ok(())
        }
    }
}

/// The graph of a key (None: a new graph), after the key, kind, policy and tenant checks.
fn graph_of<'s>(st: &'s State, pols: &Policies<Policy>, tenant: &str, key: &str, policy: &str) -> Result<Option<&'s Graph>, Refusal> {
    match pols.get(policy) {
        None => return Err(refusal("UNKNOWN_POLICY", vec![], "no ledger_graph policy of that name is pinned in this store")),
        Some(Policy::Graph { .. }) => {}
        Some(_) => return Err(refusal("WRONG_POLICY_KIND", vec![("policy_kind", "not_graph".into())], "the policy is not a graph")),
    }
    if key.starts_with("reg:") { return Err(malformed("RESERVED_KEY", "keys that start with reg: are registry handles")) }
    match kind_of(st, key) {
        Some("graph") | None => {}
        Some(kind) => return Err(refusal("WRONG_KEY_KIND", vec![("key", key.to_string()), ("kind", kind.into())], "the key is not a graph")),
    }
    let g = st.graphs.get(key);
    if let Some(g) = g {
        if g.tenant != tenant { return Err(refusal("CROSS_TENANT", vec![("key", key.to_string())], "")) }
        if g.policy != policy { return Err(refusal("POLICY_MISMATCH", vec![("policy", g.policy.clone())], "the graph key is bound to another graph policy")) }
    }
    Ok(g)
}

/// Applies a checked op. Err for an arithmetic fault, or (add_edge) for an edge that `graph_add` refuses.
fn apply(st: &mut State, pols: &Policies<Policy>, tenant: &str, keys: &[&str], op: &Op) -> Result<(), String> {
    let lkey = |l: &str| (tenant.to_string(), l.to_string());
    let credit = |st: &mut State, k: &str, amt: u64| -> Result<(), String> {
        let a = st.accounts.get_mut(k).ok_or("ACCOUNT")?;
        a.balance = a.balance.checked_add(amt).ok_or("OVERFLOW")?;
        Ok(())
    };
    let debit = |st: &mut State, k: &str, amt: u64| -> Result<(), String> {
        let a = st.accounts.get_mut(k).ok_or("ACCOUNT")?;
        a.balance = a.balance.checked_sub(amt).ok_or("UNDERFLOW")?;
        Ok(())
    };
    match op {
        Op::Open { ledger, bals } => {
            let l = st.ledgers.entry(lkey(ledger)).or_default();
            for (k, b) in keys.iter().zip(bals) {
                l.issued = l.issued.checked_add(*b as u128).ok_or("OVERFLOW")?;
                l.total = l.total.checked_add(*b as u128).ok_or("OVERFLOW")?;
                l.accounts += 1;
                st.accounts.insert(k.to_string(), Account { tenant: tenant.into(), ledger: ledger.clone(), balance: *b });
            }
        }
        Op::Transfer { from, to, amt, .. } => {
            debit(st, from, *amt)?;
            credit(st, to, *amt)?;
        }
        Op::Post { legs, .. } => {
            for (k, (c, amt)) in keys.iter().zip(legs) {
                if *c { credit(st, k, *amt)? } else { debit(st, k, *amt)? }
            }
        }
        Op::Mint { ledger, amt } => {
            credit(st, keys[0], *amt)?;
            let l = st.ledgers.get_mut(&lkey(ledger)).ok_or("LEDGER")?;
            l.issued = l.issued.checked_add(*amt as u128).ok_or("OVERFLOW")?;
            l.total = l.total.checked_add(*amt as u128).ok_or("OVERFLOW")?;
        }
        Op::Burn { ledger, amt } => {
            debit(st, keys[0], *amt)?;
            let l = st.ledgers.get_mut(&lkey(ledger)).ok_or("LEDGER")?;
            l.destroyed = l.destroyed.checked_add(*amt as u128).ok_or("OVERFLOW")?;
            l.total = l.total.checked_sub(*amt as u128).ok_or("UNDERFLOW")?;
        }
        Op::Claim { reg, name } => {
            let fold = matches!(pols.get(reg), Some(Policy::Registry { fold: true, .. }));
            st.names.insert((reg.clone(), canon(name, fold)), tenant.into());
            *st.reg_keys.entry(keys[0].to_string()).or_insert(0) += 1;
        }
        Op::Release { reg, name } => {
            let fold = matches!(pols.get(reg), Some(Policy::Registry { fold: true, .. }));
            st.names.remove(&(reg.clone(), canon(name, fold))).ok_or("NOT_HELD")?;
            let c = st.reg_keys.entry(keys[0].to_string()).or_insert(0);
            *c = c.checked_sub(1).ok_or("COUNT")?;
        }
        Op::AddEdge { graph, edges } => {
            let (max_nodes, max_edges) = graph_limits(pols, graph);
            let g = st.graphs.entry(keys[0].to_string()).or_insert_with(|| Graph::new(tenant, graph));
            graph_add(g, edges, max_nodes, max_edges).map_err(|r| format!("RECHECK {}", r.code))?;
        }
        Op::RemoveEdge { from, to, .. } => {
            let g = st.graphs.get_mut(keys[0]).ok_or("GRAPH")?;
            let s = g.out.get_mut(from.as_str()).ok_or("EDGE")?;
            if !s.remove(to.as_str()) { return Err("EDGE".into()) }
            if s.is_empty() { g.out.remove(from.as_str()); }
            let s = g.inn.get_mut(to.as_str()).ok_or("EDGE")?;
            if !s.remove(from.as_str()) { return Err("EDGE".into()) }
            if s.is_empty() { g.inn.remove(to.as_str()); }
            for n in [from, to] {
                if !g.out.contains_key(n.as_str()) && !g.inn.contains_key(n.as_str()) { g.ord.remove(n.as_str()); }
            }
            g.edges = g.edges.checked_sub(1).ok_or("EDGES")?;
        }
    }
    Ok(())
}

fn op_ledger(op: &Op) -> Option<&str> {
    match op {
        Op::Open { ledger, .. } | Op::Transfer { ledger, .. } | Op::Post { ledger, .. } | Op::Mint { ledger, .. } | Op::Burn { ledger, .. } => Some(ledger),
        _ => None,
    }
}

impl Primitive for LedgerGraph {
    const NAME: &'static str = "ledger_graph";
    const OPS: &'static [OpSpec] = &[
        OpSpec { op: "open", min_keys: 1, max_keys: 16, cas: Cas::Required },
        OpSpec { op: "transfer", min_keys: 2, max_keys: 2, cas: Cas::Required },
        OpSpec { op: "post", min_keys: 2, max_keys: 16, cas: Cas::Required },
        OpSpec { op: "mint", min_keys: 1, max_keys: 1, cas: Cas::Required },
        OpSpec { op: "burn", min_keys: 1, max_keys: 1, cas: Cas::Required },
        OpSpec { op: "claim", min_keys: 1, max_keys: 1, cas: Cas::AnyAllowed },
        OpSpec { op: "release", min_keys: 1, max_keys: 1, cas: Cas::AnyAllowed },
        OpSpec { op: "add_edge", min_keys: 1, max_keys: 1, cas: Cas::Required },
        OpSpec { op: "remove_edge", min_keys: 1, max_keys: 1, cas: Cas::Required },
    ];
    type Policy = Policy;
    type State = State;

    fn parse_policy(doc: &J) -> Result<Policy, String> {
        let kind = match doc.get("kind") { Some(J::Str(k)) => k.as_str(), _ => return Err("MISSING kind".into()) };
        let range = |f: &BTreeMap<String, &str>, k: &str, lo: u64, hi: u64| {
            dec_u64(f[k]).filter(|v| (lo..=hi).contains(v)).ok_or_else(|| format!("RANGE {k} {lo}..{hi}"))
        };
        match kind {
            "ledger" => {
                let f = policy_fields(doc, &["kind", "issuance", "max_balance", "max_legs"])?;
                let fixed = match f["issuance"] { "fixed" => true, "mint_burn" => false, _ => return Err("ISSUANCE fixed|mint_burn".into()) };
                Ok(Policy::Ledger { fixed, max_balance: range(&f, "max_balance", 1, u64::MAX)?, max_legs: range(&f, "max_legs", 2, 16)? as usize })
            }
            "registry" => {
                let f = policy_fields(doc, &["kind", "case", "max_name_bytes"])?;
                let fold = match f["case"] { "ascii_fold" => true, "exact" => false, _ => return Err("CASE exact|ascii_fold".into()) };
                Ok(Policy::Registry { fold, max_name: range(&f, "max_name_bytes", 1, 256)? as usize })
            }
            "graph" => {
                let f = policy_fields(doc, &["kind", "max_nodes", "max_edges"])?;
                Ok(Policy::Graph { max_nodes: range(&f, "max_nodes", 2, 1_000_000)?, max_edges: range(&f, "max_edges", 1, 4_000_000)? })
            }
            _ => Err("KIND ledger|registry|graph".into()),
        }
    }

    fn decide(req: &Request, state: &State, policies: &Policies<Policy>, _now: &Now) -> Decision {
        let keys: Vec<&str> = req.keys.iter().map(|k| k.key).collect();
        let op = match parse(req.op, req.args) { Ok(op) => op, Err(r) => return Decision::Refuse(r) };
        if let Err(r) = check(state, policies, req.tenant, &keys, &op) { return Decision::Refuse(r) }
        if let Op::AddEdge { graph, edges } = &op {
            let (max_nodes, max_edges) = graph_limits(policies, graph);
            let mut g = state.graphs.get(keys[0]).cloned().unwrap_or_else(|| Graph::new(req.tenant, graph));
            if let Err(r) = graph_add(&mut g, edges, max_nodes, max_edges) { return Decision::Refuse(r) }
        }
        Decision::Commit(payload(&op, policies))
    }

    fn fold(state: &mut State, rec: &Record, policies: &Policies<Policy>) -> Result<(), String> {
        if rec.kind != Kind::Commit { return Err("REFUSAL_RECORD".into()) }
        let op = parse(rec.op, rec.payload).map_err(|_| "PAYLOAD".to_string())?;
        if payload(&op, policies) != rec.payload { return Err("NOT_CANONICAL".into()) }
        check(state, policies, rec.tenant, rec.keys, &op).map_err(|r| format!("RECHECK {}", r.code))?;
        apply(state, policies, rec.tenant, rec.keys, &op)?;
        if let Some(l) = op_ledger(&op) {
            let s = &state.ledgers[&(rec.tenant.to_string(), l.to_string())];
            if Some(s.total) != s.issued.checked_sub(s.destroyed) { return Err("CONSERVATION".into()) }
        }
        Ok(())
    }

    fn describe(state: &State, key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        if let Some(a) = state.accounts.get(key) {
            let l = state.ledgers.get(&(a.tenant.clone(), a.ledger.clone()))?;
            return Some(vec![
                ("kind", "account".into()),
                ("ledger", a.ledger.clone()),
                ("balance", a.balance.to_string()),
                ("ledger_total", l.total.to_string()),
                ("ledger_issued", l.issued.to_string()),
                ("ledger_destroyed", l.destroyed.to_string()),
                ("ledger_accounts", l.accounts.to_string()),
            ]);
        }
        if let Some(c) = state.reg_keys.get(key) {
            return Some(vec![("kind", "registry".into()), ("claims", c.to_string())]);
        }
        let g = state.graphs.get(key)?;
        Some(vec![("kind", "graph".into()), ("policy", g.policy.clone()), ("nodes", g.ord.len().to_string()), ("edges", g.edges.to_string())])
    }
}
