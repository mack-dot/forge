//! Primitive 9, `farkas`: STUB. Owner: the worker of primitive 9, who replaces the body of this file (and only
//! this file). NATIVE CHECK when filled; nothing here is proved. Until then every op answers
//! `NOT_IMPLEMENTED` with no record, every policy file of this primitive is refused at `init`, and every WAL record
//! of this primitive refuses the store at replay.
//!
//! Binding (do not change): the unit struct `Farkas`, `impl Primitive for Farkas` with the signatures of prim.rs, and
//! the constant `NAME = "farkas"`. Free to change: `OPS`, the `Policy` and `State` types, the bodies.
//! The native Farkas check is a stateless check (max_keys = 0) like primitive 8 (PROTOCOL.md section 7.4).
use crate::json::J;
use crate::prim::{refusal, Cas, Decision, Now, OpSpec, Policies, Primitive, Record, Request};

pub struct Farkas;

pub struct Policy;

#[derive(Default)]
pub struct State;

impl Primitive for Farkas {
    const NAME: &'static str = "farkas";
    const OPS: &'static [OpSpec] = &[
        OpSpec { op: "check", min_keys: 0, max_keys: 0, cas: Cas::Required },
    ];
    type Policy = Policy;
    type State = State;

    fn parse_policy(_doc: &J) -> Result<Policy, String> {
        Err("NOT_IMPLEMENTED farkas".into())
    }
    fn decide(_req: &Request, _state: &State, _policies: &Policies<Policy>, _now: &Now) -> Decision {
        Decision::Refuse(refusal("NOT_IMPLEMENTED", vec![("primitive", "farkas".into())], "primitive 9 is a stub in this build"))
    }
    fn fold(_state: &mut State, _rec: &Record, _policies: &Policies<Policy>) -> Result<(), String> {
        Err("NOT_IMPLEMENTED farkas".into())
    }
    fn describe(_state: &State, _key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        None
    }
}
