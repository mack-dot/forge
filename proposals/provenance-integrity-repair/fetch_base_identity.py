#!/usr/bin/env python3
"""Read-only base-image identity fetch for a PROPOSAL. Never a build or a pull.

Fetch the pinned image index, its pinned linux/amd64 manifest and that
manifest's config blob from the public registry. Every byte string is accepted
only when its SHA-256 equals the content digest that names it. The derived
rootfs diff IDs are proposed reference values; they do not establish that any
local image, layer or container is genuine.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

REPOSITORY = 'theorem-labs/oss-fuzz-theorems-checker'
INDEX = 'sha256:cc9ae43a9f4b0dd59d7c8d30727d36e039bfe72a2a9f9c4a99c68e413037e902'
PLATFORM_MANIFEST = 'sha256:1b7a1e562f37e418359b646d68d9e0b69b512fa8a03188b0c35fe1ca4b3f4be2'
ACCEPT = ', '.join(['application/vnd.oci.image.index.v1+json',
                    'application/vnd.docker.distribution.manifest.list.v2+json',
                    'application/vnd.oci.image.manifest.v1+json',
                    'application/vnd.docker.distribution.manifest.v2+json'])


def sha(data):
    return 'sha256:' + hashlib.sha256(data).hexdigest()


def get(url, headers, records, label):
    request = urllib.request.Request(url, headers={**headers, 'User-Agent': 'forge-stage9-proposal'})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
        status = response.status
    records.append({'label': label, 'url': url, 'http_status': status, 'bytes': len(data), 'sha256': sha(data)})
    if status != 200:
        raise SystemExit('HTTP_STATUS:' + label)
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    records = []
    token_bytes = get(f'https://ghcr.io/token?scope=repository:{REPOSITORY}:pull', {}, records, 'anonymous-token')
    # The anonymous pull token is a transport credential. It is not stored.
    token = json.loads(token_bytes)['token']
    records[-1]['stored'] = False
    auth = {'Authorization': 'Bearer ' + token, 'Accept': ACCEPT}
    base = f'https://ghcr.io/v2/{REPOSITORY}'
    index = get(f'{base}/manifests/{INDEX}', auth, records, 'index')
    if sha(index) != INDEX:
        raise SystemExit('INDEX_DIGEST')
    entries = [m for m in json.loads(index)['manifests'] if m['digest'] == PLATFORM_MANIFEST]
    if len(entries) != 1 or entries[0]['platform'].get('os') != 'linux' \
            or entries[0]['platform'].get('architecture') != 'amd64':
        raise SystemExit('PLATFORM_ENTRY')
    manifest = get(f'{base}/manifests/{PLATFORM_MANIFEST}', auth, records, 'platform-manifest')
    if sha(manifest) != PLATFORM_MANIFEST:
        raise SystemExit('PLATFORM_MANIFEST_DIGEST')
    config_digest = json.loads(manifest)['config']['digest']
    config = get(f'{base}/blobs/{config_digest}', {'Authorization': 'Bearer ' + token}, records, 'config')
    if sha(config) != config_digest:
        raise SystemExit('CONFIG_DIGEST')
    value = json.loads(config)
    if value['os'] != 'linux' or value['architecture'] != 'amd64' or value['rootfs']['type'] != 'layers':
        raise SystemExit('CONFIG_PLATFORM')
    for name, data in [('index.json', index), ('platform-manifest.json', manifest), ('config.json', config)]:
        (args.output / name).write_bytes(data)
    result = {'scope': 'proposed_base_reference_values_only', 'index': INDEX,
              'platform_manifest': PLATFORM_MANIFEST, 'config': config_digest,
              'rootfs_diff_ids': value['rootfs']['diff_ids'],
              'layer_count': len(value['rootfs']['diff_ids']),
              'manifest_layers': [layer['digest'] for layer in json.loads(manifest)['layers']],
              'requests': records, 'docker_pull': 'not_run', 'local_image_checked': False,
              'end_to_end': False}
    (args.output / 'result.json').write_text(json.dumps(result, sort_keys=True, indent=1) + '\n')
    print(json.dumps({'config': config_digest, 'layer_count': result['layer_count']}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
