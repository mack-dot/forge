import json,sys
j=None
for l in open(sys.argv[1]):
  if l.startswith('{'): j=json.loads(l)
if j is None: print('NO JSON LINE')
else: print(f"violated={j['violated']} done={j['sequencesDone']} childGone={(j['childGone'] or '-')[:60]} P5-SILENT={j['sequencesWithViolation'].get('P5-SILENT',0)} startRefusals={j['sinkErrors']}")
