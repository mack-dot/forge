"""Dispatch the proposed existing-frontend patch; record actual tool results."""
from pathlib import Path
import hashlib,json,os,resource,subprocess,sys,time
ROOT=Path('/Users/mackianni/forge'); OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-dafny-frontend-20261104'; SRC=TC/'dafny-compat'
ENV=dict(os.environ,DOTNET_ROOT=str(TC/'sdk'),DOTNET_CLI_HOME=str(TC/'cli-home'),
         NUGET_PACKAGES=str(TC/'nuget-packages'),DOTNET_CLI_TELEMETRY_OPTOUT='1',
         DOTNET_NOLOGO='1',DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1',DOTNET_MULTILEVEL_LOOKUP='0')
ENV['PATH']=str(TC/'solver-bin')+os.pathsep+str(TC/'sdk')+os.pathsep+ENV['PATH']
action,label=sys.argv[1:3]; case=OUT/label;case.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=SRC/'Source/DafnyDriver/Commands/Bake.cs'
(case/'Bake.cs').write_bytes(source.read_bytes())
diff=subprocess.check_output(['git','diff','--','Source/DafnyDriver/Commands/Bake.cs'],cwd=SRC)
(case/'frontend.patch').write_bytes(diff)
if action=='build':
    argv=[str(TC/'sdk/dotnet'),'build','Source/DafnyDriver/DafnyDriver.csproj','--configuration','Release',
          '--no-self-contained','-m:2','-p:RestoreLockedMode=true']
elif action=='export':
    input_path=Path(sys.argv[3]).resolve()
    (case/'input.dfy').write_bytes(input_path.read_bytes())
    argv=[str(TC/'sdk/dotnet'),str(SRC/'Binaries/net8.0/DafnyDriver.dll'),'bake',str(case/'output.sexp'),str(input_path)]
else:raise SystemExit('Unknown action')
record={'argv':argv,'cwd':str(SRC),'source_sha256':sha(source),'patch_sha256':sha(case/'frontend.patch'),
        'environment_overrides':{k:ENV[k] for k in ['PATH','DOTNET_ROOT','DOTNET_CLI_HOME','NUGET_PACKAGES','DOTNET_CLI_TELEMETRY_OPTOUT','DOTNET_NOLOGO','DOTNET_SKIP_FIRST_TIME_EXPERIENCE','DOTNET_MULTILEVEL_LOOKUP']},
        'cpu_seconds_per_process':7200,'actual_exit':None,'end_to_end':False}
if action=='export':
    record['input_sha256']=sha(input_path)
    record['driver_sha256']=sha(SRC/'Binaries/net8.0/DafnyDriver.dll')
(case/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(7200,7200));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
start=time.monotonic()
with (case/'stdout.log').open('wb') as out,(case/'stderr.log').open('wb') as err:
    child=subprocess.run(argv,cwd=SRC,env=ENV,stdout=out,stderr=err,preexec_fn=limits)
record.update(actual_exit=child.returncode,wall_seconds=time.monotonic()-start)
if (case/'output.sexp').exists():record['output_sha256']=sha(case/'output.sexp')
(case/'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k not in ['environment_overrides','argv']}),flush=True)
raise SystemExit(child.returncode)
