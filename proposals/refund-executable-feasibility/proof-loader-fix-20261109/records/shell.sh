/usr/bin/python3 -I -B - <<'PY'
"""Exact byte transport and dispatch to pinned HOL. This is not a proof checker."""
import base64,ctypes,errno,hashlib,io,json,os,platform,resource,shutil,subprocess,sys,tarfile,tempfile,traceback,urllib.request,zlib
from pathlib import Path

CANONICAL='/Users/mackianni/forge'
TC_REL='.toolchain/experiments/refund-cakeml-20261104'
PREP_REL='results/hosted-cf-preparation-20261107/attempt-0001/prepared-inputs'
CANDIDATE='results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
BASE_COMMIT='ac05eaf972b8c98784466ae063fca505aaaf25f4'
BASE_MANIFEST_SHA='6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7'
HEAPS=['HOL/bin/hol.state0','HOL/src/num/termination/numheap','HOL/bin/hol.state','cakeml/misc/cakeml-heap']
PARENTS=[('results/refund-native-audit-2026-11-04/attempt-0010/model-0007','forge_refundReadBoundary'),
         ('results/refund-stdin-domain-20261107/attempt-0001/model-0004','forge_refundStdinDomain')]
sha=lambda b:hashlib.sha256(b).hexdigest()
def emit(name,**fields):print(json.dumps(dict(operation=name,end_to_end=False,**fields),sort_keys=True),flush=True)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,request,response,code,message,headers,new_url):
        raise ValueError('redirect refused before follow-up request')
def download(prefix,name,size,digest):
    assert '/' not in name and name not in ('.','..')
    with urllib.request.build_opener(NoRedirect()).open(prefix+name,timeout=30) as response:data=response.read(size+1)
    assert len(data)==size and sha(data)==digest,name
    emit('download',file=name,bytes=size,sha256=digest)
    return data
def unpack(root,manifest,archive):
    assert len(archive)==manifest['archive_bytes'] and sha(archive)==manifest['archive_sha256']
    expected={r['path']:r for r in manifest['files']}
    assert len(expected)==len(manifest['files'])
    with tarfile.open(fileobj=io.BytesIO(archive),mode='r:xz') as tar:
        members=tar.getmembers()
        assert len(members)==len(expected) and {m.name for m in members}==set(expected)
        for m in members:
            rel=Path(m.name)
            assert m.isfile() and not rel.is_absolute() and '..' not in rel.parts
            r=expected[m.name];assert m.size==r['bytes'] and r['mode'] in (0o400,0o500,0o555)
            data=tar.extractfile(m).read();assert sha(data)==r['sha256'],m.name
            p=root/rel;p.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
            with p.open('xb') as f:f.write(data)
            p.chmod(r['mode'])
    return expected
def bootstrap(root,mode):
    tc=root/TC_REL;q=lambda p:json.dumps(str(p))
    s='val _ = PolyML.SaveState.loadHierarchy ['+', '.join(q(tc/h) for h in HEAPS)+'];\n'
    s+='val _ = List.app (fn p => print ("LOADED_STATE " ^ p ^ "\\n")) (PolyML.SaveState.showHierarchy ());\n'
    s+='val forgeRoot = '+q(root)+';\nval oldRoot = '+json.dumps(CANONICAL)+';\n'
    s+='fun relocate p = if String.isPrefix (oldRoot ^ "/") p then forgeRoot ^ String.extract(p,size oldRoot,NONE) else raise Fail ("Unmapped load path: " ^ p);\n'
    s+='val _ = holpathdb.extend_db {vname="HOLDIR",path='+q(tc/'HOL')+'};\n'
    s+='val _ = holpathdb.extend_db {vname="CAKEMLDIR",path='+q(tc/'cakeml')+'};\n'
    s+='val _ = Meta.loadPath := map relocate (!Meta.loadPath);\n'
    s+='fun checked label f = (print ("PHASE " ^ label ^ "\\n"); f ()) handle ex => (print ("EXCEPTION " ^ General.exnMessage ex ^ "\\n"); print ("EXCEPTION_LOCATION " ^ PolyML.makestring (PolyML.exceptionLocation ex) ^ "\\n"); (case ex of OS.SysErr (_,SOME e) => print ("ERRNO_NAME " ^ OS.errorName e ^ "\\n") | _ => ()); PolyML.Exception.reraise ex);\n'
    s+='val _ = print ("FROZEN_SOLVER_PATH " ^ SatSolvers.getSolverExe SatSolvers.minisatp ^ "\\n");\n'
    s+='val frozenAvailable = OS.FileSys.access (SatSolvers.getSolverExe SatSolvers.minisatp,[OS.FileSys.A_EXEC]);\n'
    s+='val _ = print ("FROZEN_SOLVER_EXECUTABLE " ^ Bool.toString frozenAvailable ^ "\\n");\n'
    if mode!='inspect':s+='val _ = if frozenAvailable then raise Fail "Unexpected original-path solver outside validated private payload" else ();\n'
    s+='val _ = checked "basis-theory-load" (fn () => load "basis_ffiTheory");\n'
    if mode=='inspect':
        s+='val _ = print ("RESOLVED_CF_MODULE " ^ PolyML.makestring (Meta.findMod "cfLib") ^ "\\n");\n'
        s+='val _ = QUse.use '+q(root/PREP_REL/'parse-only.sml')+';\n'
        s+='val _ = print "RELOCATION_INSPECTION_COMPLETE\\n";\nval _ = OS.Process.exit OS.Process.success;\n'
        return s
    for path,name in PARENTS:
        for ext in ['.sig','.sml']:s+='val _ = QUse.use '+q(root/path/(name+'Theory'+ext))+';\n'
    s+='val _ = checked "cf-library-load" (fn () => load "cfLib");\nval _ = print "CF_LIBRARY_LOADED\\n";\n'
    if mode in ('proof','repeat'):target=root/CANDIDATE
    else:
        for ext in ['.sig','.sml']:s+='val _ = QUse.use '+q(root/'outputs/proof'/('forge_refundGenericReadErrorTheory'+ext))+';\n'
        target=root/PREP_REL/({'import':'import.sml','wrong-exception':'wrong-exception.sml','omitted-event':'omitted-event.sml'}[mode])
    s+='val _ = checked "unchanged-source" (fn () => QUse.use '+q(target)+');\n'
    s+='val _ = OS.Process.exit OS.Process.failure;\n'
    return s
def emit_file(case,name,path):
    data=path.read_bytes();compressed=zlib.compress(data,9);encoded=base64.b64encode(compressed).decode()
    chunks=[encoded[i:i+48000] for i in range(0,len(encoded),48000)]
    emit('file',case=case,file=name,bytes=len(data),sha256=sha(data),encoding='base64+zlib',chunks=len(chunks))
    for i,chunk in enumerate(chunks):emit('file_chunk',case=case,file=name,index=i,data=chunk)
def run_case(root,mode):
    tc=root/TC_REL;out=root/'outputs'/mode;out.mkdir(parents=True,exist_ok=False,mode=0o700)
    boot=out/'bootstrap.sml';boot.write_text(bootstrap(root,mode))
    argv=[str(tc/'HOL/bin/hol'),'--maxheap','1536','run','--poly',str(boot)]
    env={k:v for k,v in os.environ.items() if k in ('HOME','TMPDIR','PATH','LANG','LC_ALL')}
    env.update(HOLDIR=str(tc/'HOL'),CAKEMLDIR=str(tc/'cakeml'),FORGE_READ_OUT=str(out),
               DYLD_LIBRARY_PATH=str(tc/'poly-install/lib')+':'+str(tc/'transport/lib'),DYLD_PRINT_LIBRARIES='1')
    def limits():
        resource.setrlimit(resource.RLIMIT_CPU,(120,120));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        resource.setrlimit(resource.RLIMIT_FSIZE,(4*1024*1024,4*1024*1024))
    emit('invocation',case=mode,argv=argv,cwd=str(tc/'cakeml/basis'),environment=env,cpu_seconds=120,wall_seconds=150,maxheap_MiB=1536,stream_file_limit_bytes=4*1024*1024)
    emit_file(mode,'bootstrap.sml',boot)
    with (out/'stdout.log').open('xb') as stdout,(out/'stderr.log').open('xb') as stderr:
        p=subprocess.Popen(argv,cwd=tc/'cakeml/basis',env=env,stdout=stdout,stderr=stderr,preexec_fn=limits)
        timed_out=False
        try:p.wait(timeout=150)
        except subprocess.TimeoutExpired:
            timed_out=True;p.kill();p.wait()
    for name in ['stdout.log','stderr.log']:emit_file(mode,name,out/name)
    objects={}
    for file in sorted((out/'.hol').rglob('*')):
        if file.is_file():
            name=str(file.relative_to(out));objects[name]=sha(file.read_bytes());emit_file(mode,name,file)
    emit('child_result',case=mode,actual_exit=p.returncode,wall_timeout=timed_out,objects=objects)
    return p.returncode,objects,(out/'stdout.log').read_text(),(out/'stderr.log').read_text()
def main():
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    emit('identity',system=platform.system(),architecture=platform.machine(),release=platform.release(),uid=os.geteuid(),
         image_version=os.environ.get('ImageVersion'),image_os=os.environ.get('ImageOS'),run_id=os.environ.get('GITHUB_RUN_ID'),
         workflow_sha=os.environ.get('GITHUB_WORKFLOW_SHA'),source_sha=os.environ.get('GITHUB_SHA'),
         python_version=sys.version,python_sha256=sha(Path(sys.executable).read_bytes()),
         isolation='GitHub fresh VM and documented OS isolation are trusted; no independent provider attestation')
    assert platform.system()=='Darwin' and platform.machine()=='arm64'
    assert os.environ.get('RUNNER_ARCH')=='ARM64' and os.geteuid()!=0
    assert os.environ.get('ImageVersion')=='20261104.0514.1','unapproved image version'
    def command(argv):
        p=subprocess.run(argv,capture_output=True,text=True)
        emit('command',argv=argv,actual_exit=p.returncode,stdout=p.stdout,stderr=p.stderr);assert p.returncode==0
        return p.stdout.strip()
    command(['/usr/bin/sw_vers']);memory=int(command(['/usr/sbin/sysctl','-n','hw.memsize']))
    free_disk=shutil.disk_usage('/var/tmp').free
    emit('resources',memory_bytes=memory,temporary_disk_free_bytes=free_disk,full_proof_resource_adequacy='NOT_ESTABLISHED')
    assert memory>=4*1024**3 and free_disk>=2*1024**3
    libc=ctypes.CDLL(None,use_errno=True);libc.mkstemp.argtypes=[ctypes.c_char_p];libc.mkstemp.restype=ctypes.c_int
    template=ctypes.create_string_buffer(b'/var/tmp/forge-m1-cf-XXXXXX');ctypes.set_errno(0)
    mask=os.umask(0o077)
    try:fd=libc.mkstemp(template);err=ctypes.get_errno()
    finally:os.umask(mask)
    path=Path(os.fsdecode(template.value));emit('mkstemp',path=str(path),return_value=fd,errno=err,error_name=errno.errorcode.get(err))
    if fd<0:raise OSError(err,os.strerror(err),str(path))
    try:
        b=b'Forge isolated CF execution preflight\n';assert os.write(fd,b)==len(b)
        os.lseek(fd,0,os.SEEK_SET);assert os.read(fd,len(b)+1)==b;os.close(fd);fd=-1
        emit('read_write',bytes=len(b),equal=True);path.chmod(0)
        try:forbidden=os.open(path,os.O_RDONLY)
        except OSError as exc:
            emit('negative_permission',errno=exc.errno,error_name=errno.errorcode.get(exc.errno));assert exc.errno in (errno.EACCES,errno.EPERM)
        else:os.close(forbidden);raise RuntimeError('negative permission control failed')
    finally:
        if fd>=0:os.close(fd)
        path.chmod(0o600);path.unlink()
    command(['/usr/bin/true']);block=bytearray(64*1024*1024)
    for offset in range(0,len(block),4096):block[offset]=1
    emit('memory_probe',touched_bytes=len(block));del block
    tmp=Path(os.environ['RUNNER_TEMP']).resolve(strict=True);root=Path(tempfile.mkdtemp(prefix='forge-m1-cf-',dir=tmp))
    assert root.parent==tmp and root.stat().st_uid==os.geteuid() and root.stat().st_mode&0o777==0o700
    emit('private_root',path=str(root),mode='0700',uid=os.geteuid())
    inventories=[]
    for commit,folder,size,digest in [(BASE_COMMIT,'m1-hosted-sat-inputs',8435,BASE_MANIFEST_SHA),
        (os.environ['ADDON_COMMIT_SHA'],'m1-hosted-cf-inputs',int(os.environ['ADDON_MANIFEST_BYTES']),os.environ['ADDON_MANIFEST_SHA256'])]:
        assert len(commit)==40 and all(c in '0123456789abcdef' for c in commit)
        prefix='https://raw.githubusercontent.com/mack-dot/forge/'+commit+'/proposals/'+folder+'/'
        raw=download(prefix,'INPUTS.json',size,digest);m=json.loads(raw)
        archive=b''.join(download(prefix,x['name'],x['bytes'],x['sha256']) for x in m['parts'])
        inventories.append(unpack(root,m,archive))
    expected={}
    for inv in inventories:
        assert not set(inv)&set(expected);expected.update(inv)
    def verify(label):
        for name,r in expected.items():assert (root/name).stat().st_size==r['bytes'] and sha((root/name).read_bytes())==r['sha256'],name
        emit(label,files=len(expected),all_match=True)
    verify('inputs_before')
    assert sha((root/CANDIDATE).read_bytes())=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
    tc=root/TC_REL
    command(['/usr/bin/otool','-L',str(tc/'HOL/bin/hol'),str(tc/'poly-install/lib/libpolyml.16.dylib'),str(tc/'transport/lib/libgmp.10.dylib')])
    failed=None;proof_objects=None
    for mode in ['proof','repeat','import','wrong-exception','omitted-event']:
        code,objects,stdout,stderr=run_case(root,mode);verify('inputs_after_'+mode)
        loaded_lines=[line for line in stderr.splitlines() if line.startswith('dyld[')]
        for suffix in ['poly-install/lib/libpolyml.16.dylib','transport/lib/libgmp.10.dylib']:
            target=str(tc/suffix)
            assert any(line.endswith(' '+target) for line in loaded_lines),'Missing exact private runtime load: '+suffix
            assert all(line.endswith(' '+target) for line in loaded_lines if suffix.rsplit('/',1)[1] in line),'Unexpected runtime load: '+suffix
        emit('runtime_path_gate',case=mode,private_libraries_match=True,os_frameworks='Trusted OS environment; not a machine proof')
        if mode in ['proof','repeat']:
            ok=code==0 and 'READ_EVENT_GAP_COMPLETE' in stdout and len(objects)==4
            if mode=='proof':proof_objects=objects
            else:ok=ok and objects==proof_objects
        elif mode=='import':ok=code==0 and 'GENERIC_IMPORT_COMPLETE' in stdout and not objects
        else:ok=code==1 and 'Exact generic read statement mismatch' in stderr and 'GENERIC_IMPORT_COMPLETE' not in stdout and not objects
        emit('case_gate',case=mode,expected_observation_met=ok,scope='Byte/exit/marker binding only; independent proof assurance remains required')
        if not ok:failed=mode;break
    emit('run_complete',failed_case=failed,full_chain_replay='NOT_RUN',native_refund_execution='NOT_RUN')
    raise SystemExit(1 if failed else 0)
if __name__=='__main__':
    try:main()
    except Exception as exc:
        emit('driver_failure',exception_type=type(exc).__name__,message=str(exc),errno=getattr(exc,'errno',None),actual_exit=78)
        traceback.print_exc();raise SystemExit(78)
PY
