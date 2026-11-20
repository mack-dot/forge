//! `cas_probe`: a TEST module, compiled ONLY into the `--cfg test_seams` build (main.rs: `#[cfg(test_seams)] mod
//! probe;`). It exists to drive the engine's multi-key compare-and-swap before primitive 7 is filled. It decides
//! nothing of value: `put` writes one value token to 1 to 16 keys in one record. The production build has no such
//! primitive (`MALFORMED_REQUEST why=UNKNOWN_PRIMITIVE`). FINITE TEST support, not proved.
use crate::json::J;
use crate::prim::{dec_u64, refusal, Cas, Decision, Kind, Now, OpSpec, Policies, Primitive, Record, Request};
use std::collections::BTreeMap;

pub struct CasProbe;
pub struct Policy;
#[derive(Default)]
pub struct State {
    values: BTreeMap<String, u64>,
}

impl Primitive for CasProbe {
    const NAME: &'static str = "cas_probe";
    const OPS: &'static [OpSpec] = &[OpSpec { op: "put", min_keys: 1, max_keys: 16, cas: Cas::Required }];
    type Policy = Policy;
    type State = State;
    fn parse_policy(_doc: &J) -> Result<Policy, String> {
        Err("cas_probe takes no policy".into())
    }
    fn decide(req: &Request, _state: &State, _policies: &Policies<Policy>, _now: &Now) -> Decision {
        match dec_u64(req.args) {
            Some(v) => Decision::Commit(v.to_string()),
            None => Decision::Refuse(refusal("MALFORMED_REQUEST", vec![("why", "PROBE_ARGS".into())], "args: <decimal>")),
        }
    }
    fn fold(state: &mut State, rec: &Record, _policies: &Policies<Policy>) -> Result<(), String> {
        let v = dec_u64(rec.payload).filter(|_| rec.kind == Kind::Commit).ok_or("PAYLOAD")?;
        for k in rec.keys {
            state.values.insert(k.to_string(), v);
        }
        Ok(())
    }
    fn describe(state: &State, key: &str, _policies: &Policies<Policy>, _now: &Now) -> Option<Vec<(&'static str, String)>> {
        state.values.get(key).map(|v| vec![("value", v.to_string())])
    }
}
