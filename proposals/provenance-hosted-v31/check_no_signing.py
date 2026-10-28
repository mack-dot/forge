"""Prove from a workflow file alone that it cannot sign, release or deploy.

Rules: manual trigger only; contents: read is the only permission anywhere;
no id-token, secrets or Sigstore; only allowlisted pinned actions; no signing
or dispatch commands; and a first step that fails if an OIDC request URL exists.
Exit 0 when every rule holds, 1 with the violations otherwise.
"""
import sys
import yaml

ALLOWED_ACTIONS = {
    'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683',
    'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
}
FORBIDDEN_TEXT = ('id-token', 'secrets.', 'sigstore', 'cosign', 'attest', '--action sign',
                  '--action negative-sign', 'gh workflow', 'gh release', 'provenance.yml', 'deploy')


def violations(path):
    raw = open(path).read()
    data = yaml.safe_load(raw)
    found = []
    triggers = data.get('on', data.get(True))
    if (list(triggers) if isinstance(triggers, dict) else triggers) != ['workflow_dispatch']:
        found.append('trigger is not workflow_dispatch only')
    if data.get('permissions') != {'contents': 'read'}:
        found.append('top-level permissions are not exactly contents: read')
    for word in FORBIDDEN_TEXT:
        if word in raw:
            found.append('forbidden text: ' + word)
    for name, job in data['jobs'].items():
        if 'permissions' in job:
            found.append(name + ': job-level permissions')
        steps = job.get('steps', [])
        first = steps[0].get('run', '') if steps else ''
        if 'ACTIONS_ID_TOKEN_REQUEST_URL' not in first or not first.startswith('test -z'):
            found.append(name + ': first step does not assert that no OIDC token is available')
        for step in steps:
            uses = step.get('uses')
            if uses and uses.split(' ')[0] not in ALLOWED_ACTIONS:
                found.append(name + ': action not allowlisted: ' + uses)
    return found


def main():
    status = 0
    for path in sys.argv[1:]:
        found = violations(path)
        print(path + ': ' + ('NO_SIGNING_PATH' if not found else 'VIOLATIONS ' + '; '.join(found)))
        status |= bool(found)
    return status


if __name__ == '__main__':
    sys.exit(main())
