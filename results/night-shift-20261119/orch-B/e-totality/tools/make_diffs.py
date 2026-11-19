#!/usr/bin/env python3
"""Build the unapplied gate diffs on COPIES. Never writes under the repository's gate/."""
import hashlib, re, shutil, subprocess
from pathlib import Path
E = Path(__file__).resolve().parent.parent
R = Path('/Users/mackianni/forge')
D = E / 'diff'
src = (E / 'subset_rule.py').read_text()
block = src[src.index('# BEGIN GATE BLOCK\n') + len('# BEGIN GATE BLOCK\n'):src.index('# END GATE BLOCK')]
orig = subprocess.run(['git', '-C', str(R), 'show', '985f5eaf:gate/refund.py'], capture_output=True, check=True).stdout.decode()
assert orig == (R / 'gate/refund.py').read_text(), 'working gate/refund.py differs from 985f5eaf'
CALL = ('    # Termination by construction (SUBSET.md): a straight-line decision with no loop, recursion,\n'
        '    # comprehension, such-that or unbounded growth in compiled code. Unsure shapes are refused.\n'
        '    straight_line_subset(code)\n')

def patch(text, after_marker):
    assert text.count('\n\ndef prepare():') == 1 and text.count(after_marker) == 1
    text = text.replace('\n\ndef prepare():', '\n\n' + block.rstrip('\n') + '\n\n\ndef prepare():')
    return text.replace(after_marker, after_marker + CALL)

ATTR = "        raise Rejected('SOURCE_SCOPE: only assertion-isolation attributes allowed')\n"
EXP = "        raise Rejected('SOURCE_SCOPE: run-time halt statement expect is not allowed')\n"
for name, base, marker in (('standalone', orig, ATTR), ('combined', None, EXP)):
    w = D / name
    shutil.rmtree(w, ignore_errors=True)
    (w / 'a/gate').mkdir(parents=True); (w / 'b/gate').mkdir(parents=True)
    (w / 'a/gate/refund.py').write_text(orig)
    if base is None:
        (w / 'b/gate/refund.py').write_text(orig)
        subprocess.run(['patch', '-s', '-p1', '-d', str(w / 'b'), '-i',
                        str(E.parent / 'e-expect/p3/refund-expect-and-supervision.diff')], check=True)
        base = (w / 'b/gate/refund.py').read_text()
        (w / 'expect-and-supervision.refund.py').write_text(base)
    (w / 'b/gate/refund.py').write_text(patch(base, marker))
    out = subprocess.run(['diff', '-u', '--label', 'a/gate/refund.py', '--label', 'b/gate/refund.py',
                          str(w / 'a/gate/refund.py'), str(w / 'b/gate/refund.py')], capture_output=True).stdout
    (D / ('refund-subset-%s.diff' % name)).write_bytes(out)
# incremental: expect+supervision -> combined
w = D / 'combined'
out = subprocess.run(['diff', '-u', '--label', 'a/gate/refund.py', '--label', 'b/gate/refund.py',
                      str(w / 'expect-and-supervision.refund.py'), str(w / 'b/gate/refund.py')], capture_output=True).stdout
(D / 'refund-subset-on-top-of-expect-and-supervision.diff').write_bytes(out)
for f in sorted(D.glob('*.diff')):
    print(hashlib.sha256(f.read_bytes()).hexdigest(), f.name, len(f.read_bytes().splitlines()), 'lines')
