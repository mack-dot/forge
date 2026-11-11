from pathlib import Path
import hashlib,json,os,resource,subprocess,sys
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
case=OUT/sys.argv[1];case.mkdir(exist_ok=False)
source=OUT/sys.argv[2]
argv=[str(TC/'HOL/bin/hol'),'run','--poly',str(source)]
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(60,60))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
record={'argv':argv,'cwd':str(ROOT),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'scope':'Public saved-state/path API only; no SAT,cfLib,proof or native execution.',
        'cpu_limit_seconds':60,'end_to_end':False}
(case/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
with (case/'stdout.log').open('wb') as stdout,(case/'stderr.log').open('wb') as stderr:
    p=subprocess.run(argv,cwd=ROOT,stdout=stdout,stderr=stderr,preexec_fn=limits)
record['actual_exit']=p.returncode
for name in ['stdout','stderr']:
    record[name+'_sha256']=hashlib.sha256((case/(name+'.log')).read_bytes()).hexdigest()
(case/'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
raise SystemExit(p.returncode)
