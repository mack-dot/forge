//! The trusted clock of the primitives engine (primitive 6). NATIVE CHECK, not proved.
//!
//! The engine reads the time itself. No request field is ever a time.
//!
//! Rule: `now_ms = max(wall_ms, last_ms, mono_floor_ms)`, where
//! - `wall_ms` is `SystemTime::now()` in ms since the Unix epoch (0 for a clock before 1970);
//! - `last_ms` is the engine time of the newest record in the WAL (the WAL times never go back: the fold checks it);
//! - `mono_floor_ms` is `anchor_ms + (Instant::now() - anchor_instant)`: at the first reading of the process the
//!   engine keeps (now_ms, Instant); later readings of the SAME process cannot fall below that anchor plus the
//!   monotonic time that has passed since. 0 at the first reading.
//!
//! Why: a wall clock set back (by an operator, by NTP, or a restored machine image) must never reopen a window or end
//! a cooldown early. With the max rule, time as the engine sees it never goes back past the newest record. While the
//! wall clock is behind, the engine reports `skew_ms` (how far behind) in `STATE` and in every answer that writes.
//! The monotonic floor lets time go on inside one process while the wall clock is behind.
//!
//! A monotonic reading means nothing across processes: `Instant` has a per-boot, per-process origin, and on macOS it
//! does not count the time the machine sleeps. The engine never writes it to the WAL and never compares readings of
//! two processes. A new process starts with no monotonic floor; its floor is the newest record time.
//!
//! Limits, stated plainly: the engine trusts the host clock. A host administrator who moves the clock FORWARD ends
//! every window and every cooldown early, and a time once written stays the floor (a clock set far forward by
//! mistake freezes the engine time at that value until the wall clock passes it: windows then stay full; fail
//! closed, but a denial of service). A store whose WAL is restored to an older copy forgets the newer records, so
//! their events and rejections are forgiven; the engine cannot see that. Nothing here is a secure time source.
//!
//! Test seam, live ONLY in the `--cfg test_seams` build (build/primitives_v2_test/): PRIMITIVES_TEST_CLOCK=<file>,
//! the file holds `<wall_ms> <mono_ms>` and is read at every reading in place of SystemTime and Instant. In the
//! production build `cfg!(test_seams)` is false and the variable is never read.
use crate::prim::{refusal, Now, Refusal};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

pub struct Clock {
    origin: Instant,
    anchor: Option<(u64, u64)>, // (now_ms at the first reading, monotonic ms at the first reading)
}

fn wall_ms() -> u64 {
    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(d) => u64::try_from(d.as_millis()).unwrap_or(u64::MAX),
        Err(_) => 0, // a clock before 1970: the max rule keeps the newest record time
    }
}

/// The test seam: (wall_ms, mono_ms) from the file PRIMITIVES_TEST_CLOCK names. Never in the production build.
fn seam_reading() -> Option<Result<(u64, u64), Refusal>> {
    let path = if cfg!(test_seams) { std::env::var("PRIMITIVES_TEST_CLOCK").ok() } else { None };
    let path = path?;
    let bad = || refusal("IO_ERROR", vec![("why", "TEST_CLOCK".to_string())], "the test clock file is not `<wall_ms> <mono_ms>`");
    let text = match std::fs::read_to_string(&path) { Ok(t) => t, Err(_) => return Some(Err(bad())) };
    let mut it = text.trim_end_matches('\n').split(' ');
    let (w, m) = (it.next().and_then(crate::prim::dec_u64), it.next().and_then(crate::prim::dec_u64));
    match (w, m, it.next()) {
        (Some(w), Some(m), None) => Some(Ok((w, m))),
        _ => Some(Err(bad())),
    }
}

impl Clock {
    pub fn new() -> Self {
        Clock { origin: Instant::now(), anchor: None }
    }
    /// One reading. `last_ms` is the newest record time of the WAL (read under the lock).
    pub fn read(&mut self, last_ms: u64) -> Result<Now, Refusal> {
        let (wall, mono) = match seam_reading() {
            Some(r) => r?,
            None => (wall_ms(), u64::try_from(self.origin.elapsed().as_millis()).unwrap_or(u64::MAX)),
        };
        let floor = match self.anchor {
            Some((at, m0)) => at.saturating_add(mono.saturating_sub(m0)),
            None => 0,
        };
        let now_ms = wall.max(last_ms).max(floor);
        if self.anchor.is_none() { self.anchor = Some((now_ms, mono)) }
        Ok(Now { now_ms, wall_ms: wall, skew_ms: now_ms - wall })
    }
}
