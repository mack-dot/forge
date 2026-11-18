"""Build the COMPLETE print-effects change (version 2) in a scratch git worktree and emit its diffs (Round 2, U423).

Nothing in the real working tree is changed. Steps in the scratch worktree at HEAD:
  1. git apply the approved candidate.diff (three files);
  2. toolchain/linux-pins.json: the same option;
  3. spec/refund/spec.lock: new digest of toolchain/pins.json;
  4. gate/refund.py: new digest of spec/refund/spec.lock in APPROVED;
  5. scripts/exit_stage_5.py: a class for programs that Dafny's print-effect tracking rejects;
  6. bugs/print_effect.dfy, bugs/print_effect_marked.dfy.
Regenerated records and EXIT runs are done by the caller in the same worktree.
Usage: python3 -I -B build_v2.py <scratch-worktree>
"""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[3]
W = Path(sys.argv[1]).resolve()
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()


def sub(path, old, new):
    text = (W / path).read_text()
    assert text.count(old) == 1, (path, old, text.count(old))
    (W / path).write_text(text.replace(old, new))


subprocess.run(['git', 'apply', str(ROOT / 'proposals/forge2-pillar1-print-effects/candidate.diff')], cwd=W, check=True)
sub('toolchain/linux-pins.json', '    "--verify-included-files"\n', '    "--verify-included-files",\n    "--track-print-effects"\n')
old_pins, new_pins = sha(ROOT / 'toolchain/pins.json'), sha(W / 'toolchain/pins.json')
old_lock = sha(W / 'spec/refund/spec.lock')
sub('spec/refund/spec.lock', old_pins, new_pins)
sub('gate/refund.py', old_lock, sha(W / 'spec/refund/spec.lock'))
sub('scripts/exit_stage_5.py',
    "                else:\n                    raise RuntimeError('TOOLCHAIN_OR_INPUT_ERROR: unexpected verify exit ' + str(verified.returncode))",
    "                elif verified.returncode == 2 and 'print' in (verified.stdout + verified.stderr).lower():\n"
    "                    row.update(classification='effect_rejected',\n"
    "                               reason='Dafny print-effect tracking rejected the program; not a spec-proof kill.')\n"
    "                else:\n                    raise RuntimeError('TOOLCHAIN_OR_INPUT_ERROR: unexpected verify exit ' + str(verified.returncode))")
sub('scripts/exit_stage_5.py', "for name in ('killed', 'survived', 'invalid', 'audit_rejected', 'inconclusive')}",
    "for name in ('killed', 'survived', 'invalid', 'audit_rejected', 'inconclusive', 'effect_rejected')}")
sub('scripts/exit_stage_5.py', "'excluded': ['invalid', 'audit_rejected', 'inconclusive']}", "'excluded': ['invalid', 'audit_rejected', 'inconclusive', 'effect_rejected']}")
for name in ('print_effect.dfy', 'print_effect_marked.dfy'):
    shutil.copyfile(ROOT / 'proposals/forge2-pillar1-print-effects/candidate-bugs' / name, W / 'bugs' / name)
print(json.dumps({'pins_sha256': new_pins, 'refund_lock_sha256': sha(W / 'spec/refund/spec.lock'), 'gate_refund_sha256': sha(W / 'gate/refund.py')}, indent=1))
