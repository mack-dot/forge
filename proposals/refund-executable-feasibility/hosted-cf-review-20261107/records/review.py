"""Read-only review of the frozen U329 package. Does not execute HOL or network calls."""
from pathlib import Path
import ast,hashlib,io,json,re,subprocess,tarfile,yaml
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
PACKET=ROOT/'proposals/refund-executable-feasibility/hosted-cf-candidate-20261107'
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((PACKET/'MANIFEST.json').read_text())
for name,digest in manifest['files'].items():assert sha((PACKET/name).read_bytes())==digest,name
assert len(manifest['files'])==66
driver=(PACKET/'records/hosted-driver.py').read_text();ast.parse(driver)
assert sha(driver.encode())=='b859fe575016c8b88f77a9d105e6e54f4535d7b82fffe8173dfdb28223b94eaf'
raw=(PACKET/'records/proposed-workflow.yml').read_bytes()
assert sha(raw)=='6db12f716e14a227b5de1b6d7f58da6ba3c020dc07bb87b413a225cedfea2b42'
wf=yaml.load(raw,Loader=yaml.BaseLoader)
assert wf['permissions']=={} and set(wf['on'])=={'push'} and len(wf['jobs'])==1
assert wf['on']['push']=={'branches':['proposal/m1-macos-preflight-20261106'],'paths':['.github/workflows/m1-macos-preflight.yml']}
job=next(iter(wf['jobs'].values()));assert job['runs-on']=='macos-15' and job['timeout-minutes']=='15'
assert 'permissions' not in job and len(job['steps'])==1
step=job['steps'][0];assert 'uses' not in step and step['shell']=='bash --noprofile --norc -euo pipefail {0}'
assert step['env']=={'ADDON_COMMIT_SHA':'INPUT_COMMIT_PENDING_APPROVAL',
 'ADDON_MANIFEST_SHA256':'6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105','ADDON_MANIFEST_BYTES':'932639'}
assert step['run']=="/usr/bin/python3 -I -B - <<'PY'\n"+driver+'PY\n'
(OUT/'embedded-shell.sh').write_text(step['run'])
argv=['/bin/bash','--noprofile','--norc','-n',str(OUT/'embedded-shell.sh')]
process=subprocess.run(argv,capture_output=True)
for name,data in [('stdout.log',process.stdout),('stderr.log',process.stderr)]:
    (OUT/name).write_bytes(data)
assert process.returncode==0
payload=json.loads((PACKET/'payload/INPUTS.json').read_text());parts=[]
assert sha((PACKET/'payload/INPUTS.json').read_bytes())==step['env']['ADDON_MANIFEST_SHA256']
for part in payload['parts']:
    data=(PACKET/'payload'/part['name']).read_bytes()
    assert len(data)==part['bytes'] and sha(data)==part['sha256'];parts.append(data)
archive=b''.join(parts);assert sha(archive)==payload['archive_sha256']
expected={r['path']:r for r in payload['files']}
with tarfile.open(fileobj=io.BytesIO(archive),mode='r:xz') as tar:
    members=tar.getmembers();assert len(members)==1475 and {m.name for m in members}==set(expected)
    candidate=None
    for member in members:
        assert member.isfile() and not Path(member.name).is_absolute() and '..' not in Path(member.name).parts
        data=tar.extractfile(member).read();rec=expected[member.name]
        assert len(data)==rec['bytes'] and sha(data)==rec['sha256']
        if member.name.endswith('/generic-read-0001.sml'):candidate=data
assert candidate is not None and sha(candidate)=='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
candidate=candidate.decode();statement=candidate.split('store_thm ("read_error_generic", ``',1)[1].split('``,',1)[0]
check=(PACKET/'records/prepared-inputs/import.sml').read_text();expected_statement=check.split('val expected = ``',1)[1].split('``;',1)[0]
assert statement==expected_statement
assert all(token in statement for token in ['FFIreturn (1w::n2w n::h3::h4::rest)', 'one (FFI_part s u ns events)', 'one (FFI_part s\' u ns','events ++ [IO_event','ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest)'])
tc=ROOT/'.toolchain/experiments/refund-cakeml-20261104/cakeml'
source_hashes={name:sha((tc/name).read_bytes()) for name in ['basis/TextIOProgScript.sml','basis/TextIOProofScript.sml','characteristic/cfScript.sml','characteristic/cfTacticsLib.sml']}
prior=json.loads((ROOT/'proposals/refund-executable-feasibility/read-event-gap-20261107/records/readback.json').read_text())['source_files']
for name,h in source_hashes.items():assert prior[str(tc/name)]==h
result={'actual_exit':0,'scope':'Same-agent offline code/statement/transport review. No HOL, native execution, remote write or independent proof replay.',
 'frozen_packet_members':66,'new_archive_members':1475,'candidate_sha256':sha(candidate.encode()),
 'candidate_and_import_statement_identical':True,'workflow_sha256':sha(raw),'driver_sha256':sha(driver.encode()),
 'shell_syntax':{'argv':argv,'actual_exit':process.returncode,'stdout_sha256':sha(process.stdout),'stderr_sha256':sha(process.stderr)},
 'pinned_source_hashes':source_hashes,'blocking_defect_found_in_reviewed_scope':False,
 'proof_result':'NOT_ESTABLISHED','dependency_closure_of_candidate':'NOT_ESTABLISHED',
 'hosted_validation':'NOT_RUN','additional_hosted_approval':'PENDING','end_to_end':False}
(OUT/'review.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
