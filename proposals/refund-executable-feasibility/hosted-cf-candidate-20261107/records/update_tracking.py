from pathlib import Path
import hashlib,json,re,shutil
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
link='proposals/refund-executable-feasibility/hosted-cf-candidate-20261107'
road=f'''## Generic FFI candidate package ready; hosted approval pending — U329

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
U328's checked replay obstruction remains. No new behavioral theorem is claimed.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Saved-state / module-path metadata |0/0|Four-state chain;549 preloaded modules |
| Input collection / packaging |0/0|1,475 new files; three archive parts |
| Relocated pinned HOL and exact term parsing |0|1,493 input identities match; no cfLib load or theorem attempt |
| Workflow validation / transport roundtrip |0/0|One bounded job; exact streams reconstructed |
| Wrong archive hash / path traversal / symlink |1/1/1|Expected transport refusals |
| First / corrected artifact readback |1/0|Cross-workspace baseline error preserved; separate historical baselines match |
| New generic proof / hosted job / independent21-snapshot replay |NOT RUN|Explicit additional-run and input-transfer approval pending |

[Results]({link}/REPORT.md); [assurance matrix]({link}/ASSURANCE.md).
Public loadHierarchy and path registration permit exact saved-state/module files
in private paths. The unchanged candidate statement parses. Its proof and closure
remain unchecked. No failing local loader/SAT/ARM8 route was retried.
[Concrete next action]({link}/APPROVAL.md):publish10,815,103 input bytes and
run one15-minute macOS ARM64 job for the unchanged generic FFI candidate,with
conditional repeat/import/two controls. No automatic retry or native/full-chain
replay is included. The owner's current goal requires this additional approval.
No publication,protected change,signing,Stage12 or deployment occurred.

'''
tracker=f'''## Hosted generic FFI scope prepared — U329

[Actual preparation results]({link}/REPORT.md); [current assurance matrix]({link}/ASSURANCE.md).
The exact candidate parses after supported relocation of four pinned saved
states and module paths. Local child0;1,493 input hashes match before/after.
No cfLib load or behavioral proof ran. Static workflow and transport checks0/0;
three archive rejection controls1/1/1. A wrong cross-workspace baseline check1
is preserved; corrected separate-baseline readback0 confirms preservation.

The [reviewable one-job scope]({link}/APPROVAL.md) awaits explicit hosted-run
and input-transfer approval. New manifest SHA256
6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105.
No remote write or new hosted execution. Generic error theorem, native C/frame
relation, memory/init, linker/loader and independent21-snapshot replay remain
open. U328's full-event obstruction is retained; no no-error assumption added.
M1 PARTIAL; Stage12 unauthorized; end_to_end=false. No silicon proof is pursued.

'''
entry='''
## U329 — Exact generic FFI hosted package prepared; additional approval pending

- References:U310,U315,U320,U326,U327,U328. Parentb8586b6. CURRENT none;
  M1 open; Stage12 unauthorized; end_to_end=false. The software boundary stays
  unchanged:explicit ISA implementation, documented OS behavior and HOL trust.
- U328's generic candidate remains byte-identical,SHA
  7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6.
  Its last actual cfLib attempt is still the U328 exit1 before the theorem.
  The cause remains distinct from the proved U320 mkstemp failure unless new
  evidence relates them. No local failing loader/SAT/ARM8 route was retried.
- Public PolyML saved-state and HOL path metadata inspections exit0/0.
  Four required states are identified;549 preloaded modules do not include
  cfLib. Published holpathdb registration and Meta.loadPath permit relocation
  without rewriting any runtime,state,library file,theorem or solver binding.
- Static collection/packaging exit0/0:280 module nodes,1,475 additional files
  and18 previously published base files. Three parts bind9,882,464 compressed
  bytes. New manifest932,639 bytes,SHA
  6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105.
  Proposed new publication totals10,815,103 bytes plus one workflow. Static
  file references and cached proof ancestry are not a checked new theorem closure.
- Local private-context inspection exits0. All1,493 input hashes match before
  and after. Exact candidate quotation parses. Private pinned Poly/ML/GMP paths
  appear in the load log. No cfLib load,theorem attempt or generated theory.
  This is same-host preparation,not independently controlled full-chain replay.
- Workflow/transport checks exit0/0. Three complete logged files reconstruct
  byte for byte. Wrong archive hash,path traversal and symlink controls exit1/1/1
  at expected assertions. These check transport,not mathematical correctness.
- First artifact readback exits1 because the root protected baseline was
  incorrectly applied to a distinct review-worktree history. Script and traceback
  preserved. Corrected readback exits0:root historical50 protected paths and
  frozen mission match; review worktree protected diff againstb8586b6 exits0.
  Source lookup failures,ps permission denial and a wrong-directory copy failure
  are retained. No observed cause is attributed to the historical cfLib failure.
- The exact prepared workflow has token permissions{},one macOS ARM64 job,
  fixed image20261104.0514.1,private paths and unchanged pinned inputs.
  Limits:15 minutes per job;CPU120/wall150 seconds and maxheap1536MiB per child;
  4MiB per output file. The final wall-limit/runtime-path additions are statically
  reviewed; they have not executed remotely. Missing evidence is failure.
- Proposed sequence:environment controls; unchanged generic candidate; only
  on success,identical repeat,fresh import and two exact-statement refusals.
  Stop on the first unexpected result. No implicit second job or proof revision.
  Original MiniSat binding remains; its old absolute path must be unavailable,
  so any use of HOL's existing fallback is disclosed as inU326.
- Approval requested for this exact input publication and one job under the
  owner's explicit additional-hosted-run rule. None received at this checkpoint.
  No remote write,hosted execution,new native run,Stage12,signing,deployment,
  swarm or21-snapshot replay occurred. Provider/OS isolation would remain trust;
  private permissions and hashes do not prove adversarial same-UID isolation.
- Smallest next action:approve the concrete scope in
  proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/APPROVAL.md.
  Then read back exact published bytes and execute the unchanged candidate.
  If it runs,inspect the actual residual or theorem premises/closure. A generic
  transition remains an obligation,not a new assumption. Native errors/frame,
  inputAllFrom/refund_main,stdout,memory/install/resources,link/loader and full
  independent replay remain open. Logical Success is not native OS exit0.
- Evidence:the same packet's REPORT.md,ASSURANCE.md,COMMANDS.md,payload,
  records and MANIFEST.json. ROADMAP/tracker updated; this append preserves
  the separate journal prefixes. No original theorem or event requirement changed.
'''
records=[]
for base in [ROOT,WT]:
    path=base/'unsure.md';before=path.read_bytes()
    assert re.search(rb'^## U328\b',before,re.M) and not re.search(rb'^## U329\b',before,re.M)
    with path.open('ab') as f:f.write(entry.encode())
    assert path.read_bytes()[:len(before)]==before
    row={'base':str(base),'journal_prefix_bytes':len(before),'journal_prefix_sha256':sha(before),
         'journal_after_sha256':sha(path.read_bytes()),'entry_sha256':sha(entry.encode())}
    for name,addition in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',tracker)]:
        p=base/name;old=p.read_bytes();pos=old.index(b'\n## ')
        p.write_bytes(old[:pos+1]+addition.encode()+old[pos+1:])
        row[name]={'before_sha256':sha(old),'after_sha256':sha(p.read_bytes())}
    records.append(row)
(OUT/'tracking.json').write_text(json.dumps(records,indent=2)+'\n')
packet=ROOT/link
for name in ['readback_packet.py','readback_packet_v1.py','readback_packet_v2.py','readback.json','update_tracking.py','tracking.json']:
    shutil.copy2(OUT/name,packet/'records'/name)
files={str(p.relative_to(packet)):sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file()}
assert 'MANIFEST.json' not in files
(packet/'MANIFEST.json').write_text(json.dumps({'files':files,'end_to_end':False,'approval':'PENDING'},indent=2)+'\n')
shutil.copytree(packet,WT/link)
for base in [ROOT,WT]:
    for rel,h in files.items():assert sha((base/link/rel).read_bytes())==h,(base,rel)
for r in records:
    b=(Path(r['base'])/'unsure.md').read_bytes()
    assert sha(b[:r['journal_prefix_bytes']])==r['journal_prefix_sha256']
print(json.dumps({'actual_exit':0,'packet_members':len(files),'two_copies_match':True,
                  'distinct_journal_prefixes_preserved':True,'approval':'PENDING','end_to_end':False},indent=2))
