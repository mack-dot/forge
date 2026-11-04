"""Check saved identities and command evidence. This does not check a proof."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
CAKE = ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml'
IO = ROOT / 'results/refund-native-io-2026-11-04/attempt-0001'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text())

baseline = read(OUT / 'baseline.json')
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
assert all(sha(ROOT / name) == digest for name, digest in baseline['protected'].items())
journal = (ROOT / 'unsure.md').read_bytes()
assert hashlib.sha256(journal[:baseline['unsure_bytes']]).hexdigest() == baseline['unsure_prefix_sha256']

files = set(baseline['upstream_files']) | {
    'basis/SexpProgScript.sml', 'basis/pure/mlsexpScript.sml',
    'compiler/backend/semantics/targetSemScript.sml',
    'semantics/proofs/semanticsPropsScript.sml',
    'compiler/backend/arm8/arm8_configScript.sml',
}
upstream = []
for name in sorted(files):
    argv = ['git', '-C', str(CAKE), 'show', baseline['cakeml_commit'] + ':' + name]
    result = subprocess.run(argv, capture_output=True)
    assert result.returncode == 0, (argv, result.stderr)
    assert (CAKE / name).read_bytes() == result.stdout, name
    upstream.append(dict(path=name, sha256=sha(CAKE / name), argv=argv, actual_exit=result.returncode))

runtime = []
for name, expected in [('runtime-build-0001', 1), ('runtime-build-0002', 0), ('runtime-repeat-0002', 0)]:
    directory = OUT / name
    record = read(directory / 'command.json')
    assert record['actual_exit'] == expected
    assert sha(directory / 'basis_ffi.c') == baseline['upstream_files']['basis/basis_ffi.c']
    if expected == 0:
        assert sha(directory / 'basis_ffi.o') == record['object_sha256']
        assert sha(Path(record['argv'][0])) == record['clang_sha256']
        sdk = Path(record['argv'][record['argv'].index('-isysroot') + 1])
        assert sha(sdk / 'SDKSettings.json') == record['sdk_settings_sha256']
    else:
        assert "'assert.h' file not found" in (directory / 'stderr.log').read_text()
    runtime.append(dict(case=name, actual_exit=record['actual_exit'], record_sha256=sha(directory / 'command.json')))
assert (OUT / 'runtime-build-0002/basis_ffi.o').read_bytes() == (OUT / 'runtime-repeat-0002/basis_ffi.o').read_bytes()
dependencies = read(OUT / 'runtime-dependencies.json')['dependency_sha256']
assert all(sha(Path(path)) == digest for path, digest in dependencies.items())

corpus = read(OUT / 'native-corpus/freeze.json')
assert all(sha(OUT / 'native-corpus' / name) == digest for name, digest in corpus['files'].items())
assert len(read(OUT / 'native-corpus/cases.json')) == corpus['case_count'] == 22
attempts = []
for name in ['corpus-0001', 'corpus-0002']:
    directory = OUT / name
    record = read(directory / 'command.json')
    assert record['actual_exit'] == 1
    assert sha(directory / 'forge_native_corpusScript.sml') == record['source_sha256']
    assert 'Operation not permitted' in (directory / 'build.log').read_text()
    assert not list((directory / 'objects').glob('*'))
    attempts.append(dict(case=name, actual_exit=1, classification='BUILD_DRIVER_REFUSED_BEFORE_PROOF'))

io_records = []
for name in ['proof-full-0002', 'proof-repeat']:
    directory = IO / name
    record = read(directory / 'command.json')
    assert record['actual_exit'] == 0
    assert sha(directory / 'forge_refund_ioScript.sml') == record['source_sha256']
    assert all(sha(directory / 'objects' / name) == digest for name, digest in record['object_sha256'].items())
    io_records.append(record)
assert io_records[0]['source_sha256'] == io_records[1]['source_sha256']
assert io_records[0]['object_sha256'] == io_records[1]['object_sha256']
controls = []
for name, theorem in [('swapped-input', 'refund_schema_roundtrip'),
                      ('swapped-output', 'refund_response_roundtrip'),
                      ('nonnegative-coercion', 'refund_schema_roundtrip'),
                      ('ignored-tail', 'refund_trailing_input_rejected')]:
    directory = IO / ('proof-' + name)
    record = read(directory / 'command.json')
    assert record['actual_exit'] == 1
    assert sha(directory / 'forge_refund_ioScript.sml') == record['source_sha256']
    log = (directory / 'theory.log').read_text()
    assert re.findall(r'Tactic failure proving "([^"]+)"', log) == [theorem]
    controls.append(dict(case=name, actual_exit=1, failing_theorem=theorem,
                         log_sha256=sha(directory / 'theory.log')))
closure = read(IO / 'closure-lines.json')
nodes = [line for line in closure if line.startswith('FORGE_PARENT ')]
tags = [line for line in closure if line.startswith('FORGE_TAG ')]
axioms = [line.removeprefix('FORGE_CLOSURE_AXIOM ') for line in closure if line.startswith('FORGE_CLOSURE_AXIOM ')]
assert len(nodes) == 159 and len(tags) == 12
assert all('oracles=DISK_THM axioms= hypotheses=0' in line for line in tags)
assert set(axioms) == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
result = dict(actual_exit=0, classification='SAVED_RECORD_IDENTITY_CHECK_ONLY',
    protected_files_unchanged=len(baseline['protected']), mission_unchanged=True,
    prior_uncertainty_bytes_unchanged=baseline['unsure_bytes'], upstream=upstream,
    runtime_commands=runtime, runtime_source_and_headers=len(dependencies), runtime_objects_identical=True,
    prepared_corpus_count=22, corpus_attempts=attempts, corpus_model_check='NOT_ESTABLISHED',
    io_source_sha256=io_records[0]['source_sha256'], io_exports=io_records[0]['object_sha256'],
    io_recorded_positive_exits=[0, 0], io_recorded_controls=controls, io_recorded_closure_nodes=len(nodes),
    io_recorded_theorems=len(tags), io_recorded_foundation_axioms=axioms,
    fresh_independent_kernel_replay='NOT_RUN', native_refund_execution='NOT_RUN',
    compiler_theorem_instantiation='NOT_RUN', native_runtime_correspondence='NOT_ESTABLISHED',
    end_to_end=False)
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in ('upstream', 'io_exports', 'io_recorded_controls')}))
