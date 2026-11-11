from pathlib import Path
import ast
import difflib
import hashlib
import json
import shutil

root = Path('/Users/mackianni/forge')
review = Path('/private/tmp/forge-native-audit-review-20261104')
out = Path(__file__).resolve().parent
old_rel = Path('proposals/refund-executable-feasibility/integrity-preflight-20261108')
rel = Path('proposals/refund-executable-feasibility/integrity-preflight-20261109')
packet = root / rel
sha = lambda b: hashlib.sha256(b).hexdigest()
write_json = lambda p, v: p.write_text(json.dumps(v, indent=2) + '\n')
assert not packet.exists() and not (review / rel).exists()
old_manifest = json.loads((root / old_rel / 'MANIFEST.json').read_text())
for base in [root, review]:
    for name, expected in old_manifest['files'].items():
        assert sha((base / old_rel / name).read_bytes()) == expected, str(base / old_rel / name)
old_source = (root / old_rel / 'records/integrity_driver.py').read_text()
source = (out / 'integrity_driver.py').read_text()
def constants(text):
    return {ast.dump(n.targets[0]): ast.dump(n.value) for n in ast.parse(text).body
            if isinstance(n, ast.Assign)}
assert constants(source) == constants(old_source)
(out / 'driver.diff').write_text(''.join(difflib.unified_diff(old_source.splitlines(True), source.splitlines(True),
                                                           fromfile='U333/integrity_driver.py', tofile='U334/integrity_driver.py')))
prep = json.loads((out / 'PREPARATION.json').read_text())
assert prep['workflow_bytes'] == 11897 and prep['driver_bytes'] == 9886
write_json(out / 'SOURCE-PRESERVATION.json', {
    'actual_exit': 0, 'old_packet_members_each_copy': len(old_manifest['files']), 'copies': 2,
    'old_manifest_sha256': sha((root / old_rel / 'MANIFEST.json').read_bytes()),
    'commit_manifest_candidate_constants_unchanged': True,
    'published_inputs_changed': False, 'proof_input_audit_reused': 'U333 OFFLINE-CHECK.json; no full replay repeated',
    'new_git_commit': 'NOT_RUN', 'hosted_jobs_started': 0, 'end_to_end': False})
packet.mkdir(parents=True)
approval = (root / old_rel / 'APPROVAL.md').read_text()
for before, after in [
    ('# Proposed integrity-only preflight: one job, no proof execution', '# Revised U334 integrity-only preflight: one job, no proof execution'),
    ('11,609', '11,897'), ('9,638', '9,886'),
    ('proposal/m1-input-integrity-20261108', 'proposal/m1-input-integrity-20261109'),
    ('3e7c35a8b3a21a3645f8f966e6ba8058a2a605646c9eb3499d105eed2ed20e78', prep['workflow_sha256']),
    ('a22b7aa7496739a189366f6178c1d041dd4dda354dc441cb255221ce3def6812', prep['driver_sha256']),
]:
    approval = approval.replace(before, after)
approval += '''
This copy replaces the U333 approval proposal. U333 remains preserved and must
not be published: its default urllib handler followed redirects before checking
the final URL. The revised driver refuses redirects before a follow-up request.
The local controlled HTTP302 case confirms the original defect without network
access. Revised positive control exits0;301/302/303/307/308 controls exit1 with
zero follow-up requests. Exit codes and exact request/rejection records agree.
Python3.10 rejects308 via HTTPError; the actual Ubuntu Python remains untested.
These controls are TESTED evidence only. The hosted preflight is NOT RUN.

The expected source identities are the two remote input commits listed above.
Their commit/tree/blob identities and actual downloaded bytes are checked by
the job. Missing local review Git metadata does not supply or substitute a
commit identity. The new workflow commit must also be read back before its
branch is published. No proof-run approval is included in this request.
'''
(packet / 'APPROVAL.md').write_text(approval)
(packet / 'REPORT.md').write_text('''# U334: exact workflow review found and corrected a redirect scope defect

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner explicitly described the latest message as a recommendation,not an
authorization. Neither integrity nor proof execution is authorized by it.

U333 used urllib.request.urlopen,which can follow a redirect before checking
response.geturl(). It rejected a changed final URL, but only after a possible
request outside the stated host scope. A controlled local HTTP302 response
demonstrated the original handler attempting the second URL; child exit1.
The fake transport intercepted every request. No network socket was opened.
This is an orchestration defect,not a refund theorem or input defect.

The revised driver installs an HTTPRedirectHandler that raises before following
a redirect. All commit,manifest,archive,candidate and quotation checks remain.
The workflow uses a new proposal branch; no published file was changed.
The original U333 packet remains byte-identical in both directories.

| Executed check | Actual exit | Evidence |
| --- | --- | --- |
| Revised preparation / embedded shell syntax |0 / 0|PREPARATION.json |
| Original controlled HTTP302 case |1|Follow-up URL detected before any socket |
| Revised positive response |0|Exact fixture bytes accepted |
| Revised301/302/303/307/308 controls |1/1/1/1/1|Zero follow-ups; exact reasons checked |
| Corrected control recorder |0|REDIRECT-CONTROLS-V2.json |
| U333 preservation and pinned constants |0|SOURCE-PRESERVATION.json |
| Hosted integrity / HOL / replay |NOT RUN|No external execution authority |

The initial control recorder exited0 after checking only child exit codes.
Its308 child raised HTTPError without the expected result record. That summary
was insufficient. Its source and all stdout/stderr remain. The corrected
recorder checks exact rejection reasons,request lists and request counts.
On local Python3.10,308 is rejected by the existing HTTP error path; the other
four codes enter the new redirect refusal. Ubuntu runtime behavior is untested.
No local fixture result is remote byte readback or universal correctness proof.

The previous1,493-member audit and three identity-mutation controls are reused
from U333. They were not rerun. The source pins and theorem premise quotation
did not change. Full remote package readback and the theorem remain unestablished.

[APPROVAL.md](APPROVAL.md) fixes the exact revised11897-byte workflow and9886-byte
driver. Scope:one Ubuntu job,5-minute cap,permissions{},180-second driver wall
limit,90 CPU seconds,1GiB address space,32MiB/file,zero core dumps. It reads the
same26196042 payload bytes plus eight bounded metadata responses from the two
existing input commits. No new proof payload,install,secret or input execution.
Only the reviewed workflow is published. Recheck parent/trigger definitions and
new workflow commit identity before publishing its trigger branch.

NO-GO for the old U333 workflow. GO recommendation for the revised integrity-only
preflight after explicit approval. No approval extends to HOL,candidate repeat,
fresh import or proof controls. Native memory/frame,whole-program composition
and21-snapshot replay remain separate. Local Git metadata remains unresolved;
no Git repair or new commit was attempted. Evidence is preserved as local files.
''')
(packet / 'ASSURANCE.md').write_text('''# U334 assurance update

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| Original redirect scope defect | TESTED |Controlled302 attempts a second URL; intercepted before socket access. |
| Revised redirect refusal | TESTED |Positive0; five redirect controls1; exact reasons and zero follow-ups checked locally. |
| Workflow identity and syntax | TESTED |PREPARATION.json; no hosted execution. |
| Frozen input and theorem identity | TESTED |U333 reused; candidate/manifest/commit constants unchanged; U333 packet matches. |
| Remote complete byte readback | NOT_ESTABLISHED |No job run; local fixtures are not GitHub bytes. |
| Hosted checker isolation and runtime | ASSUMED |GitHub control plane,OS,Python/hash/TLS; future actual runner identity must be recorded. |
| TextIO.read theorem and closure | NOT_ESTABLISHED |No HOL invocation. |
| Native memory/frame and whole-program correspondence | NOT_ESTABLISHED |Separate obligations; all existing premises retained. |
| Independent21-snapshot replay | NOT_ESTABLISHED |Separate and unrun. |
| Exact executable end-to-end correctness | NOT_ESTABLISHED |M1 remains open. |

The current owner message explicitly supplies no authorization. The revised
integrity job requires approval; the HOL job requires separate approval later.
Local Git metadata failure remains unresolved; no new local commit is claimed.
''')

roadmap = '''## Redirect scope corrected; revised integrity job awaits approval — U334

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner's recommendation is explicitly not authorization. No hosted job ran.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Revised workflow preparation / shell syntax |0 / 0|New orchestration only; pinned inputs unchanged |
| Original HTTP302 local control |1|Default handler attempts redirected URL |
| Revised positive / five redirect controls |0 / 1,1,1,1,1|Exact reasons and zero follow-up requests checked |
| Corrected control recorder / preservation |0 / 0|Original records and U333 retained |
| Hosted integrity / HOL /21-snapshot replay |NOT RUN|Authorization absent |

[Revised exact approval scope](proposals/refund-executable-feasibility/integrity-preflight-20261109/APPROVAL.md);
[report](proposals/refund-executable-feasibility/integrity-preflight-20261109/REPORT.md);
[assurance](proposals/refund-executable-feasibility/integrity-preflight-20261109/ASSURANCE.md).
NO-GO for U333's workflow:it checked redirects after following them. U334 refuses
them first. GO recommendation for this revised11897-byte workflow,one Ubuntu job,
5 minutes,permissions{},only after explicit approval. Remote bytes remain unchecked.
The first recorder's exit-only308 result was insufficient; both control versions
are preserved. No repeated input audit,DNS retry,proof change or Git repair.

'''
tracker = '''## Revised integrity scope ready; no execution approval — U334

[Exact revised approval](proposals/refund-executable-feasibility/integrity-preflight-20261109/APPROVAL.md),
[results](proposals/refund-executable-feasibility/integrity-preflight-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/integrity-preflight-20261109/ASSURANCE.md).
Review found a real redirect scope defect in U333. Its workflow is NO-GO.
The revised driver refuses redirects before following them. Local positive0;
five rejection controls1; exact reasons and request counts checked. No network.
U333's frozen input audit is reused. Full remote byte readback remains open.
Neither revised integrity execution nor HOL execution is currently authorized.
GO recommendation applies only to approval of the exact revised integrity job.
No new theorem,Git commit or hosted run. M1 open; Stage12 unauthorized;
end_to_end=false. Native frame/composition/replay remain separate obligations.

'''
entry = '''
## U334 — Exact preflight review corrects redirect scope before authorization

- References:U332,U333. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner explicitly gave a recommendation,not authorization.
- Exact workflow review found urllib followed redirects before the final URL
  check. This could exceed the stated host scope before rejection. Original
  local302 control exits1 and records a second URL,intercepted before a socket.
  This is a checker orchestration defect; no proof/input defect is inferred.
- New proposal refuses redirects before following them. Workflow SHA256
  213160ff1a6b09f1e7def8f2076b2e7abf73e24a6d0f982faac38192fbfe753d;
 11897 bytes. Driver SHA867ef586d6d1a5ed8a5f9efa7efd71c9ed60fcef150ad655c5938d5307c62e72;
 9886 bytes. Preparation/shell0/0. Only transport handler and proposal branch/
  concurrency changed; all source pins and theorem quotations remain.
- Initial recorder exits0 but accepts exit codes without checking result records.
  Its308 child has HTTPError and no expected result record. This limitation is
  preserved. Corrected recorder0 validates exact reasons,request lists/counts:
  positive0;301/302/303/307/308 each1 with zero follow-up requests. Python3.10
  rejects308 via HTTPError; remaining codes use the new guard. Ubuntu execution
  is still untested. These controls use local fake HTTP handlers,no network.
- U333's1,493-member and identity-mutation checks are reused,not repeated.
  Both copies of its64 packet members match. Actual remote binary readback
  remains NOT_ESTABLISHED. No DNS retry,Git repair,proof or hosted run occurred.
- Supersedes U333's GO recommendation for its original workflow:old version
  NO-GO. GO for requesting approval of revised one-job Ubuntu integrity scope,
  permissions{},5-minute cap,same immutable downloads; no proof input execution.
  Latest owner instruction requires approval,and explicitly has not granted it.
- Missing local Git metadata remains unresolved; no new commit claimed. The
  hosted checker must independently bind remote input commits21c4bdf/ac05eaf,
  their trees/blobs and actual downloaded bytes. Local Git is no substitute.
- Evidence:proposals/refund-executable-feasibility/integrity-preflight-20261109/
  APPROVAL.md,REPORT.md,ASSURANCE.md,records and MANIFEST.json. Both old journal
  prefixes retained; tracker and ROADMAP updated. Prior evidence unchanged.
- Next check:explicit approval of the revised integrity job,then its full logs
  and actual exit. HOL still needs separate approval after integrity. Native
  memory/frame,whole-program composition and21-snapshot replay remain separate.
'''
tracking = []
for base in [root, review]:
    before = {n: (base / n).read_bytes() for n in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']}
    assert all(b'U334' not in b for b in before.values())
    with (base / 'unsure.md').open('ab') as f:
        f.write(entry.encode())
    for name, text in [('ROADMAP.md', roadmap), ('FORGE_MISSION_STATUS.md', tracker)]:
        data = before[name].decode()
        i = data.index('## ')
        (base / name).write_text(data[:i] + text + data[i:])
    row = {'root': str(base), 'files': {}}
    for name, data in before.items():
        after = (base / name).read_bytes()
        if name == 'unsure.md':
            assert after.startswith(data)
        row['files'][name] = {'before_bytes': len(data), 'before_sha256': sha(data), 'after_sha256': sha(after)}
    tracking.append(row)
write_json(out / 'tracking.json', tracking)
shutil.copytree(out, packet / 'records', ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
files = {str(p.relative_to(packet)): sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file()}
write_json(packet / 'MANIFEST.json', {'files': files, 'hosted_jobs_started': 0, 'new_commit': 'NOT_RUN', 'end_to_end': False})
shutil.copytree(packet, review / rel)
print(json.dumps({'actual_exit': 0, 'packet_members': len(files), 'manifest_sha256': sha((packet / 'MANIFEST.json').read_bytes()),
                  'journal_prefixes_preserved': 2, 'hosted_jobs_started': 0, 'end_to_end': False}))
