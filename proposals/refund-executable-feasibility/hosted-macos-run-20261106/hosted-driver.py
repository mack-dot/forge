import traceback

def main():
    import ctypes
    import errno
    import hashlib
    import json
    import os
    import platform
    import resource
    import shutil
    import subprocess
    import sys
    
    def emit(name, **fields):
        print(json.dumps(dict(operation=name, end_to_end=False, **fields), sort_keys=True), flush=True)
    
    def command(argv):
        process = subprocess.run(argv, capture_output=True, text=True)
        emit('command', argv=argv, actual_exit=process.returncode,
             stdout=process.stdout, stderr=process.stderr)
        if process.returncode != 0:
            raise RuntimeError('command failed: ' + argv[0])
        return process.stdout.strip()
    
    resource.setrlimit(resource.RLIMIT_CPU, (120, 120))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    emit('identity', architecture=platform.machine(), system=platform.system(),
         release=platform.release(), effective_uid=os.geteuid(),
         runner_os=os.environ.get('RUNNER_OS'), runner_arch=os.environ.get('RUNNER_ARCH'),
         image_os=os.environ.get('ImageOS'), image_version=os.environ.get('ImageVersion'),
         workflow_sha=os.environ.get('GITHUB_WORKFLOW_SHA'), source_sha=os.environ.get('GITHUB_SHA'),
         run_id=os.environ.get('GITHUB_RUN_ID'), python_version=sys.version,
         python_sha256=hashlib.sha256(open(sys.executable, 'rb').read()).hexdigest(),
         provider_isolation='GitHub fresh-VM claim; not independently proved by this probe')
    assert platform.system() == 'Darwin' and platform.machine() == 'arm64'
    assert os.environ.get('RUNNER_ARCH') == 'ARM64'
    assert os.environ.get('ImageVersion') == os.environ['APPROVED_IMAGE_VERSION'], 'image identity differs; review required'
    assert os.geteuid() != 0, 'negative permission control requires a non-root process'
    command(['/usr/bin/sw_vers'])
    memory = int(command(['/usr/sbin/sysctl', '-n', 'hw.memsize']))
    disk = shutil.disk_usage('/var/tmp')
    emit('resources', memory_bytes=memory, temporary_disk_free_bytes=disk.free,
         cpu_limit_seconds=120, core_limit_bytes=0,
         full_HOL_resource_adequacy='NOT_ESTABLISHED')
    
    libc = ctypes.CDLL(None, use_errno=True)
    mkstemp = libc.mkstemp
    mkstemp.argtypes = [ctypes.c_char_p]
    mkstemp.restype = ctypes.c_int
    template = ctypes.create_string_buffer(b'/var/tmp/forge-m1-preflight-XXXXXX')
    old_mask = os.umask(0o077)
    ctypes.set_errno(0)
    try:
        fd = mkstemp(template)
        error = ctypes.get_errno()
    finally:
        os.umask(old_mask)
    path = os.fsdecode(template.value)
    emit('mkstemp', path=path, return_value=fd, errno=error,
         error_name=errno.errorcode.get(error) if error else None)
    if fd == -1:
        raise OSError(error, os.strerror(error), path)
    try:
        payload = b'Forge environment preflight only\n'
        written = os.write(fd, payload)
        os.lseek(fd, 0, os.SEEK_SET)
        observed = os.read(fd, len(payload) + 1)
        emit('read_write', written=written, read_bytes=len(observed), equal=observed == payload)
        assert written == len(payload) and observed == payload
        os.close(fd)
        fd = -1
        os.chmod(path, 0)
        try:
            forbidden = os.open(path, os.O_RDONLY)
        except OSError as exc:
            emit('negative_permission', path=path, errno=exc.errno,
                 error_name=errno.errorcode.get(exc.errno))
            assert exc.errno in (errno.EACCES, errno.EPERM)
        else:
            os.close(forbidden)
            raise RuntimeError('mode000 file could be opened by non-root process')
    finally:
        if fd != -1:
            os.close(fd)
        os.chmod(path, 0o600)
        os.unlink(path)
    
    command(['/usr/bin/true'])
    allocation = bytearray(64 * 1024 * 1024)
    for offset in range(0, len(allocation), 4096):
        allocation[offset] = 1
    emit('memory_probe', touched_bytes=len(allocation))
    emit('environment_controls_complete', scope='Finite observations only')
    
    # Runs only after the unchanged U322 environment controls have passed.
    # This transport binds bytes and dispatches the existing checker. It proves no theorem.
    import base64
    import io
    from pathlib import Path
    import tarfile
    import urllib.request
    
    sha = lambda data: hashlib.sha256(data).hexdigest()
    libc.access.argtypes = [ctypes.c_char_p, ctypes.c_int]
    libc.access.restype = ctypes.c_int
    ctypes.set_errno(0)
    access_result = libc.access(b'/var/tmp', os.W_OK)
    access_errno = ctypes.get_errno()
    emit('access', path='/var/tmp', mode='W_OK', return_value=access_result,
         errno=access_errno, error_name=errno.errorcode.get(access_errno))
    assert access_result == 0
    
    # Preserve compiled paths. Never elevate, change an existing path, or relocate a heap.
    installation_parent = Path('/Users/mackianni')
    try:
        installation_parent.mkdir(mode=0o700)
    except OSError as exc:
        emit('installation_parent_mkdir', path=str(installation_parent), errno=exc.errno,
             error_name=errno.errorcode.get(exc.errno), SAT='NOT_RUN')
        raise
    emit('installation_parent_mkdir', path=str(installation_parent), actual_result=0)
    root = installation_parent / 'forge'
    root.mkdir(mode=0o700)
    prefix = 'https://raw.githubusercontent.com/mack-dot/forge/' + os.environ['INPUT_COMMIT_SHA'] + '/proposals/m1-hosted-sat-inputs/'
    
    def download(name, expected_size, expected_sha):
        # Downloads are bounded and hash checked before any input executes.
        with urllib.request.urlopen(prefix + name, timeout=30) as response:
            data = response.read(expected_size + 1)
        assert len(data) == expected_size, name + ': size mismatch'
        assert sha(data) == expected_sha, name + ': hash mismatch'
        emit('download_identity', file=name, bytes=len(data), sha256=sha(data))
        return data
    
    manifest_data = download('INPUTS.json', int(os.environ['INPUT_MANIFEST_BYTES']), os.environ['INPUT_MANIFEST_SHA256'])
    manifest = json.loads(manifest_data)
    assert manifest['installation_root'] == str(root)
    archive = b''.join(download(p['name'], p['bytes'], p['sha256']) for p in manifest['parts'])
    assert len(archive) == manifest['archive_bytes'] and sha(archive) == manifest['archive_sha256']
    expected = {e['path']: e for e in manifest['files']}
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as tar:
        members = tar.getmembers()
        assert len(members) == len(expected) and {m.name for m in members} == set(expected)
        for member in members:
            rel = Path(member.name)
            assert member.isfile() and not rel.is_absolute() and '..' not in rel.parts
            entry = expected[member.name]
            assert member.size == entry['bytes']
            data = tar.extractfile(member).read()
            assert sha(data) == entry['sha256']
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with path.open('xb') as output:
                output.write(data)
            path.chmod(entry['mode'])
    
    def verify_inputs(label):
        for name, entry in expected.items():
            path = root / name
            actual = sha(path.read_bytes())
            emit(label, file=name, bytes=path.stat().st_size, sha256=actual)
            assert actual == entry['sha256']
    
    verify_inputs('input_before')
    tc = root / '.toolchain/experiments/refund-cakeml-20261104'
    diagnostic = root / 'results/refund-native-audit-2026-11-04/attempt-0011/dependency-diagnostic'
    hol = tc / 'HOL/bin/hol'
    solver = tc / 'HOL/src/HolSat/sat_solvers/minisat/minisat'
    assert os.access(hol, os.X_OK) and os.access(solver, os.X_OK)
    command(['/usr/bin/otool', '-L', str(hol), str(tc/'poly-install/lib/libpolyml.16.dylib'), str(tc/'transport/lib/libgmp.10.dylib'), str(solver)])
    env = {key: value for key, value in os.environ.items() if key in ('HOME', 'TMPDIR', 'PATH', 'LANG', 'LC_ALL')}
    env['DYLD_LIBRARY_PATH'] = str(tc/'poly-install/lib') + ':' + str(tc/'transport/lib')
    env['DYLD_PRINT_LIBRARIES'] = '1'
    argv = [str(hol), '--maxheap', '1024', 'run', '--holstate=' + str(tc/'HOL/examples/l3-machine-code/arm8/step/arm8-heap'),
            str(diagnostic/'preload.sml'), str(diagnostic/'proof.sml')]
    emit('sat_invocation', argv=argv, cwd=str(tc/'HOL/examples/l3-machine-code/arm8/step'),
         environment=env, cpu_limit_seconds=120, maxheap_MiB=1024, core_limit_bytes=0,
         loaded_libraries='DYLD_PRINT_LIBRARIES stderr; inspect exact paths',
         physical_correspondence='NOT_ESTABLISHED')
    
    def child_limits():
        resource.setrlimit(resource.RLIMIT_CPU, (120, 120))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_FSIZE, (32*1024*1024, 32*1024*1024))
    
    # Preserve complete streams independently of the theorem's printed markers.
    stdout_path = root / 'sat.stdout'
    stderr_path = root / 'sat.stderr'
    with stdout_path.open('xb') as stdout, stderr_path.open('xb') as stderr:
        process = subprocess.run(argv, cwd=tc/'HOL/examples/l3-machine-code/arm8/step',
                                 env=env, stdout=stdout, stderr=stderr, preexec_fn=child_limits)
    for name, path in [('stdout', stdout_path), ('stderr', stderr_path)]:
        data = path.read_bytes()
        emit('sat_stream', stream=name, bytes=len(data), sha256=sha(data), base64=base64.b64encode(data).decode('ascii'))
    emit('sat_result', actual_exit=process.returncode, scope='Unchanged one-term SAT diagnostic only',
         logical_Success='No inference from process exit', physical_ffiread_proof='NOT_ESTABLISHED')
    verify_inputs('input_after')
    raise SystemExit(process.returncode if process.returncode >= 0 else 128-process.returncode)

try:
    main()
except Exception as exc:
    import json,sys
    print(json.dumps({"operation":"preflight_failure","exception_type":type(exc).__name__,"message":str(exc),"errno":getattr(exc,"errno",None),"actual_exit":78,"end_to_end":False},sort_keys=True),flush=True)
    traceback.print_exc()
    sys.exit(78)
