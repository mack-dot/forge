"""Build proposal version 3 in a scratch git worktree (Round 3). Nothing in the real working tree is changed.

Step A (bootstrap, cannot be ratified by a mechanism that does not exist yet; needs the owner's explicit merge):
  gate/approval.py     Tier-0 gate ratification, read from the trusted base only
  gate/ratification.py non-weakening controls with the ratified gate bytes
  gate/incremental.py  calls both; binds the record into the evidence
  .github/CODEOWNERS   owner review for governance/
Step B (the print-effects change of version 2; the FIRST change that the new mechanism can ratify):
  build_v2.py (six protected files, exit_stage_5.py, two planted print bugs)
Usage: python3 -I -B build_v3.py <scratch-worktree> a|b|ab
"""
from pathlib import Path
import shutil, subprocess, sys

HERE = Path(__file__).resolve().parent
W = Path(sys.argv[1]).resolve()
steps = sys.argv[2]
assert W != HERE.parents[2] and not str(HERE).startswith(str(W) + '/'), 'refusing to change the real working tree'


def sub(path, old, new):
    text = (W / path).read_text()
    assert text.count(old) == 1, (path, old, text.count(old))
    (W / path).write_text(text.replace(old, new))


MAIN_LINEAGE = (W / 'gate/obligations.py').is_file()      # main has the Stage 11 obligation gate; the local tree does not
if 'a' in steps:
    for name in ('gate/approval.py', 'gate/ratification.py'):
        shutil.copyfile(HERE / 'files' / name, W / name)
    sub('gate/incremental.py', 'from approval import authorize\n', 'from approval import authorize\nfrom ratification import run_controls\n')
    if MAIN_LINEAGE:
        sub('gate/incremental.py', "    approval = authorize(ROOT, trusted_before, proposed_before)\n    inventory = coverage.inventories(ROOT, candidate)\n    operation['spec_approval'] = approval\n",
            '    approval = authorize(ROOT, trusted_before, proposed_before, candidate)\n'
            "    ratification = approval if approval and approval.get('kind') == 'gate_ratification' else None\n"
            '    if ratification:\n'
            "        operation['ratification_controls'] = run_controls(ROOT, candidate, ratification, work)\n"
            "        operation['gate_ratification'] = ratification\n"
            '    inventory = coverage.inventories(ROOT, candidate)\n'
            "    operation['spec_approval'] = None if ratification else approval\n")
        sub('gate/incremental.py', "ROOT / 'gate/coverage.py', ROOT / 'gate/obligations.py']",
            "ROOT / 'gate/coverage.py', ROOT / 'gate/obligations.py',\n                                                        ROOT / 'gate/ratification.py']")
    else:
        sub('gate/incremental.py', '    approval = authorize(ROOT, trusted_before, proposed_before)\n',
            '    approval = authorize(ROOT, trusted_before, proposed_before, candidate)\n'
            "    ratification = approval if approval and approval.get('kind') == 'gate_ratification' else None\n"
            '    if ratification:\n'
            "        operation['ratification_controls'] = run_controls(ROOT, candidate, ratification, work)\n")
        sub('gate/incremental.py', "[Path(__file__).resolve(), ROOT / 'gate/approval.py']",
            "[Path(__file__).resolve(), ROOT / 'gate/approval.py', ROOT / 'gate/ratification.py']")
    sub('gate/incremental.py', "        'spec_approval': approval,\n",
        "        'spec_approval': None if ratification else approval,\n"
        "        **({'gate_ratification': ratification} if ratification else {}),\n")
    if '/toolchain/ @mack-dot\n' in (W / '.github/CODEOWNERS').read_text():     # main owns every path already ("* @mack-dot")
        sub('.github/CODEOWNERS', '/toolchain/ @mack-dot\n', '/toolchain/ @mack-dot\n/governance/ @mack-dot\n')
if 'b' in steps:
    subprocess.run([sys.executable, '-I', '-B', str(HERE.parent / 'v2/build_v2.py'), str(W)], check=True)
print('built steps', steps, 'in', W.name)
