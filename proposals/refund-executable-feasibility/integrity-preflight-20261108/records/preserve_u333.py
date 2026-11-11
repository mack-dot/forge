from pathlib import Path
import hashlib
import json
import shutil

root = Path('/Users/mackianni/forge')
review = Path('/private/tmp/forge-native-audit-review-20261104')
raw = root / 'results/hosted-integrity-prep-20261108/attempt-0001'
rel = Path('proposals/refund-executable-feasibility/integrity-preflight-20261108')
packet = root / rel
sha = lambda b: hashlib.sha256(b).hexdigest()
write_json = lambda p, v: p.write_text(json.dumps(v, indent=2) + '\n')
assert not (packet / 'MANIFEST.json').exists()
assert not (review / rel).exists()

baseline_path = root / 'proposals/refund-executable-feasibility/native-audit-20261104/records/baseline.json'
baseline = json.loads(baseline_path.read_text())
for name, expected in baseline['protected'].items():
    assert sha((root / name).read_bytes()) == expected, name
assert sha((root / 'FORGE_MISSION.md').read_bytes()) == baseline['mission_sha256']
old_packets = []
for base in [root, review]:
    for name in ['hosted-cf-candidate-20261107', 'hosted-cf-transfer-20261108']:
        p = base / 'proposals/refund-executable-feasibility' / name
        m = json.loads((p / 'MANIFEST.json').read_text())
        for n, h in m['files'].items():
            assert sha((p / n).read_bytes()) == h, str(p / n)
        old_packets.append({'path': str(p), 'matched_files': len(m['files']),
                            'manifest_sha256': sha((p / 'MANIFEST.json').read_bytes())})

write_json(raw / 'PRESERVATION.json', {
    'actual_exit': 0, 'root_protected_paths': len(baseline['protected']),
    'root_mission_matches': True, 'baseline_path': str(baseline_path),
    'baseline_sha256': sha(baseline_path.read_bytes()), 'old_packets': old_packets,
    'current_review_git_diff': 'NOT_ESTABLISHED: worktree metadata missing',
    'local_commit': 'NOT_RUN', 'hosted_runs_started': 0, 'end_to_end': False})
admin = Path('/private/tmp/forge-campaign-main-20261102/.git/worktrees/forge-native-audit-review-20261104')
write_json(raw / 'WORKTREE-METADATA-FINAL.json', {
    'review_git_pointer_exists': (review / '.git').exists(),
    'admin_path': str(admin), 'admin_entries': sorted(p.name for p in admin.iterdir()),
    'missing_admin_fields': [n for n in ['HEAD', 'gitdir', 'commondir'] if not (admin / n).exists()],
    'earlier_preservation_script_actual_exit': 1,
    'earlier_git_rev_parse_actual_exit': 128,
    'earlier_followup_git_batch_actual_exit': 129,
    'issuer_or_cause': 'NOT_ESTABLISHED', 'repair_attempted': False,
    'decision': 'Preserve files; do not reconstruct missing Git metadata or invent a commit.',
    'end_to_end': False})

preservation_note = '''
## Local preservation limitation

During final preservation, the review worktree's .git pointer and its shared
HEAD/gitdir/commondir metadata were absent. git rev-parse exited128. The first
preservation script exited1 before tracker edits; a later Git diagnostic batch
exited129. Cause and issuer are unknown. No Git metadata repair was attempted.
This checkpoint is preserved as files without a new local commit. Root50
protected paths and the mission match their recorded hashes. Both copies of
the frozen U329 and U332 packets match their manifests. A current review Git
diff is NOT_ESTABLISHED. This does not replace remote byte verification.
'''
with (packet / 'REPORT.md').open('a') as f:
    f.write(preservation_note)
with (packet / 'ASSURANCE.md').open('a') as f:
    f.write('\nLocal preservation: root50 protected hashes and mission match; U329/U332\n'
            'packets match in both directories. Current review Git status is\n'
            'NOT_ESTABLISHED because worktree metadata is incomplete. New commit NOT RUN.\n')

roadmap = '''## Remote integrity preflight prepared; authorization pending — U333

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit/result | Result |
| --- | --- | --- |
| getaddrinfo localhost / three GitHub hosts |0 / 1,1,1|Remote names fail with gaierror8 |
| scutil --dns / curl --head |1 / 6|No visible DNS configuration; resolution fails |
| Remote manifest,commit and tree reads |Tool success|Two exact manifests; commit/tree identities reconstructed |
| Offline independent-code verifier |0|1,475 new and18 base local members; original premises match |
| Changed commit / manifest / part controls |1 / 1 / 1|Expected integrity refusals |
| Workflow and shell syntax |0|No hosted execution |
| Root protected paths / mission / old packet hashes |0|50 paths and mission; U329/U332 copies match |
| Initial preservation / git rev-parse / Git diagnostic batch |1 / 128 / 129|Missing worktree metadata; no new commit |
| Hosted preflight / proof /21-snapshot replay |NOT RUN|Explicit authorization pending |

[Exact preflight approval scope](proposals/refund-executable-feasibility/integrity-preflight-20261108/APPROVAL.md);
[evidence](proposals/refund-executable-feasibility/integrity-preflight-20261108/REPORT.md);
[assurance matrix](proposals/refund-executable-feasibility/integrity-preflight-20261108/ASSURANCE.md).
GO recommendation:authorize one integrity-only Ubuntu job,5-minute cap,
permissions{},one11,609-byte workflow; no proof inputs uploaded or executed.
NO-GO for proof:full remote binary readback remains unestablished. Proof execution
needs complete integrity evidence and separate approval under the owner's rule.
Local offline checks are not remote readback or independently controlled replay.
No theorem,premise,published input or protected file changed. The new checkpoint
has no commit because review Git metadata is incomplete; evidence remains local.

'''
tracker = '''## Integrity-only preflight ready; remote bytes remain unchecked — U333

[Exact approval scope](proposals/refund-executable-feasibility/integrity-preflight-20261108/APPROVAL.md),
[results](proposals/refund-executable-feasibility/integrity-preflight-20261108/REPORT.md),and
[assurance matrix](proposals/refund-executable-feasibility/integrity-preflight-20261108/ASSURANCE.md).
Remote manifest and commit/tree checks pass. Separate local verification checks
all1,493 frozen members and unchanged candidate premises; mutations exit1/1/1.
Remote binary readback remains NOT_ESTABLISHED. Local DNS fails before HTTPS.
Prepared fallback:one integrity-only Ubuntu job,permissions{},5-minute cap.
No hosted job or proof ran. Approval is pending under the current owner rule.
The existing macOS proof/repeat/import/two controls remain frozen and separately
authorized; native memory/frame,whole-program composition and21-snapshot replay
remain separate. M1 open; Stage12 unauthorized; end_to_end=false.
Missing review Git metadata prevents a new commit; both local journal histories
remain separate and append-only. Root protected hashes and prior packets match.

'''
entry = '''
## U333 — DNS boundary diagnosed; integrity-only hosted fallback prepared

- References:U328–U332. Last verified parentbd37d71. CURRENT none; M1 open;
  Stage12 unauthorized; end_to_end=false. No hosted execution or remote write.
- getaddrinfo(localhost) exits0. Three GitHub host lookups exit1/gaierror8;
  scutil --dns exits1 with "No DNS configuration available"; curl exits6.
  Resolver visibility in the managed context is the likely boundary,not a
  proven global DNS defect. Exact enforcing rule and issuer remain unknown.
- DNS recorder exits0 but its scutil boolean was overwritten by empty stderr.
  Raw stdout establishes the actual message. Explicit annotation correction
  preserves the original flawed summary,script,logs and failures.
- Fresh connector reads return both full frozen manifests. SHA256 values match.
  Reconstructed unsigned commits21c4bdf/ac05eaf and six trees match. An initial
  UTC-only reconstruction had no matches; original -0500 headers match exactly.
- Separate verifier exits0 for2 commits,6 trees,10 package files and all1,475
  new plus18 base local archived members. Full candidate SHA7e36c486 and exact
  candidate/import quotation match. Changed commit/manifest/part exit1/1/1.
  This is separate implementation by the same agent,not independent control.
  Captured API data plus local archives do not prove remote binary readback.
- Remote complete package readback remains NOT_ESTABLISHED. Known binary
  connector limitations were not retried. No DNS/security setting was changed.
- Prepared workflow SHA3e7c35a8b3a21a3645f8f966e6ba8058a2a605646c9eb3499d105eed2ed20e78;
  driver SHAa22b7aa7496739a189366f6178c1d041dd4dda354dc441cb255221ce3def6812.
  Workflow/shell checks exit0. Proposed one Ubuntu integrity job,permissions{},
  5-minute cap;180 wall seconds,90 CPU seconds,1GiB address space. Only one
  11,609-byte workflow is published;26,196,042 existing payload bytes plus
  eight bounded API responses are read. No input execution,installation or HOL.
- GO recommendation:authorize the exact integrity-only preflight. NO-GO proof
  until complete remote integrity evidence and separate proof-run approval.
  Current owner rule explicitly requires approval; none received for this job.
- During preservation the review .git pointer and admin HEAD/gitdir/commondir
  were absent. Initial preservation exited1 before edits; git rev-parse128;
  followup Git diagnostic batch129. Cause unknown. No metadata repair or new
  commit. Local protected50 hashes/mission and both prior packet copies match.
  Current review Git diff is NOT_ESTABLISHED; no reconstructed history claimed.
- Evidence:proposals/refund-executable-feasibility/integrity-preflight-20261108/
  APPROVAL.md,REPORT.md,ASSURANCE.md,records and MANIFEST.json. Root and review
  journals keep their separate prefixes; tracker and ROADMAP record actual exits.
- Next check:authorized hosted byte verification,with complete logs and actual
  exit0 required. The frozen TextIO.read theorem/closure remains unproved.
  Native frame/memory,whole-program composition and21-snapshot replay remain
  separate. Logical Success,FFI events,OS exit and physical effects stay distinct.
'''

prior_tracking = json.loads((root / 'proposals/refund-executable-feasibility/hosted-cf-transfer-20261108/records/tracking.json').read_text())
tracking = []
for base in [root, review]:
    # Different histories are checked and updated separately.
    before = {n: (base / n).read_bytes() for n in ['unsure.md', 'ROADMAP.md', 'FORGE_MISSION_STATUS.md']}
    assert all(b'U333' not in b for b in before.values())
    rec = {'root': str(base), 'files': {}}
    for n, data in before.items():
        rec['files'][n] = {'before_bytes': len(data), 'before_sha256': sha(data)}
    with (base / 'unsure.md').open('ab') as f:
        f.write(entry.encode())
    for n, text in [('ROADMAP.md', roadmap), ('FORGE_MISSION_STATUS.md', tracker)]:
        data = before[n].decode()
        pos = data.index('## ')
        (base / n).write_text(data[:pos] + text + data[pos:])
    for n, data in before.items():
        after = (base / n).read_bytes()
        if n == 'unsure.md':
            assert after[:len(data)] == data
        rec['files'][n].update({'after_bytes': len(after), 'after_sha256': sha(after)})
    rec['journal_prefix_preserved'] = True
    tracking.append(rec)
write_json(raw / 'tracking.json', tracking)

for p in raw.rglob('*'):
    if not p.is_file() or 'offline' in p.relative_to(raw).parts:
        continue
    dest = packet / 'records' / p.relative_to(raw)
    if dest.exists():
        assert dest.read_bytes() == p.read_bytes(), str(dest)
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, dest)
files = {str(p.relative_to(packet)): sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file()}
write_json(packet / 'MANIFEST.json', {'files': files, 'hosted_runs_started': 0,
    'remote_complete_byte_readback': 'NOT_ESTABLISHED', 'local_commit': 'NOT_RUN', 'end_to_end': False})
shutil.copytree(packet, review / rel)
print(json.dumps({'actual_exit': 0, 'packet_files': len(files), 'root_protected_paths': 50,
                  'journal_prefixes_preserved': 2, 'manifest_sha256': sha((packet / 'MANIFEST.json').read_bytes()),
                  'local_commit': 'NOT_RUN', 'hosted_runs_started': 0, 'end_to_end': False}))
