import importlib.metadata,json,hashlib
from pathlib import Path
from jsonschema import Draft202012Validator
pins=json.loads(Path('toolchain/validator-pins.json').read_text())
for name,expected in pins['packages'].items():
 d=importlib.metadata.distribution(name);assert d.version==expected['version']
 for name2,sha in expected['files'].items(): assert hashlib.sha256(d.locate_file(name2).read_bytes()).hexdigest()==sha
schema=json.loads(Path('schemas/policy.schema.json').read_text())
Draft202012Validator.check_schema(schema)
Draft202012Validator(schema).validate(json.loads(Path('proposals/refund/refund-policy.yaml').read_text()))
p=Path('results/stage8/proposal/policy-schema');p.mkdir()
(p/'report.json').write_text(json.dumps({'validator':'jsonschema','version':importlib.metadata.version('jsonschema'),'validator_pins_sha256':hashlib.sha256(Path('toolchain/validator-pins.json').read_bytes()).hexdigest(),'schema_sha256':hashlib.sha256(Path('schemas/policy.schema.json').read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(Path('proposals/refund/refund-policy.yaml').read_bytes()).hexdigest(),'result':'structurally_valid','proof_executed':False,'policy_accepted':False},indent=2,sort_keys=True)+'\n')
print('SCHEMA_VALID: candidate structure only; no policy acceptance or proof.')
