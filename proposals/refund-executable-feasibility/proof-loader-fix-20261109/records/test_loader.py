"""Bounded real-loader regression; no candidate proof or theory-source execution."""
from pathlib import Path
import hashlib,json,os,resource,subprocess,time

root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent
tc=root/'.toolchain/experiments/refund-cakeml-20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
inventories={}
for kind in ['base','addon']:
 m=read(root/'proposals/refund-executable-feasibility/integrity-preflight-20261108/records'/('remote-'+kind+'-manifest.json'))
 inventories.update({f['path']:f for f in m['files']})
toolpaths=[tc/'HOL/bin/hol']+[tc/p for p in ['HOL/bin/hol.state0','HOL/src/num/termination/numheap','HOL/bin/hol.state','cakeml/misc/cakeml-heap']]
parents=[root/d/'.hol/objs'/(n+'Theory'+ext) for d,n in [('results/refund-native-audit-2026-11-04/attempt-0010/model-0007','forge_refundReadBoundary'),('results/refund-stdin-domain-20261107/attempt-0001/model-0004','forge_refundStdinDomain')] for ext in ['.sig','.sml']]
identities={}
for p in toolpaths+parents:
 rel=str(p.relative_to(root));b=p.read_bytes();r=inventories[rel]
 assert len(b)==r['bytes'] and sha(b)==r['sha256'],rel
 identities[rel]=sha(b)
write(out/'REGRESSION-INPUTS.json',identities)
argv=[str(tc/'HOL/bin/hol'),'--maxheap','1536','run','--poly',str(out/'loader-path-regression.sml')]
def limits():
 resource.setrlimit(resource.RLIMIT_CPU,(30,30));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
 resource.setrlimit(resource.RLIMIT_FSIZE,(4*1024*1024,4*1024*1024))
results=[]
for mode,expected_exit in [('old',1),('fixed',0)]:
 case=out/('loader-v2-'+mode);case.mkdir(exist_ok=False)
 env=dict(os.environ,FORGE_LOADER_PATH_MODE=mode,HOLDIR=str(tc/'HOL'),CAKEMLDIR=str(tc/'cakeml'))
 env['DYLD_LIBRARY_PATH']=str(tc/'poly-install/lib')+':'+str(tc/'transport/lib')
 started=time.monotonic()
 with (case/'stdout.log').open('wb') as stdout,(case/'stderr.log').open('wb') as stderr:
  child=subprocess.Popen(argv,cwd=root,env=env,stdout=stdout,stderr=stderr,preexec_fn=limits)
  timed_out=False
  try:child.wait(timeout=45)
  except subprocess.TimeoutExpired:timed_out=True;child.kill();child.wait()
 elapsed=time.monotonic()-started
 stdout=(case/'stdout.log').read_text();stderr=(case/'stderr.log').read_text()
 record={'argv':argv,'mode':mode,'actual_exit':child.returncode,'expected_exit':expected_exit,'timed_out':timed_out,
  'wall_seconds':elapsed,'cpu_limit_seconds':30,'wall_limit_seconds':45,
  'source_sha256':sha((out/'loader-path-regression.sml').read_bytes()),
  'stdout_sha256':sha((case/'stdout.log').read_bytes()),'stderr_sha256':sha((case/'stderr.log').read_bytes()),
  'scope':'Pinned HOLFileSys path resolution and file-byte reads only; no QUse theory execution,cfLib,SAT or theorem attempt',
  'end_to_end':False}
 write(case/'command.json',record);results.append(record)
 assert not timed_out and child.returncode==expected_exit,record
 if mode=='old':
  assert 'SOME ENOENT' in stderr and '.hol/objs/.hol/objs/forge_refundReadBoundaryTheory.sig' in stderr
  assert 'LOADER_PATH_REGRESSION_COMPLETE' not in stdout
 else:
  assert stdout.count('PARENT_BYTES_MATCH ')==4 and stdout.count('FUTURE_IMPORT_PATH_MATCH ')==2
  assert stdout.count('LOADER_PATH_REGRESSION_COMPLETE')==1
for rel,h in identities.items():assert sha((root/rel).read_bytes())==h,rel
write(out/'REGRESSION.json',{'results':results,'old_path_reproduces_exact_ENOENT':True,'fixed_parent_files_read':4,'future_import_paths_resolved':2,
 'inputs_unchanged':True,'theorem_execution':False,'hosted_execution':False,'end_to_end':False})
print(json.dumps({'actual_child_exits':[r['actual_exit'] for r in results],'old_ENOENT_reproduced':True,'fixed_parent_files_read':4,'future_import_paths_resolved':2,'theorem_execution':False,'end_to_end':False}))
