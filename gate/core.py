"""Backend-independent schema, identity, and method-policy checks.

These checks do not establish program correctness or authenticate supplied evidence.
The CLI also requires a fresh backend run before accepting an imported bundle.
"""

from jsonschema import Draft202012Validator
import yaml

from common import ROOT, Rejected, digest, pin_file, read_json, relative


def validate_schema(bundle):
    schema = read_json(ROOT / 'schemas/evidence.schema.json')
    Draft202012Validator.check_schema(schema)
    errors = sorted(Draft202012Validator(schema).iter_errors(bundle),
                    key=lambda error: (str(list(error.absolute_path)), error.message))
    if errors:
        error = errors[0]
        path = '/'.join(str(part) for part in error.absolute_path) or '/'
        raise Rejected('SCHEMA_REJECTED: ' + path + ': ' + error.message)


def load_policy(tier):
    path = ROOT / 'policy/tiers.yaml'
    policy = yaml.safe_load(path.read_text())
    schema = read_json(ROOT / 'schemas/policy.schema.json')
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(policy)
    if tier not in policy['tiers']:
        raise Rejected('POLICY_TIER: unknown code tier ' + tier)
    for name, rules in policy['tiers'].items():
        for claim, requirement in rules['required_claims'].items():
            if requirement['minimum_method'] not in requirement['allowed_methods']:
                raise RuntimeError('POLICY_ERROR: minimum method absent from allowed methods: '
                                   + name + '/' + claim)
    identity = {'id': policy['id'], 'version': policy['version'], 'tier': tier,
                'sha256': digest(path.read_bytes())}
    return policy['tiers'][tier], identity


def framework_paths():
    # Explicit trusted input list. No evidence field selects executable code.
    return [ROOT / path for path in (
        'gate/gate.py', 'gate/common.py', 'gate/core.py', 'gate/dependencies.py',
        'gate/backends/__init__.py', 'schemas/evidence.schema.json',
        'schemas/policy.schema.json', 'policy/tiers.yaml',
        pin_file('validator'), 'toolchain/requirements-stage2.txt',
    )]


def snapshot(paths):
    return {relative(path): digest(path.read_bytes())
            for path in sorted(set(paths))}


def validate_evidence(bundle, expected, rules, policy_identity, trusted, backend):
    validate_schema(bundle)
    if bundle['format_version'] != 2:
        raise Rejected('LEGACY_BUNDLE: Stage 1 structure is valid; rerun to obtain policy-bound evidence')
    if bundle['artifact'] != expected['artifact']:
        raise Rejected('ARTIFACT_MISMATCH: artifact differs from the current backend input bytes')
    if bundle.get('source_manifest') != expected.get('source_manifest'):
        raise Rejected('ARTIFACT_MISMATCH: source manifest differs from current backend inputs')
    for record in bundle['evidence']:
        if record['artifact_sha'] != expected['artifact']['sha256']:
            raise Rejected('ARTIFACT_MISMATCH: ' + record['claim_id'] + ' evidence names another artifact')
    if bundle['end_to_end']:
        raise Rejected('COVERAGE_SCOPE: end-to-end coverage is not established by this gate')
    if bundle['backend'] != backend:
        raise Rejected('BACKEND_BINDING: evidence names a different selected backend')
    if bundle['policy'] != policy_identity:
        raise Rejected('POLICY_BINDING: policy id, version, tier, or digest differs')
    if bundle['trusted_input_sha256'] != trusted:
        raise Rejected('TRUSTED_INPUTS: trusted input set or digests differ')
    claims = {claim['id']: claim for claim in bundle['claims']}
    required_context = {claim['id']: claim for claim in expected['claims']}
    if len(claims) != len(bundle['claims']) or claims != required_context:
        raise Rejected('CLAIM_BINDING: duplicate, missing, changed, or unknown claim/spec binding')
    if rules['artifact_kind'] != bundle['artifact']['kind']:
        raise Rejected('ARTIFACT_KIND: policy does not cover this artifact kind')
    for record in bundle['evidence']:
        if record['claim_id'] not in claims:
            raise Rejected('CLAIM_BINDING: evidence names an unknown claim')
    for claim, requirement in rules['required_claims'].items():
        if claim not in claims:
            raise Rejected('MISSING_CLAIM: ' + claim)
        matching = [record for record in bundle['evidence']
                    if record['claim_id'] == claim and record['result'] == 'passed']
        if not matching:
            raise Rejected('MISSING_EVIDENCE: no passing evidence for ' + claim)
        if not any(record['method'] in requirement['allowed_methods'] for record in matching):
            raise Rejected('METHOD_POLICY: ' + claim + ' requires '
                           + ','.join(requirement['allowed_methods']) + '; observed '
                           + ','.join(sorted({record['method'] for record in matching})))


def make_bundle(raw, backend, policy, trusted, versions, reproduce_cmd):
    evidence = []
    for record in raw['evidence']:
        updated = dict(record)
        updated['trusted_base'] = record['trusted_base'] + [
            'Forge schema and method-policy gate with policy ' + policy['version'],
            'Python validator packages: ' + ', '.join(
                name + ' ' + versions[name] for name in sorted(versions)),
            'Preinstalled validator package archives were not independently authenticated.',
        ]
        updated['reproduce_cmd'] = reproduce_cmd
        evidence.append(updated)
    bundle = {
        'format_version': 2, 'schema_version': '2.0.0', 'end_to_end': False,
        'backend': backend, 'policy': policy,
        'artifact': raw['artifact'], 'claims': raw['claims'], 'evidence': evidence,
        'trusted_input_sha256': trusted,
        'backend_details': raw['backend_details'],
    }
    if 'source_manifest' in raw:
        bundle['source_manifest'] = raw['source_manifest']
    return bundle
