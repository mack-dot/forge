"""Run the unchanged executable under explicit child-only descriptor controls."""
from pathlib import Path
import fcntl, hashlib, json, os, resource, subprocess, sys

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent / sys.argv[1]
OUT.mkdir(exist_ok=False)
EXE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
FIX = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0003/wire'
MANIFEST = json.loads((FIX.parent / 'wire-manifest.json').read_text())
SHA = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
sha = lambda data: hashlib.sha256(data).hexdigest()
assert sha(EXE.read_bytes()) == SHA
valid = (FIX / 'eligible_duplicate.stdin').read_bytes()
expected = (FIX / 'eligible_duplicate.stdout').read_bytes()
assert sha(valid) == MANIFEST['eligible_duplicate.stdin']
assert sha(expected) == MANIFEST['eligible_duplicate.stdout']
env = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C',
       'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
names = ['valid_regular', 'empty_eof', 'malformed', 'closed_stdin',
         'write_only_stdin', 'nonblocking_empty_pipe',
         'nonblocking_ready_pipe', 'closed_stdout_reader']
records = []
for name in names:
    case = OUT / name
    case.mkdir()
    offered = valid if name in ['valid_regular', 'nonblocking_ready_pipe', 'closed_stdout_reader'] else (b'(' if name == 'malformed' else b'')
    (case / 'offered-input.bin').write_bytes(offered)
    input_file = (case / 'offered-input.bin').open('rb')
    stdin = input_file
    descriptors = []
    descriptor_state = {'kind': 'regular_file', 'bytes': len(offered), 'start_offset': 0}
    stdout = subprocess.PIPE
    if name == 'write_only_stdin':
        fd = os.open(case / 'write-only.bin', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        descriptors.append(fd)
        stdin = fd
        descriptor_state = {'kind': 'write_only_regular_file', 'fcntl_flags': fcntl.fcntl(fd, fcntl.F_GETFL)}
    elif name in ['nonblocking_empty_pipe', 'nonblocking_ready_pipe']:
        read_fd, write_fd = os.pipe()
        descriptors.extend([read_fd, write_fd])
        flags = fcntl.fcntl(read_fd, fcntl.F_GETFL)
        fcntl.fcntl(read_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        if offered:
            assert os.write(write_fd, offered) == len(offered)
            os.close(write_fd)
            descriptors.remove(write_fd)
        stdin = read_fd
        descriptor_state = {'kind': 'pipe', 'fcntl_flags': fcntl.fcntl(read_fd, fcntl.F_GETFL),
                            'nonblocking_mask': os.O_NONBLOCK, 'writer_open_in_parent': not bool(offered),
                            'bytes_queued': len(offered)}
    elif name == 'closed_stdin':
        descriptor_state = {'kind': 'fd0_closed_in_child_before_exec'}
    if name == 'closed_stdout_reader':
        read_fd, write_fd = os.pipe()
        os.close(read_fd)
        descriptors.append(write_fd)
        stdout = write_fd
        descriptor_state['stdout'] = 'pipe with no readers; default SIGPIPE restored by subprocess'
    def setup():
        resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        if name == 'closed_stdin':
            os.close(0)
    record = {'case': name, 'argv': [str(EXE)], 'environment': env,
              'descriptor_setup': descriptor_state, 'cpu_seconds_per_process': 30,
              'offered_input_sha256': sha(offered), 'executable_sha256': SHA,
              'scope': 'Finite native observation, no universal FFI or exit-contract proof',
              'end_to_end': False}
    (case / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
    try:
        child = subprocess.Popen([str(EXE)], stdin=stdin, stdout=stdout, stderr=subprocess.PIPE,
                                 env=env, preexec_fn=setup, close_fds=True, restore_signals=True)
        captured_out, captured_err = child.communicate()
        captured_out = captured_out or b''
        (case / 'stdout.bin').write_bytes(captured_out)
        (case / 'stderr.bin').write_bytes(captured_err)
        record.update(actual_exit=child.returncode, stdout_sha256=sha(captured_out),
                      stderr_sha256=sha(captured_err), stdout_bytes=len(captured_out),
                      stderr_bytes=len(captured_err), stdout_captured=name != 'closed_stdout_reader',
                      matches_valid_expected=captured_out == expected if name in ['valid_regular', 'nonblocking_ready_pipe'] else None)
    finally:
        input_file.close()
        for fd in descriptors:
            os.close(fd)
    assert sha(EXE.read_bytes()) == SHA
    (case / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
    records.append(record)
    (OUT / 'observations.json').write_text(json.dumps(records, indent=2) + '\n')
    print(name, 'actual exit', record['actual_exit'], 'stdout', record['stdout_bytes'], 'stderr', record['stderr_bytes'], flush=True)
    if record.get('matches_valid_expected') is False or (name in ['valid_regular', 'nonblocking_ready_pipe'] and record['actual_exit'] != 0):
        raise SystemExit('Positive control failed; preserve evidence and inspect')
print('NATIVE_OBSERVATIONS_COMPLETE', flush=True)
