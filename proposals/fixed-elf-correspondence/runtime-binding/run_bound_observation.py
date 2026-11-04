"""Dispatch the existing observer and bind fresh output to the held fixed trace.

Identity checks only: no ISA decoder, new semantics, proof checker, signature,
admission or cross-run receipt adoption. Authenticate this script's exact bytes
through independent review before trusting its held expectations. Hashes and an
in-packet manifest do not authenticate themselves. Runtime assumptions remain.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

MANIFEST_SHA256 = '24afcae2976fbcf38a024afc29455d310510d7eedb40320cb982fc226bdd5db0'
TRACE_SHA256 = '526c4a2107262bd8624cc19e9762fa4875d536e0b7697324a1a2b468bdf9ed49'
ELF_SHA256 = '8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6'
EXECUTION_IDENTITIES = {
    'elf_sha256': ELF_SHA256,
    'qemu_sha256': 'be89e201dc6112ef101617ab575c95119ad123f80ca2b51b6c36ef218ac9df65',
    'gdb_sha256': '0baeb299d3aa39f40ca72c3cb8ae5b15a5bd01f1995583a52cfdd7527bfffe07',
    'commands_sha256': '1288a505001e2ddd3e8991e5baa871e271c0ae32e10672523e2853d4839e7a7e',
}
LOADS = {
    'ro': (344, 'fc4d1b4744166c66ed2f0c383815fd94c232ca3c036f41bbd7bb6461929e58a3'),
    'text': (60, 'abc3681a78a85d6dd01a490691f95621af177469b1c6c1b8fea70c097eb05db6'),
}
QEMU_ARGV = [
    '/runtime/qemu-riscv64-static', '-cpu', 'rv64', '-s', '8388608', '-g', '12345',
    '-one-insn-per-tb', '-strace', '-d', 'in_asm,cpu,fpu,page,nochain',
    '-D', '/records/instruction-trace.log', '/tmp/gcd-selftest.elf',
]

class Refusal(ValueError):
    pass

def require(condition, reason):
    if not condition:
        raise Refusal(reason)

def read(path):
    require(path.is_file() and not path.is_symlink(), 'MISSING_OR_LINKED_INPUT:' + path.name)
    return path.read_bytes()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def is_zero(value):
    return type(value) is int and value == 0

def check_packet(root):
    held = read(root / 'MANIFEST.json')
    require(sha(held) == MANIFEST_SHA256, 'PACKET_ANCHOR_MISMATCH')
    expected = json.loads(held)
    actual = {}
    for path in sorted(root.rglob('*')):
        name = path.relative_to(root).as_posix()
        if name == 'MANIFEST.json':
            continue
        if path.is_symlink():
            actual[name] = {'kind': 'symlink', 'target': os.readlink(path)}
        elif path.is_file():
            actual[name] = {'kind': 'file', 'sha256': sha(path.read_bytes())}
    require(actual == expected, 'PACKET_CONTENTS_CHANGED')
    return sha(held)

def bind_capture(capture):
    """Compare bytes from a trusted fresh child; this helper grants no authority."""
    trace = read(capture / 'instruction-trace.log')
    require(sha(trace) == TRACE_SHA256, 'TRACE_IDENTITY_MISMATCH')
    inputs = json.loads(read(capture / 'execution-before.json'))
    for name, expected in EXECUTION_IDENTITIES.items():
        require(inputs.get(name) == expected, 'EXECUTION_IDENTITY_MISMATCH:' + name)
    require(inputs.get('qemu_argv') == QEMU_ARGV, 'EXECUTION_COMMAND_MISMATCH')
    raw_hashes = {'instruction-trace.log': sha(trace)}
    for part, (size, expected) in LOADS.items():
        name = 'live-load-' + part + '.bin'
        raw = read(capture / name)
        require(len(raw) == size and sha(raw) == expected, 'LOAD_IDENTITY_MISMATCH:' + part)
        raw_hashes[name] = sha(raw)
    parent = json.loads(read(capture / 'qemu-command.json'))
    require(is_zero(parent.get('actual_exit')), 'PARENT_EXIT_NOT_ZERO')
    require(parent.get('terminated_by_observer') is False, 'OBSERVER_TERMINATED_OR_UNKNOWN')
    require(parent.get('argv') == inputs.get('qemu_argv'), 'EXECUTION_COMMAND_MISMATCH')
    observation = json.loads(read(capture / 'result.json'))
    require(is_zero(observation.get('qemu_exit')) and is_zero(observation.get('gdb_exit')),
            'OBSERVATION_EXIT_NOT_ZERO')
    require(observation.get('end_to_end') is False and observation.get('admitted') is False,
            'UNAUTHORIZED_SCOPE_UPGRADE')
    for name in ['execution-before.json', 'qemu-command.json', 'result.json']:
        raw_hashes[name] = sha(read(capture / name))
    return {
        'classification': 'OBSERVATION_MATCHES_HELD_TRACE',
        'elf_sha256': ELF_SHA256,
        'raw_output_sha256': raw_hashes,
        'full_trace_match': True,
        'claims': ['finite exact-byte observation binding only'],
        'proof_replayed_this_run': False,
        'runtime_refinement': 'NOT_ESTABLISHED',
        'authoritative_profile_approved': False,
        'admitted': False,
        'end_to_end': False,
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-packet', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    packet = args.runtime_packet.resolve()
    out = args.out.resolve()
    require(not out.is_relative_to(packet), 'OUTPUT_INSIDE_HELD_PACKET')
    out.mkdir(mode=0o700, parents=True, exist_ok=False)
    try:
        check_packet(packet)
        command = [sys.executable, '-I', '-B', str(packet / 'replay.py'), '--out', str(out / 'runtime')]
        start = time.monotonic()
        with (out / 'runtime.log').open('xb') as log:
            child = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        invocation = {'argv': command, 'actual_exit': child.returncode,
                      'wall_seconds': time.monotonic() - start}
        (out / 'invocation.json').write_text(json.dumps(invocation, indent=2) + '\n')
        require(child.returncode == 0, 'FRESH_OBSERVER_FAILED')
        check_packet(packet)
        result = bind_capture(out / 'runtime/capture')
        result.update({'actual_exit': 0, 'fresh_observer_child_exit': child.returncode,
                       'packet_manifest_sha256': MANIFEST_SHA256})
        (out / 'binding-result.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
        print('FRESH_OBSERVATION_MATCHES_HELD_TRACE')
        return 0
    except (Refusal, OSError, ValueError) as error:
        (out / 'refusal.json').write_text(json.dumps({'actual_exit': 1, 'reason': str(error),
            'admitted': False, 'end_to_end': False}, indent=2) + '\n')
        print(str(error), file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
