"""x-bridge2: mutation controls on decide2.py. Each mutant = ONE exact replacement (all occurrences when
marked ALL). The quick suite (tests2.py run quick <mutant>) runs once per mutant; killed = exit != 0.
Run under env -i like tests2.py. Writes run/mutants2.json."""
import json
import os
import shutil
import subprocess
import sys

X = os.path.dirname(os.path.abspath(__file__))
PYEXE = '/Library/Frameworks/Python.framework/Versions/3.10/bin/python3'
M = [
    ('drop-post-compare', "        if not _same(dataclasses.astuple(c.post), dataclasses.astuple(post)):\n"
                          "            return Decision(False, 'POST_MISMATCH')\n", ''),
    ('drop-intent-compare', "        if not _same(dataclasses.astuple(c.intent), dataclasses.astuple(intent)):\n"
                            "            return Decision(False, 'INTENT_MISMATCH')\n", ''),
    ('ignore-check-ALL', "if issue is not True:", "if False:"),
    ('ignore-native-frame', "        if not _same(tuple(nat), exp) or out != frame.render_fields(*exp):\n"
                            "            return Decision(False, 'FRAME_NOT_AUTHORIZED_TUPLE')\n", ''),
    ('frame-compare-fields-only', " or out != frame.render_fields(*exp)", ''),
    ('frame-compare-plain-eq', "not _same(tuple(nat), exp)", "tuple(nat) != exp"),
    ('post-from-candidate-amount', "c.pre.remaining - amount", "c.pre.remaining - c.request.amount"),
    ('intent-request-from-candidate', "nat[4].decode('utf-8', 'strict')", "c.request.request_id"),
    ('intent-decode-latin1', "nat[2].decode('utf-8', 'strict')", "nat[2].decode('latin-1')"),
    ('encode-latin1', "    return s.encode('utf-8')\n\n\ndef encode", "    return s.encode('latin-1', 'replace')\n\n\ndef encode"),
    ('hash-of-post', "'preStateSha256': pre_state_sha256(c.pre)", "'preStateSha256': pre_state_sha256(c.post)"),
    ('token-from-candidate', "'post': state_json(post), 'intent': intent_json(intent)}",
                             "'post': state_json(c.post), 'intent': intent_json(c.intent)}"),
    ('range-drop-bool-type', "and type(c.remaining) is int and type(c.enabled) is bool)", "and type(c.remaining) is int)"),
    ('range-drop-text-length', "    return len(s.encode('utf-16-le')) // 2 <= MAX_TEXT_UTF16\n", "    return True\n"),
    ('decide2-drop-range', "        if not in_range(c):\n            return Decision(False, 'OUT_OF_RANGE')\n        if issue",
                           "        if issue"),
    ('drop-stderr-check', "        if r.stderr_len != 0:\n", "        if False:\n"),
    ('drop-exit-check', "        if r.exit_code != 0 or type(r.exit_code) is not int:\n", "        if False:\n"),
    ('drop-stdin-complete', "        if r.stdin_complete is not True:\n", "        if False:\n"),
    ('drop-copy-unchanged', "        if r.copy_unchanged is not True:\n", "        if False:\n"),
    ('drop-timeout-check', "        if r.timed_out:\n", "        if False:\n"),
    ('drop-signal-check', "        if r.signal is not None:\n", "        if False:\n"),
    ('count-not-checked', "    return (True, x[7], x[8], x[0], x[1], 1)", "    return (True, x[7], x[8], x[0], x[1], 2)"),
]


def main():
    src = open(os.path.join(X, 'decide2.py')).read()
    out = []
    for name, a, b in M:
        n = src.count(a)
        if n == 0 or (n > 1 and not name.endswith('-ALL')):
            out.append({'mutant': name, 'status': 'NOT_APPLIED', 'count': n})
            continue
        d = os.path.join(X, 'mutants', name)
        os.makedirs(d, exist_ok=True)
        shutil.copy(os.path.join(X, 'frame.py'), d)
        mp = os.path.join(d, 'decide2.py')
        open(mp, 'w').write(src.replace(a, b))
        p = subprocess.run([PYEXE, '-I', os.path.join(X, 'tests2.py'), 'run', 'quick', mp], capture_output=True,
                           timeout=300, env={'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': X})
        lines = p.stdout.decode('utf-8', 'replace').splitlines()
        fails = [l for l in lines if l.startswith('FAIL')]
        out.append({'mutant': name, 'exit': p.returncode, 'status': 'KILLED' if p.returncode != 0 else 'SURVIVED',
                    'failing_tests': [l[:160] for l in fails][:6], 'n_fail': len(fails),
                    'stderr_tail': p.stderr.decode('utf-8', 'replace')[-300:] if p.returncode not in (0, 1) else ''})
        print(out[-1]['status'], name, len(fails), (fails[0][:120] if fails else ''))
    json.dump(out, open(os.path.join(X, 'run', 'mutants2.json'), 'w'), indent=1)
    k = sum(o['status'] == 'KILLED' for o in out)
    print('mutants', len(out), 'killed', k, 'survived', sum(o['status'] == 'SURVIVED' for o in out),
          'not_applied', sum(o['status'] == 'NOT_APPLIED' for o in out))


if __name__ == '__main__':
    sys.exit(main())
