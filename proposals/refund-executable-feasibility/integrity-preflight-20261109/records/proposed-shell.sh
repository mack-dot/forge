/usr/bin/python3 -I -B - <<'PY'
"""Frozen-byte integrity only. Never imports or executes transferred code."""
from pathlib import Path,PurePosixPath
from datetime import datetime
import hashlib,io,json,os,platform,resource,signal,sys,tarfile,tempfile,time,traceback,urllib.request

REPO='mack-dot/forge'
CONFIGS=[
 {'name':'addon','folder':'m1-hosted-cf-inputs','commit':'21c4bdf958627e6a24e8dee9a45d90568b3e3c20',
  'commit_sha256':'947a3fa64f0ff0908989a01f1388f44f407e79642ea18d7462564e5e89f1babc',
  'manifest_bytes':932639,'manifest_sha256':'6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105','files':1475},
 {'name':'base','folder':'m1-hosted-sat-inputs','commit':'ac05eaf972b8c98784466ae063fca505aaaf25f4',
  'commit_sha256':'322245d0c39534c9be74f5dfa2ace4be2d856c1404ddc351f2087ab876d5e584',
  'manifest_bytes':8435,'manifest_sha256':'6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7','files':18}]
CANDIDATE='results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
IMPORT='results/hosted-cf-preparation-20261107/attempt-0001/prepared-inputs/import.sml'
CANDIDATE_SHA='7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
    if not ok:raise ValueError(why)
def emit(operation,**data):print(json.dumps(dict(operation=operation,end_to_end=False,**data),sort_keys=True),flush=True)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,request,response,code,message,headers,new_url):
        raise ValueError('redirect refused before follow-up request')
def git_hash(kind,data):return hashlib.sha1(kind.encode()+b' '+str(len(data)).encode()+b'\0'+data).hexdigest()
def verify_commit(c,d):
    lines=['tree '+d['tree']['sha']]+['parent '+p['sha'] for p in d['parents']]
    for role in ['author','committer']:
        who=d[role];stamp=int(datetime.fromisoformat(who['date'].replace('Z','+00:00')).timestamp())
        lines.append(role+' '+who['name']+' <'+who['email']+'> '+str(stamp)+' -0500')
    raw=('\n'.join(lines)+'\n\n'+d['message']).encode()
    require(d['sha']==c['commit'] and git_hash('commit',raw)==c['commit'] and sha(raw)==c['commit_sha256'],'commit identity mismatch')
    require(d['verification']['reason']=='unsigned','unexpected commit signature representation')
    emit('commit_checked',package=c['name'],commit=c['commit'],raw_sha256=sha(raw),tree=d['tree']['sha'])
    return d['tree']['sha']
def verify_tree(expected,d):
    require(d['sha']==expected and not d.get('truncated',True),'incomplete or wrong tree')
    rows=d['tree'];require(len({x['path'] for x in rows})==len(rows),'duplicate tree path')
    body=b''
    for x in sorted(rows,key=lambda x:(x['path']+('/' if x['type']=='tree' else '')).encode()):
        require('/' not in x['path'] and '\0' not in x['path'],'invalid tree path')
        body+=(x['mode'].lstrip('0')+' '+x['path']).encode()+b'\0'+bytes.fromhex(x['sha'])
    require(git_hash('tree',body)==expected,'tree identity mismatch')
    return {x['path']:x for x in rows}
def file_identity(name,data,size,digest,entries):
    require(len(data)==size and sha(data)==digest,'size/SHA256 mismatch: '+name)
    e=entries[name]
    require(e['type']=='blob' and e['mode']=='100644' and e['size']==size and git_hash('blob',data)==e['sha'],'committed blob mismatch: '+name)
    emit('file_checked',file=name,bytes=size,sha256=digest,git_blob=e['sha'])
def verify_manifest(c,raw,entries):
    file_identity('INPUTS.json',raw,c['manifest_bytes'],c['manifest_sha256'],entries)
    m=json.loads(raw);require(len(m['files'])==c['files'],'wrong member count')
    names=['INPUTS.json']+[x['name'] for x in m['parts']]
    require(set(entries)==set(names) and len(names)==len(set(names)),'unexpected package files')
    return m
def verify_archive(c,m,path):
    expected={x['path']:x for x in m['files']};require(len(expected)==c['files'],'duplicate inventory path')
    seen=set();special={};total=0
    with tarfile.open(path,mode='r|xz') as tar:
        for member in tar:
            name=member.name;p=PurePosixPath(name)
            require(member.isfile() and not p.is_absolute() and '..' not in p.parts,'non-regular or unsafe archive member')
            require(name in expected and name not in seen,'unexpected/duplicate archive member')
            r=expected[name];require(member.size==r['bytes'] and member.mode==r['mode'],'member size/mode mismatch')
            digest=hashlib.sha256();length=0;kept=[]
            with tar.extractfile(member) as f:
                while True:
                    b=f.read(65536)
                    if not b:break
                    length+=len(b);digest.update(b)
                    if name in (CANDIDATE,IMPORT):kept.append(b)
            require(length==r['bytes'] and digest.hexdigest()==r['sha256'],'member digest mismatch: '+name)
            seen.add(name);total+=length
            if kept:special[name]=b''.join(kept)
            emit('member_checked',package=c['name'],path=name,sha256=digest.hexdigest())
    require(seen==set(expected),'missing archive member')
    emit('archive_checked',package=c['name'],members=len(seen),raw_file_bytes=total)
    return seen,special
def verify_statements(special):
    candidate=special[CANDIDATE];check=special[IMPORT]
    require(sha(candidate)==CANDIDATE_SHA,'candidate source changed')
    term=candidate.split(b'store_thm ("read_error_generic", ``',1)[1].split(b'``,',1)[0]
    expected=check.split(b'val expected = ``',1)[1].split(b'``;',1)[0]
    require(term==expected,'candidate/import statement mismatch')
    emit('statement_bytes_checked',candidate_sha256=sha(candidate),quotation_sha256=sha(term),quotation_bytes=len(term),proof_result='NOT_RUN')
def run_integrity(fetch,work):
    all_seen=set();all_special={}
    for c in CONFIGS:
        api='https://api.github.com/repos/'+REPO+'/git/'
        tree=verify_commit(c,json.loads(fetch(api+'commits/'+c['commit'],1048576)))
        for directory in ['proposals',c['folder']]:
            entries=verify_tree(tree,json.loads(fetch(api+'trees/'+tree,1048576)))
            require(entries[directory]['type']=='tree','expected directory missing');tree=entries[directory]['sha']
        entries=verify_tree(tree,json.loads(fetch(api+'trees/'+tree,1048576)))
        prefix='https://raw.githubusercontent.com/'+REPO+'/'+c['commit']+'/proposals/'+c['folder']+'/'
        m=verify_manifest(c,fetch(prefix+'INPUTS.json',c['manifest_bytes']),entries)
        archive=work/(c['name']+'.tar.xz');archive_hash=hashlib.sha256();archive_bytes=0
        with archive.open('xb') as f:
            for part in m['parts']:
                require('/' not in part['name'] and part['name'] not in ('.','..'),'invalid part name')
                b=fetch(prefix+part['name'],part['bytes']);file_identity(part['name'],b,part['bytes'],part['sha256'],entries)
                f.write(b);archive_hash.update(b);archive_bytes+=len(b)
        require(archive_bytes==m['archive_bytes'] and archive_hash.hexdigest()==m['archive_sha256'],'archive identity mismatch')
        seen,special=verify_archive(c,m,archive)
        require(not all_seen&seen,'overlapping base/addon paths');all_seen|=seen;all_special.update(special)
    require(len(all_seen)==1493,'combined member count mismatch');verify_statements(all_special)
    emit('integrity_complete',files=1493,addon_files=1475,base_files=18,proof_executed=False,transferred_code_executed=False)
def main():
    require(platform.system()=='Linux' and os.environ.get('RUNNER_OS')=='Linux','unexpected runner OS')
    require(os.environ.get('ImageOS')=='ubuntu24' and os.geteuid()!=0,'unexpected runner image/uid')
    resource.setrlimit(resource.RLIMIT_CPU,(90,90));resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
    resource.setrlimit(resource.RLIMIT_FSIZE,(32*1024**2,32*1024**2));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    def deadline(signum,frame):raise TimeoutError('integrity preflight wall limit180 seconds')
    signal.signal(signal.SIGALRM,deadline);signal.alarm(180)
    emit('identity',os=platform.system(),architecture=platform.machine(),release=platform.release(),uid=os.geteuid(),
         image_os=os.environ.get('ImageOS'),image_version=os.environ.get('ImageVersion'),python=sys.version,
         python_sha256=sha(Path(sys.executable).read_bytes()),run_id=os.environ.get('GITHUB_RUN_ID'),workflow_sha=os.environ.get('GITHUB_SHA'),
         cpu_seconds=90,wall_seconds=180,address_space_bytes=1024**3,file_bytes=32*1024**2,
         trust='GitHub runner/control plane,Python/hash/TLS implementation and OS; integrity check only')
    root=Path(tempfile.mkdtemp(prefix='forge-m1-integrity-',dir=os.environ['RUNNER_TEMP']));root.chmod(0o700)
    require(root.stat().st_uid==os.geteuid() and root.stat().st_mode&0o777==0o700,'private directory check failed')
    def fetch(url,limit):
        require(url.startswith('https://api.github.com/repos/'+REPO+'/git/') or url.startswith('https://raw.githubusercontent.com/'+REPO+'/'),'unapproved URL')
        headers={'User-Agent':'Forge-M1-integrity-preflight'}
        if url.startswith('https://api.github.com/'):headers['Accept']='application/vnd.github+json'
        request=urllib.request.Request(url,headers=headers)
        opener=urllib.request.build_opener(NoRedirect())
        with opener.open(request,timeout=15) as response:
            require(response.geturl()==url,'unexpected redirect');data=response.read(limit+1)
        require(len(data)<=limit,'download exceeds declared bound')
        emit('download',url=url,bytes=len(data),sha256=sha(data));return data
    run_integrity(fetch,root);signal.alarm(0)
if __name__=='__main__':
    try:main()
    except Exception as exc:
        emit('integrity_failure',exception=type(exc).__name__,message=str(exc),errno=getattr(exc,'errno',None))
        traceback.print_exc();raise SystemExit(1)
PY
