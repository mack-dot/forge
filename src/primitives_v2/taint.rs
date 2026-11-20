//! Primitive 8, `taint_egress`: STUB. Owner: the worker of primitive 8, who replaces the body of this file (and only
//! this file). NATIVE CHECK when filled; nothing here is proved. Until then every op answers
//! `NOT_IMPLEMENTED` with no record, every policy file of this primitive is refused at `init`, and every WAL record
//! of this primitive refuses the store at replay.
//!
//! Binding (do not change): the unit struct `Taint`, `impl Primitive for Taint` with the signatures of prim.rs, and
//! the constant `NAME = "taint_egress"`. Free to change: `OPS`, the `Policy` and `State` types, the bodies.
//! Engine rule for a stateless check (max_keys = 0): the module returns `Decision::Answer` (allow) or
//! `Decision::Refuse` (block); the engine writes NO record for either (PROTOCOL.md section 7.4).
use crate::json::J;
use crate::prim::{refusal, Cas, Decision, Now, OpSpec, Policies, Primitive, Record, Request};

pub struct Taint;

pub struct Policy;

#[derive(Default)]
pub struct State;

impl Primitive for Taint {
    const NAME: &'static str = "taint_egress";
    const OPS: &'static [OpSpec] = &[
        OpSpec { op: "check", min_keys: 0, max_keys: 0, cas: Cas::Required },
    ];
    type Policy = Policy;
    type State = State;

    fn parse_policy(_doc: &J) -> Result<Policy, String> {
        Err("NOT_IMPLEMENTED taint_egress".into())
    }
    fn decide(_req: &Request, _state: &State, _policies: &Policies<Policy>, _now: &Now) -> Decision {
        Decision::Refuse(refusal("NOT_IMPLEMENTED", vec![("primitive", "taint_egress".into())], "primitive 8 is a stub in this build"))
    }
    fn fold(_state: &mut State, _rec: &Record, _policies: &Policies<Policy>) -> Result<(), String> {
        Err("NOT_IMPLEMENTED taint_egress".into())
    }
    fn describe(_state: &State, _key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        None
    }
}
