# Master idea, Pillar II, item F2.0 — design note and protocol model (U415)

Date: 2026-11-17. Design and a MODEL only. No program, key, hash
function, database or binary is proved. No protected file changed.
Not committed. `end_to_end=false`.

## 1. The claim Pillar II wants (target text, NOT established)

"For the pinned checker artifact and the approved spec: every state
change and every outbound effect that the sink commits is a transition
that the approved spec allows from the stored state; each request id
settles at most once."

Nothing below establishes this for a real system. Section 3 lists what
each part needs.

## 2. What IS proved now: the protocol logic, in a model

`FinalityProtocol.dfy`, pinned Dafny, gate options: checker exit 0,
22 verified, 0 errors; `dafny audit` exit 0, 0 findings. Logs:
`results/forge2-pillar2-20261117/attempt-0001..0002` (attempt-0001:
exit 2, a type restriction was missing in my file).

Model: a claim is (spec id, checker id, pre-state, request id, request,
post-state, effect). `Mint` adds a (claim, tag) pair. `Commit(s, c, t)`
changes the system only if the tag verifies, the ids are the sink's
own, the stored state equals the claimed pre-state and the request id
is new. The adversary may call `Commit` with ANY claim and ANY tag, in
any order, and may replay every minted tag, including tags minted under
other spec ids.

| Lemma | Statement |
| --- | --- |
| `CommitPreservesInv` | Under A1, every commit step keeps the invariant, for every claim and tag. |
| `MintPreservesInv` | Under A2, every mint step keeps the invariant. |
| `InvMeaning` | Every settled transition satisfies the spec relation; the settled transitions form one path from the initial state to the stored state; one outbox entry per settled claim; request ids are distinct. |
| `ForgedTagRejected`, `OtherSpecOrCheckerRejected`, `StaleStateRejected`, `ReplayRejected` | Each such call leaves the system unchanged. No assumption needed. |
| `HonestCommitSettles` | An accepted claim is committed and its effect is appended once (acceptance is not vacuous). |

Assumptions, each explicit in the statements:

- **A1 ideal MAC** (`IdealMac`): a tag verifies only if it was minted
  for exactly that claim. A real MAC gives this only up to a forgery
  probability and only while the key is secret.
- **A2 sound minter** (`MintAllowed`): for the sink's own ids, a tag is
  minted only if the spec relation holds for the claim. This is the
  whole content of the checker's correctness. It is ASSUMED here.
- **A3 atomic commit**: `Commit` is one step.
- **A4 faithful state**: the model compares states. A real sink
  compares hashes; that needs collision resistance and a canonical
  encoding.

Negative controls (each is the model with one part removed; pinned
Dafny must reject; all four rejected with exit 4):

| Control | Removed | First failing obligation |
| --- | --- | --- |
| `fixtures/NoNonceCheck.dfy` | request-id freshness | distinct ids; replay rejection |
| `fixtures/NoStateCheck.dfy` | stored-state comparison | the path property |
| `fixtures/NoIdCheck.dfy` | spec-id and checker-id check | settled transitions satisfy the relation |
| `fixtures/NoIdealMac.dfy` | assumption A1 | accepted claim satisfies the relation |

A rejection means "could not be proved". It shows that each part is
used by the proof. It is not a proof that the weakened system is
unsafe.

## 3. What a real system still needs (all NOT RUN)

| Part | Obligation | Kind | Cost estimate |
| --- | --- | --- | --- |
| Checker program | A2 for the exact executable: it emits a tag only when the relation holds for the canonical encoding of the claim | binary-level functional proof | M1-sized. M1 (`refund`) needed U262–U409 and still assumes the entry state, the loader and the real FFI behaviour |
| MAC | A1 | cryptographic assumption (EUF-CMA of HMAC-SHA-256) plus a functional proof of the MAC code, plus key secrecy | assumption stays an assumption; code proof is large |
| Key | secrecy from the untrusted application | operating-system isolation; not provable in Forge | assumption |
| Sink | A3 and the acceptance rule, for the real store | proof or test of the trigger/transaction code; the database engine stays trusted | medium; engine in the trusted base |
| Encoding | A4: canonical serialisation, hash binding | proof of an encoder/decoder pair; collision resistance assumed | medium |
| Symmetric key | with an HMAC the sink can also mint | design choice: accept the sink as fully trusted, or use signatures | decision |

Evidence wording that follows from this: a finite adversarial test
suite is `unit_tested`/tested evidence. The model proof is a proof
about the model. Neither may be recorded as closing the compiler gap or
as `end_to_end=true`.

## 4. Recommended first build step (not started)

Reuse the M1 line instead of a new C program: the `refund` executable
already decides the approved refund relation on a canonical request and
prints the decision. A minter is "that decision plus a tag". The
smallest honest experiment is: (1) fix the claim encoding for refund;
(2) state A2 for the existing M1 theorem shape (output equation ⇒
relation) and see which M1 assumptions carry over; (3) keep the MAC and
the sink as tested components with their assumptions named.

Blocker for (2): the local HOL context was removed on 2026-11-17
(U413). It needs the owner's decision on a rebuild and replay.

## 5. Open decisions for the owner

1. HMAC (sink trusted as a minter) or signatures.
2. First target: refund (reuses M1) or ledger (new checker program).
3. Whether to rebuild the HOL/CakeML toolchain for the checker claim.
