from pathlib import Path
import hashlib, json, shutil, subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
frozen = json.loads((OUT / 'inputs.json').read_text())
names = sorted(n for n in set(frozen['source_closure']) | set(frozen['compiler_closure']) if n.startswith('forge_'))
overrides = {
    'forge_refundRejectDirect': OUT.parent / 'attempt-0006/export-0002/export-proof.sml',
    'forge_refundRejectSemantics': OUT.parent / 'attempt-0007/stdio-0003/proof.sml',
    'forge_refundRejectBasis': OUT.parent / 'attempt-0008/accepted-concrete.sml',
    'forge_refundPreciseBehavior': ROOT / 'results/refund-runtime-premises-2026-11-04/attempt-0002/precise-0003/proof.sml',
    'forge_refundRejectCompiled': OUT / 'accepted.sml',
}
records = {}
def copy(name, source, dest):
    assert source.is_file(), source
    if dest.exists():
        assert dest.read_bytes() == source.read_bytes(), dest
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
    records[name] = {'original_path': str(source), 'snapshot': str(dest.relative_to(OUT)),
                     'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}
for name in names + ['forge_refundRejectCompiled']:
    source = overrides[name] if name in overrides else TC / 'cakeml/compiler/dafny' / (name + '_experiment') / (name + 'Script.sml')
    copy(name, source, OUT / 'replay-sources' / (name + '.sml'))
for rel in ['basis/basis_ffi.c', 'basis/fsFFIScript.sml',
            'compiler/backend/semantics/targetSemScript.sml',
            'compiler/backend/proofs/backendProofScript.sml',
            'compiler/backend/arm8/proofs/arm8_configProofScript.sml',
            'translator/ml_progScript.sml']:
    copy(rel, TC / 'cakeml' / rel, OUT / 'upstream' / rel)
commands = []
for name, pin in [('cakeml', 'cd9155694c16831373ab695a670794f23282ed62'),
                  ('HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'),
                  ('polyml', '4557554077078decce4ce5f90da00a713cfc32e4')]:
    argv = ['git', '-C', str(TC / name), 'rev-parse', 'HEAD']
    child = subprocess.run(argv, capture_output=True, text=True)
    commands.append({'argv': argv, 'actual_exit': child.returncode, 'stdout': child.stdout, 'stderr': child.stderr})
    assert child.returncode == 0 and child.stdout.strip() == pin
    if name != 'polyml':
        argv = ['git', '-C', str(TC / name), 'diff', '--exit-code']
        child = subprocess.run(argv, capture_output=True, text=True)
        commands.append({'argv': argv, 'actual_exit': child.returncode, 'stdout': child.stdout, 'stderr': child.stderr})
        assert child.returncode == 0
record = {'actual_exit': 0, 'source_files': records, 'commands': commands,
          'execution_status': 'PREPARED_ONLY; independent replay NOT_RUN', 'end_to_end': False}
(OUT / 'replay-preparation.json').write_text(json.dumps(record, indent=2) + '\n')
print('Replay source snapshots:', len(records))
