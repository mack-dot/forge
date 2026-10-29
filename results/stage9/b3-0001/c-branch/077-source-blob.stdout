#!/usr/bin/env python3
"""Archive Stage 7 operational records without changing their original bytes.

Run only after the active EXIT command has finished. This is record packaging,
not a proof checker or an acceptance decision. Use standard tar/xz to extract.
"""
import argparse
import hashlib
import io
import json
import lzma
import re
import tarfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record-set', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', args.record_set):
        parser.error('record-set must contain lowercase words separated by hyphens')
    root = Path(__file__).resolve().parents[1]
    records = root / 'results/stage7'
    published = records / 'published'
    published.mkdir(exist_ok=True)
    destination = published / args.record_set
    destination.mkdir(exist_ok=False)
    archive = destination / 'records.tar.xz'
    index_path = destination / 'records-index.json'
    paths = sorted(p for p in records.rglob('*')
                   if p.is_file() and published not in p.parents)
    entries = []
    with lzma.open(archive, 'wb', preset=9) as compressed:
        with tarfile.open(fileobj=compressed, mode='w|', format=tarfile.USTAR_FORMAT) as tar:
            for path in paths:
                data = path.read_bytes()
                name = path.relative_to(root).as_posix()
                info = tarfile.TarInfo(name)
                info.size = len(data)
                info.mode = 0o644
                info.mtime = 0
                tar.addfile(info, io.BytesIO(data))
                entries.append({'path': name, 'bytes': len(data),
                                'sha256': hashlib.sha256(data).hexdigest()})
    # Check archive contents against the original file bytes before publication.
    expected = {item['path']: item for item in entries}
    with tarfile.open(archive, 'r:xz') as tar:
        members = tar.getmembers()
        assert len(members) == len(expected)
        for member in members:
            assert member.isfile() and member.name in expected
            data = tar.extractfile(member).read()
            assert hashlib.sha256(data).hexdigest() == expected[member.name]['sha256']
            assert hashlib.sha256((root / member.name).read_bytes()).hexdigest() == expected[member.name]['sha256']
    index = {'format': 'forge-stage7-operational-record-archive/1',
             'proof_verdict': 'not_assessed_by_packager',
             'archive': archive.relative_to(root).as_posix(),
             'archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
             'extract_cmd': 'tar -xJf ' + archive.relative_to(root).as_posix(),
             'files': entries}
    index_path.write_text(json.dumps(index, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'archived_files': len(entries), 'archive_bytes': archive.stat().st_size,
                      'all_extracted_bytes_match': True, 'original_files_retained': True}))


if __name__ == '__main__':
    main()
