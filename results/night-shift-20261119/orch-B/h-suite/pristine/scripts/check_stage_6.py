#!/usr/bin/env python3
"""Run real booking evidence replay and rejection controls; preserve every log."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest
from incremental import protected_manifest
from booking import SOURCES


def main():
    name = 'controls'
    index = 2
    while (ROOT / 'results/stage6' / name).exists():
        name = 'controls-' + str(index)
        index += 1
    output = ROOT / 'results/stage6' / name
    output.mkdir(parents=True, exist_ok=False)
    work = ROOT / 'build/stage6' / name
    work_name = work.relative_to(ROOT).as_posix()
    work.mkdir(parents=True, exist_ok=False)
    report = {'stage': 6, 'stage_exit': False, 'result': 'running', 'exit_code': None,
              'commands': [], 'checker_operations': [], 'negative_controls': []}
    before = protected_manifest(ROOT)
    before_sources = {p: digest((ROOT / p).read_bytes()) for p in SOURCES}

    def save():
        (output / 'report.json').write_bytes(canonical(report))

    def run(name, command, expected=0, diagnostic=None, cwd=ROOT):
        start = time.perf_counter_ns()
        child = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
        elapsed = time.perf_counter_ns() - start
        log = output / (name + '.log')
        log.write_text(child.stdout + child.stderr)
        report['commands'].append({'name': name, 'argv': command, 'cwd': str(cwd),
                                   'exit_code': child.returncode, 'elapsed_ns': elapsed,
                                   'log': log.relative_to(ROOT).as_posix(),
                                   'log_sha256': digest(log.read_bytes())})
        save()
        print(name + ': exit ' + str(child.returncode), flush=True)
        if child.returncode != expected or (diagnostic and diagnostic not in log.read_text()):
            raise RuntimeError('Unexpected result for ' + name + ': ' + log.read_text())

    def operation(folder, name):
        original = folder / 'operation.json'
        item = json.loads(original.read_text())
        archived = output / name
        archived.mkdir()
        for i, record in enumerate(item['commands']):
            # Child paths are relative to the checkout in which the gate ran.
            source = folder / Path(record['log']).name
            target = archived / (str(i) + '.log')
            assert digest(source.read_bytes()) == record['log_sha256']
            target.write_bytes(source.read_bytes())
            record['original_log'] = record['log']
            record['log'] = target.relative_to(ROOT).as_posix()
        (archived / 'operation.json').write_bytes(canonical(item))
        report['checker_operations'].append(item)
        save()

    try:
        run('accepted', ['python3', 'gate/booking.py', '--evidence', work_name + '/a.json',
                          '--work', work_name + '/gate-a'])
        operation(work / 'gate-a', 'gate-a')
        run('replayed', ['python3', 'gate/booking.py', '--check-evidence', work_name + '/a.json',
                          '--evidence', work_name + '/b.json', '--work', work_name + '/gate-b'])
        operation(work / 'gate-b', 'gate-b')
        run('byte-identical', ['cmp', work_name + '/a.json', work_name + '/b.json'])
        accepted = json.loads((work / 'a.json').read_text())
        for name, diagnostic, edit in (
            ('wrong-artifact', 'ARTIFACT_MISMATCH', 'artifact'),
            ('wrong-method', 'METHOD_POLICY', 'method'),
        ):
            candidate = json.loads(json.dumps(accepted))
            if edit == 'artifact':
                candidate['artifact']['sha256'] = '0' * 64
            else:
                candidate['evidence'][0]['method'] = 'unit_tested'
            incoming = work / (name + '.json')
            incoming.write_bytes(canonical(candidate))
            run(name, ['python3', 'gate/booking.py', '--check-evidence', incoming.relative_to(ROOT).as_posix(),
                       '--evidence', work_name + '/rejected.json'], 1, diagnostic)
            assert not (work / 'rejected.json').exists()
            report['negative_controls'].append({'name': name, 'rule': diagnostic, 'gate_exit_code': 1})
        for name, diagnostic in (('forbidden-assumption', 'AUDIT_REJECTED'),
                                 ('bodiless-lemma', 'AUDIT_REJECTED'),
                                 ('spec-and-lock', 'BOOKING_SPEC_LOCK'),
                                 ('changed-witness', 'WITNESS_BINDING')):
            fixture = work / name
            fixture.mkdir()
            for path in set(before) | set(SOURCES) | {'proposals/booking-decision.md'}:
                target = fixture / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / path).read_bytes())
            (fixture / '.toolchain').symlink_to(ROOT / '.toolchain', target_is_directory=True)
            if name == 'forbidden-assumption':
                p = fixture / 'impl/Booking.dfy'
                p.write_text(p.read_text().replace('    value := picked;', '    assume false;\n    value := picked;', 1))
            elif name == 'bodiless-lemma':
                p = fixture / 'impl/Booking.dfy'
                code = p.read_text().replace('  method Least(', '  lemma Escape() ensures false\n\n  method Least(', 1)
                p.write_text(code.replace('    value := picked;', '    Escape();\n    value := picked;', 1))
            elif name == 'spec-and-lock':
                p = fixture / 'spec/booking/BookingSpec.dfy'
                p.write_text(p.read_text() + '// unapproved edit\n')
                lock_path = fixture / 'spec/booking/spec.lock'
                lock = json.loads(lock_path.read_text())
                lock['spec_sha256'] = digest(p.read_bytes())
                lock_path.write_bytes(canonical(lock))
            else:
                p = fixture / 'tests/booking/SuccessfulExecution.dfy'
                p.write_text(p.read_text() + '// changed witness\n')
            run(name, ['python3', 'gate/booking.py', '--evidence', 'build/rejected.json',
                       '--work', 'build/gate-operation'], 1, diagnostic, fixture)
            assert not (fixture / 'build/rejected.json').exists()
            detail = {'name': name, 'rule': diagnostic, 'gate_exit_code': 1}
            if name in ('forbidden-assumption', 'bodiless-lemma'):
                child = json.loads((fixture / 'build/gate-operation/operation.json').read_text())
                assert child['commands'][-1]['exit_code'] == 2
                detail['dafny_audit_exit_code'] = 2
                operation(fixture / 'build/gate-operation', name)
            report['negative_controls'].append(detail)
            save()
        assert protected_manifest(ROOT) == before
        assert all(digest((ROOT / p).read_bytes()) == h for p, h in before_sources.items())
        (ROOT / 'results/stage6/source-evidence.json').write_bytes((work / 'a.json').read_bytes())
        report.update({'result': 'passed', 'exit_code': 0, 'byte_identical': True,
                       'protected_inputs_unchanged': True,
                       'source_evidence_sha256': digest((work / 'a.json').read_bytes())})
        save()
        (ROOT / 'results/stage6/controls-final.json').write_bytes(canonical(report))
        return 0
    except Exception as error:
        report.update({'result': 'failed', 'exit_code': 1, 'error': str(error)})
        save()
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
