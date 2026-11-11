from pathlib import Path
import hashlib,io,json,lzma,tarfile
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
col=json.loads((OUT/'COLLECTED.json').read_text())
files=[x for x in col['files'] if not x.get('provided_by_base')]
for p in sorted((OUT/'prepared-inputs').glob('*.sml')):
    files.append({'path':str(p.relative_to(ROOT)),'source':str(p),'resolved_source':str(p),
                  'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'mode':0o400,
                  'roles':['prepared-statement-check'],'historical_U328_binding':False})
files.sort(key=lambda x:x['path']);assert len({x['path'] for x in files})==len(files)
out=OUT/'upload';out.mkdir(exist_ok=False)
data=io.BytesIO()
with tarfile.open(fileobj=data,mode='w',format=tarfile.PAX_FORMAT) as tar:
    for rec in files:
        b=Path(rec['source']).read_bytes();assert sha(b)==rec['sha256'] and len(b)==rec['bytes']
        info=tarfile.TarInfo(rec['path']);info.size=len(b);info.mode=rec['mode'];info.mtime=0
        info.uid=info.gid=0;info.uname=info.gname='';tar.addfile(info,io.BytesIO(b))
archive=lzma.compress(data.getvalue(),preset=3)
(out/'inputs.tar.xz').write_bytes(archive)
parts=[]
for i,start in enumerate(range(0,len(archive),4*1024*1024)):
    b=archive[start:start+4*1024*1024];name=f'inputs.part-{i:03d}'
    (out/name).write_bytes(b);parts.append({'name':name,'bytes':len(b),'sha256':sha(b)})
manifest={'installation_root':str(ROOT),'files':files,'parts':parts,'archive_bytes':len(archive),
 'archive_sha256':sha(archive),'tar_bytes':len(data.getvalue()),'base_commit':col['base_commit'],
 'base_manifest_sha256':col['base_manifest_sha256'],'end_to_end':False,
 'scope':'Unchanged proof candidate, pinned library file closure and cached proof ancestry; no independent replay.'}
(out/'INPUTS.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n')
summary={'actual_exit':0,'files':len(files),'raw_file_bytes':sum(x['bytes'] for x in files),
 'archive_bytes':len(archive),'archive_sha256':sha(archive),'parts':len(parts),
 'manifest_bytes':(out/'INPUTS.json').stat().st_size,'manifest_sha256':sha((out/'INPUTS.json').read_bytes()),
 'source_candidate_sha256':next(x['sha256'] for x in files if 'unchanged-candidate' in x['roles']),
 'base_reused':True,'published':False,'end_to_end':False}
(OUT/'PACKAGE.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
