"""Link only the successful exact refund arm8 output; preserve each native build."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
COMPILE = Path(sys.argv[1]).resolve()
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
XCODE = Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin')
CLANG = XCODE / 'clang'
SDK = Path('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk')
EARLIER = OUT.parent / 'attempt-0001'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(work, name, argv):
    directory = work / name
    directory.mkdir(exist_ok=False)
    start = time.monotonic()
    with (directory / 'stdout.log').open('wb') as stdout, (directory / 'stderr.log').open('wb') as stderr:
        result = subprocess.run(argv, cwd=work, stdout=stdout, stderr=stderr)
    record = {'argv': argv, 'cwd': str(work), 'actual_exit': result.returncode,
              'wall_seconds': time.monotonic() - start}
    (directory / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record), flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)

record = json.loads((COMPILE / 'command.json').read_text())
assert record['actual_exit'] == 0 and record['status'] == 'FINISHED'
assert sha(COMPILE / 'refund.S') == record['assembly_sha256']
for name, digest in record['object_sha256'].items():
    assert sha(COMPILE / 'objects' / name) == digest, name
assert record['object_sha256'].get('forge_refundArm8CompileTheory.dat')
approval = json.loads((OUT.parent / 'attempt-0002/local-signing-authorization.json').read_text())
linker_record = json.loads((OUT.parent / 'attempt-0002/ld-help-command.json').read_text())
assert sha(XCODE / 'ld') == linker_record['tool_sha256']
# The authority is the user's actual approval, recorded in U269. This file is
# retained as evidence; its existence is not a new authorization mechanism.
builds = []
for name, runtime_name in [('native-build-0001', 'runtime-build-0002'),
                           ('native-repeat-0001', 'runtime-repeat-0002')]:
    runtime = EARLIER / runtime_name
    runtime_record = json.loads((runtime / 'command.json').read_text())
    assert runtime_record['actual_exit'] == 0
    assert sha(runtime / 'basis_ffi.o') == runtime_record['object_sha256']
    assert sha(TC / 'cakeml/basis/basis_ffi.c') == runtime_record['source_sha256']
    assert sha(CLANG) == runtime_record['clang_sha256']
    assert sha(SDK / 'SDKSettings.json') == runtime_record['sdk_settings_sha256']
    work = OUT / name
    work.mkdir(exist_ok=False)
    shutil.copyfile(COMPILE / 'refund.S', work / 'refund.S')
    shutil.copyfile(runtime / 'basis_ffi.o', work / 'basis_ffi.o')
    start_record = {'compiler_record': str(COMPILE / 'command.json'),
                    'compiler_record_sha256': sha(COMPILE / 'command.json'),
                    'assembly_sha256': record['assembly_sha256'],
                    'runtime_object_sha256': runtime_record['object_sha256'],
                    'linker_sha256': linker_record['tool_sha256'],
                    'local_ad_hoc_signature_approval': approval,
                    'signing_scope': 'Local Apple arm64 ad hoc signature only, as approved in U269',
                    'link_status': 'NOT_RUN', 'native_execution': 'NOT_RUN', 'end_to_end': False}
    (work / 'inputs.json').write_text(json.dumps(start_record, indent=2) + '\n')
    run(work, 'assemble', [str(CLANG), '-arch', 'arm64', '-isysroot', str(SDK),
                           '-O2', '-c', 'refund.S', '-o', 'refund.o'])
    # The installed Apple linker creates the approved local ad hoc signature.
    link_argv = [str(CLANG), '-arch', 'arm64', '-isysroot', str(SDK),
                 'refund.o', 'basis_ffi.o', '-lm', '-o', 'refund']
    run(work, 'link-plan', link_argv + ['-###'])
    assert str(XCODE / 'ld') in (work / 'link-plan/stderr.log').read_text()
    assert sha(XCODE / 'ld') == linker_record['tool_sha256']
    run(work, 'link', link_argv)
    exe_hash = sha(work / 'refund')
    run(work, 'signature-verify', ['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', 'refund'])
    run(work, 'signature-display', ['/usr/bin/codesign', '--display', '--verbose=4', 'refund'])
    for label, argv in [
        ('mach-header', ['/usr/bin/otool', '-hv', 'refund']),
        ('load-commands', ['/usr/bin/otool', '-l', 'refund']),
        ('libraries', ['/usr/bin/otool', '-L', 'refund']),
        ('symbols', ['/usr/bin/nm', '-nm', 'refund']),
        ('sections', [str(XCODE / 'llvm-objdump'), '--macho', '--section-headers', '--reloc', 'refund']),
    ]:
        run(work, label, argv)
    assert sha(work / 'refund') == exe_hash
    build = {'actual_exit': 0, 'executable': str(work / 'refund'),
             'executable_sha256': exe_hash, 'assembly_object_sha256': sha(work / 'refund.o'),
             'assembly_sha256': record['assembly_sha256'],
             'local_ad_hoc_signature': 'LINKER_OUTPUT_VERIFIED',
             'native_execution': 'NOT_RUN', 'end_to_end': False}
    (work / 'result.json').write_text(json.dumps(build, indent=2) + '\n')
    builds.append(build)

identical = builds[0]['executable_sha256'] == builds[1]['executable_sha256']
summary = {'actual_exit': 0 if identical else 1, 'builds': builds,
           'whole_executable_reproduced': identical,
           'scope': 'Local linking, signature validation and exact reproduction only; not behavioral proof',
           'native_execution': 'NOT_RUN', 'end_to_end': False}
(OUT / 'link-result.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary), flush=True)
raise SystemExit(summary['actual_exit'])
