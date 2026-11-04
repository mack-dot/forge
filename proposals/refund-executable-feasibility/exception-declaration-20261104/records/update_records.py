from pathlib import Path
import hashlib
import json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
paths = [ROOT / n for n in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']]
before = {p: p.read_bytes() for p in paths}
checkpoint = OUT / 'checkpoint-before-U282'
checkpoint.mkdir(exist_ok=False)
for p, content in before.items():
    (checkpoint / p.name).write_bytes(content)
entry = '''

## U282 — Exception declaration theorem proved and imported; whole-program lift remains open

- References:U271,U272,U274,U276,U278,U279,U283. CURRENT none; M1 open;
  Stage12 unauthorized; end_to_end=false. This ID was reserved before U283;
  this entry is appended after it without changing existing journal bytes.
- Exact residual inspection confirms that fs reverses the supplied SYM equation
  back to SOME(env,exp)=do_opapp[...]. Direct SUBST1_TAC o SYM closes both the
  declaration and heap branches of the unchanged refund_call_main_exception.
  The observed cause is simplification context. No new semantic premise,
  environment invariant, axiom or input restriction is introduced. No semantic
  counterexample was found; broader native correspondence remains unproved.
- U272 already records successful direct HOL checks under these permissions.
  This work uses that existing interface and pinned tools without changing the
  sandbox, redirecting a denied operation or rerunning the denied Holmake command.
  U278's Holmake EPERM remains unexplained and preserved. No-action inspection0
  reports commands only. The original five failures and subsequent attempts
  retain their counts and records; each correction has a concrete diagnosis.
- Direct checks return1/1/0: missing batch namespace, unresolved branch, then
  accepted unchanged full theorem. Intermediate residual diagnostic returns0.
  Passing direct source SHA256
  eca8a571f14f73828d25eb1dae14d0fa18833dcd6e6997dcbddc4774ebc5523e.
- Fresh standard-heap export first fails1 on unqualified constants. Exact
  qualification then yields0. Repeat yields0 with four identical exports.
  Neither successful export uses the failed diagnostic heap. A wrong normal
  result instead of Rerr(Rraise exn) fails1 at the declaration branch, with no
  accepted export. All failed sources/stdout/stderr/commands remain preserved.
- New theorem:forge_refundRejectDirectTheory.refund_call_main_exception.
  Export source94f931b6e6ac0d14c5b27b86a887b8f9059dc5c1e9e602cca09a7d3f6433435e;
  datae6a9062d763b0f049f75633e61633554e6e35a7b9e7e376d9cc6efd42d673760.
- Separate import first fails1 because physical artifact paths duplicate
  .hol/objs under the HOL virtual loader. Documented virtual paths yield0.
  It checks aconv against the exact required statement, zero hypotheses,
  zero explicitly tagged axioms and only DISK_THM. Closure244 nodes, with the
  same four bool foundation axioms. No clean independent upstream replay follows.
- readback.py returns0:1454 prior dependency files, four identical own exports,
  both failed heaps,50 protected paths, frozen mission and native executable
  b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8 unchanged.
  Exploratory hol help run exits1 as an unsupported CLI form; no proof evidence.
- Packet:proposals/refund-executable-feasibility/exception-declaration-20261104/REPORT.md.
  Raw:results/refund-native-audit-2026-11-04/attempt-0006/. Existing native tests
  and compilation were not repeated. U283's observations do not prove all runtime
  premises. The original compiler behavior run retains its existing owner.
- Next smallest experiment: prove separately that the exact exceptional
  evaluate_dec_list result gives deterministic Terminate Success plus the
  RTC call_FFI_rel relation; then compose the accepted declaration theorem.
  Logical Success is not an OS exit-code theorem. All-oracle semantics, initialized
  stdio error behavior, source/model binding, physical runtime/FFI/resources/exit
  and clean independent complete-chain replay remain open. No protected change,
  native rebuild, signing, deployment or Stage12 occurred.
'''
assert b'## U282 ' not in before[paths[2]]
roadmap = '''## Active mission update — 2026-11-04 (U282)

The unchanged exception declaration theorem is now PROVED, replayed and imported.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Observation |
| --- | --- | --- |
| Direct exact theorem checks | 1/1/0 | Namespace failure; residual branch; then both branches proved |
| Residual simplification diagnostic | 0 | fs reorients equation; direct substitution resolves it |
| Fresh standard-heap export / repeat | 1/0/0 | Qualified constants after first failure; four identical exports |
| Wrong normal-result control | 1 | Required declaration proof fails; no accepted export |
| Exported-theory import | 1/0 | Virtual-path correction; exact statement and244-node closure checked |
| readback.py | 0 |1454 prior files, two failed heaps,50 protected paths and native identity unchanged |

[Exact theorem, failures, hashes and assurance matrix](proposals/refund-executable-feasibility/exception-declaration-20261104/REPORT.md).
The existing direct HOL interface works with unchanged tools and permissions.
The earlier Holmake EPERM remains preserved and unexplained. The theorem adds no
new premise or axiom. Fresh replay still trusts this host and cached parents.
Next: exceptional evaluation to deterministic source semantics and FFI relation,
then all pointer oracles and initialized stdio. Logical Success does not establish
OS exit0. Physical native correspondence and clean independent replay stay open.
No native rebuild, signing, protected change, deployment or Stage12 occurred.

'''
road = before[paths[0]].decode()
position = road.index('## ')
road = road[:position] + roadmap + road[position:]
tracker = before[paths[1]].decode()
start = tracker.index('Latest proof diagnosis:')
end = tracker.index('Previous compiler audit:', start)
tracker = tracker[:start] + '''Latest proof result: **U282 — exception declaration theorem PROVED**.
The [declaration report](proposals/refund-executable-feasibility/exception-declaration-20261104/REPORT.md)
records the unchanged theorem, direct substitution diagnosis and all failures.
Fresh standard-heap proof/repeat/import return0/0/0. Four exports match. The
wrong normal-result control fails1. The imported closure has244 nodes and the
four existing bool foundation axioms;1454 prior dependency files match.
No new semantic premise or axiom was added. U278's denied Holmake invocation
remains preserved; the already-used direct HOL interface checks the theorem.

**Next:** lift the exception declaration result to deterministic source semantics
and its FFI relation. Then establish all pointer oracles and initialized stdio.
Whole-program error, physical native execution and independent complete-chain
replay remain NOT_ESTABLISHED. `end_to_end=false`.

''' + tracker[end:]
lines = tracker.splitlines()
for i, line in enumerate(lines):
    if line.startswith('| 3 | Complete the exception proof'):
        lines[i] = '| 3 | Complete the exception source semantics | Declaration theorem PROVED; U282 | Deterministic exception behavior, all pointer oracles, initialized stdio and exact I/O trace |'
tracker = '\n'.join(lines) + '\n'
for p in paths:
    assert p.read_bytes() == before[p], 'Concurrent update: ' + str(p)
paths[0].write_text(road)
paths[1].write_text(tracker)
with paths[2].open('ab') as stream:
    stream.write(entry.encode())
assert paths[2].read_bytes()[:len(before[paths[2]])] == before[paths[2]]
record = {'actual_exit': 0, 'journal_prefix_bytes': len(before[paths[2]]),
          'journal_prefix_sha256': hashlib.sha256(before[paths[2]]).hexdigest(),
          'entry': 'U282', 'end_to_end': False}
(OUT / 'journal-append-U282.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
