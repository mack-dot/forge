#!/usr/bin/env python3
"""M1-B mission, step I.1d: checks of the Dafny half of the contract link. Dispatch only.

It starts the pinned Dafny with the gate options and compares exit codes. It decides no proof.
What a pass means: the pinned Dafny verified `LinkedRefund.dfy` (a non-abstract module that REFINES the
approved RefundSpec, so the approved `ensures` R1 to R5 are inherited and not copied) beside the files
it includes; each wrong variant is rejected; the copies of the approved files are byte-equal to the
approved files of this tree. It is the DAFNY HALF only. It does not connect Dafny to the HOL model.
M1-B stays open. Not gate evidence. Raw outputs go to build/m1b-linked-refund/ (ignored by git).

Known and stated: the audit of ALL reached files reports one library lemma with an explicit axiom
(Std.Strings.HexConversion.CharsConsistent). The proof does not call it (by reading); the audit of the
whole closure is therefore NOT equal to the empty baseline, and this script requires exactly that state.

Usage: python3 proposals/m1b-mission-20261119/proofs/linked-refund/run_check.py
"""
import hashlib, json, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'gate'))
from backends import dafny  # noqa: E402  (the gate's own Dafny path and options)

INPUTS = HERE / 'inputs'
APPROVED = {'transport/spec/refund/RefundSpec.dfy': 'spec/refund/RefundSpec.dfy',
            'transport/impl/Refund.dfy': 'impl/Refund.dfy',
            'transport/clearing/RefundExact.dfy': 'clearing/RefundExact.dfy'}
PROOF_SHA256 = '0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34'
# control -> expected checker exit. N5 passes on purpose: a decoder that reads the request hides the gap.
CONTROLS = {'N1-unflatten-swap': 4, 'N1b-flatten-swap': 4, 'N2-amount-plus-one': 4, 'N3a-drop-flat-ensures-1': 4,
            'N3b-drop-flat-ensures-2': 4, 'N3c-drop-flat-ensures-3': 4, 'N4-count0-authorized': 4,
            'N5-decode-reads-response': 0}
OPTIONS = [('--solver-path' if False else o) for o in dafny.OPTIONS]
OPTIONS = [str(ROOT / o) if o.startswith('.toolchain/') else o for o in OPTIONS]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(folder):
    child = subprocess.run([str(dafny.DAFNY), 'verify', 'LinkedRefund.dfy', *OPTIONS], cwd=folder, capture_output=True, text=True)
    lines = [line for line in (child.stdout + child.stderr).splitlines() if line.strip()]
    return child.returncode, (lines[-1] if lines else ''), sum(': Error: ' in line for line in lines)


def main():
    work = ROOT / 'build/m1b-linked-refund'
    number = 1 + max([int(p.name.split('-')[1]) for p in work.glob('attempt-*')] or [0])
    work = work / ('attempt-%04d' % number)
    work.mkdir(parents=True)
    rows, ok = [], True

    def row(name, expected, actual, detail):
        nonlocal ok
        good = expected == actual
        ok = ok and good
        rows.append({'check': name, 'expected': expected, 'actual': actual, 'detail': detail, 'as_expected': good})
        print('%s: expected %s, actual %s%s' % (name, expected, actual, '' if good else '  <-- NOT AS EXPECTED'), flush=True)

    for copy, approved in APPROVED.items():
        row('copy equals ' + approved, sha(ROOT / approved), sha(INPUTS / copy), 'SHA-256')
    row('proof file SHA-256', PROOF_SHA256, sha(INPUTS / 'LinkedRefund.dfy'), 'LinkedRefund.dfy')
    # The flat contract file must be the exact input of the U294 export (review step D2, gap D5).
    row('flat contract file SHA-256 (the input of the U294 export)', 'a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d', sha(INPUTS / 'transport/FlatCore.dfy'), 'transport/FlatCore.dfy')
    code, last, errors = verify(INPUTS)
    row('verify LinkedRefund.dfy (exit)', 0, code, last)
    row('verify LinkedRefund.dfy (summary)', 'Dafny program verifier finished with 1489 verified, 0 errors', last, '')
    for name, expected in CONTROLS.items():
        folder = work / name
        shutil.copytree(INPUTS, folder)
        patched = subprocess.run(['patch', '-p1', '--quiet', '-i', str(HERE / 'negative' / (name + '.diff'))], cwd=folder, capture_output=True, text=True)
        if patched.returncode != 0:
            row('control ' + name + ' (patch)', 0, patched.returncode, patched.stdout + patched.stderr)
            continue
        code, last, errors = verify(folder)
        row('control ' + name + ' (exit)', expected, code, last)
    files = sorted(str(p.relative_to(INPUTS)) for p in INPUTS.rglob('*.dfy'))
    # The audit of EVERY Dafny file of the closure, written to a fresh report. The findings must be exactly the
    # one known library lemma. (A first version of this check used --compare-report and looked for the name in
    # the tool's output; with that option the name is only in the generated file, so the check failed by my
    # own defect. The audit result itself was the same.)
    report = work / 'audit.md'
    audit = subprocess.run([str(dafny.DAFNY), 'audit', *files, '--report-format', 'md', '--report-file', str(report)],
                           cwd=INPUTS, capture_output=True, text=True)
    found = sorted(line.split('|')[1].strip() for line in report.read_text().splitlines()
                   if line.startswith('|') and not line.startswith(('|Name', '|----')))
    row('audit of all %d Dafny files (exit)' % len(files), 0, audit.returncode, 'the audit command itself')
    row('audit findings of the whole closure', ['Std.Strings.HexConversion.CharsConsistent'], found,
        'one library lemma with an explicit axiom; NOT equal to the empty baseline gate/expected-audit.md; by reading it is not called')
    row('audit report differs from the empty baseline', True, report.read_bytes() != (ROOT / 'gate/expected-audit.md').read_bytes(), 'stated, not hidden')
    words = subprocess.run(['grep', '-n', '-E', r'\bassume\b|\{:axiom\}|@Axiom|\bexpect\b|\{:verify false\}|\{:extern\}', 'LinkedRefund.dfy'], cwd=INPUTS, capture_output=True, text=True)
    row('forbidden words in LinkedRefund.dfy', '', words.stdout.strip(), 'grep')
    (work / 'result.json').write_text(json.dumps({'rows': rows, 'all_as_expected': ok, 'end_to_end': False, 'm1_b': 'OPEN'}, indent=1) + '\n')
    print('LINKED-REFUND %s; the Dafny half only; M1-B OPEN; end_to_end=false' % ('PASSED' if ok else 'FAILED'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
