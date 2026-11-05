"""Bind the tracking checkpoint to existing files; no proof verdict is inferred."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path('/Users/mackianni/forge')
OUT=Path(__file__).resolve().parent
WT=Path('/private/tmp/forge-readiness-docs-20261103')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json').read_text())
for name,digest in base['protected'].items():
 assert sha(ROOT/name)==digest, name
assert sha(ROOT/'FORGE_MISSION.md')==base['mission_sha256']
packet=Path('proposals/refund-executable-feasibility/entry-capture-20261104')
man=json.loads((WT/packet/'MANIFEST.json').read_text())
cap={}
for name,digest in man.items():
 if name.startswith('records/attempt-fullmap/'):
  raw=ROOT/'results/refund-entry-observation-2026-11-04'/name.removeprefix('records/')
  assert sha(raw)==digest, str(raw)
  assert sha(WT/packet/name)==digest, name
  cap[name]=digest
assert len(cap)==12
inp=json.loads((OUT/'inputs.json').read_text())
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)==inp['native_sha256']
compiler=ROOT/'results/refund-arm8-compile-2026-11-04/attempt-0001/behavior-0001'
ps=subprocess.run(['ps','-p','47209,47239','-o','pid,ppid,etime,command'],capture_output=True,text=True)
assert ps.returncode==0
terminal=compiler/'command.json'
recovery=json.loads((OUT/'local-recovery.json').read_text())
assert sha(Path(recovery['bundle_path']))==recovery['bundle_sha256']
result={'actual_exit':0,'protected_files_checked':len(base['protected']),'mission_sha256':base['mission_sha256'],'exact_capture_members':cap,'native_sha256':sha(native),'recovery_bundle_sha256':recovery['bundle_sha256'],'independent_backup':'NOT VERIFIED','compiler_actual_exit':json.loads(terminal.read_text())['actual_exit'] if terminal.exists() else None,'compiler_process_readback':ps.stdout,'compiler_log_tail':(compiler/'build.log').read_text()[-2200:],'end_to_end':False}
(OUT/'checkpoint.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['exact_capture_members','compiler_log_tail']}))
