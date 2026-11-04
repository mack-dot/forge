from pathlib import Path
import hashlib
import json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
paths = [ROOT / n for n in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']]
before = {p: p.read_bytes() for p in paths}
checkpoint = OUT / 'checkpoint-before-U284'
checkpoint.mkdir(exist_ok=False)
for p, content in before.items():
    (checkpoint / p.name).write_bytes(content)
assert b'## U284 ' not in before[paths[2]]
entry = '''

## U284 — Refund exception contract connected to all modeled source behaviors

- References:U270,U271,U274,U278,U282,U283. CURRENT none; M1 open;
  Stage12 unauthorized; end_to_end=false. The owner expressly requested the
  exception/source/event correspondence with unchanged approved specification
  and trace. The preceding goal turn and this turn make proof progress.
- New forge_refundRejectSemanticsTheory.refund_error_stdio_semantics is checked.
  Under the exact Decls, main lookup, stdin_content=SOME text,
  refund_run_wire(implode text)=INL err, heap split and STDIO premises, the
  source behavior set is nonempty and every behavior has Terminate Success
  st3.ffi.io_events, the RTC call_FFI_rel relation, and a separated final heap
  satisfying Fail_exn err and STDIO(fastForwardFD fs0). All pointer-equality
  oracles are covered. No event is deleted, replaced or weakened in the theorem.
- Success is the logical outcome constructor derived from Rerr(Rraise exn).
  It does not mean normal ML return or establish OS exit0. The six substantive
  premises remain in the theorem. Zero explicit hypotheses does not mean that
  these implication premises have been discharged for the native executable.
- Deterministic evaluation/FFI lift exports0. First all-oracle build fails1 in
  a clock uniqueness lemma. First diagnostic fails1 from a quotation-interface
  error; corrected diagnostic0 exposes exact clock-adjusted state equality.
  Unqualified state_component_equality refers to the wrong state record.
  Explicit semanticPrimitivesTheory qualification fixes the unchanged lemma.
- Next build fails1 at the final drule_all application after generic all-oracle
  results check. Diagnostic0 shows the exact error application contract and
  original premises are present. Instantiating only P and Q explicitly and
  applying metis checks the same target, exit0. The internal assertion cause
  remains unestablished. All prior errors and the Context.snapshot warning stay
  in their original logs. No upstream theory or proof machinery was changed.
- Final source68c4f9bbf6537d1ea9f5afcd8980e1302779e3adcddd542e5f1eea96228e7655;
  datacfb0f1aa475e4c08a4f490cef6b0d187c7ac274f06e6cf9e6925da2615f215d0.
  Positive replay0 yields four byte-identical exports. Replacing only the final
  required event list with[] fails1 at refund_error_stdio_semantics, with no
  accepted export. This is a binding control, not a universal refutation proof.
- Fresh standard-heap import0 compares the final statement with its first
  frozen version. Seven new theorems have zero explicit hypotheses, zero tagged
  axioms and only DISK_THM. Closure245 nodes retains bool.SELECT_AX,
  bool.INFINITY_AX,bool.ETA_AX,bool.BOOL_CASES_AX. Three existing local helper
  statements/proofs are replayed in this proposal because they are not exported.
- readback.py returns0:1458 parent files, four identical own exports,50 protected
  paths, mission and native b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8
  unchanged. Logic/kernel, Poly/ML, loader, host and cached proof-data trust
  remain. This is not independent clean replay of the complete chain.
- Packet:proposals/refund-executable-feasibility/exception-semantics-20261104/REPORT.md.
  Raw:results/refund-native-audit-2026-11-04/attempt-0007/. The complete statement,
  premise audit, hashes, failures, closure and next exact obligation are retained.
- Smallest remaining source obligation: relate the same final events to
  extract_fs ext(cl,fs) using the basis FFI and STDIO heap, then discharge the
  exact refund_prog initialization/prefix/lookup/heap premises. The planned
  lemma in NEXT-OBLIGATION.md is NOT RUN. Unavailable-stdin behavior, full
  source/model binding, physical runtime/FFI/resources/exit, independent complete
  replay/review and operational assurance remain open. No native rebuild,
  test rerun, signing, protected change, deployment or Stage12 ran in this work.
'''
roadmap = '''## Active mission update — 2026-11-04 (U284)

The refund exception contract now has a checked all-oracle source-behavior
theorem with the full modeled event trace and exceptional heap postcondition.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Deterministic exception/FFI lift | 0 | Exact final events and modeled FFI relation |
| Source semantics builds | 1/1/0 | State-theorem namespace; rule application; then complete export |
| Clock diagnostics / stdio diagnostic | 1/0;0 | Interface error preserved; exact residuals inspected |
| Positive source replay | 0 | Four byte-identical exports |
| Wrong empty-trace substitution | 1 | Required theorem refused; no accepted export |
| Fresh theory import / readback.py | 0/0 | Seven theorems;245-node closure;1458 parent files and50 protected paths checked |

[Theorem, premises, failures, identities and assurance matrix](proposals/refund-executable-feasibility/exception-semantics-20261104/REPORT.md).
The theorem retains declaration, lookup, input/error and initial heap premises.
Logical Success is not OS exit0. Four existing foundation axioms are visible;
logic/kernel/loader/host and imported proof-data trust remain. Same-host proof
and import do not establish clean independent complete-chain replay.
Next: basis event extraction and exact refund_prog initialization composition.
The precise planned lemma is NOT RUN. Physical native I/O/resources/exit remain
open. No native rebuild, signing, protected change, deployment or Stage12 ran.

'''
road = before[paths[0]].decode()
position = road.index('## ')
road = road[:position] + roadmap + road[position:]
tracker = before[paths[1]].decode()
tracker = tracker.replace('## Current proof and observation status — U283', '## Current proof and observation status — U283/U284', 1)
old = '| 3 | Complete the exception source semantics | U282 declaration theorem PROVED; next prove modeled behavior, FFI trace and initialized stdio; native exit remains separate |'
new = '| 3 | Complete concrete exception initialization and event replay | U284 all-oracle error/STDIO/event theorem PROVED under explicit premises; basis extraction and exact refund_prog initialization remain |'
assert old in tracker
tracker = tracker.replace(old, new, 1)
old = 'Latest proof result: **U282 — exception declaration theorem PROVED**.'
assert old in tracker
new = '''Latest proof result: **U284 — error contract to all modeled source behaviors PROVED**.
The [source semantics report](proposals/refund-executable-feasibility/exception-semantics-20261104/REPORT.md)
retains the exact event trace, FFI transition relation, exception value and
consumed-stdin postcondition for every pointer oracle. The declaration, lookup,
input/error and initial heap premises remain explicit. Logical Success is not
OS exit0. The final proof, replay and fresh import return0/0/0; four exports match.
An incorrect empty-trace target fails1. The closure has245 nodes, seven checked
theorems and four existing foundation axioms;1458 parent files match.

**Next:** prove the [basis event extraction obligation](results/refund-native-audit-2026-11-04/attempt-0007/NEXT-OBLIGATION.md)
and discharge exact refund_prog initialization. That experiment is NOT RUN.
Physical runtime/FFI/resources/exit and independent complete-chain replay stay
NOT_ESTABLISHED. No approved specification or trace requirement changed.

Previous declaration result: **U282 — exception declaration theorem PROVED**.'''
tracker = tracker.replace(old, new, 1)
for p in paths:
    assert p.read_bytes() == before[p], 'Concurrent update: ' + str(p)
paths[0].write_text(road)
paths[1].write_text(tracker)
with paths[2].open('ab') as stream:
    stream.write(entry.encode())
assert paths[2].read_bytes()[:len(before[paths[2]])] == before[paths[2]]
record = {'actual_exit': 0, 'entry': 'U284', 'journal_prefix_bytes': len(before[paths[2]]),
          'journal_prefix_sha256': hashlib.sha256(before[paths[2]]).hexdigest(), 'end_to_end': False}
(OUT / 'journal-append-U284.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
