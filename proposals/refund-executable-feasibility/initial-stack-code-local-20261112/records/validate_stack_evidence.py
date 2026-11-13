"""Separate evidence reader for the local initial-stack-code cases.

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. It is not a proof checker and gives no independent proof assurance.

Usage: python3 -I -B validate_stack_evidence.py
"""
from pathlib import Path
import hashlib, json, re

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
OLD = ROOT / 'proposals/refund-executable-feasibility/initial-stack-code-checkpoint-20261105'
OLD_SHA = 'f3e2be7884bd6ee005de790179859e1858bad7e8862901e59c3709be7c8acb11'
NEW_SHA = '7d24953dea9a70a51db26a4ee7c6b858d692a9a5cd84fecf5a86544ff5871c6f'
PREPARED = {
    'expected.sml': 'edea761f3a3f69c30bb86df1388dfda08fe2e286291cb353ebcc549ed6c851ba',
    'wrong-lowering.sml': '482e2170427445eaa0d8b9c2a046d26bfe378ec801d869659798977c12421d09',
    'duplicate-label.sml': 'a43e328befa89012271eeb8584cf7ec486380a2214ff453977cefea64b37f43a',
    'missing-memory.sml': '293fab448fa44054d8b388bfe323955f4745ab73c435a4ae31feab125f27e5e4',
}
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
THEOREMS = ['refund_word_postalloc', 'refund_word_labels', 'refund_stack_lowering',
            'refund_initial_stack_good', 'refund_initialization_code']
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(name):
    folder = OUT / name
    record = json.loads((folder / 'command.json').read_text())
    stdout = (folder / 'stdout.log').read_text(errors='replace')
    stderr = (folder / 'stderr.log').read_text(errors='replace')
    require(record['stdout_sha256'] == sha(folder / 'stdout.log'), name + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(folder / 'stderr.log'), name + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(folder / 'proof.sml'), name + ': executed source differs from record')
    require(record['inputs_unchanged_after'] is True, name + ': recorded inputs changed')
    require(record['wall_timeout'] is False, name + ': wall timeout')
    objects = {str(p.relative_to(folder)): sha(p) for p in sorted((folder / '.hol').rglob('*')) if p.is_file()}
    require(objects == record['objects'], name + ': exported objects differ from record')
    return record, stdout, stderr


def statements(text):
    return re.findall(r'(?:store_thm\("[a-z_]+",|prove\()``(.*?)``,', text, flags=re.S)


old = (OLD / 'records/code-numeric.sml').read_text()
new = (OUT / 'code-local-0004.sml').read_text()
require(sha(OLD / 'records/code-numeric.sml') == OLD_SHA, 'U314 source changed')
require(sha(OUT / 'code-local-0004.sml') == NEW_SHA, 'candidate changed')
require(statements(old) == statements(new) and len(statements(old)) == 6, 'quoted statements differ')
manifest = json.loads((OLD / 'MANIFEST.json').read_text())
listed = manifest.get('files', manifest)
for name, digest in PREPARED.items():
    require(sha(OUT / name) == digest, name + ': not the prepared U314 source')
    require(listed.get('records/' + name) == digest, name + ': not bound by the U314 manifest')

proof, out, err = case('code-0004')
require(proof['actual_exit'] == 0 and proof['source_sha256'] == NEW_SHA, 'proof: exit or source')
require('RUNTIME_PROOF_COMPLETE' in out and 'REMAINING_ANTECEDENTS 14' in out.splitlines(), 'proof: markers')
require([line.split(' ', 1)[1] for line in out.splitlines() if line.startswith('CHECKED ')] == THEOREMS,
        'proof: checked theorem list')
require(len(proof['objects']) == 4, 'proof: object count')

repeat, out, err = case('repeat')
require(repeat['actual_exit'] == 0 and repeat['source_sha256'] == NEW_SHA, 'repeat: exit or source')
require('RUNTIME_PROOF_COMPLETE' in out and repeat['objects'] == proof['objects'], 'repeat: marker or exports')

audit, out, err = case('audit')
lines = out.splitlines()
require(audit['actual_exit'] == 0 and audit['source_sha256'] == PREPARED['expected.sml'], 'audit: exit or source')
require('TRACE_IMPORT_COMPLETE' in lines and not audit['objects'], 'audit: marker or objects')
nodes = [line.split(' ', 1)[1].split(':', 1)[0] for line in lines if line.startswith('CLOSURE_NODE ')]
axioms = {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}
require('forge_refundInitialStackCode' in nodes and len(nodes) == len(set(nodes)), 'audit: closure node list')
require(axioms == BOOL_AXIOMS, 'audit: closure axioms are not the four Boolean axioms')
exports = [a for a in audit['argv'] if 'forge_refundInitialStackCodeTheory' in a]
require(exports == [str(OUT / 'code-0004' / ('forge_refundInitialStackCodeTheory' + s)) for s in ('.sig', '.sml')],
        'audit: theory files are not the code-0004 exports')

control_exits, control_lines = {}, {}
for name in ('wrong-lowering', 'duplicate-label', 'missing-memory'):
    control, out, err = case(name)
    control_exits[name] = control['actual_exit']
    require(control['actual_exit'] == 1 and control['source_sha256'] == PREPARED[name + '.sml'], name + ': exit or source')
    require('AFTER_POSITIVE_AUDIT' in out.splitlines(), name + ': positive audit did not complete first')
    require('UNEXPECTED_CONTROL_ACCEPTANCE' not in out and 'TRACE_IMPORT_COMPLETE' not in out
            and not control['objects'], name + ': control accepted')
    # The control statement is the only code between the two markers, so an
    # exit 1 after AFTER_POSITIVE_AUDIT without the acceptance marker is a
    # failure of the control statement itself.
    uncaught = [line for line in err.splitlines() if line.startswith('Uncaught exception')]
    control_lines[name] = [line[:200] for line in uncaught]
    require(len(uncaught) == 1, name + ': no single uncaught exception')
require('Exact statement mismatch: refund_stack_lowering' in (OUT / 'wrong-lowering/stderr.log').read_text(errors='replace'),
        'wrong-lowering: not the intended statement mismatch')

summary = {
    'cases': {'code-0004': proof['actual_exit'], 'repeat': repeat['actual_exit'], 'audit': audit['actual_exit'],
              **control_exits},
    'candidate_sha256': NEW_SHA, 'exports': proof['objects'], 'remaining_antecedents': 14,
    'closure_nodes': len(nodes), 'closure_axioms': sorted(axioms), 'control_exceptions': control_lines,
    'scope': 'Byte, exit and marker binding only. Not a proof checker. No independent replay.',
    'failures': failures, 'end_to_end': False,
}
print(json.dumps(summary, indent=1))
raise SystemExit(1 if failures else 0)
