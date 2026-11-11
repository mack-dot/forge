from pathlib import Path
import ast,hashlib,json,yaml
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
summary=json.loads((OUT/'PACKAGE.json').read_text())
driver=(OUT/'hosted-driver.py').read_text();ast.parse(driver)
workflow='''name: Forge M1 scoped generic FFI candidate
"on":
  push:
    branches: [proposal/m1-macos-preflight-20261106]
    paths: [.github/workflows/m1-macos-preflight.yml]
permissions: {}
concurrency:
  group: forge-m1-macos-environment-preflight
  cancel-in-progress: false
jobs:
  environment-and-unchanged-generic-candidate:
    if: github.repository == 'mack-dot/forge' && github.event.repository.private == false
    runs-on: macos-15
    timeout-minutes: 15
    steps:
      - name: Validate private inputs and execute the unchanged generic FFI candidate
        shell: bash --noprofile --norc -euo pipefail {0}
        env:
          ADDON_COMMIT_SHA: 'INPUT_COMMIT_PENDING_APPROVAL'
          ADDON_MANIFEST_SHA256: '%s'
          ADDON_MANIFEST_BYTES: '%s'
        run: |
          /usr/bin/python3 -I -B - <<'PY'
%s          PY
'''%(summary['manifest_sha256'],summary['manifest_bytes'],''.join('          '+line+'\n' for line in driver.splitlines()))
(OUT/'proposed-workflow.yml').write_text(workflow)
parsed=yaml.load(workflow,Loader=yaml.BaseLoader)
assert parsed['permissions']=={} and set(parsed['on'])=={'push'}
assert len(parsed['jobs'])==1
job=next(iter(parsed['jobs'].values()));assert job['runs-on']=='macos-15' and job['timeout-minutes']=='15'
assert len(job['steps'])==1 and 'uses' not in job['steps'][0]
assert job['steps'][0]['run']=="/usr/bin/python3 -I -B - <<'PY'\n"+driver+'PY\n'
assert workflow.count('INPUT_COMMIT_PENDING_APPROVAL')==1
triggers=[]
for r in json.loads((OUT/'remote-workflow-directory.json').read_text()):
    if r['path'].endswith('m1-macos-preflight.yml'):p=OUT/'remote-workflow.yml'
    elif r['path'].endswith('booking-reuse.yml'):p=OUT/'remote-booking-reuse.yml'
    else:p=ROOT/r['path']
    b=p.read_bytes();assert len(b)==r['size']
    assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==r['sha']
    events=yaml.load(b,Loader=yaml.BaseLoader)['on']
    if 'push' in events and not r['path'].endswith('m1-macos-preflight.yml'):
        assert events['push']['branches']==['main'],r['path']
    assert 'workflow_run' not in events,r['path']
    triggers.append({'path':r['path'],'blob_sha':r['sha'],'events':events})
record={'actual_exit':0,'proposed_workflow_sha256':sha(workflow.encode()),'driver_sha256':sha(driver.encode()),
        'workflow_bytes':len(workflow.encode()),'current_remote_head':'8ad9de1e538edd48a2084796510e784913eaef8b',
        'existing_workflows':triggers,'additional_trigger_for_proposal_push':False,
        'single_dynamic_field':'ADDON_COMMIT_SHA; exact new immutable input commit only',
        'approval':'PENDING','published':False,'hosted_run':'NOT_RUN','end_to_end':False}
(OUT/'WORKFLOW-REVIEW.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k!='existing_workflows'},indent=2))
