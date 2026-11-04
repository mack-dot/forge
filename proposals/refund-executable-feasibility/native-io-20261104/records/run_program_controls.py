import json,subprocess,sys
from pathlib import Path
o=Path(__file__).resolve().parent
results=[]
for name in ['program-flat-input','program-swapped-output','program-no-tail-check']:
 a=[sys.executable,'-B',str(o/'run_program.py'),name,str(o/('negative-'+name)/'forge_refundProgScript.sml')]
 r=subprocess.run(a,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (o/(name+'-dispatch.log')).write_bytes(r.stdout)
 results.append({'name':name,'argv':a,'actual_exit':r.returncode,'required_negative_exit':1})
 print(name,r.returncode,flush=True)
a=[sys.executable,'-B',str(o/'run_program.py'),'program-repeat']
r=subprocess.run(a,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(o/'program-repeat-dispatch.log').write_bytes(r.stdout)
results.append({'name':'program-repeat','argv':a,'actual_exit':r.returncode,'required_negative_exit':0})
print('program-repeat',r.returncode,flush=True)
code=0 if all(x['actual_exit']==x['required_negative_exit'] for x in results) else 1
(o/'program-control-commands.json').write_text(json.dumps({'actual_exit':code,'commands':results,'end_to_end':False,'scope':'Partial wrapper proofs; no native execution or whole-program assurance'},indent=2)+'\n')
sys.exit(code)
