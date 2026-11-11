from pathlib import Path
import ast,hashlib,json,subprocess,yaml
OUT=Path(__file__).resolve().parent
source=(OUT/'integrity_driver.py').read_text();ast.parse(source)
workflow='''name: Forge M1 frozen input integrity only
"on":
  push:
    branches: [proposal/m1-input-integrity-20261108]
    paths: [.github/workflows/m1-input-integrity.yml]
permissions: {}
concurrency:
  group: forge-m1-input-integrity-20261108
  cancel-in-progress: false
jobs:
  integrity-only:
    if: github.repository == 'mack-dot/forge' && github.event.repository.private == false
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Read immutable bytes and verify all identities without executing inputs
        shell: bash --noprofile --norc -euo pipefail {0}
        run: |
          /usr/bin/python3 -I -B - <<'PY'
'''+''.join('          '+line+'\n' for line in source.splitlines())+'          PY\n'
(OUT/'proposed-workflow.yml').write_text(workflow)
wf=yaml.load(workflow,Loader=yaml.BaseLoader);assert wf['permissions']=={} and len(wf['jobs'])==1
job=wf['jobs']['integrity-only'];assert job['runs-on']=='ubuntu-24.04' and job['timeout-minutes']=='5'
assert len(job['steps'])==1 and 'uses' not in job['steps'][0] and 'env' not in job['steps'][0]
assert job['steps'][0]['run']=="/usr/bin/python3 -I -B - <<'PY'\n"+source+'PY\n'
shell=OUT/'proposed-shell.sh';shell.write_text(job['steps'][0]['run'])
argv=['/bin/bash','--noprofile','--norc','-n',str(shell)]
p=subprocess.run(argv,capture_output=True)
for name,data in [('shell.stdout.log',p.stdout),('shell.stderr.log',p.stderr)]:
    (OUT/name).write_bytes(data)
assert p.returncode==0
sha=lambda b:hashlib.sha256(b).hexdigest()
result={'actual_exit':0,'driver_sha256':sha(source.encode()),'driver_bytes':len(source.encode()),
 'workflow_sha256':sha(workflow.encode()),'workflow_bytes':len(workflow.encode()),
 'shell_check':{'argv':argv,'actual_exit':p.returncode},'permissions':{},'job_count':1,
 'expected_source_download_bytes':26196042,'maximum_api_metadata_bytes':8388608,
 'published':False,'hosted_run':'NOT_RUN','proof_run':'NOT_RUN','end_to_end':False}
(OUT/'WORKFLOW-REVIEW.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
