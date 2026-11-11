"""Read-only name-resolution diagnostics. No resolver,proxy or permission changes."""
from pathlib import Path
import hashlib,json,os,platform,socket,subprocess,sys
OUT=Path(__file__).resolve().parent
if len(sys.argv)>1:
    name=sys.argv[1]
    try:
        records=socket.getaddrinfo(name,443,type=socket.SOCK_STREAM)
        print(json.dumps({'name':name,'operation':'socket.getaddrinfo','success':True,
                          'result_count':len(records),'families':sorted({r[0] for r in records})}))
    except OSError as exc:
        print(json.dumps({'name':name,'operation':'socket.getaddrinfo','success':False,
                          'exception':type(exc).__name__,'errno':exc.errno,'message':str(exc)}));raise SystemExit(1)
    raise SystemExit(0)
sha=lambda b:hashlib.sha256(b).hexdigest()
cases=[('resolve-'+name,[sys.executable,'-B',str(Path(__file__).resolve()),name])
       for name in ['localhost','raw.githubusercontent.com','api.github.com','github.com']]
cases += [('system-dns',['/usr/sbin/scutil','--dns']),
          ('curl-dns',['/usr/bin/curl','--head','--silent','--show-error','--connect-timeout','5','--max-time','8',
          'https://raw.githubusercontent.com/mack-dot/forge/21c4bdf958627e6a24e8dee9a45d90568b3e3c20/proposals/m1-hosted-cf-inputs/INPUTS.json'])]
results=[]
for label,argv in cases:
    case=OUT/'dns'/label;case.mkdir(parents=True,exist_ok=False)
    with (case/'stdout.log').open('xb') as stdout,(case/'stderr.log').open('xb') as stderr:
        child=subprocess.Popen(argv,stdout=stdout,stderr=stderr)
        timeout=False
        try:child.wait(timeout=10)
        except subprocess.TimeoutExpired:timeout=True;child.kill();child.wait()
    rec={'case':label,'argv':argv,'actual_exit':child.returncode,'wall_timeout':timeout}
    for name in ['stdout','stderr']:
        b=(case/(name+'.log')).read_bytes();rec[name+'_sha256']=sha(b)
        if label!='system-dns':rec[name]=b.decode(errors='backslashreplace')
        else:rec[name+'_bytes']=len(b);rec['no_dns_configuration_message']=b'No DNS configuration available' in b
    (case/'command.json').write_text(json.dumps(rec,indent=2)+'\n');results.append(rec)
result={'actual_exit':0,'system':platform.system(),'release':platform.release(),'architecture':platform.machine(),
        'python':sys.version,'proxy_environment_variables_present':[x for x in ['HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'] if x in os.environ],
        'operations':results,'configuration_changed':False,'security_bypass':False,'end_to_end':False}
(OUT/'DNS-DIAGNOSTIC.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
