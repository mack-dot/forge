"""Mutation controls for decide.py and launcher.py. Each mutant is one source replacement. A mutant is
KILLED when at least one test of tests.run_suite fails (or the suite raises). Writes run/mutants.json.
Run under env -i. TESTED-UNPROVED."""
import json
import os
import sys
import types

X = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, X)
import tests as T  # noqa: E402

MUTANTS = [
    ('D-reject-all', 'decide.py', "        return Decision(True, 'SIGN')", "        return Decision(False, 'SIGN')"),
    ('D-ignore-native', 'decide.py', "        if not r.launched:\n",
     "        if d.issue: return Decision(True, 'SIGN')\n        if not r.launched:\n"),
    ('D-no-range', 'decide.py', "    if not in_range(x):", "    if False:"),
    ('D-no-timeout', 'decide.py', "        if r.timed_out:", "        if False:"),
    ('D-no-signal', 'decide.py', "        if r.signal is not None:", "        if False:"),
    ('D-no-exit', 'decide.py', "        if r.exit_code != 0:", "        if False:"),
    ('D-no-stderr', 'decide.py', "        if r.stderr_len != 0:", "        if False:"),
    ('D-no-overflow', 'decide.py', "        if r.stdout_overflow:", "        if False:"),
    ('D-no-stdin-complete', 'decide.py', "        if not r.stdin_complete:", "        if False:"),
    ('D-no-copy-check', 'decide.py', "        if not r.copy_unchanged:", "        if False:"),
    ('D-lenient-parse-rstrip', 'decide.py', "        nat = frame.strict_accepts(out)",
     "        nat = frame.strict_accepts(out.rstrip(b' \\n'))"),
    ('D-lenient-parse-prefix', 'decide.py', "        nat = frame.strict_accepts(out)",
     "        nat = frame.strict_accepts(out) or frame.strict_accepts(expected_bytes) if out and expected_bytes.startswith(out) else frame.strict_accepts(out)"),
    ('D-no-false-canonical', 'decide.py', "        if nat[0] is False and out != frame.REJECTED_BYTES:", "        if False:"),
    ('D-skip-field-amount', 'decide.py', "            if a != b:", "            if a != b and name != 'amount':"),
    ('D-skip-field-reason', 'decide.py', "            if a != b:", "            if a != b and name != 'reason':"),
    ('D-skip-field-charge', 'decide.py', "            if a != b:", "            if a != b and name != 'charge':"),
    ('D-skip-field-request', 'decide.py', "            if a != b:", "            if a != b and name != 'request':"),
    ('D-skip-field-count', 'decide.py', "            if a != b:", "            if a != b and name != 'count':"),
    ('D-skip-field-authorized', 'decide.py', "            if a != b:", "            if a != b and name != 'authorized':"),
    ('D-skip-bytes', 'decide.py', "        if out != expected_bytes:", "        if False:"),
    ('D-dafny-refuse-signs', 'decide.py', "        if not d.issue:\n", "        if not d.issue and not nat[0]:\n"),
    ('D-latin1-wire', 'decide.py', "    return s.encode('utf-8')\n", "    return s.encode('latin-1', 'replace')\n"),
    ('L-inherit-env', 'launcher.py', "stderr=subprocess.PIPE, env=env,", "stderr=subprocess.PIPE, env=None,"),
    ('L-no-env-filter', 'launcher.py', "    if not _check_env(env):", "    if False:"),
    ('L-no-digest', 'launcher.py', "    if not hmac.compare_digest(hashlib.sha256(data).hexdigest(), pinned_sha256):",
     "    if False:"),
    ('L-keep-fds', 'launcher.py', "close_fds=True, shell=False,", "close_fds=False, shell=False,"),
    ('L-no-timeout', 'launcher.py', "        deadline = t0 + timeout_s\n", "        deadline = t0 + 6.0 + timeout_s\n"),
    ('L-no-killpg', 'launcher.py', "        os.killpg(p.pid, signal.SIGKILL)", "        p.kill()"),
    ('L-no-stdout-cap', 'launcher.py', "                    if len(out) > stdout_cap:", "                    if False:"),
    ('L-no-stdin-eof', 'launcher.py', "                    if not pending:\n                        sel.unregister(f); f.close(); stdin_complete = True",
     "                    if not pending:\n                        sel.unregister(f); stdin_complete = True"),
    ('L-stdin-short', 'launcher.py', "        pending = memoryview(stdin_bytes)", "        pending = memoryview(stdin_bytes[:-1])"),
    ('L-cwd-inherit', 'launcher.py', "env=env, cwd=cwd,", "env=env, cwd=None,"),
]


def module_from(name, path, src):
    m = types.ModuleType(name)
    m.__file__ = path
    exec(compile(src, path, 'exec'), m.__dict__)
    return m


def main():
    rows = {r['name']: r for r in json.load(open(os.path.join(T.RUN, 'dafny_verdicts.json')))}
    pins = T.make_standins()
    src = {f: open(os.path.join(X, f)).read() for f in ('decide.py', 'launcher.py')}
    out = []
    for name, f, old, new in MUTANTS:
        if src[f].count(old) != 1:
            out.append({'mutant': name, 'status': 'NOT_APPLIED', 'count': src[f].count(old)})
            continue
        s = dict(src)
        s[f] = src[f].replace(old, new)
        try:
            D = module_from('decide_m', os.path.join(X, 'decide.py'), s['decide.py'])
            L = module_from('launcher_m', os.path.join(X, 'launcher.py'), s['launcher.py'])
            res = T.run_suite(D, L, rows, pins)
            failed = [r['test'] for r in res if not r['pass']]
            out.append({'mutant': name, 'status': 'KILLED' if failed else 'SURVIVED', 'failed_tests': failed})
        except Exception as e:
            out.append({'mutant': name, 'status': 'KILLED', 'failed_tests': ['suite raised: %r' % e]})
        print(out[-1]['mutant'], out[-1]['status'], (out[-1].get('failed_tests') or [])[:3], flush=True)
    k = sum(o['status'] == 'KILLED' for o in out)
    sv = [o['mutant'] for o in out if o['status'] == 'SURVIVED']
    na = [o['mutant'] for o in out if o['status'] == 'NOT_APPLIED']
    json.dump({'class': 'TESTED-UNPROVED', 'total': len(out), 'killed': k, 'survived': sv, 'not_applied': na,
               'mutants': out}, open(os.path.join(T.RUN, 'mutants.json'), 'w'), indent=1)
    print('total', len(out), 'killed', k, 'survived', sv, 'not_applied', na)
    return 0


if __name__ == '__main__':
    sys.exit(main())
