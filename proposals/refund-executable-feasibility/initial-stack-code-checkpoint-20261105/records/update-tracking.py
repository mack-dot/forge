from pathlib import Path
import json
import shlex

R = Path('/Users/mackianni/forge')
W = Path('/private/tmp/forge-readiness-docs-20261103')
H = Path(__file__).resolve().parent
O = R / 'results/refund-initial-stack-code-2026-11-05/attempt-0001'
P = Path('proposals/refund-executable-feasibility/initial-stack-code-checkpoint-20261105')
assert json.loads((H / 'checkpoint.json').read_text())['actual_exit'] == 0
link = str(P / 'CHECKPOINT.md')
road = f'''## Initial stack-code proof checkpoint preserved — U314

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Recorded HOL code-0001/0002/0003 | 1/1/1 | Label, numeric tactic, then FIRST_ASSUM failures preserved |
| Initial byte audit / correction preparation / premature invocation | 1/1/2 | Distinct-checkout and missing-cache assumptions corrected |
| checkpoint-complete.py | 0 | 96 raw files,18 source pins,208 prior U313 members per copy match |
| New complete import, closure audit, repeat and negative controls | NOT RUN | No complete new theory exported |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Full assurance remains open |

[Exact checkpoint, commands, failures and next check]({link}).
Three helpers complete in-process before the last two bundle failures. The final
combined proof remains unproved at FIRST_ASSUM. U313 remains the latest completed
initialization validation:15 conditions, not14. This Markdown step ran byte
checks only; it did not rerun HOL or promote partial helpers to adopted evidence.
Next: print the typed goals and specialized theorems at each drule boundary.
Identify the failed match before changing the proof. Then complete the exact
statement/premise audit, reproduction and meaningful controls. Preserve U298's
every-prefix requirement and all physical/source/resource/FFI/OS conditions.
The separate histories and U290/U297 stopped routes remain intact. Owner-reported
backup still needs exact other-device hashes/restore. Protections were not
refreshed. No protected or remote operation. M1/integration EXIT NOT_ESTABLISHED.

'''
status = f'''## Resume here — initial stack-code proof incomplete (U314)

[Checkpoint, exact commands and preserved failures]({link}).
U313 remains the latest completed initialization validation. Its15 conditions
remain; the proposed14-condition theorem is not established. M1 remains full
approved refund R1–R5 integer/Unicode behavior for the exact native executable.

| Item | Actual result / next action |
| --- | --- |
| Recorded HOL bundles | 1/1/1; three in-process helpers, no completed theory export |
| Byte audit first/corrected | 1/0; preparation failures also preserved |
| **Next executable check** | Diagnose the exact FIRST_ASSUM match with typed goals at each drule |
| Required completion checks | Complete statement/premise audit, closure, repeat and intended controls |
| Following proof link | Successful applicability and U298's complete target-prefix relation |
| Separate blockers | Physical/source/resource/FFI/OS conditions; independent review/replay; provenance/admission |
| Operational status | Exact other-device hashes/restore and current protections remain unverified |
| Verdict | M1/integration NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized |

No new proof/native/hosted execution ran in this tracking step. Do not count
draft controls or a hypothesized type mismatch as checked results. Earlier
checkpoints and the separate U310 history remain intact. Local checks/proposals
and unsigned commits may continue within existing approval boundaries.

'''
entry = f'''
## U314 — Initial stack-code composition remains unproved; exact checkpoint preserved

- References:U296,U297,U298,U303,U305,U307,U310,U311,U312,U313. CURRENT none;
  M1 open; Stage12 unauthorized; end_to_end=false. Baseline local commit
  05a6596db5c147739c74b42d3df0c7fb38bd60b1. Owner requests Markdown tracking;
  existing local-commit authorization persists. No new stage or wider authority.
- Recorded code-0001/0002/0003 exit1/1/1. First saves allocation conventions but
  leaves label goals. Published GREATER_DEF resolves that label form in the
  second source. It saves three helpers, then numeric DECIDE construction fails.
  The third uses explicit num types; its generic stack-good proof instead fails
  at Tactical.FIRST_ASSUM. No run reaches completion or exports the new theory.
- The three in-process helpers concern exact word allocation conventions, exact
  label validity and exact stack-lowering identity. They have no completed fresh
  import/closure/reproduction/control audit. Initial-stack good_code and the
  proposed14-condition initializer remain NOT_ESTABLISHED. U313's validated
  15-condition claim remains the accepted local checkpoint; no premise is removed.
- The log does not identify which drule fails. A hidden word-type mismatch is
  a hypothesis only. Next: print typed goals, assumptions and specialized theorem
  types at each drule, then change only the demonstrated mismatch. The label
  helper passed on attempt2; the generic composition has one actual failing
  proof attempt after a separate numeric-construction failure. Preserve all
  counts; no failing proof may exceed five attempts. U290/U297 stay stopped.
- expected.sml, wrong-lowering.sml, duplicate-label.sml and missing-memory.sml
  are prepared but NOT RUN. After a complete export, require exact statements,
  all14 intended remaining premises, closure audit, repeated identical exports
  and intended rejection reasons after positive audits. Script errors cannot
  count as negative-control success. No new HOL/native/hosted run in this
  Markdown tracking step; earlier command records are not fresh executions.
- Initial byte audit exits1 because it assumes identical protected bytes in
  distinct historical checkouts. First correction preparation exits1 on a
  workspace-only __pycache__ path; the premature script invocation exits2 because
  that correction script was not created. All failures are retained. Corrected
  checkpoint-complete.py exits0:96 raw files,18 exact upstream source pins,
  208 U313 members per copy and Git, parent/source/heap/native/mission identities.
  All50 workspace protected paths match their original baseline;46 tracked
  worktree protected paths match its baseline commit. No protected bytes changed.
- Latest incomplete source f3e2be7884bd6ee005de790179859e1858bad7e8862901e59c3709be7c8acb11.
  Existing native b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
  Evidence:{link}, COMMANDS.md and records/.
  Separate root/worktree histories remain intact, including root-only U310.
- Impact:the initial good_code premise remains required. Other initializer
  memory/alignment/saved-register conditions and stack non-failure remain;
  they are not the complete M1 assumption list. Then justify lower-pass
  transitions and U298's every-formal-prefix condition. Final-output equality,
  partial in-process proofs and observations do not establish physical behavior.
- Independent review/full-chain replay, physical/source/resource/FFI/OS
  applicability, fresh authenticated provenance/admission and operational controls
  remain open. Owner-reported backup needs exact required archive hashes and a
  restore from the independent device. GitHub controls were not refreshed.
  No publication,push,merge,dispatch,signing,admission,deployment or Stage12.
  M1/integration EXIT NOT_ESTABLISHED. Hosted costs/savings NOT RUN.
'''
commands = ['# Recorded commands and actual exits', '',
            'These are preserved earlier executions. The Markdown tracking step did not rerun HOL.', '']
for index in range(1, 4):
    case = f'code-{index:04d}'
    data = json.loads((O / case / 'command.json').read_text())
    commands += [f'## {case}', '', f'Working directory: `{data["cwd"]}`.', '',
                 '```sh', shlex.join(data['argv']), '```', '',
                 f'Actual exit: `{data["actual_exit"]}`. Wall seconds: `{data["wall_seconds"]}`.',
                 f'Source SHA-256: `{data["source_sha256"]}`.',
                 f'[Command record](records/{case}/command.json), [stdout](records/{case}/stdout.log), [stderr](records/{case}/stderr.log).', '']
commands += ['## Checks executed for this tracking step', '',
             f'Working directory: `{H}`.', '',
             '| Command | Actual exit |', '| --- | --- |',
             '| `python3 checkpoint.py` | 1 |',
             '| First inline correction preparation | 1 |',
             '| Premature `python3 checkpoint-complete.py` | 2 |',
             '| Corrected inline preparation | 0 |',
             '| `python3 checkpoint-complete.py` | 0 |', '',
             '[Preserved preparation errors](records/checkpoint-preparation-failures.json).', '',
             'No new proof import, repeat, negative control, native execution or hosted run occurred.']
for group, root in [('workspace', R), ('worktree', W)]:
    for name in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']:
        assert (root / name).read_bytes() == (H / 'before' / group / name).read_bytes()
    assert '## U314 ' not in (root / 'unsure.md').read_text()
    for name, section in [('ROADMAP.md', road), ('FORGE_MISSION_STATUS.md', status)]:
        path = root / name
        text = path.read_text()
        index = text.index('## ')
        text = text[:index] + section + text[index:]
        if name == 'FORGE_MISSION_STATUS.md':
            text = text.replace('Previous committed checkpoint: `195ad87e6e82badbc16151bb231581c410cebdb7`.',
                                'Previous committed checkpoint: `05a6596db5c147739c74b42d3df0c7fb38bd60b1`.\nCurrent incomplete initial-stack proof: U314; its failed bundles remain preserved.')
            old = '- [ ] **Next:** establish good_code for the exact initial stack program using\n  published word-label and word-to-stack convention theorems. Preserve compiler\n  identity, memory/alignment/register conditions and resource requirements.'
            assert old in text
            text = text.replace(old, f'- [x] Preserve the incomplete initial-stack composition, all three failures\n  and prepared but unexecuted audits/controls. See [U314]({link}).\n- [ ] **Next:** diagnose FIRST_ASSUM with typed goals at each drule boundary.\n  Then establish exact initial good_code and complete import, closure, repeat\n  and controls. Preserve compiler identity and memory/alignment/register/resource\n  conditions. The validated initializer still has15 premises, not14.')
        path.write_text(text)
    with (root / 'unsure.md').open('a') as f:
        f.write(entry)
    (root / P / 'CHECKPOINT.md').write_bytes((H / 'CHECKPOINT.template.md').read_bytes())
    (root / P / 'COMMANDS.md').write_text('\n'.join(commands) + '\n')
    (root / P / 'records/update-tracking.py').write_bytes(Path(__file__).read_bytes())
print(json.dumps({'actual_exit': 0, 'entry': 'U314', 'copies': 2, 'end_to_end': False}))
