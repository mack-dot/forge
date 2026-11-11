from pathlib import Path
import hashlib
import json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
names = ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']
before = {name: (ROOT / name).read_bytes() for name in names}
assert b'## U286 ' not in before['unsure.md']
assert b'## Initialized refund exception semantics checked' not in before['ROADMAP.md']
snapshot = OUT / 'checkpoint-before-U286'
snapshot.mkdir(exist_ok=False)
for name, data in before.items():
    (snapshot / name).write_bytes(data)

report = 'proposals/refund-executable-feasibility/exception-initialization-20261105/REPORT.md'
roadmap = f'''## Initialized refund exception semantics checked — U286

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
U286 is the reserved source-proof checkpoint. U300's compiler/runtime work and
U301's separate substrate result remain unchanged.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Extraction attempts1/2/3 | 1/1/0 | Missing helper and library-load failure preserved; exact replay lemma checked |
| Basis composition first/diagnostic/corrected/repeat/import | 1/0/0/0/0 | Three-theorem intermediate variant reproduces |
| Initial declaration inspection / three heap diagnostics / projection lemma | 0/0/0/0/0 | Exact residual facts isolated |
| Initial heap attempts1–5 | 1/1/1/1/0 | Same heap claim passes on fifth attempt |
| Concrete initialized proof / repeat / fresh import | 0/0/0 | Exact refund_prog, nine theorems, four identical exports |
| Wrong final filesystem / wrong main / omitted filesystem premise | 1/1/1 | Intended proof-claim refusals |
| readback.py | 0 |246 theory nodes,1462 parent files,50 protected paths and212 prior packet members |
| Native build/test, independent full-chain replay, signing/deployment | NOT RUN | Physical/native correspondence remains open |

[Exact theorem, premises, commands, failures and hashes]({report}).
The new refund_error_initialized_semantics discharges declaration, main lookup,
initial FFI/reference-store and STDIO-heap obligations for the existing refund_prog.
It retains the exception witness, complete modeled event list, FFI relation and
extract_fs replay to fastForwardFD fs0. Four input/environment conjuncts remain:
wfFS, STD_streams, available stdin and the stated wire-evaluation error.
Logical Success is not normal ML return or OS exit0. No event requirement changed.

All nine imported theorems have no explicit hypotheses/new tagged axioms; the
four existing Boolean foundation axioms remain. Same-host replay with cached
parents is not independent clean full-chain replay. Both old failed heaps match.
Next for this branch: compose the exact error behavior with the existing ARM8
compiler theorem, preserving full events and every runtime/resource premise.
Reuse the existing compiled artifact. U300's space/non-error and target event
obligations remain open; U290/U297 stay stopped. No protected or remote action.

'''
mission = f'''## Initialized refund error branch — U286

[Checked source theorem and evidence]({report}).
The exact existing refund_prog now has an initialized exception theorem.
Declaration, lookup, FFI/reference-store and initial STDIO heap are discharged.
Every modeled source behavior retains its Fail_exn witness, full event list and
filesystem replay with stdin consumed to EOF. The four remaining conjuncts are
wfFS, STD_streams, available stdin and the stated wire error. Logical Success
does not establish OS exit0. The approved input domain and trace are unchanged.

| Check | Actual exit / status |
| --- | --- |
| Concrete source proof / repeat / fresh import | 0/0/0 |
| Wrong filesystem / wrong entry / omitted premise | 1/1/1; intended refusal |
| Evidence readback | 0;246 theory nodes,1462 parent files, four identical exports |
| Error-specific compiler composition / physical OS correspondence | NOT_ESTABLISHED |
| Independent clean full-chain replay | NOT RUN |

- [x] Bind U284's full error event/heap contract to initialized refund_prog and
  its exact basis filesystem replay. Preserve all failed attempts and controls.
- [ ] Compose this source error behavior with the existing exact ARM8 compilation
  theorem. Preserve full events and every resource/machine premise; do not recompile.

The current compiler/runtime checklist below remains active. U300's space,
non-error and lower-pass installer-event conditions are still open. The new
source result does not discharge them. Nine theorem tags retain only DISK_THM
imports and the same four Boolean foundations. Same-host cached imports are not
independent assurance. M1 open; Stage12 unauthorized; end_to_end=false.

'''
journal = f'''

## U286 — Exact initialized refund exception behavior and event replay checked

- Reserved ID, appended after U301 without moving or changing prior entries.
  References:U270,U271,U274,U282,U284,U294,U295,U296,U300. CURRENT none;
  M1 open; Stage12 unauthorized; end_to_end=false.
- New forge_refundRejectBasisTheory.refund_error_initialized_semantics proves
  the error branch for the exact existing refund_prog. Stored declarations,
  main lookup, initial FFI/reference-store and STDIO heap are discharged using
  published kernel rules and the existing translator state. Program equality
  is a separate checked theorem; no new program definition is substituted.
- Exact premises: wfFS fs, STD_streams fs, stdin_content fs=SOME text and
  refund_run_wire(implode text)=INL err. The nonempty source behavior set retains
  all pointer oracles, Fail_exn err, the same initial heap frame, full final
  ffi.io_events, RTC call_FFI_rel and exact extract_fs replay to fastForwardFD fs0.
  No Unicode, ID, integer, reason, caller or event restriction was introduced.
  Logical Terminate Success is neither normal ML return nor an OS exit0 proof.
- Extraction attempts exit1/1/0: missing helper; existing helperLib DECIDE-load
  failure; then ordinary published SPLIT tactic expression checks the lemma.
  Internal library-load cause remains open; no library or proof machinery patched.
  Composition first/diagnostic/corrected exits1/0/0. The residual establishes
  generated goal order; reversing conjunction handling proves the same target.
  Intermediate replay/import0/0, four identical exports. Wrong final fs fails1.
- Initial declaration inspection0. Initial heap attempts1–5 exit1/1/1/1/0.
  Three diagnostics0/0/0 and a separate projection proof0 isolate the missing
  FFI partition/projection and explicit STDIO_precond hypotheses. DISCH_ALL
  exposes those hypotheses; unchanged premises discharge them. Fifth attempt
  passes. Concrete initialization composition passes first attempt0, repeat0.
  U274's five failures and U290/U297 stopped routes are not repeated.
- Wrong entry changes only the appended main in the exact program identity;
  REFL_TAC refuses it, exit1. Fresh final import0 checks the explicit expected
  final statement and closed entry identity. Removing wfFS only from that
  expected statement fails1 at exact comparison. Controls test claim binding,
  not universal refutations or native process behavior. All failures remain.
- Accepted source82c4877bb9f298fa440c1657b54e291fcd0377cbd0dc9dfc79f29e8cb37f296c;
  data3c358b38b4617b8b29349fb90200c639150a582a8da6aad2c78bee092e7a8f28.
  Four final exports reproduce byte for byte. Earlier same-name theory variants
  have distinct directories/hashes; final import binds concrete-0001 exactly.
- readback0 checks246 theory nodes,1462 parent files, nine theorem tags with
  zero explicit hypotheses/new tagged axioms and only DISK_THM. Four existing
  Boolean foundations remain: SELECT_AX,INFINITY_AX,ETA_AX,BOOL_CASES_AX.
  Eight direct ML macro files are hashed; this is not a complete dynamic ML
  loader dependency closure. Logic/kernel, Poly/ML, host and cached-parent trust
  remain. Same-host repeat/import is not independent clean full-chain replay.
- Mission,50 protected paths,212 prior packet members, both failed heaps and
  native b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8 match.
  Pinned CakeML/HOL/PolyML readbacks0; selected upstream library diff0.
  Root Git failure had no separately captured child exit; an inferred128 in
  the initial inspection note was corrected to unknown with both notes kept.
  A mistyped inspection filename failed1; no proof result depended on it.
- Impact: U284's initialized-program and exact filesystem-replay gaps are now
  closed in the source model. Native error-path composition, runtime resources,
  machine/FFI/memory/OS applicability and unavailable-stdin behavior remain open.
  U300's separate space/non-error and target installation obligations remain.
- Next smallest experiment: retain the full exception/event/heap predicate in
  the compiler's source-behavior form; apply the existing exact ARM8 correctness
  theorem without recompilation. Keep all physical/resource premises. Do not
  replace resource-limit prefixes with successful complete execution.
- Evidence:{report}; raw
  results/refund-native-audit-2026-11-04/attempt-0008/. All commands, residuals,
  intermediate variants, hashes and limitations are preserved. No native test,
  build, signing, protected change, deployment or Stage12 ran. Independent
  full-chain replay/review, source interpretation, provenance/admission and
  operational assurance remain open. M1/integration EXIT NOT_ESTABLISHED.
'''
for name in names:
    assert (ROOT / name).read_bytes() == before[name], 'Concurrent change: ' + name
for name, section in [('ROADMAP.md', roadmap), ('FORGE_MISSION_STATUS.md', mission)]:
    text = before[name].decode()
    index = text.index('\n## ')
    (ROOT / name).write_text(text[:index] + '\n' + section + text[index:])
with (ROOT / 'unsure.md').open('ab') as stream:
    stream.write(journal.encode())
assert (ROOT / 'unsure.md').read_bytes() == before['unsure.md'] + journal.encode()
record = {
    'actual_exit': 0, 'entry': 'U286',
    'journal_prefix_bytes': len(before['unsure.md']),
    'journal_prefix_sha256': hashlib.sha256(before['unsure.md']).hexdigest(),
    'appended_bytes': len(journal.encode()),
    'appended_sha256': hashlib.sha256(journal.encode()).hexdigest(),
    'before': {name: hashlib.sha256(data).hexdigest() for name, data in before.items()},
    'after': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names},
    'end_to_end': False,
}
(OUT / 'journal-append-U286.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
