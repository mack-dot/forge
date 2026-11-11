from pathlib import Path
import hashlib,json,shutil

ROOT=Path('/Users/mackianni/forge')
WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
REL=Path('proposals/refund-executable-feasibility/stdin-domain-20261107')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
packet=ROOT/REL
shutil.copytree(OUT,packet/'records')
files={str(p.relative_to(packet)):sha(p) for p in sorted(packet.rglob('*')) if p.is_file()}
(packet/'MANIFEST.json').write_text(json.dumps({'files':files,'end_to_end':False},indent=2)+'\n')
shutil.copytree(packet,WT/REL)
for base in [ROOT,WT]:
    for rel,h in files.items():assert sha(base/REL/rel)==h,(base,rel)
tracking=json.loads((OUT/'tracking.json').read_text())
for item in tracking:
    base=Path(item['base']); journal=(base/'unsure.md').read_bytes()
    assert hashlib.sha256(journal[:item['journal_prefix_bytes']]).hexdigest()==item['journal_prefix_sha256']
    assert hashlib.sha256(journal).hexdigest()==item['journal_after_sha256']
    for name in ['ROADMAP.md','FORGE_MISSION_STATUS.md']:
        assert sha(base/name)==item[name]['after_sha256']
        assert '(proposals/refund-executable-feasibility/stdin-domain-20261107/' in (base/name).read_text()
print(json.dumps({'actual_exit':0,'packet_members':len(files),'two_copies_match':True,
 'separate_journal_prefixes_preserved':True,'end_to_end':False},indent=2))
