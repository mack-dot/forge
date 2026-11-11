#!/usr/bin/env python3
"""Run the frozen Stage 10 gate benchmark against unchanged Forge gates.

  python3 bench/run.py --manifest bench/manifest.json --approved-manifest-sha256 SHA \
      --out results/stage10/run-NNNN --work ~/forge-stage10-bench/run-NNNN
  python3 bench/run.py --manifest bench/manifest.json --dry-run \
      --out results/stage10/dry-run-NNNN --work ~/forge-stage10-bench/dry-run-NNNN

Every case runs in fresh APFS clones of a clean checkout of the manifest's base
commit, under a sandbox that denies IP networking. The runner only prepares inputs
and calls existing gate entry points; it does not verify anything itself.
A dry run builds and removes every case tree but never starts a gate.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import resource
import shutil
import subprocess
import sys
import time

BENCH = Path(__file__).resolve().parent
REPO = BENCH.parent
SANDBOX = ['/usr/bin/sandbox-exec', '-p',
           '(version 1)(allow default)'
           '(deny network-outbound (remote ip "*:*"))(deny network-inbound (local ip "*:*"))']
REASON = re.compile(r'^([A-Z][A-Z0-9_]{2,}):')


class HarnessError(Exception):
    pass


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def utc():
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=1, sort_keys=True) + '\n')


def clone(source, target):
    subprocess.run(['/bin/cp', '-cRp', str(source), str(target)], check=True)


def inside(root, name):
    path = (root / name).resolve()
    if Path(name).is_absolute() or '..' in Path(name).parts or not path.is_relative_to(root.resolve()):
        raise HarnessError('PATH_SCOPE: ' + name)
    return path


def apply_change(change, roots):
    root = roots.get(change['target'])
    if root is None:
        raise HarnessError('TARGET: ' + change['target'])
    path = inside(root, change['path'])
    if change['op'] == 'edit':
        content = path.read_text()
        if content.count(change['find']) != 1:
            raise HarnessError('EDIT_ANCHOR: ' + change['path'])
        path.write_text(content.replace(change['find'], change['replace'], 1))
    elif change['op'] == 'write':
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            path.unlink()
        path.write_text(change['content'])
        if 'mode' in change:
            path.chmod(int(change['mode'], 8))
    elif change['op'] == 'delete':
        path.unlink()
    elif change['op'] == 'truncate':
        if not path.is_file():
            raise HarnessError('TRUNCATE_TARGET: ' + change['path'])
        path.write_bytes(b'')
    else:
        raise HarnessError('OP: ' + change['op'])


def locate(document, path):
    """Return (container, key) for a path of keys, indexes and {"claim_id": X} selectors."""
    node = document
    for position, step in enumerate(path):
        if isinstance(step, dict):
            (field, value), = step.items()
            matches = [i for i, item in enumerate(node) if item.get(field) == value]
            if len(matches) != 1:
                raise HarnessError('SELECTOR: ' + json.dumps(step))
            step = matches[0]
        if position == len(path) - 1:
            return node, step
        node = node[step]
    raise HarnessError('EMPTY_PATH')


def supplied_text(spec, seed_document):
    document = json.loads(json.dumps(seed_document))
    for op in spec['ops']:
        container, key = locate(document, op['path'])
        if op['op'] == 'set':
            container[key] = op['value']
        elif op['op'] == 'remove':
            del container[key]
        else:
            raise HarnessError('EVIDENCE_OP: ' + op['op'])
    text = json.dumps(document, sort_keys=True)
    duplicate = spec.get('duplicate_top_level_key')
    if duplicate:
        text = '{' + json.dumps(duplicate) + ':' + json.dumps(document[duplicate]) + ',' + text[1:]
    return text


def command(case, python, candidate):
    supplied = ['--check-evidence', 'build/bench-supplied.json'] if case['supplied_evidence'] else []
    gate = case['gate']
    if gate == 'incremental':
        if supplied:
            raise HarnessError('INCREMENTAL_HAS_NO_SUPPLIED_EVIDENCE')
        return [python, 'gate/incremental.py', '--candidate', str(candidate),
                '--evidence', 'build/bench-evidence.json', '--work', 'build/bench-work']
    if gate == 'gate':
        return [python, 'gate/gate.py', '--impl', 'impl/Ledger.dfy',
                '--evidence', 'build/bench-evidence.json'] + supplied
    if gate == 'booking':
        return [python, 'gate/booking.py', '--evidence', 'build/bench-evidence.json',
                '--work', 'build/bench-work'] + supplied
    if gate == 'refund':
        return [python, 'gate/refund.py', '--tier', 'critical',
                '--evidence', 'build/bench-evidence.json'] + supplied
    raise HarnessError('GATE: ' + gate)


def classify(classes, exit_code, timed_out, stderr):
    prefix = None
    for line in stderr.splitlines():
        match = REASON.match(line)
        if match:
            prefix = match.group(1)
            break
    if timed_out:
        return prefix, classes['exit_rules']['timeout']
    rule = classes['exit_rules'].get(str(exit_code), classes['exit_rules']['other_exit'])
    if rule != 'by_reason_prefix':
        return prefix, rule
    return prefix, classes['reason_classes'].get(prefix, classes['unmapped_reason'])


def host():
    def sysctl(name):
        child = subprocess.run(['/usr/sbin/sysctl', '-n', name], capture_output=True, text=True)
        return child.stdout.strip()
    return {'platform': platform.platform(), 'machine': platform.machine(),
            'model': sysctl('hw.model'), 'cpu': sysctl('machdep.cpu.brand_string'),
            'logical_cpus': sysctl('hw.ncpu'), 'memory_bytes': sysctl('hw.memsize'),
            'python': platform.python_version(), 'python_executable': sys.executable}


def verify_manifest(manifest_path, approved, dry_run):
    raw = manifest_path.read_bytes()
    digest = sha256(raw)
    if not dry_run and digest != approved:
        raise SystemExit('MANIFEST_NOT_APPROVED: ' + digest)
    manifest = json.loads(raw)
    for name, expected in manifest['files'].items():
        if sha256((REPO / name).read_bytes()) != expected:
            raise SystemExit('MANIFEST_FILE_CHANGED: ' + name)
    listed = sorted(manifest['files'])
    present = sorted(p.relative_to(REPO).as_posix() for p in BENCH.rglob('*')
                     if p.is_file() and p.name != 'manifest.json' and '__pycache__' not in p.parts)
    if sorted(set(present) - set(listed)):
        raise SystemExit('UNLISTED_BENCH_FILE: ' + ', '.join(sorted(set(present) - set(listed))))
    if platform.python_version() != manifest['python']['version'] or sys.executable != manifest['python']['executable']:
        raise SystemExit('PYTHON_DIFFERS: run with ' + manifest['python']['executable'])
    return manifest, digest


def prepare_base(manifest, work, log):
    plain, base = work / 'plain', work / 'base'
    env = {'PATH': '/usr/bin:/bin', 'HOME': os.environ['HOME'], 'GIT_TERMINAL_PROMPT': '0'}
    subprocess.run(['/usr/bin/git', 'clone', '-q', manifest['base_repository'], str(plain)], check=True, env=env)
    head = subprocess.run(['/usr/bin/git', '-C', str(plain), 'rev-parse', 'HEAD'],
                          capture_output=True, text=True, check=True).stdout.strip()
    if head != manifest['base_commit']:
        subprocess.run(['/usr/bin/git', '-C', str(plain), 'checkout', '-q', manifest['base_commit']], check=True, env=env)
        head = subprocess.run(['/usr/bin/git', '-C', str(plain), 'rev-parse', 'HEAD'],
                              capture_output=True, text=True, check=True).stdout.strip()
    status = subprocess.run(['/usr/bin/git', '-C', str(plain), 'status', '--porcelain'],
                            capture_output=True, text=True, check=True).stdout
    if head != manifest['base_commit'] or status:
        raise SystemExit('BASE_REVISION: ' + head)
    shutil.rmtree(plain / '.git')
    pins = sha256((plain / 'toolchain/pins.json').read_bytes())
    if pins != manifest['toolchain_pins_sha256']:
        raise SystemExit('TOOLCHAIN_PINS_DIFFER')
    clone(plain, base)
    started = time.perf_counter()
    clone(Path(manifest['toolchain_source']), base / '.toolchain')
    log['base'] = {'commit': head, 'toolchain_pins_sha256': pins,
                   'toolchain_clone_seconds': round(time.perf_counter() - started, 3)}
    return plain, base


def readiness(base, work, log):
    dafny = base / '.toolchain/dafny-4.11.0/dafny/dafny'
    version = subprocess.run(SANDBOX + [str(dafny), '--version'], cwd=base, capture_output=True, text=True)
    probe = subprocess.run(SANDBOX + [sys.executable, '-I', '-c',
                                      'import socket; socket.create_connection(("1.1.1.1", 443), 3)'],
                           capture_output=True, text=True)
    log['readiness'] = {'dafny_version_exit': version.returncode, 'dafny_version_output': version.stdout.strip(),
                        'network_probe_exit': probe.returncode,
                        'network_probe_error': (probe.stderr.strip().splitlines() or [''])[-1]}
    if version.returncode != 0 or probe.returncode == 0:
        raise SystemExit('NOT_READY: ' + json.dumps(log['readiness']))


def run_case(case, classes, plain, base, work, out, python, timeout, dry_run):
    case_work = work / ('%02d-%s' % (case['order'], case['id']))
    case_out = out / case['id']
    case_out.mkdir(parents=True)
    record = {'id': case['id'], 'order': case['order'], 'domain': case['domain'], 'gate': case['gate'],
              'kind': case['kind'], 'expected_class': case['expected_class'],
              'expected_exit': case['expected_exit'], 'expected_reason_prefix': case['expected_reason_prefix']}
    case_work.mkdir(parents=True)
    try:
        root = case_work / 'root'
        clone(base, root)
        roots = {'root': root}
        if case['gate'] == 'incremental':
            roots['candidate'] = case_work / 'candidate'
            clone(plain, roots['candidate'])
        for change in case['changes']:
            apply_change(change, roots)
        argv = command(case, python, roots.get('candidate'))
        (root / 'build').mkdir(exist_ok=True)
        if case['supplied_evidence']:
            seed = out / case['supplied_evidence']['from'] / 'evidence.json'
            if dry_run:
                for op in case['supplied_evidence']['ops']:
                    if op['op'] not in ('set', 'remove') or not op['path']:
                        raise HarnessError('EVIDENCE_OP: ' + json.dumps(op))
            elif not seed.is_file():
                raise HarnessError('SEED_EVIDENCE_MISSING: ' + case['supplied_evidence']['from'])
            else:
                text = supplied_text(case['supplied_evidence'], json.loads(seed.read_text()))
                (root / 'build/bench-supplied.json').write_text(text)
                (case_out / 'supplied.json').write_text(text)
                record['supplied_sha256'] = sha256(text.encode())
        record['argv'] = [str(Path(a).relative_to(case_work)) if a.startswith(str(case_work)) else a
                          for a in argv]
        if dry_run:
            record['status'] = 'dry_run_materialized'
            return record
        tmp = case_work / 'tmp'
        tmp.mkdir()
        env = {'PATH': str(Path(python).parent) + ':/usr/bin:/bin:/usr/sbin:/sbin',
               'HOME': os.environ['HOME'], 'TMPDIR': str(tmp)}
        for name in ('LANG', 'LC_ALL'):
            if name in os.environ:
                env[name] = os.environ[name]
        record['started_utc'] = utc()
        before = resource.getrusage(resource.RUSAGE_CHILDREN)
        start = time.perf_counter_ns()
        timed_out = False
        try:
            child = subprocess.run(SANDBOX + argv, cwd=root, env=env, capture_output=True, timeout=timeout)
            stdout, stderr, exit_code = child.stdout, child.stderr, child.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, exit_code, timed_out = error.stdout or b'', error.stderr or b'', None, True
        wall = time.perf_counter_ns() - start
        after = resource.getrusage(resource.RUSAGE_CHILDREN)
        (case_out / 'stdout.txt').write_bytes(stdout)
        (case_out / 'stderr.txt').write_bytes(stderr)
        prefix, observed = classify(classes, exit_code, timed_out, stderr.decode(errors='replace'))
        evidence = root / 'build/bench-evidence.json'
        if evidence.is_file():
            shutil.copyfile(evidence, case_out / 'evidence.json')
            record['evidence_sha256'] = sha256(evidence.read_bytes())
        if (root / 'build').is_dir():
            shutil.copytree(root / 'build', case_out / 'build', symlinks=True)
        reason_line = next((l for l in stderr.decode(errors='replace').splitlines() if REASON.match(l)), None)
        record.update({'status': 'ran', 'exit_code': exit_code, 'timed_out': timed_out,
                       'reason_prefix': prefix, 'reason_line': (reason_line or '')[:400],
                       'observed_class': observed, 'wall_seconds': round(wall / 1e9, 3),
                       'cpu_user_seconds': round(after.ru_utime - before.ru_utime, 3),
                       'cpu_system_seconds': round(after.ru_stime - before.ru_stime, 3),
                       'stdout_sha256': sha256(stdout), 'stderr_sha256': sha256(stderr),
                       'finished_utc': utc()})
        return record
    except (HarnessError, OSError, subprocess.CalledProcessError) as error:
        record.update({'status': 'harness_error', 'error': str(error)})
        return record
    finally:
        dump(case_out / 'record.json', record)
        shutil.rmtree(case_work, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--approved-manifest-sha256')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    manifest, digest = verify_manifest(args.manifest, args.approved_manifest_sha256, args.dry_run)
    classes = json.loads((REPO / manifest['classes_file']).read_text())
    cases = [json.loads((REPO / name).read_text()) for name in manifest['case_files']]
    if [c['id'] for c in cases] != manifest['case_order']:
        raise SystemExit('CASE_ORDER')
    out, work = args.out.resolve(), args.work.expanduser().resolve()
    if out.exists() or work.exists():
        raise SystemExit('OUTPUT_EXISTS: use new --out and --work folders')
    out.mkdir(parents=True)
    work.mkdir(parents=True)
    log = {'manifest_sha256': digest, 'dry_run': args.dry_run, 'started_utc': utc(), 'host': host(),
           'passes': manifest['passes'], 'timeout_seconds': manifest['timeout_seconds'],
           'sandbox': SANDBOX[2], 'end_to_end': False}
    dump(out / 'run.json', log)
    plain, base = prepare_base(manifest, work, log)
    readiness(base, work, log)
    dump(out / 'run.json', log)
    with (out / 'records.jsonl').open('w') as stream:
        for number in range(1, (1 if args.dry_run else manifest['passes']) + 1):
            pass_out = out / ('pass-%d' % number)
            for case in cases:
                record = run_case(case, classes, plain, base, work / ('pass-%d' % number), pass_out,
                                  sys.executable, manifest['timeout_seconds'], args.dry_run)
                record['pass'] = number
                stream.write(json.dumps(record, sort_keys=True) + '\n')
                stream.flush()
                print('pass', number, record['order'], record['id'], record.get('status'),
                      record.get('exit_code'), record.get('reason_prefix'), record.get('observed_class'),
                      record.get('wall_seconds'), flush=True)
    log['finished_utc'] = utc()
    dump(out / 'run.json', log)
    return 0


if __name__ == '__main__':
    sys.exit(main())
