"""Validate the existing November1 copy and restore into a NEW private folder.

Run on the independent device. Never print member contents or overwrite files.
Copy the unchanged check_archives.py beside this script before use.
"""
import argparse,hashlib,json,os,socket,tarfile
from pathlib import Path,PurePosixPath
from check_archives import check

p=argparse.ArgumentParser();p.add_argument('--archives',type=Path,required=True);p.add_argument('--restore',type=Path,required=True);a=p.parse_args()
archives=a.archives.resolve();destination=a.restore.resolve()
integrity=check(archives)
destination.mkdir(parents=False,exist_ok=False,mode=0o700)
rows=[]
for kind in ['raw','sanitized']:
 stem='forge-records-'+kind+'-2026-11-01'
 expected=json.loads((archives/(stem+'.manifest.json')).read_text())
 output=destination/kind;output.mkdir(mode=0o700)
 with tarfile.open(archives/(stem+'.tar.xz'),'r:xz') as archive:
  for member in archive.getmembers():
   name=PurePosixPath(member.name)
   assert member.isfile() and not name.is_absolute() and '..' not in name.parts
   path=output.joinpath(*name.parts)
   path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
   data=archive.extractfile(member).read()
   with path.open('xb') as stream:stream.write(data)
   path.chmod(0o600)
 for name,entry in expected.items():
  data=(output/name).read_bytes()
  assert len(data)==entry['bytes'] and hashlib.sha256(data).hexdigest()==entry['sha256']
 rows.append({'kind':kind,'restored_members_checked':len(expected),'mismatches':0})
result={'archive_integrity':integrity,'restore':rows,'hostname':socket.gethostname(),
        'archive_directory':str(archives),'restore_directory':str(destination),
        'archive_device_id':archives.stat().st_dev,'restore_device_id':destination.stat().st_dev,
        'storage_independence_requires_owner_confirmation':True,'contents_printed':False,'end_to_end':False}
(destination/'restore-result.json').write_text(json.dumps(result,indent=2)+'\n')
(destination/'restore-result.json').chmod(0o600)
print(json.dumps(result))
