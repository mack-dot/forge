from pathlib import Path
import hashlib, json

root = Path('/Users/mackianni/forge')
packet = root / 'proposals/refund-executable-feasibility/integrity-confirmation-20261109'
out = packet / 'records'
sha = lambda b: hashlib.sha256(b).hexdigest()
before = json.loads((out / 'tracking-before.json').read_text())
assert json.loads((out / 'CONFIRMATION.json').read_text())['actual_exit'] == 0
original = {name: (root / name).read_bytes() for name in before}
for name, data in original.items():
    assert len(data) == before[name]['bytes'] and sha(data) == before[name]['sha256'], name
    assert b'U336' not in data

roadmap = '''## Completed integrity preflight confirmed; no duplicate job — U336

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
TRANSFER_INTEGRITY_ESTABLISHED. U335 already completed the requested one-job
preflight. Fresh read-only provider evidence confirms that result; no rerun.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/confirm.py` |0|Fresh workflow/log equality; all181 prior packet members,50 protected paths and mission match |
| `python3 -I -B proposals/refund-executable-feasibility/integrity-confirmation-20261109/records/readback.py` (child) |0|Fresh provider evidence;1475+18 members; complete records match frozen manifests |
| Existing hosted `/usr/bin/python3 -I -B -` |0|Run42624212334,job129183679727,attempt1; log confirms shell exit |
| Existing three integrity mutations |Expected ValueError rejections|No separate OS exits |
| Six fresh GitHub reads |Tool success|Run,list,job,workflow,full log and timing |
| New hosted job / HOL / native /21-snapshot replay |NOT RUN|One-job request already fulfilled; HOL remains unauthorized |

[Report](proposals/refund-executable-feasibility/integrity-confirmation-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/integrity-confirmation-20261109/ASSURANCE.md).
Exact U335 workflow SHA b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9;
fresh log SHA b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
Existing use:9.004512771s wall,48684KiB peak RSS; provider16s,0 billable Ubuntu ms.
U333's redirect defect remains preserved; the executed workflow uses U334's fix
and the requested mutations/resource records. No source input or premise changed.
The existing [separate TextIO.read proof proposal](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
remains unchanged and unrun. Only root tracking updated; no local commit claimed.

'''
tracker = '''## Completed integrity request confirmed from fresh provider evidence — U336

TRANSFER_INTEGRITY_ESTABLISHED. [Fresh confirmation](proposals/refund-executable-feasibility/integrity-confirmation-20261109/REPORT.md)
and [assurance matrix](proposals/refund-executable-feasibility/integrity-confirmation-20261109/ASSURANCE.md).
U335's one hosted job already completed the requested scope. Fresh workflow and
full-log bytes match; confirmation0 and separate evidence reader0 validate the
complete1493-member result. Existing hosted process exit0; three mutation
rejections; no new hosted job. All181 prior packet members and50 protected paths
remain unchanged. Same-provider and runtime trust limits remain explicit.
The [TextIO.read proof proposal](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
is prepared and unrun; separate authorization remains required. No full correctness
claim or stage transition. M1 open; Stage12 unauthorized; end_to_end=false.

'''
entry = '''
## U336 — Existing authorized integrity run confirmed; duplicate execution avoided

- References:U333,U334,U335. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. The resumed request found U335 already complete on disk.
- Fresh GitHub run/list/job/workflow/log/timing reads all succeed. Run42624212334
  remains completed/success,attempt1,one job129183679727,one run at its head.
  No new job,rerun,publication,proof,native execution or21-snapshot replay occurred.
- confirm.py exits0. Fresh13735-byte workflow and455127-byte decoded log match
  U335 exactly. Workflow SHA b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9;
  log SHA b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
  One Ubuntu job,5-minute cap,permissions{},no secrets,privilege or proof execution.
  Original U333 redirect defect stays preserved. Executed U335 code retains the
  U334 refusal and adds requested mutation,exit and resource records.
- Existing separate readback.py runs against fresh provider responses and exits0.
  All1475+18 member records match frozen manifests; ten package identities,two
  commits,download counts,original quotation,three exact mutation reasons and
  complete exit0 evidence match. Its result is byte-identical to U335's result.
  Hosted mutation controls have ValueError rejections,not invented child exits.
- Existing measurements remain26196042 payload bytes plus36303 metadata bytes,
  9.004512771s wall,1.68537s user CPU,0.050339s system CPU,48684KiB peak RSS;
  provider16000ms,one job,0 billable Ubuntu ms reported. No new performance run.
- All181 manifest-listed U333/U334/U335 files match,including preserved failures;
  root50 protected hashes and mission match. No Git repair or new commit claimed.
  Only root tracker/journal updated; no other-workspace synchronization claimed.
- Impact:TRANSFER_INTEGRITY_ESTABLISHED remains TESTED. The requested preflight
  was already fulfilled; repeating it is unnecessary. Provider/control-plane,
  OS,Python/hash/TLS and connector authenticity remain explicit trust. Separate
  checker code does not establish independent administrative control.
- Evidence:proposals/refund-executable-feasibility/integrity-confirmation-20261109/
  REPORT.md,ASSURANCE.md,records and MANIFEST.json. No old journal bytes changed.
- Next check:separate authorization for the existing unchanged TextIO.read proof
  proposal. Proof workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1
  matches. HOL is not run. Native memory/frame,whole-program correspondence and
  independent21-snapshot replay remain open. M1 is not complete.
'''
for name, addition in [('ROADMAP.md', roadmap), ('FORGE_MISSION_STATUS.md', tracker)]:
    content = original[name].decode()
    index = content.index('## ')
    (root / name).write_text(content[:index] + addition + content[index:])
with (root / 'unsure.md').open('ab') as f:
    f.write(entry.encode())
after = {name: (root / name).read_bytes() for name in before}
assert after['unsure.md'] == original['unsure.md'] + entry.encode()
for name, addition in [('ROADMAP.md', roadmap), ('FORGE_MISSION_STATUS.md', tracker)]:
    assert after[name].decode().replace(addition, '', 1) == original[name].decode()
tracking = {name: {'before': before[name], 'after_sha256': sha(data)} for name, data in after.items()}
(out / 'tracking-after.json').write_text(json.dumps(tracking, indent=2) + '\n')
files = {str(p.relative_to(packet)): sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file() and p.name != 'MANIFEST.json'}
(packet / 'MANIFEST.json').write_text(json.dumps({'files': files, 'status': 'TRANSFER_INTEGRITY_ESTABLISHED', 'new_hosted_runs': 0, 'HOL_executed': False, 'end_to_end': False}, indent=2) + '\n')
print(json.dumps({'journal_prefix_preserved': True, 'prior_tracking_preserved': True, 'packet_members': len(files), 'end_to_end': False}))
