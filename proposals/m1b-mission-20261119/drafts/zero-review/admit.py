#!/usr/bin/env python3
"""Admission rule of the refund CRITICAL obligation, mirrored from gate/refund.py (main tree, read only).

Mirrored checks (gate/refund.py line numbers):
  M1  lines 80-82   approved spec bytes: SHA-256 of spec/refund/RefundSpec.dfy == 90a21c71...
  M2  lines 99-102  impl starts with the exact prefix; the bytes 'include' occur exactly once
  M3  lines 104-105 no '{:' except '{:isolate_assertions}'; no '@'
  M4  lines 106-107 binding adds no include (fixed trusted copy; checked anyway)
  M5  lines 131-137 dafny audit impl/Refund.dfy gate/refund/Bindings.dfy --report-format md
                    --report-file <copy of empty baseline> --compare-report ; exit must be 0
  M6  lines 138-143 dafny verify impl/Refund.dfy gate/refund/Bindings.dfy <OPTIONS> --json-output
                    --log-format trx;LogFileName=... ; exit must be 0
  M7  lines 144-149 TRX: REQUIRED names present (batch suffix removed), every outcome Passed
  M8  lines 254-260 final audit, same as M5
NOT mirrored: toolchain pin and Python checks (83-98, not submission-dependent), the evidence bundle,
snapshot/INPUT_CHANGED (292), policy, and the hostile-tests tier (JS build and fast-check, 153-194).
OPTIONS = gate/backends/dafny.py lines 352-356 (solver path made absolute). cwd = the work tree root,
as the gate uses cwd=ROOT (line 66). One Dafny process at a time; memory check before each run.
Usage: python3 admit.py [name ...]   (default: every entry of manifest.json)
"""
import hashlib, json, re, shutil, subprocess, sys, time
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path('<HOME>/forge')
DAFNY = REPO / '.toolchain/dafny-4.11.0/dafny/dafny'
OPTIONS = ['--solver-path', str(REPO / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'),
           '--resource-limit', '1000000', '--verification-time-limit', '0',
           '--cores', '1', '--verify-included-files', '--track-print-effects']
SPEC_SHA = '90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57'
BINDING = 'gate/refund/Bindings.dfy'
PREFIX = b'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
REQUIRED = {
    'Refund.Assess (correctness)', 'Refund.Assess (well-formedness)',
    'RefundSpec.Assess (well-formedness)', 'RefundSpec.Eligible (well-formedness)',
    'RefundChecks.Universal (correctness)', 'RefundChecks.SuccessfulWitness (correctness)',
}


def sha(b):
    return hashlib.sha256(b).hexdigest()


def memory_ok():
    for _ in range(30):
        out = subprocess.run(['memory_pressure'], capture_output=True, text=True).stdout
        m = re.search(r'free percentage: (\d+)%', out)
        if m and int(m.group(1)) >= 15:
            return int(m.group(1))
        time.sleep(10)
    raise SystemExit('memory too low; stop')


def dafny(args, cwd, log, timeout=900):
    free = memory_ok()
    t = time.time()
    try:
        c = subprocess.run([str(DAFNY), *args], cwd=cwd, capture_output=True, text=True, timeout=timeout)
        code, text = c.returncode, c.stdout + c.stderr
    except subprocess.TimeoutExpired as e:
        code, text = 'TIMEOUT', str(e)
    log.write_text('argv: %r\nfree%%: %s\nseconds: %.1f\nexit: %s\n\n%s' % (args, free, time.time() - t, code, text))
    return code, text


def admit(name, extra):
    work = HERE / 'work' / name
    shutil.rmtree(work, ignore_errors=True)
    shutil.copytree(HERE / 'base', work)
    (work / 'impl').mkdir()
    code = (HERE / 'subs' / (name + '.dfy')).read_bytes()
    (work / 'impl/Refund.dfy').write_bytes(code)
    for rel, text in extra.items():
        p = work / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    r = {'audit_before': None, 'verify': None, 'audit_after': None}
    if sha((work / 'spec/refund/RefundSpec.dfy').read_bytes()) != SPEC_SHA:          # M1
        return r, 'REFUSED', 'M1 APPROVED_CONTRACT'
    if not code.startswith(PREFIX) or code.count(b'include') != 1:                   # M2
        return r, 'REFUSED', 'M2 SOURCE_SCOPE prefix/sole include'
    if b'{:' in code.replace(b'{:isolate_assertions}', b'') or b'@' in code:         # M3
        return r, 'REFUSED', 'M3 SOURCE_SCOPE attribute or @'
    if b'include' in (work / BINDING).read_bytes().replace(b'include paths', b''):    # M4
        return r, 'REFUSED', 'M4 binding include'
    def audit(tag):
        report = work / (tag + '.md')
        report.write_bytes((HERE / 'base/gate/expected-audit.md').read_bytes())
        c, t = dafny(['audit', 'impl/Refund.dfy', BINDING, '--report-format', 'md', '--report-file',
                      str(report), '--compare-report'], work, work / (tag + '.log'))
        return c
    r['audit_before'] = audit('audit-before')                                        # M5
    if r['audit_before'] != 0:
        return r, 'REFUSED', 'M5 AUDIT_REJECTED'
    trx = work / 'verification.trx'
    r['verify'], text = dafny(['verify', 'impl/Refund.dfy', BINDING, *OPTIONS, '--json-output',
                               '--log-format', 'trx;LogFileName=' + str(trx)], work, work / 'verify.log')
    if r['verify'] != 0:                                                             # M6
        return r, 'REFUSED', 'M6 VERIFICATION_REJECTED'
    rows = [(e.get('testName'), e.get('outcome')) for e in ET.parse(trx).iter() if e.tag.endswith('UnitTestResult')]
    members = {re.sub(r' \(assertion batch \d+\)$', '', n) for n, _ in rows}
    r['trx_rows'] = len(rows)
    if not REQUIRED <= members or any(o != 'Passed' for _, o in rows):               # M7
        return r, 'REFUSED', 'M7 PROOF_COVERAGE missing=%s' % sorted(REQUIRED - members)
    r['audit_after'] = audit('audit-after')                                          # M8
    if r['audit_after'] != 0:
        return r, 'REFUSED', 'M8 AUDIT_REJECTED final'
    return r, 'ADMITTED', 'all mirrored checks passed'


def first_diag(name):
    work = HERE / 'work' / name
    for log in ('audit-before.log', 'verify.log', 'audit-after.log'):
        p = work / log
        if p.exists():
            for line in p.read_text().splitlines():
                if re.search(r'Error|error|Warning|warning|Possible|assumption|Verified|verified', line) and len(line) < 400:
                    return log + ': ' + line.strip()[:300]
    return ''


def main():
    manifest = json.loads((HERE / 'manifest.json').read_text())
    names = sys.argv[1:] or list(manifest)
    results = json.loads((HERE / 'results.json').read_text()) if (HERE / 'results.json').exists() else {}
    for name in names:
        m = manifest[name]
        r, verdict, why = admit(name, m['extra_files'])
        ideal = 'ADMITTED' if m['expected_admitted'] else 'REFUSED'
        results[name] = {'kind': m['kind'], 'ideal': ideal, 'actual': verdict, 'why': why,
                         'exit_codes': r, 'gate_exit': 0 if verdict == 'ADMITTED' else 1,
                         'diag': first_diag(name), 'submission_sha256': sha((HERE / 'subs' / (name + '.dfy')).read_bytes())}
        print('%-34s %-9s ideal=%-8s actual=%-8s %s %s' % (name, m['kind'], ideal, verdict, why, r), flush=True)
        (HERE / 'results.json').write_text(json.dumps(results, indent=1) + '\n')
    bad = [n for n in names if results[n]['ideal'] != results[n]['actual']]
    print('MISMATCH between ideal and actual:', bad)
    return 0


if __name__ == '__main__':
    sys.exit(main())
