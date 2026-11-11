from pathlib import Path
import hashlib, json, re

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
names = ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']
before = {name: (ROOT / name).read_bytes() for name in names}
ids = [int(s) for s in re.findall(rb'^## U(\d+)\b', before['unsure.md'], re.M)]
entry = 'U' + str(max(ids) + 1)
packet_rel = 'proposals/refund-executable-feasibility/exception-compiler-20261105'
packet = ROOT / packet_rel
packet.mkdir(exist_ok=False)
report = (OUT / 'REPORT.template.md').read_text().replace('@ENTRY@', entry)
(packet / 'REPORT.md').write_text(report)
snapshot = OUT / ('checkpoint-before-' + entry)
snapshot.mkdir()
for name, value in before.items():
    (snapshot / name).write_bytes(value)
link = packet_rel + '/REPORT.md'
roadmap = f'''## Exact ARM8 refund exception composition checked — {entry}

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Input inventory first/corrected | 1/0 | Manifest schema failure preserved |
| Original-theorem inspection / new proof / repeat / exact import | 0/0/0/0 | Complete error predicate retained; four identical exports |
| Wrong code / omitted space / shortened trace | 1/1/1 | Intended complete-statement refusals |
| Standard artifact checksum / both signature verifications | 0/0/0 |311 historical members and exact existing builds verified; no signing |
| Replay preparation first/corrected | 1/0 | Historical source filename corrected;21 snapshots prepared |
| readback.py | 0 |486 theory nodes,2659 parent bindings,2727 prior chain files,50 protected paths |
| Independent full-chain replay / new native execution | NOT RUN | Complete physical/native assurance remains open |

[Exact theorem, eight premise groups, commands and assurance matrix]({link}).
refund_error_compiled_precise composes U286 with the existing exact ARM8 compiler
theorem. It preserves the outer initial heap frame, Fail_exn witness, complete
FFI events and consumed-stdin replay. Installed state, read_limits, the four
source conditions, ARM8 machine configuration and universal space safety remain.
Logical Success does not imply normal ML return or OS exit0. No specification,
original theorem, trace requirement or valid input domain changed.

Fresh same-host import checks both complete statements and the four existing
Boolean foundations. It is not independent clean full-chain replay. All failures
remain, including two preparation failures; both new proofs pass first attempt.
Next physical check: exact ffiread error/EOF/buffer behavior and ABI frame against
the published ffi_read model. Its unchanged-filesystem error branch has an
explicit source warning about real file-position behavior; no Darwin counterexample
is claimed. Independent replay sources and acceptance plan are prepared only.
Separate initializer/pointer/target-event work remains unchanged. U290/U297 stay
stopped. No native rebuild, signing, protected change, deployment or Stage12.

'''
mission = f'''## Refund error compiler branch complete conditionally — {entry}

[Checked statement, identities and assurance matrix]({link}).
U286 now composes with the exact CakeML ARM8 compiler theorem. The initial heap
frame stays outside the target behavior; the exception witness, complete event
list and consumed-stdin replay remain. Eight premise groups are explicit. They
include physical installation/configuration and universal resource conditions.

| Check | Actual exit / status |
| --- | --- |
| Inspection / proof / repeat / exact import | 0/0/0/0 |
| Wrong code / omitted space / shortened trace | 1/1/1; intended refusals |
| Dependency/artifact readback | 0;486 theory nodes,2659 parent bindings |
| Standard checksums / existing signatures | 0/0/0 |
| Independent full-chain replay | NOT RUN;21 source snapshots and plan prepared |
| Physical runtime, FFI, resources and OS exit relation | NOT_ESTABLISHED |

- [x] Compose U286's full error/event/heap predicate with exact ARM8 compilation.
- [ ] Prove the exact native ffiread single-call relation, including errors,
  EOF, unchanged buffer tail, descriptor state and ABI memory/register frame.
- [ ] Run the prepared full-chain replay in an authorized independent clean
  environment; retain source-interpretation and physical-runtime assumptions.

Logical Success is not OS exit0. The source model's unchanged-filesystem read-error
branch needs specific physical justification. The separate initializer/pointer
work below remains open. No approved input restriction or runtime premise was
removed. M1/integration NOT_ESTABLISHED; Stage12 unauthorized; end_to_end=false.

'''
journal = f'''

## {entry} — Exact ARM8 error composition preserves complete exception events and heap frame

- References:U286,U296,U305,U307,U308,U309. Continue the user-requested U286
  branch from cf91be0c. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Concurrent U306–U309 entries remain unchanged.
- forge_refundRejectCompiledTheory.refund_error_compiled_precise composes the
  exact initialized source error theorem with compile_correct_is_safe_for_space
  and the existing precise_sem_satisfies_IMP_Terminate helper. The original
  refund_prog/code/data/configuration identity comes from refund_arm8_compiled.
- Eight retained premise groups: exact installed state; read_limits equation;
  wfFS; STD_streams; stdin_content=SOME text; wire evaluation=INL err;
  is_arm8_machine_config; is_safe_for_space for every pointer oracle. No input
  domain, specification, original theorem or event requirement was changed.
- Conclusion preserves outer h1/h2 initial STDIO split, singleton target
  Terminate Success io, io equal to full final source ffi.io_events, Fail_exn err,
  final source SPLIT3 with the same h2, RTC call_FFI_rel and exact extract_fs
  replay to fastForwardFD fs0. This retains the source heap relation; it does
  not establish a new physical C-heap correspondence. Logical Success is neither
  normal ML return nor a universal OS exit0 claim.
- Minimal new exception_event_witness repacks the event projection and retains
  the predicate verbatim. Kernel CHOOSE eliminates temporary existential-body
  hypotheses. Fresh inspection0 precedes construction; proof0, repeat0, exact
  import0 on their first attempts. Four exported files are byte-identical.
- Wrong installed code, omitted universal space premise and shortened trace
  each exit1 at Exact statement mismatch: refund_error_compiled_precise. These
  are complete-claim binding controls, not physical attacks or universal
  falsification proofs. Every source, command and output remains preserved.
- Setup inventory1/corrected0: U296 uses a direct manifest dictionary instead
  of U286's files wrapper. Replay preparation1/corrected0: U282 uses the saved
  export-proof.sml filename. Incidental missing-file/no-match inspections are
  recorded; an uncaptured child status remains unknown. No proof exceeded its
  attempt limit. U290/U297 stopped paths are not repeated.
- New source4c0a0c2a6e27cfd3b2b1e1e510f301bff47d731ef44c8ba03ca9645c132e6a56;
  data6b8a9a3cb7ecf6746d407b22d840f414b2d6d4e2618c8afc87680a6c94f0917f.
  Both exact imported statements have zero open hypotheses/new tagged axioms
  and only DISK_THM. Closure486 nodes retains bool.SELECT_AX,INFINITY_AX,
  ETA_AX,BOOL_CASES_AX. Logic/kernel/PolyML/loader/host/cached-parent trust remains.
- readback0 checks2659 parent file bindings,2727 historical chain files,
  370 parent packet members,50 protected paths, frozen mission and U286 journal
  bytes. Separate standard shasum check0 covers311 artifact/native-record members.
  Existing signatures verify0/0; full native digests and code/bitmap slices match.
  Native b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8
  remains unchanged. No native process runs, build or signing occur here.
- Three source pins match; CakeML/HOL tracked trees are unchanged. Fresh readback
  processes are separate from proof construction but on the same host, not
  independent clean full-chain replay or authenticated production.21 replay
  source snapshots and an explicit dependency-order/acceptance plan are prepared.
- Smallest physical FFI check: relate one exact ffiread C/ABI call to ffi_read,
  including short reads, EOF, error result, descriptor position and full frame.
  The pinned model's own comment warns that its unchanged-fs error fallback
  may not describe unspecified real file-position effects. No physical Darwin
  counterexample is established. Do not assume away this relation or alter the
  approved model. Preserve all resource/installation/interference/OS conditions.
- Evidence:{link}; raw
  results/refund-native-audit-2026-11-04/attempt-0009/. The assurance matrix,
  PHYSICAL-NEXT.md and REPLAY-PLAN.md state exact scope and pending checks.
  Full physical/FFI/OS correspondence, resource adequacy, source interpretation,
  independent full-chain review/replay and provenance remain open. No protected
  change, release signing, deployment or Stage12. M1/integration NOT_ESTABLISHED.
'''
for name, value in before.items():
    assert (ROOT / name).read_bytes() == value, 'Concurrent update: ' + name
for name, section in [('ROADMAP.md', roadmap), ('FORGE_MISSION_STATUS.md', mission)]:
    value = before[name].decode()
    index = value.index('\n## ')
    (ROOT / name).write_text(value[:index] + '\n' + section + value[index:])
with (ROOT / 'unsure.md').open('ab') as stream:
    stream.write(journal.encode())
assert (ROOT / 'unsure.md').read_bytes() == before['unsure.md'] + journal.encode()
after = OUT / ('checkpoint-after-' + entry)
after.mkdir()
for name in names:
    (after / name).write_bytes((ROOT / name).read_bytes())
record = {'actual_exit': 0, 'entry': entry,
          'journal_prefix_bytes': len(before['unsure.md']),
          'journal_prefix_sha256': hashlib.sha256(before['unsure.md']).hexdigest(),
          'appended_bytes': len(journal.encode()),
          'appended_sha256': hashlib.sha256(journal.encode()).hexdigest(),
          'report': link, 'end_to_end': False}
(OUT / 'tracking.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
