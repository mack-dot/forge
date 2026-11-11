from pathlib import Path
import ctypes, errno, fcntl, hashlib, json, os, platform, resource, subprocess, sys

OUT = Path(__file__).resolve().parent / 'native-errno'
OUT.mkdir(exist_ok=False)
EXE = Path('/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund')
def sha(data): return hashlib.sha256(data).hexdigest()
expected = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
assert sha(EXE.read_bytes()) == expected
libc = ctypes.CDLL('/usr/lib/libSystem.B.dylib',use_errno=True)
libc.read.argtypes = [ctypes.c_int,ctypes.c_void_p,ctypes.c_size_t]
libc.read.restype = ctypes.c_ssize_t
records = []
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(30,30))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
for case in ['nonblocking_empty_writer_open','nonblocking_empty_eof']:
    rd,wr = os.pipe()
    fcntl.fcntl(rd,fcntl.F_SETFL,fcntl.fcntl(rd,fcntl.F_GETFL)|os.O_NONBLOCK)
    buf = (ctypes.c_ubyte * 16)(*([0xA5]*16))
    before = bytes(buf)
    writer_open = case.endswith('writer_open')
    if not writer_open: os.close(wr)
    try:
        ctypes.set_errno(0)
        ret = libc.read(rd,buf,16)
        err = ctypes.get_errno()
        record = {'case':case,'operation':'read(fd,buffer,16)','fd':rd,
                  'fd_flags':fcntl.fcntl(rd,fcntl.F_GETFL),'read_return':ret,
                  'errno':err,'errno_name':errno.errorcode.get(err,'NONE'),
                  'writer_open':writer_open,'buffer_before_hex':before.hex(),
                  'buffer_after_hex':bytes(buf).hex(),'argv':[str(EXE)],
                  'scope':'The probe observes this descriptor before child execution; it does not trace the child read syscall.'}
        child = subprocess.run([str(EXE)],stdin=rd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,preexec_fn=limits)
        (OUT / (case+'.stdout')).write_bytes(child.stdout)
        (OUT / (case+'.stderr')).write_bytes(child.stderr)
        record.update(actual_native_exit=child.returncode,stdout_bytes=len(child.stdout),
                      stderr_bytes=len(child.stderr),stdout_sha256=sha(child.stdout),stderr_sha256=sha(child.stderr))
        records.append(record)
    finally:
        os.close(rd)
        if writer_open: os.close(wr)
result = {'python':sys.executable,'platform':platform.platform(),'machine':platform.machine(),
          'executable':str(EXE),'executable_sha256':expected,'executable_unchanged':sha(EXE.read_bytes())==expected,
          'records':records,'end_to_end':False,'proof_status':'TESTED_ONLY'}
(OUT / 'observations.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
assert records[0]['read_return']==-1 and records[0]['errno']==errno.EAGAIN
assert records[1]['read_return']==0 and records[1]['errno']==0
assert all(r['buffer_before_hex']==r['buffer_after_hex'] for r in records)
assert all(r['actual_native_exit']==0 and r['stdout_bytes']==r['stderr_bytes']==0 for r in records)
assert result['executable_unchanged']
