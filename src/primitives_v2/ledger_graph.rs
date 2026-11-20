//! Primitive 7, `ledger_graph`: STUB. Owner: the worker of primitive 7, who replaces the body of this file (and only
//! this file). NATIVE CHECK when filled; nothing here is proved. Until then every op answers
//! `NOT_IMPLEMENTED` with no record, every policy file of this primitive is refused at `init`, and every WAL record
//! of this primitive refuses the store at replay.
//!
//! Binding (do not change): the unit struct `LedgerGraph`, `impl Primitive for LedgerGraph` with the signatures of prim.rs, and
//! the constant `NAME = "ledger_graph"`. Free to change: `OPS`, the `Policy` and `State` types, the bodies.
//! Engine side ready for it: a request names up to 16 keys in strictly ascending byte order, each with its present
//! state hash (Cas::Required); the engine compares ALL of them before the module decides, writes ONE record that
//! names all keys, and sets the state hash of every key to the hash of that record (PROTOCOL.md section 7.3).
use crate::json::J;
use crate::prim::{refusal, Cas, Decision, Now, OpSpec, Policies, Primitive, Record, Request};

pub struct LedgerGraph;

pub struct Policy;

#[derive(Default)]
pub struct State;

impl Primitive for LedgerGraph {
    const NAME: &'static str = "ledger_graph";
    const OPS: &'static [OpSpec] = &[
        OpSpec { op: "transfer", min_keys: 2, max_keys: 16, cas: Cas::Required },
        OpSpec { op: "claim", min_keys: 1, max_keys: 1, cas: Cas::Required },
        OpSpec { op: "add_edge", min_keys: 1, max_keys: 16, cas: Cas::Required },
    ];
    type Policy = Policy;
    type State = State;

    fn parse_policy(_doc: &J) -> Result<Policy, String> {
        Err("NOT_IMPLEMENTED ledger_graph".into())
    }
    fn decide(_req: &Request, _state: &State, _policies: &Policies<Policy>, _now: &Now) -> Decision {
        Decision::Refuse(refusal("NOT_IMPLEMENTED", vec![("primitive", "ledger_graph".into())], "primitive 7 is a stub in this build"))
    }
    fn fold(_state: &mut State, _rec: &Record, _policies: &Policies<Policy>) -> Result<(), String> {
        Err("NOT_IMPLEMENTED ledger_graph".into())
    }
    fn describe(_state: &State, _key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        None
    }
}
