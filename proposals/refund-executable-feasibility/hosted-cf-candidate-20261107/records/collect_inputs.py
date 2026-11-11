"""Inventory published HOL .ui/.uo file references. Not a proof checker."""
from pathlib import Path
import hashlib,json,os,re,sys

ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
BASE=ROOT/'proposals/refund-executable-feasibility/hosted-macos-nosudo-20261107/INPUTS.json'
preloaded=set(json.loads((OUT/'PRELOADED-MODULES.json').read_text()))
meta=(OUT/'loader-metadata/stdout.log').read_text().splitlines()
paths=next(x.removeprefix('LOAD_PATH ') for x in meta if x.startswith('LOAD_PATH ')).split(',')
mapping={}
for line in meta:
    if line.startswith('PATH_MAPPING '):
        v,p=line.removeprefix('PATH_MAPPING ').split(' ',1);mapping[v]=p
assert mapping['HOLDIR']==str(TC/'HOL') and mapping['CAKEMLDIR']==str(TC/'cakeml')
base=json.loads(BASE.read_text());base_files={x['path']:x for x in base['files']}
old=json.loads((ROOT/'results/refund-read-event-gap-20261107/attempt-0001/fresh-import/command.json').read_text())['input_files']
files={};nodes={};absolute_references=[]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def expand(s):
    if s.startswith('$('):
        m=re.fullmatch(r'\$\(([^)]+)\)/(.*)',s);assert m and m[1] in mapping,s
        return str(Path(mapping[m[1]])/m[2])
    if s.startswith(str(ROOT)):absolute_references.append(s)
    return s
def physical(s):
    p=Path(s)
    if p.is_file():return p
    p=p.parent/'.hol/objs'/p.name
    if p.is_file():return p
    raise FileNotFoundError(s)
def add(path,role):
    p=Path(path);assert p.is_relative_to(ROOT),p
    resolved=p.resolve(strict=True);assert resolved.is_relative_to(ROOT),resolved
    rel=str(p.relative_to(ROOT));h=sha(p)
    if str(p) in old:assert old[str(p)]==h,p
    rec={'path':rel,'source':str(p),'resolved_source':str(resolved),'bytes':p.stat().st_size,
         'sha256':h,'mode':0o400,'roles':[role],'historical_U328_binding':str(p) in old}
    if rel in base_files:
        assert base_files[rel]['sha256']==h,rel
        rec['provided_by_base']=True
    if rel in files:
        if role not in files[rel]['roles']:files[rel]['roles'].append(role)
    else:files[rel]=rec
    return p
def locate_module(s):
    p=Path(s)
    candidates=[p] if p.is_absolute() else [Path(d)/p for d in paths]
    for p in candidates:
        try:physical(str(p)+'.uo');return p
        except FileNotFoundError:pass
    raise FileNotFoundError('module '+s)
def module(ref):
    s=expand(ref);name=Path(s).name
    if name in preloaded:
        nodes.setdefault(name,{'preloaded':True,'references':[]})['references'].append(ref)
        return
    if name in nodes:
        nodes[name]['references'].append(ref);return
    path=locate_module(s)
    nodes[name]={'preloaded':False,'references':[ref],'module_path':str(path),'files':[]}
    for ext in ['.ui','.uo']:
        p=add(physical(str(path)+ext),'loader-metadata');nodes[name]['files'].append(str(p))
        for line in p.read_text().splitlines():
            if not line:continue
            if Path(line).suffix in ['.sml','.sig']:
                src=add(physical(expand(line)),'module-source');nodes[name]['files'].append(str(src))
                if src.name.endswith('Theory.sml'):
                    add(src.with_suffix('.dat'),'theory-data')
            else:module(line)
try:
    module('basis_ffiTheory');module('cfLib')
    for parent,name in [(ROOT/'results/refund-native-audit-2026-11-04/attempt-0010/model-0007','forge_refundReadBoundary'),
                       (ROOT/'results/refund-stdin-domain-20261107/attempt-0001/model-0004','forge_refundStdinDomain')]:
        for ext in ['.sig','.sml','.dat']:add(parent/'.hol/objs'/(name+'Theory'+ext),'unchanged-local-parent')
    for p in json.loads((OUT/'HEAP-CHAIN.json').read_text()):add(p,'unchanged-saved-state')
    add(ROOT/'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml','unchanged-candidate')
    # Retain the inspected proof ancestry source/object identities as evidence.
    for p,h in json.loads((ROOT/'results/refund-read-event-gap-20261107/attempt-0001/dependency-snapshot.json').read_text())['parent_files'].items():
        assert sha(p)==h,p
        add(p,'cached-proof-ancestry')
    for p in [TC/'HOL/LICENSE',TC/'cakeml/LICENSE']:
        if p.is_file():add(p,'license')
except Exception as exc:
    (OUT/'collection-failure.json').write_text(json.dumps({'type':type(exc).__name__,'message':str(exc),
       'nodes':nodes,'files':list(files.values()),'end_to_end':False},indent=2)+'\n')
    raise
inventory={'files':sorted(files.values(),key=lambda x:x['path']),'module_nodes':nodes,
 'path_mappings':mapping,'original_load_path':paths,'absolute_module_references':absolute_references,
 'base_manifest_sha256':sha(BASE),'base_commit':'ac05eaf972b8c98784466ae063fca505aaaf25f4',
 'scope':'Static published-loader file closure and existing cached proof ancestry. Not proof execution or independent replay.',
 'end_to_end':False}
(OUT/'COLLECTED.json').write_text(json.dumps(inventory,indent=2)+'\n')
print(json.dumps({'actual_exit':0,'module_nodes':len(nodes),'files':len(files),
 'base_files_reused':sum(bool(r.get('provided_by_base')) for r in files.values()),
 'new_bytes':sum(r['bytes'] for r in files.values() if not r.get('provided_by_base')),
 'absolute_module_references':absolute_references,'end_to_end':False},indent=2))
