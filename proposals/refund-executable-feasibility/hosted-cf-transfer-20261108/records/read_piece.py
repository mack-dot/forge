"""Read only the four owner-approved payload files for GitHub API transport."""
from pathlib import Path
import base64,hashlib,json,sys
ROOT=Path('/Users/mackianni/forge')
PACKET=ROOT/'proposals/refund-executable-feasibility/hosted-cf-candidate-20261107'
OUT=Path(__file__).resolve().parent
names=['INPUTS.json','inputs.part-000','inputs.part-001','inputs.part-002']
sha=lambda b:hashlib.sha256(b).hexdigest()
if len(sys.argv)==1:
    files=[]
    m=json.loads((PACKET/'payload/INPUTS.json').read_text())
    assert sha((PACKET/'payload/INPUTS.json').read_bytes())=='6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105'
    for name in names:
        data=(PACKET/'payload'/name).read_bytes()
        if name!='INPUTS.json':
            r=next(x for x in m['parts'] if x['name']==name)
            assert len(data)==r['bytes'] and sha(data)==r['sha256']
        files.append({'name':name,'bytes':len(data),'sha256':sha(data),
          'git_blob_sha':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()})
    approval=(PACKET/'APPROVAL.md').read_bytes()
    result={'user_authorization':'go ahead and try it','authorized_scope':str(PACKET/'APPROVAL.md'),
      'approval_document_sha256':sha(approval),'maximum_hosted_runs':1,'files':files,
      'remote_branch_before':'8ad9de1e538edd48a2084796510e784913eaef8b',
      'template_sha256':'6db12f716e14a227b5de1b6d7f58da6ba3c020dc07bb87b413a225cedfea2b42',
      'end_to_end':False}
    (OUT/'AUTHORIZED-INPUTS.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
else:
    index,offset,count=map(int,sys.argv[1:]);assert index in range(4) and offset>=0 and 0<count<=1048576
    with (PACKET/'payload'/names[index]).open('rb') as f:f.seek(offset);data=f.read(count)
    print(json.dumps({'bytes':len(data),'offset':offset,'data_base64':base64.b64encode(data).decode()}))
