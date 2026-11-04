# Refund I/O schema and model binding

Status: local checked model result. Native I/O and executable correctness remain
NOT_ESTABLISHED. CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

The adapter composes the pinned published S-expression parser, `dest9`/`dest7`,
and string, integer and Boolean field conversions. It introduces no parser,
codec algorithm, machine semantics, proof checker or axiom. The input is nine
fields in this exact order: charge ID, request ID, original amount, remaining
amount, enabled, opened, candidate, requested amount and reason. All mathematical
integers and finite byte strings remain representable. The earlier UTF-8 source
proof supplies the Unicode representation; its Dafny-to-HOL assurance link is
still an explicit boundary, not a new kernel theorem.

The complete input round trip and the existing generated-method caller result
are composed in `refund_wire_model_result`. The output has the tag
`refund-result-v1` and six fields: decision, amount, reason, charge ID, request ID
and intent count. Its parser/field round trip is checked. This does not yet prove
that a native program reads stdin, invokes the method and writes that output.

The upstream `fromString` drops the parser remainder. The proposal instead uses
published `parse` and requires an empty remainder. A valid request followed by
another expression is refused. Malformed syntax, missing fields, wrong field
types and malformed integers also have explicit rejection theorems. These are
wire-format checks; every approved typed refund input remains representable.

| Executed command | Actual exit | Result |
| --- | --- | --- |
| `python3 -B run.py 0001` | 1 | Initial proof-file syntax error; retained |
| `python3 -B run.py 0002` | 0 | Complete-consumption input/model relation |
| `python3 -B run.py full-0001` | 1 | Output variable collided with HOL count constant; retained |
| `python3 -B run.py full-0002` | 0 |12 own theorems, input and output relations |
| `python3 -B run_controls.py` | 0 | Four expected refusals plus fresh repeat |
| Individual altered input/output, trailing-data and integer-domain checks | 1 each | Exact failed theorem and reason in schema-acceptance.json |
| `python3 -B run.py repeat` | 0 | Six exported files byte-identical to full-0002 |
| Fresh HOL closure inspection | 0 |159 nodes,12 own theorems, zero own hypotheses |

The negative integer conversion produces the unproved premise `0 <= original`.
It is rejected; no new precondition is added. Input/output swaps fail identity
preservation. Ignoring the remainder fails the trailing-input rejection theorem.
No syntax or resource error is counted as an expected security refusal.

Final source SHA256:
`9a6e51a5c840d751ad793f8fa99e4162e76c96e8a975a7c0bd21d3c88a7af59f`.
Final theory data SHA256:
`d9e7f1b77932f7e8c476e4a7230601f6b6cbe722a27764035e07ca01ea7becec`.
The four existing HOL foundation axioms are SELECT_AX, INFINITY_AX, ETA_AX and
BOOL_CASES_AX. Own theorem tags report DISK_THM and zero hypotheses. Imported
HOL data is not a self-authenticating proof certificate. The pinned HOL/PolyML
build, dependency sources and host remain trusted. This is not human review.

Pinned CakeML: cd9155694c16831373ab695a670794f23282ed62.
Pinned HOL4: 9783a49979c94c401ff8c0e51b2eefae7ea95ae3.
Poly/ML5.9.2:4557554077078decce4ce5f90da00a713cfc32e4.
The command records name exact argv, working directories and source/export
hashes. `run.py` invokes installed Holmake. It does not judge theorem truth.
To reproduce, use these pinned tools and the parent model/caller theories, then
run `python3 -B run.py fresh` in a new packet copy. Controls dispatch the same
checker on the included altered sources. No result is accepted from a cache key.

Raw records: results/refund-native-io-2026-11-04/attempt-0001/. Failed proof
heaps remain there and in local recovery archives; they are not Git payloads.
The broad generic-heap evaluation attempts were separately interrupted and are
not proof results. The published SexpProg source rebuild and characteristic-
formula method/I/O composition were still in progress at this checkpoint.
Next: prove the generated method's library heap/frame contract and complete the
whole-program I/O relation, then compile through the pinned arm8 Apple export.
No native refund executable, signing, admission, deployment or hosted benchmark
has run. Independent claim review and off-machine hash/restore remain open.
