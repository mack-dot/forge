//! Cosign TTL, the engine side (primitive 6, "cryptographic TTL expiration on cosign tokens"). NATIVE CHECK, not
//! proved. Status: the TIME part is implemented; the SIGNATURE part is a precise STUB (`verify` answers
//! NOT_IMPLEMENTED and never accepts).
//!
//! Message (exactly seven LF-terminated lines; at most 4,096 bytes):
//!   forge-primitives-cosign-v1\n<store_id>\n<genesis_hash 64 hex>\n<request_id>\n<pre_state_hash 64 hex or *>\n
//!   <not_after_ms>\n<action>\n
//! `not_after_ms` (canonical decimal u64) is INSIDE the signed bytes, so a holder cannot extend it without a new
//! signature. The engine compares it with its trusted `Now` (clock.rs), never with a time from the request:
//! - `now_ms > not_after_ms`: `COSIGN_EXPIRED expired_by_ms=<now - not_after>` (the token is valid up to and
//!   including not_after_ms);
//! - `not_after_ms - now_ms > max_ttl_ms`: `COSIGN_TTL_TOO_LONG max_ttl_ms=<m>` (a token may not live longer than
//!   the policy allows, so an old signature cannot be kept for later use).
//! With the clock rule `now = max(wall, newest record time, monotonic floor)`, a clock set back cannot revive a token
//! that expired before the newest record. Limit: it can revive a token that expired AFTER the newest record (no
//! record holds the later time). A host administrator who moves the clock forward expires every token early.
//!
//! Signature (NOT implemented here): the owner's approved method is `/usr/bin/ssh-keygen -Y verify` (reviewed design
//! on the unmerged branch `apex1/native-cosign`, `src/airlock/cosign.rs` and its PROTOCOL.md section 7: strict
//! base64 and SSHSIG parsing, weak-R and S < L checks, the pinned key compared before the run, a private 0700
//! folder, an exact compare of the "Good" line with the fingerprint of the pinned key, every other result
//! HELPER_FAILED). It is left out because it needs a subprocess runner, a key pin in the genesis record and that
//! review's test set; copying 250 lines of an unmerged branch into a second place would split one reviewed design.
//! The order of checks when it is added: message form -> TTL (this file, no subprocess) -> signature. A TTL refusal
//! never runs ssh-keygen.
#![allow(dead_code)] // `verify` is the stub of the signature check
use crate::prim::{dec_u64, refusal, Now, Refusal};
use crate::store::canonical_id;

pub const MESSAGE_VERSION: &str = "forge-primitives-cosign-v1";
pub const MAX_MESSAGE: usize = 4096;

/// The exact signed bytes. Err for a field that could move a line boundary or is not canonical.
pub fn message(store_id: &str, genesis_hash: &str, request_id: &str, pre_state_hash: &str, not_after_ms: u64, action: &str) -> Result<String, Refusal> {
    let bad = |why: &str| refusal("MALFORMED_REQUEST", vec![("why", why.to_string())], "cosign message field");
    if !canonical_id(store_id) { return Err(bad("STORE_ID")) }
    if crate::store::parse_hash(genesis_hash).is_none() { return Err(bad("GENESIS_HASH")) }
    if !canonical_id(request_id) { return Err(bad("REQUEST_ID")) }
    if pre_state_hash != "*" && crate::store::parse_hash(pre_state_hash).is_none() { return Err(bad("PRE_STATE_HASH")) }
    if action.is_empty() || !crate::store::printable(action.as_bytes()) { return Err(bad("ACTION")) }
    let m = format!("{MESSAGE_VERSION}\n{store_id}\n{genesis_hash}\n{request_id}\n{pre_state_hash}\n{not_after_ms}\n{action}\n");
    if m.len() > MAX_MESSAGE { return Err(bad("TOO_LONG")) }
    Ok(m)
}

/// The TTL rule. Ok: the milliseconds the token stays valid (0 = valid only at this ms).
pub fn ttl_check(not_after_ms: u64, max_ttl_ms: u64, now: &Now) -> Result<u64, Refusal> {
    if now.now_ms > not_after_ms {
        return Err(refusal("COSIGN_EXPIRED", vec![("expired_by_ms", (now.now_ms - not_after_ms).to_string())], "the cosign token is past its not_after_ms"));
    }
    let left = not_after_ms - now.now_ms;
    if left > max_ttl_ms {
        return Err(refusal("COSIGN_TTL_TOO_LONG", vec![("max_ttl_ms", max_ttl_ms.to_string())], "the token lives longer than allowed"));
    }
    Ok(left)
}
pub fn parse_ms(s: &str) -> Option<u64> {
    dec_u64(s)
}

/// STUB: the signature check. It never accepts.
pub fn verify(_store_dir: &str, _key_token: &str, _sig_token: &str, _message: &str) -> Result<bool, Refusal> {
    Err(refusal("NOT_IMPLEMENTED", vec![("why", "COSIGN_SIGNATURE".into())], "the ssh-keygen signature check is not in this build"))
}
