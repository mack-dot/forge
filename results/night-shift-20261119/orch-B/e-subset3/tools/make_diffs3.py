#!/usr/bin/env python3
"""Build the UNAPPLIED gate diffs for subset rule 3 on COPIES (under ../diff/work). Never writes under gate/.
Same composition as orch-B/e-subset2/tools/make_diffs2.py; only the gate block and its call differ."""
import hashlib, shutil, subprocess
from pathlib import Path
E = Path(__file__).resolve().parent.parent
B = E.parent
R = Path('<REPO>')
D = E / 'diff'
src = (E / 'subset_rule3.py').read_text()
block = src[src.index('# BEGIN GATE BLOCK\n') + len('# BEGIN GATE BLOCK\n'):src.index('# END GATE BLOCK')]
orig = subprocess.run(['git', '-C', str(R), 'show', '985f5eaf:gate/refund.py'], capture_output=True,
                      check=True).stdout.decode()
assert orig == (R / 'gate/refund.py').read_text(), 'working gate/refund.py differs from 985f5eaf'
CALL = ('    # Strict core subset (rule 3; cost claim above bounded_subset3): straight-line compiled code over if/match,\n'
        '    # no loop, no recursion, no growth operator, no extra module, no shadowing. Unknown forms are refused.\n'
        '    bounded_subset3(code)\n')
ATTR = "        raise Rejected('SOURCE_SCOPE: only assertion-isolation attributes allowed')\n"
EXP = "        raise Rejected('SOURCE_SCOPE: run-time halt statement expect is not allowed')\n"
OLD_LINE_END = ("# Fail closed: a `//` comment ends at the earliest possible line break (Dafny 4.11 ends it at a lone CR).\n"
                "LINE_END = re.compile('[\\r\\n\\x0b\\x0c\\x85\\u2028\\u2029]')\n")
NEW_LINE_END = ("# A `//` comment ends at CR or LF, as in the pinned Dafny 4.11 (controls L01-L06: VT, FF, NEL, LS\n"
                "# and PS do not end it). bounded_subset3 refuses control characters other than these.\n"
                "LINE_END = re.compile('[\\r\\n]')\n")
OLD_PREFIX = ("    if not code.startswith(prefix) or code.count(b'include') != 1:\n")
NEW_PREFIX = ("    # CRLF line ends are allowed. A second include can only be a line that starts with `include`; Dafny\n"
              "    # also refuses an include after the first module (controls L07, L08). `include` in a comment is text.\n"
              "    text = code.replace(b'\\r\\n', b'\\n')\n"
              "    if not text.startswith(prefix) or re.search(rb'(?m)^[ \\t]*include\\b', text[len(prefix):]):\n")
OLD_ATTR = "    if b'{:' in code.replace(b'{:isolate_assertions}', b'') or b'@' in code:\n"
NEW_ATTR_BYTES = ("    if (b'{:' in code.replace(b'{:isolate_assertions}', b'').replace(b'{:induction false}', b'') or\n"
                  "            b'@' in code):\n")
NEW_ATTR_TOKENS = ("    # `@` in a comment or string literal is text; bounded_subset3 refuses an `@` token in code.\n"
                   "    if b'{:' in code.replace(b'{:isolate_assertions}', b'').replace(b'{:induction false}', b''):\n")


def once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)


def with_block(text, marker):
    assert text.count('\n\ndef prepare():') == 1
    text = text.replace('\n\ndef prepare():', '\n\n' + block.rstrip('\n') + '\n\n\ndef prepare():')
    return once(text, marker, marker + CALL)


w = D / 'work'
shutil.rmtree(w, ignore_errors=True)
(w / 'a/gate').mkdir(parents=True)
(w / 'a/gate/refund.py').write_text(orig)
(w / 'e/gate').mkdir(parents=True)
(w / 'e/gate/refund.py').write_text(orig)
subprocess.run(['patch', '-s', '-p1', '-d', str(w / 'e'), '-i',
                str(B / 'e-expect/p3/refund-expect-and-supervision.diff')], check=True)
expect_base = (w / 'e/gate/refund.py').read_text()
variants = {
    'refund-subset3-standalone': with_block(orig, ATTR),
    'refund-subset3-combined': once(with_block(expect_base, EXP), OLD_LINE_END, NEW_LINE_END),
    'refund-scope-minimal': once(once(orig, OLD_PREFIX, NEW_PREFIX), OLD_ATTR, NEW_ATTR_BYTES),
}
variants['refund-subset3-combined-scope'] = once(once(variants['refund-subset3-combined'], OLD_PREFIX, NEW_PREFIX),
                                                 OLD_ATTR, NEW_ATTR_TOKENS)
for name, text in variants.items():
    (w / name / 'gate').mkdir(parents=True)
    (w / name / 'gate/refund.py').write_text(text)
    out = subprocess.run(['diff', '-u', '--label', 'a/gate/refund.py', '--label', 'b/gate/refund.py',
                          str(w / 'a/gate/refund.py'), str(w / name / 'gate/refund.py')], capture_output=True).stdout
    (D / (name + '.diff')).write_bytes(out)
for f in sorted(D.glob('*.diff')):
    print(hashlib.sha256(f.read_bytes()).hexdigest(), f.name, len(f.read_bytes().splitlines()), 'lines')
