"""Run established tools and record their diagnostics for spec-quality checks."""

import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest
from backends import dafny
from incremental import protected_manifest


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def preserve(path):
    if path.exists():
        parent = ROOT / 'build/stage5-history' / path.name
        parent.mkdir(parents=True, exist_ok=True)
        index = 1
        while (parent / str(index)).exists():
            index += 1
        shutil.move(path, parent / str(index))
    path.mkdir(parents=True)


class Session:
    def __init__(self, folder):
        self.folder = folder
        self.commands = []
        self.protected = protected_manifest(ROOT)
        self.state = dafny.prepare('impl/Ledger.dfy')
        self.source_before = {name: digest((ROOT / name).read_bytes()) for name in (
            'impl/Ledger.dfy', 'tests/stage5/SuccessfulExecution.dfy',
            'scripts/stage5_tools.py', 'scripts/exit_stage_5.py',
            'scripts/generate_claim_docs.py', 'scripts/generate_examples.ts',
            'scripts/build_model.py', 'scripts/javascript_env.py',
            'ts/ledger.ts', 'ts/types.ts', 'interop/model.ts', 'interop/export.cjs',
            'package.json', 'package-lock.json', 'tsconfig.json',
        )}
        version = self.run('tool-version', [str(dafny.DAFNY), '--version'])
        require(version.returncode == 0 and version.stdout.strip() == self.state['pins']['dafny']['version_output'],
                'TOOLCHAIN_ERROR: actual Dafny version command failed or differed')

    def run(self, name, command):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        log = self.folder / (name + '.log')
        log.write_text(result.stdout + result.stderr)
        self.commands.append({'name': name, 'command': shlex.join(command), 'exit_code': result.returncode,
                              'log': log.relative_to(ROOT).as_posix(), 'log_sha256': digest(log.read_bytes())})
        print(name + ': exit ' + str(result.returncode), flush=True)
        (self.folder / 'commands.json').write_bytes(canonical(self.commands))
        return result

    def fixture(self, name, implementation=None, specification=None):
        target = self.folder / name
        for path in ('spec/LedgerSpec.dfy', 'impl/Ledger.dfy', 'gate/ContractBinding.dfy',
                     'tests/stage5/SuccessfulExecution.dfy'):
            destination = target / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / path).read_bytes())
        if implementation is not None:
            (target / 'impl/Ledger.dfy').write_text(implementation)
        if specification is not None:
            (target / 'spec/LedgerSpec.dfy').write_text(specification)
        return target

    def inputs(self, fixture, witness=False):
        first = 'tests/stage5/SuccessfulExecution.dfy' if witness else 'impl/Ledger.dfy'
        return [str((fixture / first).relative_to(ROOT)),
                str((fixture / 'gate/ContractBinding.dfy').relative_to(ROOT))]

    def audit(self, name, fixture, witness=False):
        report = self.folder / (name + '-audit.md')
        report.write_bytes(dafny.AUDIT.read_bytes())
        return self.run(name + '-audit', [str(dafny.DAFNY), 'audit', *self.inputs(fixture, witness),
                        '--report-format', 'md', '--report-file', str(report), '--compare-report'])

    def verify(self, name, fixture, witness=False, required=None):
        report = self.folder / (name + '.trx')
        child = self.run(name + '-verify', [str(dafny.DAFNY), 'verify', *self.inputs(fixture, witness),
                        *dafny.OPTIONS, '--json-output', '--log-format', 'trx;LogFileName=' + str(report)])
        results = []
        if report.exists():
            for item in ET.parse(report).iter():
                if item.tag.endswith('UnitTestResult'):
                    results.append({'name': item.get('testName'), 'outcome': item.get('outcome')})
        results.sort(key=lambda item: item['name'])
        if child.returncode == 0:
            required = set(dafny.REQUIRED_RESULTS if required is None else required)
            if witness:
                required.add('SuccessfulExecution.Witness (correctness)')
            require(required <= {x['name'] for x in results} and all(x['outcome'] == 'Passed' for x in results),
                    'PROOF_COVERAGE: required obligations missing or not passed')
        return child, results

    def finish(self):
        require(protected_manifest(ROOT) == self.protected, 'PROTECTED_INPUT_CHANGED: approved inputs changed')
        require(all(digest((ROOT / name).read_bytes()) == expected for name, expected in self.source_before.items()),
                'INPUT_CHANGED: a driver, source, witness, or comparison input changed during checking')

    def identity(self):
        return {'spec_sha256': self.state['lock']['spec_sha256'],
                'implementation_sha256': self.source_before['impl/Ledger.dfy'],
                'driver_input_sha256': self.source_before,
                'protected_manifest_sha256': digest(canonical(self.protected)),
                'tool': 'Dafny', 'tool_version': self.state['pins']['dafny']['version_output'],
                'solver_sha256': self.state['pins']['z3']['executable_sha256'],
                'verification_options': dafny.OPTIONS, 'end_to_end': False}


def diagnostics(output):
    return [json.loads(line)['value'] for line in output.splitlines()
            if line.startswith('{') and json.loads(line).get('type') == 'diagnostic']


def message(diagnostic):
    return diagnostic.get('defaultFormatMessage', diagnostic.get('message', ''))


def contract_locations(output, specification):
    locations = set()
    for item in diagnostics(output):
        if item.get('severity') != 1 or 'postcondition' not in message(item).lower():
            continue
        for related in item.get('relatedInformation', []):
            location = related.get('location', {})
            path = location.get('filePath')
            if path and (ROOT / path).resolve() == specification.resolve():
                locations.add(location['range']['start']['line'])
    lines = specification.read_text().splitlines()
    return [{'spec_ref': 'spec/LedgerSpec.dfy:' + str(line), 'source_line': lines[line - 1].strip()}
            for line in sorted(locations)]


def claim_failures(output, specification):
    ranges = dafny.claim_ranges(specification.read_text())
    found = set()
    for item in diagnostics(output):
        if item.get('severity') != 1:
            continue
        for location in [item.get('location', {})] + [x.get('location', {}) for x in item.get('relatedInformation', [])]:
            path = location.get('filePath')
            if not path or (ROOT / path).resolve() != specification.resolve():
                continue
            line = location['range']['start']['line']
            found.update(claim for claim, (start, end) in ranges.items() if start <= line <= end)
    return sorted(found)
