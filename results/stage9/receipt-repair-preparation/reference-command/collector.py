#!/usr/bin/env python3
"""Read existing stopped Stage 7 files. Never start a container or checker."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--work', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=False)
    a.work.mkdir(parents=True, exist_ok=False)
    container = 'forge-stage7-own-proof-0001'
    log = Path('results/stage7/own-proof/attempt-0001/linux/independent-kernel.log')
    assert sha(log.read_bytes()) == '17f533b4873ea0ba11ede10140b6b1c41289402398737056862e00508e935758'
    paths = re.findall(r'^\[intern (.+\.vo) \.\.\.$', log.read_text(), re.M)
    assert len(paths) == len(set(paths)) == 579
    def inspect(label):
        fmt = '{"id":{{json .Id}},"image":{{json .Image}},"image_ref":{{json .Config.Image}},"readonly":{{json .HostConfig.ReadonlyRootfs}},"state":{{json .State}},"mounts":{{json .Mounts}}}'
        cmd = ['docker', 'inspect', '--format', fmt, container]
        r = subprocess.run(cmd, capture_output=True)
        (a.output / (label + '.stdout.log')).write_bytes(r.stdout)
        (a.output / (label + '.stderr.log')).write_bytes(r.stderr)
        (a.output / (label + '.command.json')).write_text(json.dumps({'argv':cmd,'exit_code':r.returncode},indent=2)+'\n')
        assert r.returncode == 0, 'Existing-container inspection failed'
        state = json.loads(r.stdout)
        pins = json.loads(Path('toolchain/stage7-pins.json').read_text())
        assert state['image_ref'] == pins['checker_image'] and state['readonly'] is True
        assert state['state']['Running'] is False and state['state']['ExitCode'] == 0
        return state
    before = inspect('before')
    def collect(item):
        number, path = item
        cmd = ['docker', 'cp', container + ':' + path, '-']
        r = subprocess.run(cmd, capture_output=True)
        (a.output / f'{number:03d}.stderr.log').write_bytes(r.stderr)
        record = {'argv':cmd,'exit_code':r.returncode,'stdout_tar_sha256':sha(r.stdout),
                  'stdout_tar_bytes':len(r.stdout),'stderr_sha256':sha(r.stderr)}
        (a.output / f'{number:03d}.command.json').write_text(json.dumps(record,indent=2)+'\n')
        if r.returncode:
            (a.work / f'{number:03d}.failed.stdout').write_bytes(r.stdout)
            return path, None
        with tarfile.open(fileobj=io.BytesIO(r.stdout)) as archive:
            members = [m for m in archive.getmembers() if m.isfile()]
            assert len(members) == 1 and Path(members[0].name).name == Path(path).name
            data = archive.extractfile(members[0]).read()
        target = a.work / path.removeprefix('/')
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
        return path, sha(data)
    with ThreadPoolExecutor(max_workers=8) as pool:
        entries = dict(pool.map(collect, enumerate(paths)))
    after = inspect('after')
    assert before == after, 'Container state changed'
    failures = [p for p,h in entries.items() if h is None]
    (a.output / 'closure-sha256.json').write_text(json.dumps(entries,sort_keys=True,indent=2)+'\n')
    # The nine archived own-proof objects must be exactly the published bytes.
    prefix = '/work/.forge-stage7/own-proof/attempt-0001/'
    archived = 0
    for path,h in entries.items():
        if path.startswith(prefix):
            assert h == sha((Path('results/stage7/own-proof/attempt-0001/linux') / path.removeprefix(prefix)).read_bytes())
            archived += 1
    assert archived == 9
    result = {'scope':'read_only_reference_collection','result':'blocked' if failures else 'collected',
              'dependencies':len(entries),'archived_own_objects_matched':archived,'failed_paths':failures,
              'new_kernel_execution':False,'new_signature':False,'end_to_end':False}
    (a.output / 'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
