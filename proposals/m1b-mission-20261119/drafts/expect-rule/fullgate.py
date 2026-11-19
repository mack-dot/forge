#!/usr/bin/env python3
"""Mirror of ALL submission-dependent tiers of gate/refund.py (repo read only), --tier hostile-tests.

Order and checks (gate/refund.py line numbers):
  P   99-107  source scope byte rules (same as Y5 admit.py M2-M4); spec digest (80-82)
  A1  131-137 dafny audit impl/Refund.dfy gate/refund/Bindings.dfy --report-format md --report-file <copy of
              gate/expected-audit.md> --compare-report     (exit must be 0)
  V   138-149 dafny verify impl/Refund.dfy BINDING <OPTIONS> --json-output --log-format trx;LogFileName=...
              (exit 0; REQUIRED TRX rows present; every outcome Passed)
  B   159-167 rm build/refund-generated/model.{js,cjs}; dafny build impl/Refund.dfy --target js
              --output build/refund-generated/model <OPTIONS>   (exit must be 0)
  F   168-171 model.cjs = model.js + FOOTER
  H   175-179 node --import tsx gate/refund/hostile.ts --module build/refund-generated/model.cjs
              --report <work>/hostile.json      (exit must be 0)
  R   180-186 report checks: result passed, method property_tested, runs == 3 claims x seeds 8001..8003 x 1000,
              generated_cases 9000, fixture_cases >= 20, model_quality unmeasured
  A2  254-260 final audit, as A1
Deviations (stated): Dafny runs through dafny_locked.sh (WAVE4_RULES 11); solver path absolute (same binary);
the copy tree has symlinks node_modules -> repo/node_modules (read only); a wall-clock timeout and an RSS
watchdog guard the node process (the gate has NONE: a hang there is a hang of the gate, never an ACCEPTED).
Toolchain pin checks (83-98, 156, 189) are not submission dependent; javascript_env.check run once from the repo.
Usage: fullgate.py <sub.dfy> <name> [timeout_s] [rss_limit_MB]
"""
import hashlib, json, os, re, shutil, signal, subprocess, sys, time
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path('<HOME>/forge')
LOCKED = HERE.parent / 'dafny_locked.sh'
NODE = '/opt/homebrew/bin/node'
OPTIONS = ['--solver-path', str(REPO / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'),
           '--resource-limit', '1000000', '--verification-time-limit', '0',
           '--cores', '1', '--verify-included-files', '--track-print-effects']
BINDING = 'gate/refund/Bindings.dfy'
TEST = 'gate/refund/hostile.ts'
PREFIX = b'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
FOOTER = b'\nmodule.exports = { Refund, runtime: _dafny };\n'
REQUIRED = {'Refund.Assess (correctness)', 'Refund.Assess (well-formedness)',
            'RefundSpec.Assess (well-formedness)', 'RefundSpec.Eligible (well-formedness)',
            'RefundChecks.Universal (correctness)', 'RefundChecks.SuccessfulWitness (correctness)'}
COPY = ['spec/refund/RefundSpec.dfy', BINDING, 'gate/expected-audit.md', TEST, 'ts/refund.ts',
        'package.json', 'package-lock.json', 'tsconfig.json']
SPEC_SHA = '90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57'


def sha(b): return hashlib.sha256(b).hexdigest()


def mem_ok():
    for _ in range(60):
        out = subprocess.run(['memory_pressure'], capture_output=True, text=True).stdout
        m = re.search(r'free percentage: (\d+)%', out)
        if m and int(m.group(1)) >= 20:
            return int(m.group(1))
        time.sleep(10)
    raise SystemExit('memory too low; stop')


def run(argv, cwd, log, timeout=1800, rss_mb=None, env=None):
    free = mem_ok(); t = time.time(); peak = 0; note = ''
    with open(str(log) + '.out', 'wb') as out:
        p = subprocess.Popen(argv, cwd=cwd, stdout=out, stderr=subprocess.STDOUT, env=env, start_new_session=True)
        while p.poll() is None:
            time.sleep(1)
            if rss_mb:
                ps = subprocess.run(['ps', '-o', 'rss=', '-p', str(p.pid)], capture_output=True, text=True).stdout
                rss = sum(int(x) for x in ps.split() if x.isdigit()) // 1024
                peak = max(peak, rss)
                if rss > rss_mb:
                    note = 'KILLED_BY_WATCHDOG rss>%dMB' % rss_mb; os.killpg(p.pid, signal.SIGKILL); break
            if time.time() - t > timeout:
                note = 'KILLED_BY_WATCHDOG timeout>%ds' % timeout; os.killpg(p.pid, signal.SIGKILL); break
        code = p.wait()
    rec = {'argv': argv, 'exit': code, 'seconds': round(time.time() - t, 1), 'free_pct': free, 'peak_rss_mb': peak,
           'note': note}
    Path(str(log) + '.run.json').write_text(json.dumps(rec, indent=1))
    print('  %-12s exit=%s %.1fs %s' % (Path(log).name, code, rec['seconds'], note), flush=True)
    return rec


def main():
    sub, name = Path(sys.argv[1]), sys.argv[2]
    timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 600
    rss = int(sys.argv[4]) if len(sys.argv) > 4 else 2500
    w = HERE / 'tree' / name
    shutil.rmtree(w, ignore_errors=True)
    for rel in COPY:
        (w / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / rel, w / rel)
    os.symlink(REPO / 'node_modules', w / 'node_modules')
    (w / 'impl').mkdir()
    code = sub.read_bytes()
    (w / 'impl/Refund.dfy').write_bytes(code)
    logs = w / 'logs'; logs.mkdir()
    res = {'name': name, 'submission_sha256': sha(code), 'steps': {}}
    def done(verdict, why):
        res['verdict'], res['why'] = verdict, why
        (logs / 'result.json').write_text(json.dumps(res, indent=1))
        print('%s: %s (%s)' % (name, verdict, why), flush=True)
        return 0
    if sha((w / 'spec/refund/RefundSpec.dfy').read_bytes()) != SPEC_SHA:
        return done('REFUSED', 'APPROVED_CONTRACT')
    if not code.startswith(PREFIX) or code.count(b'include') != 1:
        return done('REFUSED', 'P SOURCE_SCOPE prefix/include (refund.py:101-102)')
    if b'{:' in code.replace(b'{:isolate_assertions}', b'') or b'@' in code:
        return done('REFUSED', 'P SOURCE_SCOPE attribute/@ (refund.py:104-105)')
    def audit(tag):
        rep = logs / (tag + '.md'); rep.write_bytes((w / 'gate/expected-audit.md').read_bytes())
        return run(['sh', str(LOCKED), 'audit', 'impl/Refund.dfy', BINDING, '--report-format', 'md',
                    '--report-file', str(rep), '--compare-report'], w, logs / tag)
    r = audit('audit-before'); res['steps']['A1'] = r['exit']
    if r['exit']: return done('REFUSED', 'A1 AUDIT_REJECTED (refund.py:136-137)')
    trx = logs / 'verification.trx'
    r = run(['sh', str(LOCKED), 'verify', 'impl/Refund.dfy', BINDING, *OPTIONS, '--json-output', '--log-format',
             'trx;LogFileName=' + str(trx)], w, logs / 'verify'); res['steps']['V'] = r['exit']
    if r['exit']: return done('REFUSED', 'V VERIFICATION_REJECTED (refund.py:142-143)')
    rows = [(e.get('testName'), e.get('outcome')) for e in ET.parse(trx).iter() if e.tag.endswith('UnitTestResult')]
    members = {re.sub(r' \(assertion batch \d+\)$', '', n) for n, _ in rows}
    if not REQUIRED <= members or any(o != 'Passed' for _, o in rows):
        return done('REFUSED', 'V PROOF_COVERAGE (refund.py:148-149)')
    d = w / 'build/refund-generated'; d.mkdir(parents=True, exist_ok=True)
    r = run(['sh', str(LOCKED), 'build', 'impl/Refund.dfy', '--target', 'js', '--output',
             'build/refund-generated/model', *OPTIONS], w, logs / 'compile-js'); res['steps']['B'] = r['exit']
    if r['exit'] or not (d / 'model.js').exists():
        return done('REFUSED', 'B BUILD_ERROR, gate exit 2 (refund.py:166-167)')
    gen = (d / 'model.js').read_bytes(); (d / 'model.cjs').write_bytes(gen + FOOTER)
    res['generated_js_sha256'] = sha(gen)
    env = dict(os.environ); env['PATH'] = '/opt/homebrew/bin:' + env['PATH']
    hrep = logs / 'hostile-report.json'
    r = run([NODE, '--import', 'tsx', TEST, '--module', 'build/refund-generated/model.cjs', '--report',
             str(hrep)], w, logs / 'hostile', timeout=timeout, rss_mb=rss, env=env)
    res['steps']['H'] = r['exit']; res['hostile_note'] = r['note']; res['hostile_seconds'] = r['seconds']
    res['hostile_peak_rss_mb'] = r['peak_rss_mb']
    if hrep.exists():
        rep = json.loads(hrep.read_text())
        res['hostile_report'] = {k: rep.get(k) for k in ('result', 'fixture_cases', 'generated_cases', 'runs',
                                                         'active_fixture', 'error', 'failure')}
    if r['note']:
        return done('NO-VERDICT', 'H hangs/aborts; the gate has no timeout: ' + r['note'])
    if r['exit']:
        return done('REFUSED', 'H HOSTILE_REJECTED (refund.py:178-179)')
    rep = json.loads(hrep.read_text())
    exp = [{'claim_id': c, 'seed': s, 'num_runs': 1000, 'failed': False} for c in ('T1', 'T2', 'T3')
           for s in (8001, 8002, 8003)]
    if (rep.get('result') != 'passed' or rep.get('method') != 'property_tested' or rep.get('runs') != exp or
            rep.get('generated_cases') != 9000 or rep.get('fixture_cases', 0) < 20 or
            rep.get('model_quality') != 'unmeasured'):
        return done('REFUSED', 'R TEST_COVERAGE (refund.py:185-186)')
    r = audit('audit-after'); res['steps']['A2'] = r['exit']
    if r['exit']: return done('REFUSED', 'A2 AUDIT_REJECTED final (refund.py:259-260)')
    return done('ADMITTED', 'all submission-dependent tiers passed')


if __name__ == '__main__':
    sys.exit(main())
