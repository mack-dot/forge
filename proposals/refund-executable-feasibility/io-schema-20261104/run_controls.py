import json,subprocess,sys
from pathlib import Path
o=Path(__file__).resolve().parent
results=[]
for name in ['swapped-input','ignored-tail','nonnegative-coercion','swapped-output']:
 a=[sys.executable,'-B',str(o/'run.py'),name,str(o/('negative-'+name)/'forge_refund_ioScript.sml')]
 r=subprocess.run(a,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (o/(name+'-dispatch.log')).write_bytes(r.stdout)
 results.append({'name':name,'argv':a,'actual_exit':r.returncode,'expected_exit':1})
 print(name,r.returncode,flush=True)
a=[sys.executable,'-B',str(o/'run.py'),'repeat']
r=subprocess.run(a,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(o/'repeat-dispatch.log').write_bytes(r.stdout)
results.append({'name':'repeat','argv':a,'actual_exit':r.returncode,'expected_exit':0})
print('repeat',r.returncode,flush=True)
(o/'control-commands.json').write_text(json.dumps(results,indent=2)+'\n')
sys.exit(0 if all(x['actual_exit']==x['expected_exit'] for x in results) else 1)
