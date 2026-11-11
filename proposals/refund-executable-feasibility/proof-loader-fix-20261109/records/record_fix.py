from pathlib import Path
import hashlib,json
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent;packet=out.parent
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
assert read(out/'PRESERVATION.json')['actual_exit']==0
before=read(out/'tracking-before.json');original={n:(root/n).read_bytes() for n in before}
for n,b in original.items():assert len(b)==before[n]['bytes'] and sha(b)==before[n]['sha256']
assert b'U341' not in original['unsure.md']
section='''## Loader paths fixed; real local regression passes — U341

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Two bootstrap expressions now supply virtual theory paths for parent loads and
later imports. All other driver/workflow fields and proof inputs are unchanged.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/prepare_fix.py` |0|New unpublished workflow;five generated modes checked |
| `/bin/bash --noprofile --norc -n proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/shell.sh` |0|Shell syntax only |
| Initial local loader regression |1|Non-exported API in test;source/logs preserved,not an accepted negative |
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/test_loader.py` corrected |0|Real child old path1/exact ENOENT;fixed path0,four parent byte reads,two import path resolutions |
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/check_preservation.py` |0|Only two driver expressions differ;candidate/controls,50 protected paths and mission match |
| Candidate proof / hosted job / publication |NOT RUN|Prior one-retry grant exhausted |

[Fix and tests](proposals/refund-executable-feasibility/proof-loader-fix-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-loader-fix-20261109/ASSURANCE.md),
[separate execution scope](proposals/refund-executable-feasibility/proof-loader-fix-20261109/NEXT-RUN-APPROVAL.md).
Workflow SHA9a29e94d16033592704bfa20bd1ef06818e50458d4155a2216500ac205486629,
16363 bytes. Actual pinned HOL file APIs tested;no theory sources compiled,
cfLib/SAT loaded or theorem attempted. Future output paths resolve correctly,
but no fresh theorem import occurred. Full hosted proof remains unestablished.
Old failures preserved;no protected change,Stage12,signing or deployment.

'''
tracker='''## Bootstrap path fix tested locally; proof execution remains open — U341

[Fix](proposals/refund-executable-feasibility/proof-loader-fix-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-loader-fix-20261109/ASSURANCE.md).
Parent and generated-theorem imports now use virtual paths. Only two driver
expressions changed. Actual pinned HOL file-layer regression reproduces old
ENOENT/exit1;corrected path exits0 and reads all four parent files byte-identically.
Two future import paths resolve correctly;no exports exist to import yet.
Initial test API static error1 preserved;corrected test runner0. Candidate and
controls unchanged. No cfLib/SAT/theorem execution or hosted action.
[Exact corrected one-job scope](proposals/refund-executable-feasibility/proof-loader-fix-20261109/NEXT-RUN-APPROVAL.md)
is prepared for separate authorization. M1 open;Stage12 unauthorized;
end_to_end=false. Native correspondence/composition/replay remain separate.

'''
entry='''
## U341 — Virtual theory paths fixed; actual pinned loader regression passes

- References:U282,U291,U340. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner requests fixing the defect. No additional hosted
  execution is inferred from that request;the preceding single retry is exhausted.
- New local proposal removes explicit .hol/objs from two driver expressions:
  parent signature/source paths and generated-theorem import/control paths.
  All other driver bytes and workflow fields unchanged. All five generated
  modes use virtual theory paths;candidate/control script paths untouched.
- Corrected workflow16363 bytes,SHA9a29e94d16033592704bfa20bd1ef06818e50458d4155a2216500ac205486629;
  drivercf7e2f2281130d186b2ee22511b953b81e2c6750469085ec0e7629e154215dd1.
  Preparation0,shell syntax0. No published workflow or original packet edit.
- Initial local test runner1,child1:HOLFileSys.toFS is internal,not exported.
  Static Errors occur before file reads. This is not an accepted ENOENT control.
  Initial source/generator/runner/logs retained. Corrected test uses exported
  HFS_NameMunge.HOLtoFS and real HOLFileSys.openIn/inputAll. No driver change
  was needed for that test correction.
- Corrected test runner0. Old-path child1 reproduces exact U340 duplicated
  .hol/objs/.hol/objs/forge_refundReadBoundaryTheory.sig ENOENT. Fixed child0
  reads all four parent signature/source files and matches direct physical
  reads byte for byte. Real resolver maps both future theorem import paths to
  the correct physical output locations. No generated theorem files exist yet;
  those two resolution checks are not actual fresh imports.
- Tests use pinned local HOL runtime and unchanged four saved states,with
  CPU30s,wall45s,maxheap1536MiB,4MiB/file,zero core dumps. They read file bytes
  only:no QUse theory-source compilation,cfLib,SAT,candidate or proof attempt.
  They are targeted fix regressions,not a new hosted run or correctness proof.
- check_preservation.py0:reverse substitution recovers original driver exactly;
  runtime/states/parent input hashes match before/after;candidate and four
  prepared source identities,50 protected files and mission remain unchanged.
- Impact:specific double-translation defect fixed and locally tested. Full
  parent theory compilation,candidate theorem,conditional controls and hosted
  environment integration remain untested with the new workflow. No assumption,
  theorem,premise,dependency,image guard,limit or permission was changed.
- Evidence:proposals/refund-executable-feasibility/proof-loader-fix-20261109/
  REPORT.md,ASSURANCE.md,NEXT-RUN-APPROVAL.md,records and MANIFEST.json.
  Root tracker/ROADMAP updated;journal prefix preserved;old failures untouched.
- Next check:separately authorize exact corrected one-job scope,then publish
  with current-head/trigger checks. Rerunning old commit would retain the bug.
  No publication,hosted run,protected edit,Stage12,signing,deployment,Git repair
  or new local commit occurred. M1 and native/frame/composition/replay stay open.
'''
for n,s in [('ROADMAP.md',section),('FORGE_MISSION_STATUS.md',tracker)]:
 b=original[n].decode();i=b.index('## ');(root/n).write_text(b[:i]+s+b[i:])
with (root/'unsure.md').open('ab') as f:f.write(entry.encode())
assert (root/'unsure.md').read_bytes()==original['unsure.md']+entry.encode()
for n,s in [('ROADMAP.md',section),('FORGE_MISSION_STATUS.md',tracker)]:assert (root/n).read_text().replace(s,'',1)==original[n].decode()
write(out/'tracking-after.json',{n:{'before':before[n],'after_sha256':sha((root/n).read_bytes())} for n in before})
write(out/'COMMANDS.json',{'commands':[
 {'argv':['python3','-B',str(out/'prepare_fix.py')],'actual_exit':0,'executed_source':'prepare_fix.py.initial'},
 {'argv':['python3','-I','-B',str(out/'test_loader.py')],'actual_exit':1,'executed_source':'test_loader.py.initial'},
 {'argv':['python3','-I','-B',str(out/'test_loader.py')],'actual_exit':0,'child_exits':[1,0]},
 {'argv':['python3','-I','-B',str(out/'check_preservation.py')],'actual_exit':0}],
 'proof_executed':False,'hosted_execution':False,'end_to_end':False})
files={str(p.relative_to(packet)):sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file() and p!=packet/'MANIFEST.json'}
write(packet/'MANIFEST.json',{'files':files,'status':'LOADER_PATH_FIX_LOCALLY_TESTED','proof_executed':False,'hosted_execution':False,'end_to_end':False})
for n,h in files.items():assert sha((packet/n).read_bytes())==h,n
print(json.dumps({'packet_members':len(files),'journal_prefix_preserved':True,'status':'LOADER_PATH_FIX_LOCALLY_TESTED','proof_executed':False,'end_to_end':False}))
