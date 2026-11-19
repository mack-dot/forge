# The skeptic gauntlet: one command, three acts

`scripts/demo_gauntlet.py` runs the real components of Slices 1, 2 and
3 against a list of attacks and prints what happened. Nothing in it is
mocked, canned or simulated: each printed result comes from a process
that the script started in that run, or from a file that such a process
wrote.

It is a **finite demonstration**. A run is not a proof and adds no
evidence class. `end_to_end=false`. The proofs behind the acts are the
source proofs of the slices; their EXIT scripts check them
([Slice 1](../proposals/forge2-slice1-refund-finality/REPORT.md),
[Slice 2](../proposals/forge2-slice2-spec-clearing/REPORT.md),
[Slice 3](../proposals/forge2-slice3-runtime-certificates/REPORT.md)).
Actual results of the demo runs, the mutation runs and the review:
[Wave Gate 3 report](../proposals/forge2-demo-gauntlet/REPORT.md).

## Run it

Needs: macOS on arm64, the pinned toolchain
([setup](../toolchain/README.md), [TypeScript setup](../ts/README.md)),
the pinned Node first in `PATH`, and `rustc` in `PATH` (it builds the
untrusted optimizer v2; the script installs nothing).

```sh
python3 scripts/demo_gauntlet.py                    # all three acts, flood of 600 MiB
python3 scripts/demo_gauntlet.py --flood-mb 10240   # the same with a flood of 10 GiB
python3 scripts/demo_gauntlet.py --acts 2           # one act (NOT COMPLETE, exit 3)
```

Exit 0: all three acts ran with the full checks and every required
result was observed. Exit 1: a required result was not observed (the
message names the act). Exit 2: a tool is missing or the script
crashed; that is not a result of the demonstration. Exit 3: a PARTIAL
run (`--acts`) or a REDUCED run (a flood below 512 MiB); the checks
that ran held, and it is not a pass of the demo. A
full run takes about 80 to 100 seconds on the machine of the recorded
runs. Raw outputs go to `build/demo-gauntlet/` (not tracked).

Run it alone: Act 3 requires that no Dafny, Boogie or Z3 process is
seen on the machine while the optimizers are exchanged. Another Dafny
job at that time makes the demo fail.

## Act 1: Spec Clearing

The script starts `scripts/spec_clearing.py` on four subjects of
`clearing/subjects.json`. The tool starts the pinned Dafny; each
verdict rests on Dafny's exit codes for lemmas and witness files.

| Subject | Required verdict | What it shows |
| --- | --- | --- |
| `refund` (the approved refund spec) | `NO_CHOICE` | the spec leaves no choice to an implementation |
| `refund-rewrite` (a planted variant in other words) | `EQUIVALENT` | a change of wording that changes no allowed result |
| `refund-cap` (a planted variant with a cap) | `DIVERGES` | one concrete input with its result before and after, verified by Dafny |
| `refund-loose` (a planted loose spec) | `CHOICE` | two verified implementations that differ at one input |

Limits: `Post` and the general lemmas are written by hand per spec; a
person must read them. The three variants are fixtures, not proposals.
The verdict `CHOICE` blocks nothing by itself: a person, or a rule that
reads the verdict, does.

## Act 2: Proof-Carrying Finality under attack

The script compiles the Slice 1 checker core with the pinned Dafny
(the module must be byte-equal to the module of the Slice 1 record),
starts the real token issuer as its own process, and makes one SQLite
sink with one charge: original 1000, remaining 600.

| Step | Attack | Required result |
| --- | --- | --- |
| 2a | four out-of-policy proposals to the issuer (amount above the remaining amount, an unapproved reason, a post-state that keeps the money, an intent with another amount) | no token; reason `core: Refuse` |
| 2a | three commits with no valid token (a forged token with the right shape and hashes and a signature of zero bytes; `{}`; an empty text) | rejected; the store is unchanged |
| 2b | eight processes, each with its own valid token for 400 of the 600, call commit at one common start time | exactly 1 commit; 7 rejected as stale; remaining 200 |
| 2c | the settled token twelve times at once; the seven losing tokens again; a new signed token for the settled request id | `replayed`; rejected; rejected; the store is unchanged |
| 2d | a flood of raw bytes with no line end into the issuer's input (`--flood-mb`), then one valid request | one answer `message too long`; the issuer's resident memory grows by at most 256 MiB (checked only for a flood of 512 MiB or more); the valid request gets a token, and the sink commits it |

At the end the store must hold exactly two refunds (400 and 150), both
for a token, and the sink's own audit of the token chain must find no
problem. The script prints the measured bytes, the issuer's resident
memory before and at its peak, and the time from the valid request to
its token.

Limits: the issuer, the sink and the compiled core are not proved
(Slice 1 report). The race has eight processes and one start time; it
is one race, not all schedules. The memory numbers are for one run on
one machine: resident memory sampled 20 times per second, and the peak
that the kernel reports when the issuer ends. The memory bound finds an
issuer that keeps more than 256 MiB of the flood; at 600 MiB an issuer
that keeps less than about 43 percent of the bytes passes it. The flood
is one kind of flood (bytes with no line end on the input pipe).

## Act 3: three optimizers, one checker core

The script compiles the Slice 3 certificate checker core once (byte-
equal to the module of the Slice 3 record), builds the Rust optimizer
with the `rustc` of the machine, and runs
`tests/booking-certificate/swap.ts` five times against that one core:

| Optimizer | Language | Required result |
| --- | --- | --- |
| v1 | TypeScript | the counts of the Slice 3 record (70 batches; commits only for tokens) |
| v2 | safe Rust (`#![forbid(unsafe_code)]`) | the counts of the Slice 3 record |
| v3, three modes (`overbook`, `forged-certificate`, `double-book`) | Python, adversarial | 0 tokens, 0 commits, every forged offer rejected |

Each optimizer runs under the macOS sandbox tool (no file writes, no
network). Between the first and the last optimizer a sampler (ten
samples per second) must see no Dafny, Boogie or Z3 process on the
machine (by program name). The sampler is the only check of this.
It has a control: it must see the Dafny of this run while that Dafny
compiles the core.

Limits: the checker core is proved against a candidate spec that is
not approved intent; the check is sound, not complete. The sandbox tool
is trusted, not proved, and is for one platform. "No Dafny run" means:
none seen by the sampler; a process shorter than a sample interval can
be missed. The Slice 3 EXIT script
runs sixteen adversary modes; this demo runs three.

## What the demo does not show

- Nothing about inputs or attacks that are not in the lists above.
- Nothing about a deployed system, keys in real storage, or a remote
  processor.
- It does not run M1 or Stage 7. It does not run the EXIT scripts of
  the slices.
