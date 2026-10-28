"""Record the real `docker image save` layout of one local image.

Read-only for the image store. The archive is streamed; it is not stored.
Writes timestamp-free JSON records. Exit 0 means the observation completed;
it does not mean the layout satisfies the gate.
"""
import argparse
import io
import hashlib
import json
import subprocess
import sys
import tarfile
import zlib
from pathlib import Path

ZSTD_MAGIC = b'\x28\xb5\x2f\xfd'


def dump(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def run(command, out, name):
    result = subprocess.run(command, capture_output=True)
    (out / (name + '.stdout')).write_bytes(result.stdout)
    (out / (name + '.stderr')).write_bytes(result.stderr)
    return {'name': name, 'argv': command, 'exit_code': result.returncode}, result.stdout


def gunzip_sha(stream):
    inflater = zlib.decompressobj(16 + zlib.MAX_WBITS)
    h = hashlib.sha256()
    while True:
        chunk = stream.read(1 << 20)
        if not chunk:
            break
        h.update(inflater.decompress(chunk))
    h.update(inflater.flush())
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    out = Path(args.output)
    out.mkdir(parents=True)
    commands = []
    record, data = run(['docker', 'info', '--format', '{{json .DriverStatus}} {{.Driver}} {{.ServerVersion}}'],
                       out, 'docker-info')
    commands.append(record)
    record, data = run(['docker', 'image', 'inspect', args.image], out, 'image-inspect')
    commands.append(record)
    info = json.loads(data)[0]

    # Hash each member while streaming. Keep only small JSON metadata files.
    argv = ['docker', 'image', 'save', args.image]
    process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    members, kept = {}, {}
    with tarfile.open(fileobj=process.stdout, mode='r|') as tar:
        for member in tar:
            entry = {'type': member.type.decode(), 'size': member.size}
            if member.isfile():
                raw = tar.extractfile(member).read()
                entry['sha256'] = hashlib.sha256(raw).hexdigest()
                entry['magic'] = ('gzip' if raw[:2] == b'\x1f\x8b' else 'zstd' if raw[:4] == ZSTD_MAGIC
                                  else 'tar' if raw[257:262] == b'ustar' else 'json' if raw[:1] in b'{[' else 'other')
                if entry['magic'] == 'gzip':
                    entry['gunzip_sha256'] = gunzip_sha(io.BytesIO(raw))
                elif entry['magic'] == 'tar':
                    entry['gunzip_sha256'] = None
                if member.size < 1 << 20 and entry['magic'] == 'json':
                    kept[member.name] = raw
            members[member.name] = entry
    stderr = process.stderr.read()
    code = process.wait()
    (out / 'image-save.stderr').write_bytes(stderr)
    commands.append({'name': 'image-save', 'argv': argv, 'exit_code': code, 'stdout': 'streamed; not stored'})
    for name, raw in kept.items():
        target = out / 'kept' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    dump(out / 'members.json', members)
    dump(out / 'commands.json', commands)

    manifest = json.loads(kept['manifest.json']) if 'manifest.json' in kept else None
    summary = {'image': args.image, 'image_id': info['Id'], 'repo_digests': info.get('RepoDigests'),
               'platform': info['Os'] + '/' + info['Architecture'], 'save_exit_code': code,
               'top_level_files': sorted(n for n in members if '/' not in n),
               'manifest_entries': len(manifest) if isinstance(manifest, list) else None}
    if isinstance(manifest, list) and len(manifest) == 1:
        config, layers = manifest[0]['Config'], manifest[0]['Layers']
        diff_ids = info['RootFS']['Layers']
        config_hash = members.get(config, {}).get('sha256')
        summary.update({
            'config_path': config,
            'config_file_sha256': config_hash,
            'config_path_equals_image_id': config == 'blobs/sha256/' + info['Id'].removeprefix('sha256:'),
            'config_rootfs_equals_inspect': json.loads(kept[config])['rootfs']['diff_ids'] == diff_ids
            if config in kept else None,
            'layer_count': len(layers), 'diff_id_count': len(diff_ids),
            'layer_paths_are_blobs': all(p.startswith('blobs/sha256/') for p in layers),
            'layer_file_hash_matches_path': all(members[p]['sha256'] == p.rsplit('/', 1)[1] for p in layers),
            'layer_magic': sorted({members[p]['magic'] for p in layers}),
            'layer_diff_id_matches': all('sha256:' + (members[p].get('gunzip_sha256') or members[p]['sha256']) == d
                                         for p, d in zip(layers, diff_ids)),
        })
    dump(out / 'summary.json', summary)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if code == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
