from pathlib import Path
import hashlib,json,shutil,subprocess,re
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
REL=Path('proposals/refund-executable-feasibility/runtime-blocked-audit-20261105')
PACKET=ROOT/REL
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
tracking=json.loads((OUT/'tracking-update.json').read_text())
assert tracking['goal_status']=='blocked'
for rec in tracking['journals']:
    b=Path(rec['path']).read_bytes();n=rec['prefix_bytes'];k=rec['appended_bytes']
    assert hashlib.sha256(b[:n]).hexdigest()==rec['prefix_sha256']
    assert hashlib.sha256(b[n:n+k]).hexdigest()==rec['appended_sha256']
baseline=json.loads((OUT.parent/'attempt-0001/baseline.json').read_text())
for rel,h in baseline['protected'].items():assert sha(ROOT/rel)==h
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
raw={str(p.relative_to(OUT)):sha(p) for p in OUT.rglob('*') if p.is_file() and p.name not in ['preserve.log','preservation.json']}
for rel,h in raw.items():
    dst=PACKET/'records'/rel;dst.parent.mkdir(parents=True,exist_ok=True);assert not dst.exists();shutil.copyfile(OUT/rel,dst);assert sha(dst)==h
for link in re.findall(r'\]\(([^)]+)\)',(PACKET/'REPORT.md').read_text()):
    if not link.startswith(('https://','http://','#')):assert (PACKET/link.split('#')[0]).exists(),link
result={'actual_exit':0,'entry':tracking['entry'],'goal_status':'blocked','raw_files':len(raw),
        'append_only':True,'protected_files_unchanged':len(baseline['protected']),
        'local_links_checked':True,'end_to_end':False}
(PACKET/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n')
files={str(p.relative_to(PACKET)):sha(p) for p in PACKET.rglob('*') if p.is_file() and p.name!='MANIFEST.json'}
(PACKET/'MANIFEST.json').write_text(json.dumps({'files':files,'end_to_end':False},indent=2)+'\n')
assert not (WT/REL).exists();shutil.copytree(PACKET,WT/REL)
for base in [PACKET,WT/REL]:
    for p,h in files.items():assert sha(base/p)==h
result['packet_files']=len(files)
(OUT/'preservation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
