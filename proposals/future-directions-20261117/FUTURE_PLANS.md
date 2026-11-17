# Future plans: three ideas saved on 2026-11-17 (U408)

Status: IDEAS ONLY. Saved by owner instruction ("save them for future
plans"). Nothing here is a stage, a mission requirement, an approval or
a result. Nothing was run. No protected file was changed. M1 stays the
current work (S4–S6, then freeze; owner priority order of 2026-11-13).

Source: a text from another AI model, pasted by the owner on
2026-11-17 ("Forge 2.0", "Proof-Carrying Finality"). Its code results
came from that model's sandbox. They are NOT Forge evidence. Its
literature citations are NOT verified. Its stage numbers 9–11 collide
with Forge's completed Stages 9–11; they are not used here.

Each plan below has: the idea; what I checked and how; the corrected
claim; the cost; the first cheap check; the entry condition.

## Plan A — spec determinism check ("spec arbitrage")

**Idea.** For each approved spec, prove a two-run lemma: if two
post-states and outcomes both satisfy the postcondition for the same
pre-state and request, they are equal. A failed proof gives a concrete
pair of different allowed results. That pair shows a degree of freedom
that an implementation can use.

    lemma SpecIsDeterministic(s, id, req, n1, o1, n2, o2)
      requires WellFormed(s)
      requires Post(s, id, req, n1, o1) && Post(s, id, req, n2, o2)
      ensures n1 == n2 && o1 == o2

**Checked (by reading only; NOT machine-checked).**

- `spec/LedgerSpec.dfy`: C4 states the new balances as a map update of
  the old map. Accounts other than sender, recipient and account 0
  keep their value. The three cases (retry, fresh valid, other) are
  exclusive and cover every request; each fixes `next` and `outcome`.
  So the stored spec looks deterministic. The "five-account bystander
  theft" in the source text applies to a hypothetical rewrite of C4 as
  separate relational clauses. It does not apply to the stored spec.
- `spec/booking/BookingSpec.dfy`: B2 fixes the least available slot;
  B3, B4 and the rejection rule fix the rest. Looks deterministic.
- `spec/refund/RefundSpec.dfy`: not read for this purpose.

**Corrected claim.** The lemma shows that the spec leaves no choice. It
does not show that the spec matches intent. A deterministic spec can
still be the wrong spec. Some specs are meant to leave a choice; for
those the lemma fails by design and a frame lemma is the right check.

**Also in this plan.**

- Reject `print` and `{:extern}` in implementations. The Stage 5
  `print_effect` mutant survived because output is outside the claims
  (`docs/spec-quality.md`). This is a gate change (protected).
- Spec-diff witnesses: for a spec change, ask the solver for a request
  where old and new specs differ. Show concrete before/after examples
  to the approver. Useful; the "proved unchanged cone" needs a real
  proof per change and is not automatic.
- Cumulative diff against the approved lock ("split-edit" defence).
  Compare first with what `gate/obligations.py` (Stage 11) already
  does. Not examined.

**Cost.** Small. One lemma per spec with the pinned Dafny. The Dafny
method postcondition must first be restated as a predicate `Post`; that
restatement is new text that needs review.

**First cheap check (not run).** Write the lemma for `LedgerSpec` under
`proposals/`, run pinned Dafny, record the exit. Negative control: a
copy of the spec with C4 written without the frame must fail.

**Entry condition.** Owner's word. It touches no protected file while
it stays a diagnostic under `proposals/`. Gate or policy integration
needs a proposal with an exact diff.

## Plan B — small proved checker in front of the effect ("finality minter")

**Idea.** Untrusted application code proposes `(pre, request, post,
witness)`. A very small program checks the spec relation and, on
success, issues a single-use token bound to the spec hash, the program
hash, the pre-state hash, the request id and the post-state/effect
hash. The database or the outbound API accepts an effect only with a
valid token, with compare-and-swap on the pre-state hash and a unique
request id.

**Why it fits Forge.** It makes the proved object small and exact, and
puts it on the path of the effect. That is the same shape as M1 (one
small executable with a behavioural claim). It is the natural candidate
for priority item 5, "a second program".

**Corrected claims.**

- Stage 7 proved termination with status 0 for one 1,240-byte RISC-V
  ELF. It did not prove functional correctness. A checker that
  evaluates the spec relation and computes HMAC-SHA-256 needs a
  functional proof at machine level. M1 shows the price: the refund
  executable has needed U262–U407 and is not finished.
- With an HMAC, the sink holds the same key and can also mint. The sink
  is then fully trusted. A signature scheme removes that; it needs much
  more proved code.
- NOT proved by this design: key isolation; the database trigger or
  proxy; that `H(pre)` is the hash of the real stored state at commit
  time; the hash function's collision resistance (an assumption); the
  platform under the checker (the same loader, OS and processor gaps
  as M1).
- So trust moves to a smaller place. It is not removed. Evidence must
  keep `end_to_end=false`. Fields such as
  `compiler_gap_on_safety: closed` are not allowed by Forge's rules
  until a machine-checked chain supports them.
- "0 of 50 exploits settled" is a test result (finite), not a proof.

**Cost.** Large. Comparable to M1 for the checker alone, plus the sink.

**First cheap check (not run).** A design note only: exact token
format, exact trusted base, exact claim text, and which M1 theorems
could be reused if the checker is a CakeML program like `refund`.

**Entry condition.** After M1 is frozen as a reference (priority 4).
Owner approval of the claim text and of the trusted base.

## Plan C — runtime optimality certificates for a booking optimizer

**Idea.** For a batch allocation problem `max w·x` subject to `A x ≤ c`,
`x ∈ {0,1}ⁿ`, an untrusted solver returns `x` and dual values `(y, z)`.
A small checker tests, in integers:

    A x ≤ c;   y ≥ 0;   z ≥ 0;   Aᵀ y + z ≥ w;
    100 · (w·x) ≥ (100 − α) · (c·y + 1·z)

**Checked (by hand, not by a tool).** Weak duality holds for every
feasible `x'`: `w·x' ≤ (Aᵀy + z)·x' = y·(A x') + z·x' ≤ c·y + 1·z`.
The steps use only `x' ≥ 0`, `x' ≤ 1`, `y ≥ 0`, `z ≥ 0`. So an accepted
`x` is within the factor `(100 − α)/100` of the optimum. The proof of
the checker needs only this inequality, not linear-programming theory.

**Corrected claims.**

- A certificate with `α = 0` always exists only when the problem has an
  integer optimal dual, for example when `A` is totally unimodular
  (interval scheduling, bipartite assignment). For other shapes the
  checker stays sound but can reject an optimal `x`; a fallback is
  needed.
- It certifies the gap for this one objective on this one batch. It is
  not "model quality" in general.
- The solver can change without a new proof. The checker, its
  integration and the spec still need the normal gate. "0.0 s" is the
  cost of solver edits only.
- A runtime check is a new evidence method. It must not be recorded as
  `source_proof`. Adding it changes `policy/` and `schemas/`
  (protected).

**Why I called it a separate product idea.** Plans A and B make
existing Forge claims stronger or carry them closer to the effect.
Plan C adds a new capability that Forge does not have today: the
approved `BookingSpec` books one request into the least free slot
(B1–B4). It has no revenue, no batch and no optimum. Plan C therefore
needs a new approved intent (a new spec), a new component and a new
evidence method. Its value ("change the optimizer freely; every
answer carries a checked certificate") can be built and sold without
the rest of Forge. That makes it a product of its own more than a step
on the current research path.

**Cost.** Small for the checker and its Dafny proof. Medium for the
new spec, the policy change and the integration.

**First cheap check (not run).** A Dafny lemma for the weak-duality
inequality over sequences of integers, and a 30-line checker method
with the postcondition "accepted ⇒ every feasible x' has
`100·w·x' ≤ …`". Under `proposals/` only.

**Entry condition.** Owner decision that an optimizing booking
component is wanted. Then a spec proposal.

## Order I recommend

1. M1: S4, S5, S6; then replays and freeze (unchanged).
2. Plan A as a side diagnostic, when the owner says so. It is cheap
   and can find real spec holes.
3. Plan B as the second program, after the M1 freeze.
4. Plan C only if the owner wants the new capability.

## What is uncertain

- The determinism of the stored specs is my reading. No tool checked it.
- I did not check the cited papers or the "239 binaries" figure.
- I did not compare the "split-edit" attack with the Stage 11 gate.
- Cost estimates are judgments from the M1 history, not measurements.
