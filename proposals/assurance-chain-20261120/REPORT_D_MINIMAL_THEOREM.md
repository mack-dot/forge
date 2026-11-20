# Report D: the minimal theorem (detection) and the longer theorem (prevention)

Two theorems, kept apart:
- D-1 is about a VERIFIER. It reads a durable log and decides if the log respects the spec.
- D-2 is about the ENGINE. It says the engine cannot make a disallowed durable transition.

D-1 answers the owner's question with the fewest assumptions. Neither theorem is proved. Both are targets. `end_to_end=false`.

## 0. The fact that decides the structure (re-checked by reading)

`Eligible(c, r)` (`spec/refund/RefundSpec.dfy:33-36`) = `ValidContext(c) ∧ r.Candidate? ∧ 0 ≤ r.amount ≤ c.remaining ∧ AllowedReason(r.reason)`. `ValidContext` (`:27-31`) = `chargeId ≠ "" ∧ requestId ≠ "" ∧ refundEnabled ∧ requestOpen ∧ Money(original) ∧ 0 ≤ remaining ≤ original`.

| Conjunct | Silicon sink: native check after the binary, under the lock | Airlock canonical refund |
| --- | --- | --- |
| `chargeId ≠ ""`, `requestId ≠ ""` | `canonical_id` (1–24 bytes) in `parse` (`sink.rs:136`); the charge is equal to the stored one (`:168`) | `id()` in `parse_refund` (`verbs.rs:136`) |
| `Money(original)`, `0 ≤ remaining ≤ original` | CAS on original and remaining against the fold (`:168`); the fold keeps `remaining` in [0, original] (`:90-93`) | CAS on the key hash (`verbs.rs:73`) |
| `0 ≤ amount ≤ remaining` | `u64`; `:171` | `u64`; `:177` |
| `AllowedReason` | `:163` | `:177` |
| `Candidate?` | true by construction (the request carries amount and reason) | same |
| `requestOpen` (as a bit) | NOT read. The caller's bit is checked for spelling only (`:133`). The id-freshness check (`:167`) is its stateful meaning | constant `True` (`:174`); id freshness at `:72` |
| `refundEnabled` (as a bit) | NOT read; caller's bit, spelling only (`:133`). No stored counterpart: the genesis record has no such field (`sink.rs:7-11`) | constant `True`; the profile choice `m.canonical` (`:168`) |

Consequences:
- Under a stateful spec that defines `requestOpen := id ∉ settled` and fixes `refundEnabled` from stored state, the native checks imply `Eligible`. The binary's answer is then never needed for safety.
- A `False` bit sent to the binary can only cause a rejection.
- The binary carries weight only for completeness (D-2 C4), and in a design where the binary decides alone (D-2b).

## 1. New specification text that both theorems need (NOT approved; edge A1.5 MISSING)

The approved `RefundSpec` (`90a21c71…`) is stateless. The text below extends it without changing it. It follows the draft `proposals/m1b-mission-20261119/proofs/sink-core/SPEC_STATE_PROPOSAL_U8.txt` ("UNAPPLIED … NOT approved"):
```
datatype StoredCharge = SC(chargeId: string, original: int, remaining: int,
                           refundEnabled: bool, settled: set<string>)
function ContextAt(s: StoredCharge, id: string): Context :=
  ChargeContext(s.chargeId, id, s.original, s.remaining, s.refundEnabled, id !in s.settled)
predicate CommitStep(pre: StoredCharge, id: string, amount: int, reason: string, post: StoredCharge) :=
  Eligible(ContextAt(pre, id), Candidate(amount, reason)) &&
  post == pre.(remaining := pre.remaining - amount, settled := pre.settled + {id})
function Genesis(charge: string, original: int): StoredCharge := SC(charge, original, original, ENABLED0, {})
predicate History(g, steps, states) := |states| == |steps| + 1 && states[0] == Genesis(g) &&
  forall i | 0 <= i < |steps| :: CommitStep(states[i], steps[i].id, steps[i].amount, steps[i].reason, states[i+1])
```

Open decisions for the owner:
- (a) `ENABLED0`. The silicon genesis record has no flag, so the spec must fix the value (for example `true` for every silicon store), or the format must carry it. The earlier draft rule "enabled := the charge matches" makes the flag a tautology, given the charge CAS. That rule is withdrawn.
- (b) Zero amounts. `Eligible` allows `amount = 0`. Zero-amount refunds with fresh ids each commit (`SinkCore.ZeroAmountRepeats`, `SinkCore.dfy:390`). U8 lists `0 < amount` as a separate decision.
- (c) The record format F. These are the meanings of the 64-byte record fields (`sink.rs:7-11`): kind `'1'..'3'` = index + 1 into the three reasons, little-endian u64 amount, NUL-padded id. F is part of what the owner approves, because the dispatched effect is read from these bytes.

At-most-once is a lemma of `History`, not a separate axiom. `requestOpen` is a conjunct of `Eligible`, and `settled` only grows.

## 2. D-1: soundness of a spec-recheck verifier (minimal)

### Objects
- `W`: the bytes of `ledger.wal`. `P`: the bytes of `ledger.epoch`. `D` (optional): the dispatch transcript, i.e. the `COMMITTED <epoch> <fnv> <frame>` lines (`sink.rs:187`). `A` (optional): signed heads or anchors.
- `Decode: bytes[64] → Option<Rec>` and `Encode: Rec → bytes[64]`. These are the format F, written in V's own Dafny text. `Rec` = Genesis(charge, original) | Refund(epoch, pre, id, amount, kind).
- `V(W, P, D, A) ∈ {ACCEPT(n, σ), VIOLATION(i, why), MALFORMED(i, why), ROLLBACK, DISPATCH_MISMATCH(j), USAGE}`. V is a Dafny method.

### Statement
```
theorem D1_RecheckSound
  ∀ W P D A. V(W, P, D, A) = ACCEPT(n, σ) ⇒
    ∃ recs: seq<Rec>, tail: bytes.
      W = Encode(recs[0]) ++ … ++ Encode(recs[n-1]) ++ tail
      ∧ Torn(tail)                         // |tail| < 64, or |tail| = 64 and its CRC fails
      ∧ recs[0] = Genesis(c, o) ∧ c canonical ∧ o ≤ MaxMoney
      ∧ ChainOk(recs) ∧ ∀ i. epoch(recs[i]) = i     // CRC, FNV pre-hash, epochs (integrity of the fold only)
      ∧ ∃ states. History((c, o), Steps(recs[1..n]), states) ∧ states[n-1] = σ
      ∧ ∀ 1 ≤ i < j < n. id(recs[i]) ≠ id(recs[j])          // at-most-once inside W (lemma of History)
      ∧ Σ_{1≤i<n} amount(recs[i]) = o − σ.remaining ≤ o     // conservation (lemma of History)
      ∧ RatchetFloor(P) ≤ n − 1
      ∧ (D given ⇒ every line of D names a distinct epoch e ∈ [1, n) with fnv = fnv128(Encode recs[e])
                   and frame = the frame of recs[e])
      ∧ (A given ⇒ head(recs) extends the last valid signed/anchored head)
```

Completeness (desired; proved or tested): V accepts every `W` that has this shape. Without it, V is sound but may be useless.

Corollary for the owner's question. Assume H_LOG and V(W,…) = ACCEPT. Then:
- Every dispatched refund effect is a record `recs[i]`, `i ≥ 1`.
- That record was a `CommitStep` at the state it was applied to.
- No request id produced two effects.

### Named hypotheses of D-1
| Name | Text | Status today | What can turn it into checked evidence |
| --- | --- | --- | --- |
| H_SPEC' | N2' (section 1) and format F express the owner's authorization | MISSING approval (A1.5) | owner approval, signed (A1.4); the meaning stays a human judgement |
| H_VTOOLS | Dafny 4.11.0 + Z3 4.12.1 are sound; the Dafny compiler, the target runtime and the file-read extern preserve V's meaning | ASSUMED once V exists | partly: two compile targets with equal verdicts (TESTED_ONLY); see "V's trusted base" |
| H_LOG.1 completeness | the bytes V reads are the whole durable WAL of this charge; nothing durable was removed or rewritten | ASSUMED | witness under another uid (V2): checked from the witness's first read onwards. External anchor (V3): checked for rollback and fork beyond the anchored head. Engine-signed heads: NOT enough (the same principal re-signs) |
| H_LOG.2 single store | no second store or fork exists for the same charge | ASSUMED | anchor keyed by charge id (V3); reconciliation (V4) shows effects from another store |
| H_LOG.3 correspondence | each dispatched external effect matches exactly one record, with the meaning given by F | ASSUMED | provider reconciliation (V4), keyed by request id. A dispatch transcript `D` helps only if a principal other than the engine captured it |
| H_LOG.4 genesis | `recs[0]` names the real charge and its real original amount | ASSUMED | reconciliation with the provider's charge record (V4) |
| H_CRYPTO, H_KEY | signatures are EUF-CMA; witness and anchor keys are held only by their principals | needed only with V2/V3 | not closable by proof |

Still assumed after V2–V4:
- the provider's own report;
- the witness host and key custody;
- the anchor operator;
- the drive. A record lost before the witness reads it is either undispatched, or it shows up as a reconciliation mismatch. That is detected only if V4 exists.
- the external effect itself (what the provider did with money).

### V's own trusted base: two options
| | V-Dafny (recommended for V1) | V-CakeML |
| --- | --- | --- |
| Proof | Dafny 4.11.0 + Z3 (pinned in `toolchain/pins.json`) | HOL4 kernel + CakeML `compile_correct` |
| Compilation | Dafny compiler to JS or Python: unverified (ASSUMED) | verified to ARMv8 code in the L3 model |
| Host assumptions | target runtime; file read through an extern | the M1 set returns on the VERIFIER's host: H_ISA, H_LOAD, H_FFI (stdin/stdout only, if V is the "pure filter" shape of `DESIGN.md:298`), X8, H_READ for V's own image |
| Reproducibility | the Dafny pin exists; Dafny runs are rebuildable from `main` | depends on M1-R. A new image means redoing the per-image chain (`DESIGN.md:285-290`). M1-B is open for the present binary in the same way |
| Mitigation | compile to two targets, require equal verdicts; anyone can re-run V on their own machine | same re-run argument |

Judgement:
- V-Dafny first. Its one extra assumption is the unverified Dafny compiler, named and narrowed by target diversity.
- V-CakeML removes that assumption but brings the M1 assumptions back on the verifier's host. It also waits for M1-R.
- For detection, host assumptions weigh less than for the engine. Any party can re-run V on bytes it holds, on its own machine. The engine's run cannot be repeated.

### What D-1 does NOT give
- Prevention. A bad transition is found after it is durable, and possibly after it was dispatched.
- Liveness, timeouts, availability.
- Anything about the engine binary, the Rust code, the CPU, the loader or the FFI. V does not need them.
- Who asked (no requester field; A9.7), or when (A9.8).
- Properties across charges. Each silicon store holds one charge.
- The meaning of the spec (H_SPEC').

## 3. D-2: prevention (the longer path), corrected

### Scenario
- Canonical refund on one charge through the silicon-sink protocol. Abstract state (charge, original, remaining, ids, epoch, tail) (`sink.rs:77-79`).
- The engine MODEL `E_N` includes the native checks (`sink.rs:163-171`). It treats the binary as an arbitrary oracle that may answer anything.

### Statement
```
theorem D2_Prevention   // over E_N; Abs, Scan, Recover as in the WAL model
  C1 (one request, any binary answer b, no crash):
       Abs(Scan(W1)) = Abs(Scan(W0)) ∨ CommitStep(Abs(Scan(W0)), q.id, q.amount, q.reason, Abs(Scan(W1)))
  C2 (every finite trace T of requests, crashes at any write offset, recoveries; W_T := the WAL after T;
      Disp_T := the multiset of COMMITTED lines emitted in T):
       (a) every element of Disp_T names a record of Scan(W_T);
       (b) no request id occurs twice in Disp_T;
       (c) History(genesis of W_T, Scan(W_T)) holds.
  C3 (receipt): VerifyReceipt(pk_W, ρ, anchor) ⇒ ρ names a record of Scan(W_T), and the head extends the anchor.
  C4 (completeness; the only conclusion that uses the binary's theorem):
       q names the present state ∧ Eligible(ContextAt(L, q.id), Candidate(q.amount, q.reason))
       ∧ the binary run reaches Success (no Resource_limit_hit) ∧ no other writer ⇒ E_N commits q.
```
This fixes defect 9:
- C2 speaks of dispatched effects across all crash and recovery histories, which is where H_ROLLBACK matters.
- `W_T` is bound to the trace.
- "At most one record per id in `Scan(W')`" alone would be true by construction, because `scan` stops at a duplicate (`sink.rs:92`).

### Hypotheses per conclusion
| Hypothesis | C1 | C2 | C3 | C4 |
| --- | --- | --- | --- | --- |
| H_SPEC' (N2' + F approved) | yes | yes | yes | yes |
| H_TOOLS_D (Dafny/Z3) | yes | yes | yes | yes |
| H_WAL (Rust `scan`/`commit`/`open_ledger`/`encode` refine `E_N`; TESTED_ONLY at best) | yes | yes | yes | yes |
| H_STORE (`sync_all` ⇒ durable; prefix-closed writes) | — | yes | yes | — |
| H_WRITER (only the engine writes W, P) | — | yes | yes | yes |
| H_ROLLBACK (no joint restore, or the anchor covers it) | — | yes | yes | — |
| H_DISPATCH (one COMMITTED line per commit, after both syncs; `sink.rs:183-187`) | — | yes | — | — |
| H_CRYPTO, H_KEY, H_WITNESS | — | — | yes | — |
| O1 (LO-0006, MF-0002), PF-0004/PX-0001, FC1, M-a wire, M-c flags, M-d run lift (H_PROC) | — | — | — | yes |
| H_ISA, H_LOAD, H_FFI, H_NATIVE (X8), H_READ, H_EXEC, H_LINK (premises 2–11) | — | — | — | yes |
| H_PRINT or H_BRIDGE (or the all-HOL variant) | — | — | — | yes |

The M1 chain and its nine hardware/FFI hypotheses are needed ONLY for C4. The earlier version of this report put them on C1/C2. That was wrong (review defect 6).

### D-2b: the binary as the only decider (why and what it costs)
Use D-2b only if a policy is too complex to recheck natively, so that the native checks at `sink.rs:163-171` are removed from the model. Then C1 and C2 need the C4 column, plus three more items:
- M-c: flags derived from the stored state, which needs L. Today `handle` asks the binary before `open_ledger` takes the lock (`sink.rs:192` vs `:166`). Either the binary runs under the lock, or the flags enter the CAS (defect 10). The airlock already locks first (`store.rs:142`).
- H_BRIDGE: the Dafny lemma "engine accepts on `wire(a)` with the exact frame ⇒ `refund_fields a = AcceptTuple a`".
  - This is hand-written bridge text, not printer output: `machine_sem`, `basis_ffi` and the engine's accept relation have no Dafny image.
  - It absorbs H_EXEC, H_NATIVE and the pipe semantics. H_PRINT does not cover it.
  - It needs a consistency control: a separate module that exhibits a model of the axiom (a definition that satisfies it, proved), and an audit that refuses a variant whose axiom implies `false`.
- The refinement M-i, with `FinalityProtocol` instantiated as follows:
  - The sink has no tag. Set `Tag := ()`, `VerifyTag(c, ()) := NativeOk(c)` (the checks on the state read under the lock), and `minted := {(c, ()) | NativeOk(c)}`.
  - A1 (IdealMac) then holds by construction.
  - A2 (MinterSound, `FinalityProtocol.dfy:47-49`) becomes the lemma `NativeOk(c) ⇒ SpecRel(c)`. This is where the native checks carry the weight; in D-2b, the binary's theorem does.
  - A3 is discharged by the crash model M-g.
  - A4 is not used if `Claim.pre :=` the state read under the lock. The FNV tail compare (`sink.rs:168`) is then a consistency check for the caller, not a premise. FNV is not collision resistant (`sink.rs:12`).

All-HOL variant (reviewer's proposal): put the WAL model in HOL and compose it directly with LO-0006/MF-0002 and PF/PX. The spec crossing reuses FC1 plus the existing Dafny link (`HolLink.dfy`, printer, A3.4).

| | Dafny + H_BRIDGE | All-HOL |
| --- | --- | --- |
| Crossings | machine → Dafny (H_BRIDGE) and HOL → Dafny spec (printer) | HOL → Dafny spec only (printer) |
| Reuse | `FinalityProtocol`, `SinkCore`, `ShellCoreV5` (Dafny) | none for the WAL; F2.7 design only (`DESIGN.md:261-300`) |
| Trusted base | larger (adds H_BRIDGE) | smaller |
| Effort | could not establish | could not establish. `DESIGN.md:396` estimates 9–18 days for a CakeML WAL program (a different, larger object) |

Verdict: the all-HOL variant has the smaller trusted base. I could not establish which one needs less proof work. D-2b matters only if the native checks are removed.

### Existing obligations (for D-2)
- O1: `refund_profile_a_sl_fd1`, `refund_model_frame_meets_exported_contract`, R1. MACHINE_CHECKED, same machine.
- O2: FC1.
- O3: `HolLink.dfy` D1–D4 and `LinkedRefund` (one library axiom).
- O4: `refund_file_code`/`bitmaps` (A5.1 ASSUMED).
- O5: `FinalityProtocol` lemmas.
- O6: `RefundExact.PostIsExact`.
- O7 (frame, formerly "missing" M-b, now existing): PF-0004 `refund_render_fields_prefix_code`, `refund_strict_parse_no_strict_prefix`; PX-0001 `refund_frame_decision`, `refund_strict_parse_exact`. What remains of M-b is only "Rust `frame()` = `refund_render_fields (AcceptTuple a)`" (A6.8b).
- O8: `SinkCore` (`ChainSum` :321, `ZeroAmountRepeats` :390); `ShellCoreV5` (`MoneyInd` :227, `ReplayRowsAuthorized` :266).

### Missing obligations (for D-2)
- M-a (wire, C4 only): `∀a. Valid(a) ⇒ WireText(a) = sexp_to_string (refund_request a)`.
- M-c (flags, C4 and D-2b): the engine sends `(ENABLED0, q.id ∉ L.settled, Grammar(q))`, computed from the locked state.
- M-d (run lift, C4): ML-08/ML-09.
- M-e (FFI witness, C4): narrows H_FFI.
- M-f (fold): `Scan(W ++ Encode(r)) = Ok(Commit(Scan(W), r))` iff `NativeOk`; otherwise E_N writes nothing.
- M-g (crash): `∀k ≤ 64. Recover(W ++ take k (Encode r)) ∈ {Abs W, Commit(Abs W, r)}`; the second case only for k = 64 after sync.
- M-h (ratchet): `Ratchet(P) > Abs(Scan(W)).epoch ⇒` refuse; D7 rule.
- M-i (refinement): see D-2b.
- M-j (effect): `NativeOk(L, q) ⇒ CommitStep(L, q, Commit(L, rec(q)))`. This is the lemma that makes C1 independent of the binary.
- M-k (receipt): C3 under H_CRYPTO, H_KEY, H_WITNESS.
- M-comp: the theorem, in Dafny. The control for any `{:axiom}` is as for H_BRIDGE.

### What D-2 does NOT cover
- The owner's intent.
- CPU, loader, kernel, C FFI, drive (hypotheses only).
- The Rust code itself (only through H_WAL, which is tested).
- The external payment effect; liveness.
- More than one charge; other airlock verbs; MCP; primitives; Dafny-to-JS paths; a root user.
- It is not `end_to_end=true`.

## 4. How D-1 and D-2 relate
- D-1 does not need D-2. D-2 does not need D-1.
- Together they give two things: prevention under H_WAL, and detection that does not rely on H_WAL. A bad record that D-2 rules out in the model is still caught by V if H_WAL is false in reality.
