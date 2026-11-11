from pathlib import Path
import hashlib,json,shutil,re
ROOT=Path('/Users/mackianni/forge')
WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
REL=Path('proposals/refund-executable-feasibility/read-runtime-20261105')
PACKET=ROOT/REL
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
checks=json.loads((OUT/'whitespace-checks.json').read_text())
assert [c['actual_exit'] for c in checks]==[2,0]
report=PACKET/'REPORT.md'
report.write_text(report.read_text()+'''
## Preservation checks

The full staged whitespace check exits2 for exact debugger/proof logs, generated
HOL exports and pinned upstream sources. The authored Markdown check exits0.
Those evidence bytes remain unchanged. `records/whitespace-checks.json` and its
full output retain the distinction. All original failures remain available.
''')
commands=PACKET/'COMMANDS.md'
commands.write_text(commands.read_text()+'''
## Preservation checks

`git diff --cached --check` exits2 on exact preserved evidence bytes. The command
restricted to authored Markdown exits0. Exact argv and outputs are in
`records/whitespace-checks.json` and `records/whitespace-full.stdout`.
The tracking and package-copy wrappers each exit0. The new uncertainty entry is
U315; prefix hashes prove append-only preservation in both distinct histories.
''')
files={str(p.relative_to(OUT)):sha(p) for p in OUT.rglob('*') if p.is_file() and p.name!='finalize-package.log'}
for rel,h in files.items():
    dst=PACKET/'records'/rel;dst.parent.mkdir(parents=True,exist_ok=True)
    if dst.exists():assert sha(dst)==h,rel
    else:shutil.copyfile(OUT/rel,dst)
for name in ['REPORT.md','ASSURANCE.md','NEXT-CHECK.md','COMMANDS.md']:
    for link in re.findall(r'\]\(([^)]+)\)',(PACKET/name).read_text()):
        if not link.startswith(('https://','http://','#')):assert (PACKET/link.split('#')[0]).exists(),(name,link)
result={'actual_exit':0,'entry':'U315','raw_files':len(files),'raw_files_sha256':files,
        'initial_packaging':json.loads((OUT/'packaging.json').read_text()),
        'whitespace_checks':checks,'authored_local_links_checked':True,
        'scope':'Final local preservation and identity check; no independent clean replay or physical runtime proof.',
        'end_to_end':False}
(PACKET/'FINAL-PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n')
manifest={str(p.relative_to(PACKET)):sha(p) for p in PACKET.rglob('*') if p.is_file() and p.name!='MANIFEST.json'}
(PACKET/'MANIFEST.json').write_text(json.dumps({'files':manifest,'end_to_end':False},indent=2)+'\n')
shutil.copytree(PACKET,WT/REL,dirs_exist_ok=True)
for base in [PACKET,WT/REL]:
    for rel,h in manifest.items():assert sha(base/rel)==h
print(json.dumps({'actual_exit':0,'entry':'U315','packet_files':len(manifest),'raw_files':len(files),'end_to_end':False},indent=2))
