from pathlib import Path
import hashlib,json,shutil,subprocess,re
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
REL=Path('proposals/refund-executable-feasibility/native-error-instructions-20261105')
PACKET=ROOT/REL
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
track=json.loads((OUT/'tracking-update.json').read_text())
for rec in track['journals']:
    b=Path(rec['path']).read_bytes();n=rec['prefix_bytes'];k=rec['appended_bytes']
    assert hashlib.sha256(b[:n]).hexdigest()==rec['prefix_sha256']
    assert hashlib.sha256(b[n:n+k]).hexdigest()==rec['appended_sha256']
baseline=json.loads((OUT.parent/'attempt-0001/baseline.json').read_text())
for rel,h in baseline['protected'].items():assert sha(ROOT/rel)==h
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
commands=[]
for args in [['rev-parse','HEAD'],['diff','--exit-code','HEAD','--','spec','spec.lock','policy','gate','FORGE_MISSION.md']]:
    argv=['git','-C',str(WT)]+args;r=subprocess.run(argv,capture_output=True,text=True)
    commands.append({'argv':argv,'actual_exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
    assert r.returncode==0
    if args[0]=='rev-parse':assert r.stdout.strip()=='2e4315138a6984268d4ad1297748337af3adcec3'
raw={str(p.relative_to(OUT)):sha(p) for p in OUT.rglob('*') if p.is_file() and p.name not in ['package.log','packaging.json']}
for rel,h in raw.items():
    dst=PACKET/'records'/rel;dst.parent.mkdir(parents=True,exist_ok=True);assert not dst.exists();shutil.copyfile(OUT/rel,dst);assert sha(dst)==h
for name in ['REPORT.md','ASSURANCE.md','COMMANDS.md']:
    for link in re.findall(r'\]\(([^)]+)\)',(PACKET/name).read_text()):
        if not link.startswith(('https://','http://','#')):assert (PACKET/link.split('#')[0]).exists(),(name,link)
result={'actual_exit':0,'entry':track['entry'],'raw_files':len(raw),'append_only':True,'protected_files_unchanged':len(baseline['protected']),'git_commands':commands,'local_links_checked':True,'end_to_end':False}
(PACKET/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n')
files={str(p.relative_to(PACKET)):sha(p) for p in PACKET.rglob('*') if p.is_file() and p.name!='MANIFEST.json'}
(PACKET/'MANIFEST.json').write_text(json.dumps({'files':files,'end_to_end':False},indent=2)+'\n')
assert not (WT/REL).exists();shutil.copytree(PACKET,WT/REL)
for base in [PACKET,WT/REL]:
    for p,h in files.items():assert sha(base/p)==h
result['packet_files']=len(files)
(OUT/'packaging.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
