"""Read back real HOL outcomes and exact fixture identity; no semantic evaluator."""
import hashlib
import json
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
preparation = json.loads((OUT/'constructor-controls-preparation.json').read_text())
assert preparation['actual_exit'] == 0
accepted = []
for case, theorem, prefix in [('altered-read-byte-0003', 0, []),
                              ('wrong-write-descriptor-0003', 3, ['0','1','2'])]:
    dest = OUT/('model-'+case)
    record = json.loads((dest/'command.json').read_text())
    frozen = next(c for c in preparation['cases'] if c['case']==case)
    assert record['source_sha256'] == frozen['source_sha256'] == sha(dest/'check.sml')
    assert record['actual_exit'] == 1
    assert not record['objects'] and not record['completion_marker']
    stdout = (dest/'stdout.log').read_text()
    stderr = (dest/'stderr.log').read_text()
    assert re.search(r'First unsolved sub-goal is\s+F\s',stdout)
    assert 'Failed to prove theorem "observed_ffi_'+str(theorem)+'"' in stderr
    assert re.findall(r'^OBSERVED_FFI_(\d+)_CHECKED$',stdout,re.M) == prefix
    assert 'OBSERVED_FFI_MODEL_CHECK_COMPLETE' not in stdout
    assert not list((dest/'.hol').rglob('*Theory.dat'))
    accepted.append({'case':case,'actual_exit':1,'expected_exit':1,
                     'rejection_theorem':'observed_ffi_'+str(theorem),
                     'residual_goal':'F','positive_prefix_equations':prefix,
                     'complete_export':False,'source_sha256':sha(dest/'check.sml'),
                     'command_sha256':sha(dest/'command.json'),
                     'stdout_sha256':sha(dest/'stdout.log'),'stderr_sha256':sha(dest/'stderr.log')})
record = {'actual_exit':0,'scope':'Readback of two actual intended HOL refusals',
          'cases':accepted,'full_positive_model_result':'Still requires its original terminal record',
          'end_to_end':False}
assert not (OUT/'model-controls-readback.json').exists()
(OUT/'model-controls-readback.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
