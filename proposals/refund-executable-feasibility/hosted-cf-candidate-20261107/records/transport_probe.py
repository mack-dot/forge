"""Negative controls for untrusted archive transport. No HOL or theorem execution."""
from pathlib import Path
import hashlib,importlib.util,io,json,sys,tarfile
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('prepared_driver',OUT/'hosted-driver.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
mode=sys.argv[1];data=b'archive transport negative control\n'
name='../escape' if mode=='path-traversal' else 'control'
tarbytes=io.BytesIO()
with tarfile.open(fileobj=tarbytes,mode='w:xz') as tar:
    info=tarfile.TarInfo(name);info.size=len(data);info.mode=0o400
    if mode=='symlink':info.type=tarfile.SYMTYPE;info.linkname='../escape';info.size=0
    tar.addfile(info,io.BytesIO(data) if mode!='symlink' else None)
archive=tarbytes.getvalue()
manifest={'archive_bytes':len(archive),'archive_sha256':d.sha(archive),
          'files':[{'path':name,'bytes':len(data),'sha256':d.sha(data),'mode':0o400}]}
if mode=='wrong-hash':manifest['archive_sha256']='0'*64
root=OUT/'transport-controls'/mode;root.mkdir(parents=True,exist_ok=False)
d.unpack(root,manifest,archive)
raise RuntimeError('Negative control accepted forbidden archive')
