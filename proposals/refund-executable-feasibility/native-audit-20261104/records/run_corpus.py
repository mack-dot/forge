"""Run HOL's existing kernel on the frozen native test expectations."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

OUT = Path(__file__).resolve().parent
TC = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
work = TC / 'cakeml/compiler/dafny/forge_native_corpus_experiment'
record = OUT / ('corpus-' + sys.argv[1])
record.mkdir(exist_ok=False)
work.mkdir(exist_ok=True)
source = OUT / 'native-corpus/forge_native_corpusScript.sml'
target = work / source.name
if target.exists():
    assert target.read_bytes() == source.read_bytes()
else:
    shutil.copyfile(source, target)
(work / 'Holmakefile').write_text('ifdef POLY\nHOLHEAP = $(CAKEMLDIR)/misc/cakeml-heap\nendif\n')
env = os.environ.copy()
env.update(HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
jobs = sys.argv[2] if len(sys.argv) > 2 else '1'
assert jobs in ('1', '2')
argv = [str(TC / 'HOL/bin/Holmake'), '--no-cache', '-j', jobs]
if sys.argv[1] == 'dry-run':
    argv += ['-n']
argv += ['forge_native_corpusTheory.uo']
with (record / 'build.log').open('wb') as log:
    result = subprocess.run(argv, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
summary = {'argv': argv, 'cwd': str(work), 'actual_exit': result.returncode,
           'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
           'native_execution': 'NOT_RUN', 'end_to_end': False}
(record / 'command.json').write_text(json.dumps(summary, indent=2) + '\n')
if sys.argv[1] != 'dry-run':
    shutil.copyfile(source, record / source.name)
    objects = record / 'objects'
    objects.mkdir()
    for f in (work / '.hol/objs').glob('forge_native_corpusTheory.*'):
        shutil.copyfile(f, objects / f.name)
    log = work / '.hol/logs/forge_native_corpusTheory'
    if log.exists():
        shutil.copyfile(log, record / 'theory.log')
print(json.dumps(summary))
print((record / 'build.log').read_text(errors='replace')[-4500:])
raise SystemExit(result.returncode)
