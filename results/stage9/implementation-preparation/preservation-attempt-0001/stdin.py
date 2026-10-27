from pathlib import Path
import json,hashlib
before=json.loads(Path('results/stage9/contract-adoption/before-identities.json').read_text())
changed=[p for p,h in before.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
assert set(changed)=={'ROADMAP.md','unsure.md'},changed
old_unsure=Path('results/stage9/preparation/before-identities.json')
# The append-only boundary is the already published U074 ending.
text=Path('unsure.md').read_text();prefix=text.split('\n## U075 —',1)[0]+'\n'
assert hashlib.sha256(prefix.encode()).hexdigest()==before['unsure.md']
manifest=json.loads(Path('proposals/provenance/approval-manifest.json').read_text())
for item in manifest['changes']:
 assert hashlib.sha256(Path(item['target']).read_bytes()).hexdigest()==item['sha256']
newmanifest=json.loads(Path('proposals/provenance-implementation/approval-manifest.json').read_text())
for item in newmanifest['changes']:
 assert not Path(item['target']).exists()
 assert hashlib.sha256(Path(item['candidate']).read_bytes()).hexdigest()==item['sha256']
record={'base_commit':'097431cf458e5c62332575b09e953224471fa64d','previously_existing_files_checked':len(before),'existing_files_changed':changed,'unsure_append_only':True,'old_protected_files_unchanged':30,'approved_new_protected_files':3,'prior_stage7_stage8_records_unchanged':sum(p.startswith(('results/stage7/','results/stage8/')) for p in before),'proposed_implementation_targets_unapplied':len(newmanifest['changes']),'stage9_exits':'not_run','end_to_end':False}
Path('results/stage9/implementation-preparation/preservation.json').write_text(json.dumps(record,sort_keys=True,indent=2)+'\n')
print(json.dumps(record))
