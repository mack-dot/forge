"""x-bridge3 G4: small mutants of native_bridge.ts (exact text replacements; each must apply exactly once).
Writes mutants/<name>/native_bridge.ts and mutants/list.json. A mutant is KILLED when run_ts.ts reports at least
one difference from the Python reference results (exit 1)."""
import json, os
X = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(X, 'native_bridge.ts')).read()
M = {
 'M01-skip-digest': [('if (!sameHex(sha256hex(data), pinned)) return', 'if (false) return')],
 'M02-inherit-env': [('spawn(copy, [], { cwd, env, stdio', 'spawn(copy, [], { cwd, env: { ...process.env, ...env }, stdio')],
 'M03-skip-stderr': [('    if (r.stderrLen !== 0) return refuse("STDERR_NONEMPTY");\n', '')],
 'M04-longer-stdout': [('REJECTED_BYTES.length);', 'REJECTED_BYTES.length) + 64;')],
 'M05-fields-only-no-bytes-eq': [(' || !out.equals(renderFields(...exp))', '')],
 'M06-skip-post-recompute': [('const post: Charge = { chargeId: c.pre.chargeId, original: c.pre.original, remaining: c.pre.remaining - amount, enabled: c.pre.enabled };',
                              'const post: Charge = c.post;')],
 'M07-skip-intent-compare': [('    if (!sameIntent(c.intent, intent)) return refuse("INTENT_MISMATCH");\n', '')],
 'M08-ignore-timeout': [('const timer = setTimeout(() => { timedOut = true; stop(); }, timeoutMs);', 'const timer: any = undefined;')],
 'M09-lax-int-040': [('return x.length === 1 || x[0] !== 48;', 'return true;')],
 'M10-decode-latin1': [('requestId: utf8.decode(nat[4]), amount, reason: utf8.decode(nat[2])',
                        'requestId: nat[4].toString("latin1"), amount, reason: nat[2].toString("latin1")')],
 'M11-ignore-exit': [('    if (r.exitCode !== 0) return refuse("EXIT_NONZERO");\n', '')],
 'M12-ignore-count-field': [('a.every((v, k) => {', 'a.every((v, k) => { if (k === 5) return true;')],
 'M13-encode-latin1': [('return Buffer.from(s, "utf8");', 'return Buffer.from(s, "latin1");')],
 'M14-skip-signal': [('    if (r.signal !== null) return refuse("SIGNAL");\n', '')],
 'M15-skip-stdin-complete': [('    if (r.stdinComplete !== true) return refuse("STDIN_INCOMPLETE");\n', '')],
 'M16-skip-copy-unchanged': [('    if (r.copyUnchanged !== true) return refuse("BINARY_CHANGED");\n', '')],
 'M17-decide-no-range': [('    if (!inRange(c)) return refuse("OUT_OF_RANGE");\n    if (issue !== true)', '    if (issue !== true)')],
 'M18-issue-truthy': [('if (issue !== true) return refuse("CHECK_REFUSE");', 'if (!issue) return refuse("CHECK_REFUSE");')],
 'M19-no-rerender-in-parse': [('  if (!renderFields(...out).equals(s)) throw new FrameErr("strict: re-render differs");\n', '')],
 'M20-kill-pid-not-group': [('process.kill(-pid, "SIGKILL")', 'process.kill(pid, "SIGKILL")')],
 'M21-skip-overflow': [('    if (r.stdoutOverflow) return refuse("STDOUT_OVERFLOW");\n', '')],
 # combined: remove both redundant checks of one property
 'M22-count-and-bytes-eq': [('a.every((v, k) => {', 'a.every((v, k) => { if (k === 5) return true;'), (' || !out.equals(renderFields(...exp))', '')],
 'M23-lax-int-and-no-rerender': [('return x.length === 1 || x[0] !== 48;', 'return true;'),
                                 ('  if (!renderFields(...out).equals(s)) throw new FrameErr("strict: re-render differs");\n', '')],
}
lst = []
for name, reps in M.items():
    s = src
    for a, b in reps:
        assert s.count(a) == 1, (name, a)
        s = s.replace(a, b)
    d = os.path.join(X, 'mutants', name); os.makedirs(d, exist_ok=True)
    open(os.path.join(d, 'native_bridge.ts'), 'w').write(s)
    lst.append(name)
json.dump(lst, open(os.path.join(X, 'mutants', 'list.json'), 'w'), indent=0)
print('mutants', len(lst))
