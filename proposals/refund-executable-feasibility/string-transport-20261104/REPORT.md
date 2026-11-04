# Refund string representation transport

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. Classification: LOCALLY_VALIDATED conditional source proof.

## Checked proposition

The unchanged approved `Refund.Assess` and unchanged feasibility `AssessFlat`
produce the same authorization, amount, allowed reason and intent count when
the string representations preserve two caller-ID emptiness tests and equality
with each of the three allowed ASCII reason literals. The encoded outputs copy
the supplied encoded caller IDs exactly. This holds for every original context,
every mathematical integer and every response constructor for which the stated
representation relation holds. The proof does not narrow the original contract.

`source/Transport.dfy` states the representation premises explicitly. The
candidate representations must be byte-valued strings. They must preserve empty
charge IDs, empty request IDs and all three exact reason equalities. These are
obligations for a future codec theorem, not facts established about a codec here.
The body calls both existing implementations and checks the decision and original
plan against their contracts. Included-file verification checks those bodies.

The witnesses include U+0100 and U+10FFFF caller IDs, an amount of40 and an amount
of0. They establish that the conditional theorem is usable for those supplied
byte sequences. They do not prove that a particular encoder produces them.

## Actual commands

From `/Users/mackianni/forge`, run the recorded dispatcher with an unused case
directory. Existing case directories are never overwritten.

| Command | Actual exit | Observation |
| --- | ---: | --- |
| `python3 -B results/refund-unicode-bridge-2026-11-04/run_check.py positive-0001` | 2 | 9 verified; warning-as-error failure retained |
| Same dispatcher `positive-0002` | 0 | 9 verified,0 errors; parentheses resolve indentation warnings |
| Same dispatcher `repeat-0001` | 0 | Same source digests and byte-identical positive output |
| Same dispatcher `negative-charge-empty` | 4 | Removed only charge-ID emptiness premise; authorization equality unproved |
| Same dispatcher `negative-reason` | 4 | Removed only reason relation; authorization/reason assertions unproved |
| Same dispatcher `negative-original-id` | 4 | False encoded-ID/original-ID equality unproved |
| Pinned `dafny audit Transport.dfy --report-format md --report-file .../audit.md --compare-report --unicode-char=true` | 0 | Zero findings against the unchanged empty audit baseline |
| `python3 -B results/refund-unicode-bridge-2026-11-04/validate.py` | 0 | Recorded exits/reasons, source/repeat identity, audit and50 protected paths checked |

Each checker invocation uses pinned Dafny4.11.0 and Z3 4.12.1,
`--resource-limit 1000000 --verification-time-limit 0 --cores 1`,
`--verify-included-files` and `--unicode-char=true`. The command records retain
full argv, source hashes, executable hashes, actual exits and raw stdout/stderr.
The dispatcher only invokes the established checker and records its outcome.
The validator compares evidence records; it does not prove program correctness.

## Exact assurance boundary

This is a source theorem checked by Dafny/Boogie/Z3. It is not a HOL4 certificate,
proof of a concrete UTF-8 codec, proof that two source languages have the same
semantics, or native-code result. Dafny's Unicode representation is documented
in [Strings and Characters](https://dafny.org/dafny/Compilation/StringsAndChars).

Caller-ID equality after decoding remains a separate obligation. The third
negative control demonstrates that these transport premises do not establish
that the encoded bytes equal the original ID. They also do not establish codec
injectivity or a round trip. No encoder, decoder, proof checker, solver wrapper
that decides logical correctness, or machine semantics was added.

The earlier source bridge, HOL4 model/compiler/caller proofs and their failed
attempts remain unchanged. The concurrent concrete Unicode experiment is in
`results/refund-unicode-2026-11-04/`; this packet does not claim its results.
Protected files and the original `unsure.md` prefix match the recorded baseline.

## Next check

Discharge these representation premises for the published Unicode library and
prove complete caller-ID round trips. Then connect the same representation to
the existing HOL4 caller theorem and exact native interface. A checked codec
source proof alone does not establish its native implementation or I/O boundary.
No publication, policy adoption, signing, admission or stage transition occurred.
