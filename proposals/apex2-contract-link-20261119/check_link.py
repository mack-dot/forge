#!/usr/bin/env python3
"""APEX-2: the translation-boundary check (NOT a proof; a pinned, tested check).

It checks the one step of the Dafny <-> HOL4 contract link that no prover
checks: that dafny/HolFlatGenerated.dfy is the text that the HOL build printed
from the definition flat_plain, and that Dafny proves this text equal to the
contract of the real FlatRefund.AssessFlat.

Steps:
  1. PINS.json: the SHA-256 of every input. A fixed set of keys is REQUIRED.
  2. The two recorded HOL build logs (pinned) end in FLAT_CONTRACT_COMPLETE and
     hold one line FORGE_DAFNY_PARAMS and one line FORGE_DAFNY_BODY. They must
     be the parameter list and the body of dafny/HolFlatGenerated.dfy, byte
     for byte. This compares a file with a log of the same printer. It does
     not check the printer.
  3. With --dafny <binary> --z3 <binary>: `dafny verify HolLink.dfy` in a
     temporary copy; required: exit 0 and "11 verified, 0 errors".
     With --slice also `dafny verify HolSlice.dfy` in the repository tree;
     required: exit 0 and the pinned count.

Results. Only ONE result is a pass:
  exit 0  CHECK_LINK PASS      steps 1, 2 and 3 ran on the pinned files.
  exit 1  FAIL                 a pin, a required key, a file or a text differs.
  exit 4  FAIL                 Dafny did not verify.
  exit 5  PARTIAL              steps 1 and 2 hold; Dafny NOT RUN. Not a pass.
  exit 3  CONTROL MODE         --skip-pins was given. Never a pass, whatever Dafny says.
  exit 2  usage.
Control options: --flatcore, --generated, --hollink put another file in the
place of FlatCore.dfy, HolFlatGenerated.dfy or HolLink.dfy. With the pins on,
such a file is refused at step 1 (exit 1). --skip-pins skips steps 1 and 2,
only to show that step 3 ALSO refuses a control.
Standard library only."""
import argparse, hashlib, json, pathlib, shutil, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PKG = HERE.relative_to(ROOT).as_posix()
SLICE_IN = 'proposals/m1b-mission-20261119/proofs/slice-theorem/inputs'
FLATCORE_REL = SLICE_IN + '/transport/FlatCore.dfy'
GEN_REL = PKG + '/dafny/HolFlatGenerated.dfy'
LINK_REL = PKG + '/dafny/HolLink.dfy'
LOGS = [PKG + f'/records/hol/{r}/forge_refundFlatContractTheory.log' for r in ('run-0001', 'run-0002')]
REQUIRED = [FLATCORE_REL, GEN_REL, LINK_REL, PKG + '/dafny/HolSlice.dfy', SLICE_IN + '/SliceTheorem.dfy',
            SLICE_IN + '/LinkedRefund.dfy',
            PKG + '/hol/forge_refundFlatContractScript.sml', PKG + '/hol/forge_refundExportedContractScript.sml',
            PKG + '/hol/forge_refundFlatExportedScript.sml', PKG + '/hol/Holmakefile', PKG + '/hol/FlatCore.sexp',
            PKG + '/routeA/RA-FLAT.sml'] + LOGS
LINK_LINE = 'Dafny program verifier finished with 11 verified, 0 errors'
SLICE_LINE = 'Dafny program verifier finished with 1583 verified, 0 errors'


def fail(code, msg):
    print('CHECK_LINK FAIL:', msg)
    raise SystemExit(code)


def sha(p):
    try:
        return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
    except OSError as e:
        fail(1, f'cannot read {p}: {e.strerror}')


def dafny(a, cwd, name):
    cmd = [a.dafny, 'verify', name, '--solver-path', a.z3, '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files', '--track-print-effects']
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=1800)
    return r.returncode, r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dafny'); ap.add_argument('--z3'); ap.add_argument('--slice', action='store_true')
    ap.add_argument('--flatcore'); ap.add_argument('--generated'); ap.add_argument('--hollink')
    ap.add_argument('--skip-pins', action='store_true')
    a = ap.parse_args()
    if bool(a.dafny) != bool(a.z3) or (a.slice and not a.dafny):
        print('usage: --dafny and --z3 go together; --slice needs them'); return 2
    over = {FLATCORE_REL: a.flatcore, GEN_REL: a.generated, LINK_REL: a.hollink}
    path = {rel: (pathlib.Path(o) if o else ROOT / rel) for rel, o in over.items()}
    if a.skip_pins:
        print('CONTROL MODE: pins and text checks SKIPPED. This run can not be a pass.')
    else:
        try:
            pins = json.loads((HERE / 'PINS.json').read_text())
        except (OSError, ValueError) as e:
            fail(1, f'PINS.json: {e}')
        for rel in REQUIRED:
            if rel not in pins: fail(1, f'PINS.json has no entry for the required file {rel}')
        for rel, want in pins.items():
            if rel.startswith('/') or '..' in rel.split('/'): fail(1, f'PIN key leaves the repository: {rel}')
            got = sha(path.get(rel, ROOT / rel))
            if got != want: fail(1, f'PIN {rel}: {got} is not {want}')
        print(f'pins: {len(pins)} files equal ({len(REQUIRED)} required)')
        text = path[GEN_REL].read_text()
        for rel in LOGS:
            lines = (ROOT / rel).read_text().splitlines()
            params = [l for l in lines if l.startswith('FORGE_DAFNY_PARAMS ')]
            body = [l for l in lines if l.startswith('FORGE_DAFNY_BODY ')]
            if len(params) != 1 or len(body) != 1 or 'FLAT_CONTRACT_COMPLETE' not in lines:
                fail(1, f'{rel}: not a complete log with one PARAMS and one BODY line')
            want = ('  predicate FlatPlain(' + params[0][len('FORGE_DAFNY_PARAMS '):] + ')\n  {\n    '
                    + body[0][len('FORGE_DAFNY_BODY '):] + '\n  }\n}\n')
            if not text.endswith(want) or text.count('predicate') != 1:
                fail(1, f'{rel}: the generated file is not the text that the HOL build printed')
        print('generated file: equal to the text in both recorded HOL logs')
        if not a.dafny:
            print('CHECK_LINK PARTIAL: pins and text hold; Dafny NOT RUN. This is not a pass.')
            return 5
    if not a.dafny:
        print('CONTROL MODE: nothing was checked.'); return 3
    with tempfile.TemporaryDirectory() as t:
        t = pathlib.Path(t)
        d = t / PKG / 'dafny'; d.mkdir(parents=True)
        f = t / FLATCORE_REL; f.parent.mkdir(parents=True)
        shutil.copy(path[LINK_REL], d / 'HolLink.dfy')
        shutil.copy(path[GEN_REL], d / 'HolFlatGenerated.dfy')
        shutil.copy(path[FLATCORE_REL], f)
        rc, out = dafny(a, d, 'HolLink.dfy')
        out = out.replace(str(t) + '/', '').replace(str(t.resolve()) + '/', '')
        print(out.strip()); print('dafny exit', rc, '(HolLink.dfy)')
        if rc != 0 or LINK_LINE not in out: fail(4, 'Dafny did not verify HolLink.dfy')
    if a.slice:
        if any(over.values()): fail(1, '--slice runs in the repository tree; it takes no override')
        rc, out = dafny(a, HERE / 'dafny', 'HolSlice.dfy')
        print(out.strip().splitlines()[-1] if out.strip() else ''); print('dafny exit', rc, '(HolSlice.dfy)')
        if rc != 0 or SLICE_LINE not in out: fail(4, 'Dafny did not verify HolSlice.dfy with the pinned count')
    if a.skip_pins:
        print('CONTROL MODE: Dafny verified the given files. NOT a pass: the pins were skipped.')
        return 3
    print('CHECK_LINK PASS' + (' (HolLink and HolSlice)' if a.slice else ' (HolLink; HolSlice NOT RUN)'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
