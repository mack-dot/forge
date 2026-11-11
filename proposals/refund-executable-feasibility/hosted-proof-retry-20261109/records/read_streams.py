"""Read hosted evidence as data; never execute transferred sources or artifacts."""
from pathlib import Path, PurePosixPath
from collections import Counter
import base64, hashlib, json, re, zlib

out=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
response=json.loads((out/'remote-logs.json').read_text())
assert not response.get('isError')
log=response['structuredContent']['content'].encode()
(out/'hosted-job.log').write_bytes(log)
rows=[]
for line in log.decode().splitlines():
    m=re.match(r'^\ufeff?(\d{4}-\d\d-\d\dT\S+) (.*)$',line)
    if m and m[2].startswith('{'):
        event=json.loads(m[2])
        if 'operation' in event:rows.append({'provider_log_time':m[1],'record':event})
events=[r['record'] for r in rows]
assert all(e['end_to_end'] is False for e in events)
headers={}; chunks={}; artifacts=[]
for e in events:
    if e['operation'] not in ('file','file_chunk'):continue
    key=(e['case'],e['file'])
    if e['operation']=='file':
        assert key not in headers
        assert e['encoding']=='base64+zlib' and 0<=e['bytes']<=4*1024*1024
        headers[key]=e;chunks[key]={}
    else:
        assert key in headers and e['index'] not in chunks[key]
        assert 0<=e['index']<headers[key]['chunks']
        chunks[key][e['index']]=e['data']
for key,header in headers.items():
    case,name=key
    assert case in ['proof','repeat','import','wrong-exception','omitted-event']
    rel=PurePosixPath(name)
    assert not rel.is_absolute() and '..' not in rel.parts
    assert set(chunks[key])==set(range(header['chunks']))
    encoded=''.join(chunks[key][i] for i in range(header['chunks']))
    compressed=base64.b64decode(encoded,validate=True)
    d=zlib.decompressobj();data=d.decompress(compressed,header['bytes']+1)
    assert d.eof and not d.unused_data and not d.unconsumed_tail
    assert len(data)==header['bytes'] and sha(data)==header['sha256']
    target=out/'decoded'/case/name
    target.parent.mkdir(parents=True,exist_ok=True)
    assert not target.exists()
    target.write_bytes(data)
    artifacts.append({'case':case,'file':name,'bytes':len(data),'sha256':sha(data)})
counts=dict(Counter(e['operation'] for e in events))
result={'log_bytes':len(log),'log_sha256':sha(log),'event_counts':counts,'artifacts':artifacts,
        'child_results':[e for e in events if e['operation']=='child_result'],
        'driver_failures':[e for e in events if e['operation']=='driver_failure'],
        'run_complete':[e for e in events if e['operation']=='run_complete'],
        'end_to_end':False}
(out/'events.json').write_text(json.dumps(rows,indent=2)+'\n')
(out/'STREAM-READBACK.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['log_bytes','log_sha256','event_counts','child_results','driver_failures','run_complete']}))
