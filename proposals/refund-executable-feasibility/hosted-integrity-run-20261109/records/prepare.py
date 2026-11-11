from pathlib import Path
import ast,hashlib,json,subprocess,yaml
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
old=root/'proposals/refund-executable-feasibility/integrity-preflight-20261109/records'
sha=lambda b:hashlib.sha256(b).hexdigest()
source=(old/'integrity_driver.py').read_text()
assert sha(source.encode())=='867ef586d6d1a5ed8a5f9efa7efd71c9ed60fcef150ad655c5938d5307c62e72'
def change(before,after):
 global source
 assert source.count(before)==1,before
 source=source.replace(before,after,1)
change('class NoRedirect(','''def expect_rejection(name,action,reason):
    try:action()
    except ValueError as exc:
        require(str(exc)==reason,'wrong mutation rejection: '+name)
        emit('mutation_control',name=name,rejected=True,exception=type(exc).__name__,reason=str(exc),process_exit='NOT_APPLICABLE: in-process control')
    else:raise ValueError('mutation accepted: '+name)
class NoRedirect(''')
change("tree=verify_commit(c,json.loads(fetch(api+'commits/'+c['commit'],1048576)))", """commit_data=json.loads(fetch(api+'commits/'+c['commit'],1048576))
        tree=verify_commit(c,commit_data)
        if c['name']=='addon':
            changed=dict(c,commit='0'*40)
            expect_rejection('changed-commit',lambda:verify_commit(changed,commit_data),'commit identity mismatch')""")
change("m=verify_manifest(c,fetch(prefix+'INPUTS.json',c['manifest_bytes']),entries)", """manifest_raw=fetch(prefix+'INPUTS.json',c['manifest_bytes'])
        m=verify_manifest(c,manifest_raw,entries)
        if c['name']=='addon':
            changed=bytes([manifest_raw[0]^1])+manifest_raw[1:]
            expect_rejection('changed-manifest',lambda:verify_manifest(c,changed,entries),'size/SHA256 mismatch: INPUTS.json')""")
change("f.write(b);archive_hash.update(b);archive_bytes+=len(b)", """if c['name']=='addon' and archive_bytes==0:
                    changed=bytes([b[0]^1])+b[1:]
                    expect_rejection('changed-part',lambda:file_identity(part['name'],changed,part['bytes'],part['sha256'],entries),'size/SHA256 mismatch: '+part['name'])
                f.write(b);archive_hash.update(b);archive_bytes+=len(b)""")
change("try:main()\n    except Exception as exc:\n        emit('integrity_failure',exception=type(exc).__name__,message=str(exc),errno=getattr(exc,'errno',None))\n        traceback.print_exc();raise SystemExit(1)", """started=time.monotonic();exit_code=0
    try:main()
    except Exception as exc:
        exit_code=1
        emit('integrity_failure',exception=type(exc).__name__,message=str(exc),errno=getattr(exc,'errno',None))
        traceback.print_exc()
    finally:
        usage=resource.getrusage(resource.RUSAGE_SELF)
        emit('resource_usage',wall_seconds=time.monotonic()-started,user_cpu_seconds=usage.ru_utime,system_cpu_seconds=usage.ru_stime,max_rss_kib=usage.ru_maxrss,intended_exit=exit_code)
    raise SystemExit(exit_code)""")
ast.parse(source)
workflow=(old/'proposed-workflow.yml').read_text()
original=(old/'integrity_driver.py').read_text()
indent=lambda s:''.join('          '+line+'\n' for line in s.splitlines())
assert workflow.count(indent(original))==1
workflow=workflow.replace(indent(original),indent(source),1)
workflow=workflow.replace("          /usr/bin/python3 -I -B - <<'PY'", "          set +e\n          /usr/bin/python3 -I -B - <<'PY'",1)
workflow += '''          forge_integrity_exit=$?
          printf 'FORGE_INTEGRITY_EXIT=%s\\n' "$forge_integrity_exit"
          exit "$forge_integrity_exit"
'''
wf=yaml.load(workflow,Loader=yaml.BaseLoader)
assert wf['permissions']=={} and len(wf['jobs'])==1
job=wf['jobs']['integrity-only'];assert job['runs-on']=='ubuntu-24.04' and job['timeout-minutes']=='5'
assert len(job['steps'])==1 and set(job['steps'][0])=={'name','shell','run'}
step=job['steps'][0];assert step['shell']=='bash --noprofile --norc -euo pipefail {0}'
for marker in ['sudo','secrets.','GITHUB_TOKEN','actions/checkout','pip install','apt-get','Holmake','workflow_dispatch']:
 assert marker not in workflow,marker
assert 'NoRedirect()' in source
for name,data in [('integrity_driver.py',source),('proposed-workflow.yml',workflow),('proposed-shell.sh',step['run'])]:
 p=out/name;assert not p.exists();p.write_text(data)
argv=['/bin/bash','--noprofile','--norc','-n',str(out/'proposed-shell.sh')]
p=subprocess.run(argv,capture_output=True)
(out/'shell.stdout.log').write_bytes(p.stdout);(out/'shell.stderr.log').write_bytes(p.stderr)
assert p.returncode==0
r={'actual_exit':0,'workflow_bytes':len(workflow.encode()),'workflow_sha256':sha(workflow.encode()),
 'workflow_git_blob':hashlib.sha1(b'blob '+str(len(workflow.encode())).encode()+b'\0'+workflow.encode()).hexdigest(),
 'driver_sha256':sha(source.encode()),'shell_check':{'argv':argv,'actual_exit':p.returncode},
 'job_count':1,'timeout_minutes':5,'permissions':{},'new_proof_inputs':0,
 'source_commits':['21c4bdf958627e6a24e8dee9a45d90568b3e3c20','ac05eaf972b8c98784466ae063fca505aaaf25f4'],
 'authorization':'Current owner explicitly authorizes one integrity job within these limits and requests mutation controls. Use the reviewed redirect correction; add only the requested controls and exit/resource records.',
 'proof_execution':False,'end_to_end':False}
(out/'PREPARATION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
