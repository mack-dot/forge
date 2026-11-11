"""Prepare a separate proposal only. Do not execute or publish this workflow."""
from pathlib import Path
import ast,difflib,hashlib,json,subprocess,yaml
root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
old=root/'proposals/refund-executable-feasibility/hosted-cf-candidate-20261107/records/proposed-workflow.yml'
sha=lambda b:hashlib.sha256(b).hexdigest()
original=old.read_text();assert sha(original.encode())=='6db12f716e14a227b5de1b6d7f58da6ba3c020dc07bb87b413a225cedfea2b42'
assert original.count('INPUT_COMMIT_PENDING_APPROVAL')==1
bound=original.replace('INPUT_COMMIT_PENDING_APPROVAL','21c4bdf958627e6a24e8dee9a45d90568b3e3c20')
wf=yaml.load(bound,Loader=yaml.BaseLoader)
step=wf['jobs']['environment-and-unchanged-generic-candidate']['steps'][0]
old_shell=step['run'];head="/usr/bin/python3 -I -B - <<'PY'\n";tail='PY\n'
assert old_shell.startswith(head) and old_shell.endswith(tail)
source=old_shell[len(head):-len(tail)]
assert sha(source.encode())=='b859fe575016c8b88f77a9d105e6e54f4535d7b82fffe8173dfdb28223b94eaf'
insert='''class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,request,response,code,message,headers,new_url):
        raise ValueError('redirect refused before follow-up request')
'''
new=source.replace('def download(prefix,name,size,digest):',insert+'def download(prefix,name,size,digest):',1)
new=new.replace('urllib.request.urlopen(prefix+name,timeout=30)',
                'urllib.request.build_opener(NoRedirect()).open(prefix+name,timeout=30)',1)
assert new.replace(insert,'',1).replace('urllib.request.build_opener(NoRedirect()).open(prefix+name,timeout=30)',
                                      'urllib.request.urlopen(prefix+name,timeout=30)',1)==source
ast.parse(new)
indent=lambda s:''.join('          '+line+'\n' for line in s.splitlines())
assert bound.count(indent(source))==1
proposed=bound.replace(indent(source),indent(new),1)
parsed=yaml.load(proposed,Loader=yaml.BaseLoader)
job=parsed['jobs']['environment-and-unchanged-generic-candidate']
assert parsed['permissions']=={} and len(parsed['jobs'])==1 and job['runs-on']=='macos-15' and job['timeout-minutes']=='15'
assert job['steps'][0]['run']==head+new+tail
for name,text in [('bound-frozen-proof-workflow.yml',bound),('proposed-proof-workflow.yml',proposed),
                  ('proposed-proof-driver.py',new),('proposed-proof-shell.sh',head+new+tail)]:
 p=out/name;assert not p.exists();p.write_text(text)
(out/'proof-orchestration.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),proposed.splitlines(True),fromfile='U329/workflow.yml',tofile='proposed/workflow.yml')))
argv=['/bin/bash','--noprofile','--norc','-n',str(out/'proposed-proof-shell.sh')]
p=subprocess.run(argv,capture_output=True)
(out/'proof-shell.stdout.log').write_bytes(p.stdout);(out/'proof-shell.stderr.log').write_bytes(p.stderr)
assert p.returncode==0
r={'actual_exit':0,'frozen_template_sha256':sha(original.encode()),'bound_frozen_workflow_sha256':sha(bound.encode()),
 'proposed_workflow_sha256':sha(proposed.encode()),'proposed_workflow_bytes':len(proposed.encode()),
 'proposed_driver_sha256':sha(new.encode()),'shell_check':{'argv':argv,'actual_exit':p.returncode},
 'changes':['Bind the already published and verified addon commit.','Apply the same redirect refusal to transport only.'],
 'all_other_driver_code_identical':True,'theorem_or_input_changes':False,'published':False,'HOL_executed':False,
 'authorization':'NOT_GRANTED: current user explicitly excludes hosted HOL execution','end_to_end':False}
(out/'PROOF-PREPARATION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
