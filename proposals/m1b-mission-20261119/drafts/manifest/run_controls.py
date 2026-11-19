#!/usr/bin/env python3
"""Negative controls for verify_m1_manifest.py (W5 draft). Works only on copies in the scratch folder.

Two baselines:
  REAL       m1_manifest_draft.json, today's evidence. Expected: REFUSED for M1-A and M1-B.
  SYNTHETIC  the same manifest with every missing record replaced by a SYNTHETIC stand-in file in the
             scratch folder. NOT EVIDENCE. It exists only to show that the verifier CAN say SUPPORTED, so
             that a refusal by a control is caused by the control and not by a verifier that always refuses.
Every control changes ONE thing. It passes only if the verifier exits 1 and prints the control's own reason
code, and that code was absent from the baseline output at the same level. The executable copy is never run.
"""
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path('<HOME>/forge')
TC = REPO / '.toolchain/experiments/refund-cakeml-20261104'
WORK = HERE / 'ctl'
EXE = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
SPEC = 'spec/refund/RefundSpec.dfy'
FINAL_DAT = ('proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/final-cases/e4-0001/'
             'theory-export/forge_refundSlideProfileATheory.dat')
OLD_PROFILE_A_DAT_SHA = 'a5cb0494089fdf67557c70456779d9da3a6bdfcc40809181db222033e2bcb260'  # slide-0 theorem, older proof
sys.path.insert(0, str(HERE))
import verify_m1_manifest as V  # noqa: E402


def sha(b):
    return hashlib.sha256(b).hexdigest()


def file_locators(o, out):
    if isinstance(o, dict):
        if set(o) == {'file'} and isinstance(o['file'], str):
            out.add(o['file'])
        for v in o.values():
            file_locators(v, out)
    elif isinstance(o, list):
        for v in o:
            file_locators(v, out)
    return out


def run(name, manifest, replace, level):
    d = WORK / name
    if d.exists():
        shutil.rmtree(d)
    root = d / 'root'
    for p in file_locators(manifest, set()):
        dst = root / p
        dst.parent.mkdir(parents=True, exist_ok=True)
        if p in replace:
            dst.write_bytes(replace[p])
        elif p in SNAP:
            dst.write_bytes(SNAP[p])  # copy of the snapshot taken at start (the repository is only read)
    mf = d / 'manifest.json'
    mf.write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding='utf-8')
    r = subprocess.run([sys.executable, '-I', str(HERE / 'verify_m1_manifest.py'), str(mf), '--level', level,
                        '--root', str(root), '--git-dir', str(REPO / '.git'), '--toolchain-root', str(TC)],
                       capture_output=True, text=True)
    (d / f'verdict-{level}.txt').write_text(r.stdout + r.stderr)
    return r.returncode, r.stdout


def codes(out):
    return {line.strip().split(':')[0] for line in out.split('\n')[1:] if line.strip()}


def synthetic(real):
    """Fill every gap with a SYNTHETIC stand-in record. NOT EVIDENCE."""
    m = copy.deepcopy(real)
    art = m['artifact']['file']['sha256']
    spec = m['approved_spec']['contract']['sha256']
    rep = {}

    def rec(path, body):
        body = dict(body, synthetic='SYNTHETIC STAND-IN, NOT EVIDENCE')
        data = json.dumps(body, sort_keys=True).encode()
        rep[path] = data
        return {'locator': {'file': path}, 'sha256': sha(data)}

    pins = (b"# SYNTHETIC stand-in for a protected pin file. NOT EVIDENCE.\nPINS = {"
            b"'polyml': ('https://github.com/polyml/polyml', '4557554077078decce4ce5f90da00a713cfc32e4'),\n"
            b"'HOL': ('https://github.com/HOL-Theorem-Prover/HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'),\n"
            b"'cakeml': ('https://github.com/CakeML/cakeml', 'cd9155694c16831373ab695a670794f23282ed62')}\n")
    rep['toolchain/m1-hol-pins.SYNTHETIC.py'] = pins
    m['toolchain']['pin_source'] = {'locator': {'file': 'toolchain/m1-hol-pins.SYNTHETIC.py'}, 'sha256': sha(pins)}
    led = m['assumption_profile']['premise_ledger']
    led['status'] = 'REVIEWED'
    led['record'] = rec('synthetic/ledger.json', {'status': 'REVIEWED', 'artifact_sha256': art})
    for cnd in m['assumption_profile']['conditions']:
        cnd['status'] = 'VALIDATED'
        cnd['record'] = rec('synthetic/q3c.json', {'status': 'VALIDATED', 'artifact_sha256': art})
    for o in m['obligations']:
        if o['status'] == 'OPEN':
            o['status'] = 'DISCHARGED'
    for o in m['open_issues']:
        o['status'] = 'RESOLVED'
    for k in ('recorded_cases_158', 'clean', 'independent'):
        m['replays'][k] = {'status': 'PASSED', 'record': rec(f'synthetic/replay-{k}.json',
                                                             {'status': 'PASSED', 'artifact_sha256': art})}
    m['contract_link'] = {
        'status': 'MACHINE_CHECKED', 'review': None, 'note': 'SYNTHETIC',
        'mechanical': {'dafny_record': rec('synthetic/link-dafny.json',
                                           {'status': 'VERIFIED', 'exit': 0, 'spec_sha256': spec}),
                       # a stored theorem inside the closure, used as a stand-in for the link theorem
                       'hol_theory': 'forge_refundCertifiedProg', 'hol_theorem': STAND_IN_THM}}
    review = rec('synthetic/review.json', {
        'spec_sha256': spec, 'artifact_sha256': art, 'reviewer': 'SYNTHETIC', 'reviewer_is_author': False,
        'owner_named_reviewer_ref': 'SYNTHETIC', 'rows': [{'row': i, 'verdict': 'HOLDS', 'disposition': 'CLOSED'}
                                                           for i in range(1, 19)]})
    return m, rep, review


def stand_in_theorem(real):
    th = next(t for t in real['proof_dependencies']['forge_theories'] if t['theory'] == 'forge_refundCertifiedProg')
    loc = th['dat']['locator']['git']
    data = subprocess.run(['git', '-C', str(REPO), 'cat-file', 'blob', f"{loc['commit']}:{loc['path']}"],
                          capture_output=True, check=True).stdout
    _, _, entries = V.read_dat(data)
    return sorted(n for n, (cls, _) in entries.items() if cls == 2)[0]


def main():
    real = json.loads((HERE / 'm1_manifest_draft.json').read_text(encoding='utf-8'))
    dr = real['assumption_profile']['decision_record']
    for p in file_locators(real, set()):
        if (REPO / p).is_file():
            SNAP[p] = (REPO / p).read_bytes()
    now = sha(SNAP[dr['locator']['file']])
    if now != dr['sha256']:
        print(f'NOTE: {dr["locator"]["file"]} changed after the manifest was built; re-pinned to the snapshot {now[:16]}...')
        dr['sha256'] = now
    global STAND_IN_THM
    STAND_IN_THM = stand_in_theorem(real)
    syn, syn_rep, syn_review = synthetic(real)
    exe = (REPO / EXE).read_bytes()
    spec = (REPO / SPEC).read_bytes()
    fdat = (REPO / FINAL_DAT).read_bytes()

    def flip(b, i):
        return b[:i] + bytes([b[i] ^ 1]) + b[i + 1:]

    def c_substituted(m, rep):  # one byte changed inside the code slice; manifest unchanged
        rep[EXE] = flip(exe, 20000)
        return 'DIGEST_MISMATCH'

    def c_substituted_and_repinned(m, rep):  # attacker also rewrites the artifact digest
        rep[EXE] = flip(exe, 20000)
        m['artifact']['file']['sha256'] = sha(rep[EXE])
        return 'ARTIFACT_SLICES'

    def c_stale_proof(m, rep):  # an older proof's .dat digest presented for the final theory
        th = next(t for t in m['proof_dependencies']['forge_theories'] if t['theory'] == 'forge_refundSlideProfileA')
        th['dat']['sha256'] = OLD_PROFILE_A_DAT_SHA
        return 'STALE_PROOF_RECORD'

    def c_stale_proof_repinned(m, rep):  # a different final .dat with a consistent manifest digest
        th = next(t for t in m['proof_dependencies']['forge_theories'] if t['theory'] == 'forge_refundSlideProfileA')
        rep[FINAL_DAT] = fdat.replace(b'"refund_profile_a_sl"', b'"refund_profile_a_sk"', 1)
        th['dat']['sha256'] = sha(rep[FINAL_DAT])
        return 'STALE_PROOF_RECORD'

    def c_weaker_method(m, rep):  # a reviewed link presented for M1-B
        m['contract_link']['status'] = 'REVIEWED'
        m['contract_link']['mechanical'] = None
        if m is syn_m:
            m['contract_link']['review'] = syn_review
        return 'LINK_METHOD_WEAKER'

    def c_spec_change(m, rep):  # one byte changed in a copy of the spec; digest re-pinned
        rep[SPEC] = flip(spec, 200)
        m['approved_spec']['contract']['sha256'] = sha(rep[SPEC])
        return 'SPEC_NOT_APPROVED'

    def c_compiler_pin(m, rep):  # CakeML commit changed
        m['toolchain']['cakeml_commit'] = '0' * 40
        return 'TOOLCHAIN_MISMATCH'

    def c_backend_config(m, rep):  # another backend configuration named
        m['toolchain']['backend_config'] = 'x64_target$x64_config'
        return 'COMPILER_CONFIG'

    def c_missing_field(m, rep):
        del m['artifact']['size']
        return 'MISSING_FIELD'

    def c_unknown_field(m, rep):
        m['comment'] = 'trust me'
        return 'UNKNOWN_FIELD'

    def c_stated_level(m, rep):
        m['claim_level'] = 'M1-B'
        return 'PRODUCER_STATED_LEVEL'

    def c_null_artifact(m, rep):
        m['artifact']['file'] = None
        return 'MISSING_EVIDENCE'

    def c_parent_swap(m, rep):  # upstream parent theory replaced by another file with the same name
        u = m['proof_dependencies']['upstream_parents'][0]
        u['dat'] = {'locator': {'file': 'synthetic/upstream.dat'}, 'sha256': sha(b'(theory)')}
        rep['synthetic/upstream.dat'] = b'(theory)'
        return 'PARENT_LINK'

    controls = [c_substituted, c_substituted_and_repinned, c_stale_proof, c_stale_proof_repinned, c_weaker_method,
                c_spec_change, c_compiler_pin, c_backend_config, c_missing_field, c_unknown_field, c_stated_level,
                c_null_artifact, c_parent_swap]
    rows, ok = [], True
    if WORK.exists():
        shutil.rmtree(WORK)
    base = {}
    global syn_m
    syn_m = None
    for bname, bm, brep in (('REAL', real, {}), ('SYNTHETIC', syn, syn_rep)):
        for level in ('M1-A', 'M1-B'):
            rc, out = run(f'{bname}-baseline', bm, brep, level)
            base[(bname, level)] = (rc, codes(out))
            rows.append((bname, 'baseline', level, rc, '-', ' '.join(sorted(codes(out))) or '(none)'))
            want = 1 if bname == 'REAL' else 0
            ok &= rc == want
    for bname, bm, brep in (('REAL', real, {}), ('SYNTHETIC', syn, syn_rep)):
        for ctl in controls:
            for level in ('M1-A', 'M1-B'):
                m, rep = copy.deepcopy(bm), dict(brep)
                syn_m = m if bname == 'SYNTHETIC' else None
                code = ctl(m, rep)
                if ctl is c_weaker_method and level == 'M1-A':
                    rc, out = run(f'{bname}-{ctl.__name__}-{level}', m, rep, level)
                    expect = 0 if bname == 'SYNTHETIC' else 1  # a reviewed link is enough for M1-A
                    passed = rc == expect
                    rows.append((bname, ctl.__name__, level, rc, f'expect exit {expect}', 'PASS' if passed else 'FAIL'))
                    ok &= passed
                    continue
                rc, out = run(f'{bname}-{ctl.__name__}-{level}', m, rep, level)
                got = codes(out)
                new = code in got and code not in base[(bname, level)][1]
                passed = rc == 1 and code in got
                note = 'own reason, new' if new else ('own reason, already in baseline' if code in got else 'reason absent')
                if bname == 'SYNTHETIC':
                    passed = passed and new
                rows.append((bname, ctl.__name__, level, rc, code, ('PASS ' if passed else 'FAIL ') + note))
                ok &= passed
    w = max(len(r[1]) for r in rows)
    lines = [f'{"baseline":9} | {"control":{w}} | level | exit | expected reason | result']
    for r in rows:
        lines.append(f'{r[0]:9} | {r[1]:{w}} | {r[2]} | {r[3]:4} | {r[4]} | {r[5]}')
    lines.append(f'ALL CONTROLS {"PASS" if ok else "FAIL"}')
    text = '\n'.join(lines)
    (HERE / 'controls-result.txt').write_text(text + '\n')
    print(text)
    return 0 if ok else 1


STAND_IN_THM = None
SNAP = {}
syn_m = None
if __name__ == '__main__':
    sys.exit(main())
