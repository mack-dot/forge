"""Read-only libc access queries. Never creates a file or changes permissions."""
from pathlib import Path
import ctypes
import errno
import hashlib
import json
import os
import stat

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
libc = ctypes.CDLL(None, use_errno=True)
access = libc.access
access.argtypes = [ctypes.c_char_p, ctypes.c_int]
access.restype = ctypes.c_int
missing = OUT / 'nonexistent-read-only-control'
assert not missing.exists()
paths = [Path('/var/tmp'), Path('/private/var/tmp'),
         Path('/private/tmp'), ROOT, missing]
records = []
for path in paths:
    metadata = None
    try:
        info = path.stat()
        metadata = {'mode': oct(stat.S_IMODE(info.st_mode)),
                    'owner_uid': info.st_uid, 'owner_gid': info.st_gid,
                    'directory': stat.S_ISDIR(info.st_mode)}
    except OSError as ex:
        metadata = {'stat_errno': ex.errno, 'stat_error_name': errno.errorcode.get(ex.errno)}
    queries = []
    for name, mode in [('F_OK',os.F_OK),('R_OK',os.R_OK),('W_OK',os.W_OK),('X_OK',os.X_OK)]:
        ctypes.set_errno(0)
        result = access(os.fsencode(path), mode)
        error = ctypes.get_errno()
        queries.append({'function':'libc.access','mode':name,'return':result,
                        'errno':error,'error_name':errno.errorcode.get(error) if error else None})
    records.append({'path':str(path),'resolved_path':str(path.resolve()),
                    'metadata':metadata,'queries':queries})
data = {'scope':'Read-only libc access permission queries in the current managed Python process; no file creation, SAT, proof, or permission change.',
        'effective_uid':os.geteuid(),'real_uid':os.getuid(),
        'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'observations':records,
        'denial_issuer':'NOT_ESTABLISHED: errno alone does not distinguish sandbox, ACL, TCC or other policy.',
        'historical_SAT_failing_operation':'NOT_ESTABLISHED',
        'end_to_end':False}
with (OUT / 'access-errno.json').open('x') as handle:
    json.dump(data,handle,indent=2);handle.write('\n')
for record in records:
    print(json.dumps({'path':record['path'],'metadata':record['metadata'],
                      'queries':record['queries']}))
