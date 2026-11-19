#!/usr/bin/env python3
"""Controls for verify_ledger.py and make_ledger.py (night shift 2026-11-19, Orchestrator B, task f-binding;
extended by task f-binding-2: every earlier control is kept; C20-C25 and G4-G5 are new; extended by task f-binding-3:
every earlier control is kept; C26-C28 and G6-G8 are new: exploration run, two-root command line, superseded_by).

Each negative control writes a mutated ledger copy and/or a mutated evidence file into an overlay folder under
controls/<id>/ (the repository is never written) and runs verify_ledger.py on it. A control PASSES when the verifier
exits 1 AND prints the expected failure code. The positive control passes when the real ledger exits 0.
Generator controls (G*) import make_ledger.py, change one edge in memory, and check that the edge is downgraded.
Python 3 standard library only; short runs; no prover.
"""
import copy, json, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ledger_lib as L

REPO = L.DEFAULT_REPO
NS = L.NIGHT + '/orch-B'
CTL = HERE / 'controls'
LED = json.loads((HERE / 'ASSURANCE_LEDGER.json').read_text())


def E(led, eid):
    return [e for e in led['edges'] if e['id'] == eid][0]


def recount(led):
    led['counts'] = {c: sum(1 for e in led['edges'] if e['class'] == c) for c in L.CLASSES}


def overlay_file(d, rel, fn):
    src = REPO / rel
    dst = d / 'overlay' / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    b = fn(src.read_bytes())
    dst.write_bytes(b)
    return L.sha_bytes(b)


def run_verify(d, led=None, overlay=True):
    lp = d / 'ledger.json'
    lp.write_text(json.dumps(led if led is not None else LED, indent=1))
    argv = [sys.executable, str(HERE / 'verify_ledger.py'), '--ledger', str(lp)]
    if overlay and (d / 'overlay').exists():
        argv += ['--overlay', str(d / 'overlay')]
    p = subprocess.run(argv, capture_output=True, text=True)
    (d / 'verify.out').write_text(p.stdout + p.stderr)
    return p.returncode, p.stdout


def flip(b):
    i = len(b) // 2
    return b[:i] + bytes([b[i] ^ 0x01]) + b[i + 1:]


CONTROLS = []


def control(cid, desc, expect_code):
    def deco(f):
        CONTROLS.append((cid, desc, expect_code, f))
        return f
    return deco


@control('C01', 'flipped byte in a proof source (b-signing/SliceSafetyV2.dfy, overlay)', 'DIGEST_MISMATCH')
def c01(d):
    overlay_file(d, NS + '/b-signing/SliceSafetyV2.dfy', flip)
    return run_verify(d)


@control('C02', 'T-V2 run log replaced by a log that ends `exit 4` (M2-drop-H1), still labelled MACHINE-CHECKED', 'EXIT_NOT_ZERO')
def c02(d):
    led = copy.deepcopy(LED); r = E(led, 'T-V2')['runs'][0]
    r['log'] = NS + '/b-signing/logs/M2-drop-H1.log'; r['log_sha256'] = L.sha_file(REPO / r['log'])
    return run_verify(d, led)


@control('C03', 'U5r primary log path names a file that does not exist', 'LOG_MISSING')
def c03(d):
    led = copy.deepcopy(LED); E(led, 'U5r')['runs'][0]['log'] = NS + '/d-reqid/logs/v02-reqid-verify-ABSENT.log'
    return run_verify(d, led)


@control('C04', 'T-V2 closure list omits one file (digest and count made self-consistent)', 'CLOSURE_MISMATCH')
def c04(d):
    led = copy.deepcopy(LED); c = E(led, 'T-V2')['closure']
    c['files'] = [f for f in c['files'] if not f['path'].endswith('FinalityProtocol.dfy')]
    c['count'] = len(c['files']); c['digest'] = L.set_digest((f['path'], f['sha256']) for f in c['files'])
    return run_verify(d, led)


@control('C05', 'U5a names an assumption id that does not exist (A99-NOPE)', 'UNKNOWN_ASSUMPTION')
def c05(d):
    led = copy.deepcopy(LED); E(led, 'U5a')['assumptions'].append('A99-NOPE')
    return run_verify(d, led)


@control('C06', 'U5r (MACHINE-CHECKED) command names Contrast.dfy, closure entry is SinkCoreReqId.dfy', 'COMMAND_ROOT_MISMATCH')
def c06(d):
    led = copy.deepcopy(LED); e = E(led, 'U5r'); e['command'] = e['command'].replace('SinkCoreReqId.dfy', 'Contrast.dfy')
    return run_verify(d, led)


@control('C07', 'duplicate edge id (a second S2; counts recomputed)', 'DUPLICATE_EDGE')
def c07(d):
    led = copy.deepcopy(LED); led['edges'].append(copy.deepcopy(E(led, 'S2'))); recount(led)
    return run_verify(d, led)


@control('C08', 'log `# cmd:` header names Contrast.dfy for the U5r run (overlay; log digest updated in the ledger)', 'CMD_FILE_MISMATCH')
def c08(d):
    rel = NS + '/d-reqid/logs/v02-reqid-verify.log'
    h = overlay_file(d, rel, lambda b: b.replace(b'track-print-effects --log-format', b'track-print-effects --log-format', 1)
                     .replace(b'SinkCoreReqId.dfy\n', b'Contrast.dfy\n', 1))
    led = copy.deepcopy(LED); E(led, 'U5r')['runs'][0]['log_sha256'] = h
    return run_verify(d, led)


@control('C09', 'CSV of T-V2 without the rows of SliceTheoremV2.SliceSafetyV2 (overlay; CSV digest updated)', 'CSV_LEMMA')
def c09(d):
    rel = NS + '/b-signing/logs/final-V2-01.csv'
    h = overlay_file(d, rel, lambda b: b''.join(l for l in b.splitlines(True) if not l.startswith(b'SliceTheoremV2.SliceSafetyV2 (')))
    led = copy.deepcopy(LED); E(led, 'T-V2')['runs'][0]['csv_sha256'] = h
    return run_verify(d, led)


@control('C09b', 'CSV of T-V2 with SliceTheoremV2.UniqueAuthorizationV2 marked Failed (overlay; CSV digest updated)', 'CSV_LEMMA')
def c09b(d):
    rel = NS + '/b-signing/logs/final-V2-01.csv'
    h = overlay_file(d, rel, lambda b: b''.join(l.replace(b',Passed,', b',Failed,') if l.startswith(b'SliceTheoremV2.UniqueAuthorizationV2 (') else l
                                                for l in b.splitlines(True)))
    led = copy.deepcopy(LED); E(led, 'T-V2')['runs'][0]['csv_sha256'] = h
    return run_verify(d, led)


@control('C10', 'ASSUMPTION edge S7 relabelled MACHINE-CHECKED, no log (counts recomputed)', 'MC_WITHOUT_RUN')
def c10(d):
    led = copy.deepcopy(LED); E(led, 'S7')['class'] = 'MACHINE-CHECKED'; recount(led)
    return run_verify(d, led)


@control('C11a', 'stale approved spec: spec/refund/protocol.md changed by one byte (overlay)', 'APPROVED_SPEC_STALE')
def c11a(d):
    overlay_file(d, 'spec/refund/protocol.md', flip)
    return run_verify(d)


@control('C11b', 'stale approved spec: spec/refund/RefundSpec.dfy changed by one byte (overlay)', 'APPROVED_SPEC_STALE')
def c11b(d):
    overlay_file(d, 'spec/refund/RefundSpec.dfy', flip)
    return run_verify(d)


@control('C11c', 'stale approved spec: root spec.lock changed by one byte (overlay)', 'APPROVED_SPEC_STALE')
def c11c(d):
    overlay_file(d, 'spec.lock', flip)
    return run_verify(d)


@control('C11d', 'stale approved spec digest in the ledger (spec/refund/spec.lock pinned to another value)', 'APPROVED_SPEC_STALE')
def c11d(d):
    led = copy.deepcopy(LED)
    [n for n in led['nodes'] if n['path'] == 'spec/refund/spec.lock'][0]['sha256'] = '0' * 64
    return run_verify(d, led)


@control('C12', 'zero edges (reject-all / empty ledger; counts zero)', 'MANDATORY_MISSING')
def c12(d):
    led = copy.deepcopy(LED); led['edges'] = []; recount(led)
    for a in led['assumptions']:
        a['used_by'] = []
    return run_verify(d, led)


@control('C12b', 'zero edges AND an empty mandatory list', 'MANDATORY_MISSING')
def c12b(d):
    led = copy.deepcopy(LED); led['edges'] = []; led['mandatory_edges'] = []; recount(led)
    for a in led['assumptions']:
        a['used_by'] = []
    return run_verify(d, led)


@control('C13', 'MACHINE-CHECKED run log outside the repository tree (../ path)', 'PATH_OUTSIDE')
def c13(d):
    led = copy.deepcopy(LED); E(led, 'T-TOTAL')['runs'][0]['log'] = '../../../../../../private/tmp/final-Total-01.log'
    return run_verify(d, led)


@control('C13b', 'MACHINE-CHECKED run log given as an absolute path', 'PATH_OUTSIDE')
def c13b(d):
    led = copy.deepcopy(LED); r = E(led, 'T-TOTAL')['runs'][0]; r['log'] = str(REPO / r['log'])
    return run_verify(d, led)


@control('C14', 'HOL edge X7-L1 pointed at A\'s L2 log (`go exit 1`; digest updated)', 'EXIT_NOT_ZERO')
def c14(d):
    led = copy.deepcopy(LED); r = E(led, 'X7-L1')['runs'][0]
    r['log'] = 'results/m1b-routeA-20261119/attempt-0001/L2-0001.go.log'; r['log_sha256'] = L.sha_file(REPO / r['log'])
    return run_verify(d, led)


@control('C15', 'stated counts tampered (one more MACHINE-CHECKED)', 'COUNTS_MISMATCH')
def c15(d):
    led = copy.deepcopy(LED); led['counts']['MACHINE-CHECKED'] += 1
    return run_verify(d, led)


@control('C16', 'assumption H1-EUF-CMA no longer lists T-V2 in used_by', 'ASSUMPTION_BACKREF')
def c16(d):
    led = copy.deepcopy(LED); a = [x for x in led['assumptions'] if x['id'] == 'H1-EUF-CMA'][0]; a['used_by'].remove('T-V2')
    return run_verify(d, led)


@control('C17', 'the S3a derivation diff changed by one byte (overlay)', 'DIGEST_MISMATCH')
def c17(d):
    overlay_file(d, 'proposals/m1b-mission-20261119/proofs/linked-refund/review-controls/S3a-remove-hex-module.diff',
                 lambda b: b + b'\n')
    return run_verify(d)


@control('C18', 'approved RefundSpec.dfy replaced and the ledger re-pinned to the new bytes: closures no longer bind it', 'APPROVED_NOT_BOUND')
def c18(d):
    h = overlay_file(d, 'spec/refund/RefundSpec.dfy', lambda b: b + b'// changed\n')
    led = copy.deepcopy(LED); [n for n in led['nodes'] if n['path'] == 'spec/refund/RefundSpec.dfy'][0]['sha256'] = h
    return run_verify(d, led)


@control('C19', 'log `# dafny:` version line changed to 4.10.1 (overlay; digest updated)', 'VERSION_MISMATCH')
def c19(d):
    rel = NS + '/b-signing/logs/final-Total-01.log'
    h = overlay_file(d, rel, lambda b: b.replace(b'# dafny: 4.11.0', b'# dafny: 4.10.1', 1))
    led = copy.deepcopy(LED); E(led, 'T-TOTAL')['runs'][0]['log_sha256'] = h
    return run_verify(d, led)


LINK = L.NIGHT + '/orch-A/link/run/attempt-0001'


@control('C20', 'HOL edge S6 (MACHINE-CHECKED) pointed at the NC1 control log (`go exit 1`) and its run record; digests updated', 'EXIT_NOT_ZERO')
def c20(d):
    led = copy.deepcopy(LED); r = E(led, 'S6')['runs'][0]
    r['log'] = LINK + '/NC1.go.log'; r['log_sha256'] = L.sha_file(REPO / r['log'])
    r['run_json'] = LINK + '/ctl-NC1.run.json'; r['run_json_sha256'] = L.sha_file(REPO / r['run_json']); r['run_id'] = 'ctl-NC1'
    return run_verify(d, led)


@control('C21', 'TESTED-UNPROVED edge X16-TEST relabelled MACHINE-CHECKED (counts recomputed)', 'MC_WITHOUT_RUN')
def c21(d):
    led = copy.deepcopy(LED); E(led, 'X16-TEST')['class'] = 'MACHINE-CHECKED'; recount(led)
    return run_verify(d, led)


@control('C21b', 'X16-TEST relabelled MACHINE-CHECKED with its test log (ends `exit 0`) as a run, a Dafny checker and the X16-DRAFT closure', 'CMD_FILE_MISMATCH')
def c21b(d):
    led = copy.deepcopy(LED); e = E(led, 'X16-TEST'); src = E(led, 'X16-DRAFT')
    e['class'] = 'MACHINE-CHECKED'; e['checker'] = src['checker']; e['closure'] = src['closure']; e['command'] = src['command']
    log = NS + '/recheck-xb/tests.log'
    e['runs'] = [dict(log=log, log_sha256=L.sha_file(REPO / log), root=src['closure']['root'], entry=src['closure']['entry'],
                      closure_digest=src['closure']['digest'], csv=None)]
    recount(led)
    return run_verify(d, led)


@control('C22', 'retired assumption H3a-SER-INJECTIVE named again by edge U3 (used_by made consistent)', 'RETIRED_ASSUMPTION_USED')
def c22(d):
    led = copy.deepcopy(LED); E(led, 'U3')['assumptions'].append('H3a-SER-INJECTIVE')
    [a for a in led['assumptions'] if a['id'] == 'H3a-SER-INJECTIVE'][0]['used_by'] = ['U3']
    return run_verify(d, led)


@control('C23', 'S6 negative control NB1 pointed at the PC1 log (`go exit 0`; digest updated)', 'HOL_CONTROL_MISMATCH')
def c23(d):
    led = copy.deepcopy(LED); c = [x for x in E(led, 'S6')['controls'] if x['id'] == 'NB1'][0]
    c['log'] = LINK + '/PC1.go.log'; c['log_sha256'] = L.sha_file(REPO / c['log'])
    return run_verify(d, led)


@control('C24', 'S6 requires a HOL theorem that its log does not report (exported_contract_total)', 'HOL_THEOREM_MISSING')
def c24(d):
    led = copy.deepcopy(LED); E(led, 'S6')['required_theorems'].append('exported_contract_total')
    return run_verify(d, led)


@control('C25', 'T-V2B keeps its retired hypothesis H3a but loses superseded_by', 'SUPERSEDED_BAD')
def c25(d):
    led = copy.deepcopy(LED); E(led, 'T-V2B').pop('superseded_by')
    return run_verify(d, led)


RA = 'results/m1b-routeA-20261119/attempt-0001'


@control('C26', 'HOL edge X-MF pointed at the exploration run LOx-0001 (`go exit 0`, actual_exit 0, EXPLORE_COMPLETE); digests and run id updated', 'HOL_EXPLORE_RUN')
def c26(d):
    led = copy.deepcopy(LED); r = E(led, 'X-MF')['runs'][0]
    r['log'] = RA + '/LOx-0001.go.log'; r['log_sha256'] = L.sha_file(REPO / r['log'])
    r['run_json'] = RA + '/LOx-0001.run.json'; r['run_json_sha256'] = L.sha_file(REPO / r['run_json']); r['run_id'] = 'LOx-0001'
    return run_verify(d, led)


def one_root(led):
    """T-BYTES-V3 with ONE closure root (ControlsBytesV3.dfy) while its logs name two; closure list, digest and count
    recomputed consistently, so only the root rule can catch it."""
    e = E(led, 'T-BYTES-V3'); clo = e['closure']
    rows, _ = L.closure_of(L.Tree(REPO), L.load_frecords(REPO), clo['root'], 'ControlsBytesV3.dfy', tmpbase=HERE / 'tmp')
    clo.pop('entries', None); clo['entry'] = 'ControlsBytesV3.dfy'
    clo['files'] = [dict(path=p_, sha256=h) for p_, h in rows]; clo['count'] = len(rows); clo['digest'] = L.set_digest(rows)
    for r in e['runs']:
        r.pop('entries', None); r['entry'] = 'ControlsBytesV3.dfy'; r['closure_digest'] = clo['digest']
    return e


@control('C27', 'two-root command (ControlsBytesV3.dfy RefineHashV3.dfy) but T-BYTES-V3 closure of ONE root (self-consistent closure)', 'CMD_ROOTS_MISMATCH')
def c27(d):
    led = copy.deepcopy(LED); one_root(led)
    return run_verify(d, led)


@control('C27b', 'T-BYTES-V3 log `# cmd:` with RefineHashV3.dfy removed (overlay; log digest updated); the closure keeps two roots', 'CMD_ROOTS_MISMATCH')
def c27b(d):
    rel = NS + '/recheck-m/BytesV3.log'
    h = overlay_file(d, rel, lambda b: b.replace(b'ControlsBytesV3.dfy RefineHashV3.dfy\n', b'ControlsBytesV3.dfy\n', 1))
    led = copy.deepcopy(LED); E(led, 'T-BYTES-V3')['runs'][0]['log_sha256'] = h
    return run_verify(d, led)


@control('C28', 'T-BYTES-R superseded_by pointed at E6 (a MISSING edge)', 'SUPERSEDED_BAD')
def c28(d):
    led = copy.deepcopy(LED); E(led, 'T-BYTES-R')['superseded_by'] = 'E6'
    return run_verify(d, led)


@control('P0', 'POSITIVE: the real ledger, no overlay', None)
def p0(d):
    return run_verify(d)


def gen_controls():
    """G1: the generator downgrades an edge whose primary log ends `exit 4`; G2: whose log is missing;
    G3: whose required lemma is absent from the CSV. Runs make_ledger in memory; writes to controls/G*/."""
    import make_ledger as M
    out = []
    cases = [('G1', 'generator: U5r primary log replaced by the exit-4 mutant log m-M1_noReqIdCheck', 'U5r',
              lambda e: e['runs'].__setitem__(0, dict(e['runs'][0], log=NS + '/d-reqid/logs/m-M1_noReqIdCheck-verify.log',
                                                          csv=NS + '/d-reqid/logs/m-M1_noReqIdCheck-verify.csv'))),
             ('G2', 'generator: T-TOTAL primary log missing', 'T-TOTAL',
              lambda e: e['runs'].__setitem__(0, dict(e['runs'][0], log=NS + '/b-signing/logs/final-Total-99.log'))),
             ('G3', 'generator: T-V2 requires a lemma that is not in the CSV', 'T-V2',
              lambda e: e.__setitem__('required', e['required'] + ['SliceTheoremV2.NoSuchLemma'])),
             ('G4', 'generator: S6 primary HOL case replaced by control NC1 (go exit 1)', 'S6',
              lambda e: e.__setitem__('hol', dict(e['hol'], case='NC1', run='ctl-NC1', extra=[]))),
             ('G4b', 'generator: S6 control PC1 expected to fail (go exit 1) but its log ends go exit 0', 'S6',
              lambda e: e.__setitem__('hol', dict(e['hol'], controls=[('PC1', 1)]))),
             ('G4c', 'generator: X13-PF requires a theorem its log does not report', 'X13-PF',
              lambda e: e.__setitem__('required_theorems', e['required_theorems'] + ['no_such_theorem'])),
             # [f3]
             ('G6', 'generator: X-MF primary HOL case replaced by the exploration run LOx-0001 (go exit 0, EXPLORE_COMPLETE)', 'X-MF',
              lambda e: e.__setitem__('hol', dict(e['hol'], case='LOx-0001'))),
             ('G7', 'generator: T-BYTES-V3 runs given ONE root (ControlsBytesV3.dfy) while the logs name two', 'T-BYTES-V3',
              lambda e: e.__setitem__('runs', [dict({k: v for k, v in r.items() if k != 'entries'}, entry='ControlsBytesV3.dfy') for r in e['runs']]))]
    for gid, desc, eid, mut in cases:
        saved = copy.deepcopy(M.EDGES)
        try:
            e = [x for x in M.EDGES if x['id'] == eid][0]
            mut(e)
            try:
                led = M.Gen(REPO).build()
                got = E(led, eid)
            except SystemExit as x:   # [f3] a whole-ledger refusal (for example a superseded_by that loses its MC target) also fails closed
                got = {'class': 'REFUSED (generator SystemExit)', 'downgrade_reason': [str(x)]}
            ok = got['class'] != 'MACHINE-CHECKED'
            d = CTL / gid; d.mkdir(parents=True, exist_ok=True)
            (d / 'result.txt').write_text('%s class=%s reason=%s\n' % (eid, got['class'], got.get('downgrade_reason')))
            out.append(dict(id=gid, description=desc, command='python3 run_controls.py (in-process make_ledger.Gen().build())',
                            exit=None, expected='edge %s not MACHINE-CHECKED' % eid, observed='%s: %s' % (got['class'], got.get('downgrade_reason')),
                            passed=ok))
        finally:
            M.EDGES[:] = saved
    return out


def gen_retired_control():
    """G5: the generator refuses (SystemExit) when an edge names a retired assumption."""
    import make_ledger as M
    saved = copy.deepcopy(M.EDGES)
    d = CTL / 'G5'; d.mkdir(parents=True, exist_ok=True)
    try:
        [x for x in M.EDGES if x['id'] == 'U3'][0]['assumptions'].append('H3a-SER-INJECTIVE')
        try:
            M.Gen(REPO).build(); obs = 'no refusal'; ok = False
        except SystemExit as x:
            obs = str(x); ok = obs.startswith('REFUSED: retired assumption H3a-SER-INJECTIVE')
    finally:
        M.EDGES[:] = saved
    (d / 'result.txt').write_text(obs + '\n')
    return [dict(id='G5', description='generator: edge U3 names the retired assumption H3a-SER-INJECTIVE', command='python3 run_controls.py (in-process make_ledger.Gen().build())',
                 exit=None, expected='SystemExit REFUSED', observed=obs, passed=ok)]


def gen_superseded_control():
    """[f3] G8: the generator refuses (SystemExit) when `superseded_by` names an edge that is not MACHINE-CHECKED."""
    import make_ledger as M
    saved = copy.deepcopy(M.EDGES)
    d = CTL / 'G8'; d.mkdir(parents=True, exist_ok=True)
    try:
        [x for x in M.EDGES if x['id'] == 'T-BYTES-R'][0]['superseded_by'] = 'E6'
        try:
            M.Gen(REPO).build(); obs = 'no refusal'; ok = False
        except SystemExit as x:
            obs = str(x); ok = obs.startswith('REFUSED: edge T-BYTES-R is superseded_by')
    finally:
        M.EDGES[:] = saved
    (d / 'result.txt').write_text(obs + '\n')
    return [dict(id='G8', description='generator: T-BYTES-R superseded_by E6 (MISSING)', command='python3 run_controls.py (in-process make_ledger.Gen().build())',
                 exit=None, expected='SystemExit REFUSED', observed=obs, passed=ok)]


def main():
    if CTL.exists():
        shutil.rmtree(CTL)
    CTL.mkdir()
    results = []
    for cid, desc, code, f in CONTROLS:
        d = CTL / cid; d.mkdir()
        rc, outp = f(d)
        first = outp.splitlines()[0] if outp else ''
        if code is None:
            ok = rc == 0 and 'CONSISTENT' in outp and first == L.BANNER_IDENTITY
        else:
            ok = rc == 1 and ('FAIL %s:' % code) in outp and first == L.BANNER_IDENTITY
        codes = sorted(set(l.split(':')[0][5:] for l in outp.splitlines() if l.startswith('FAIL ')))
        results.append(dict(id=cid, description=desc, command='python3 verify_ledger.py --ledger controls/%s/ledger.json%s' % (
            cid, ' --overlay controls/%s/overlay' % cid if (d / 'overlay').exists() else ''), exit=rc, expected=code or 'exit 0, CONSISTENT',
            observed_codes=codes, passed=ok))
        print('%-5s exit=%s expected=%-22s passed=%s codes=%s' % (cid, rc, code, ok, codes))
    for g in gen_controls() + gen_retired_control() + gen_superseded_control():
        results.append(g)
        print('%-5s %s passed=%s' % (g['id'], g['observed'], g['passed']))
    (HERE / 'controls-result.json').write_text(json.dumps(results, indent=1) + '\n')
    rows = ['| Id | Control | Command | Exit | Expected | Observed codes | Pass |', '|---|---|---|---|---|---|---|']
    for r in results:
        rows.append('| %s | %s | `%s` | %s | %s | %s | %s |' % (r['id'], r['description'], r['command'], r['exit'], r['expected'],
                                                             ', '.join(r.get('observed_codes', [])) or r.get('observed', ''), 'PASS' if r['passed'] else 'FAIL'))
    (HERE / 'CONTROLS.md').write_text('# Controls of the ledger verifier (generated by run_controls.py)\n\n' + '\n'.join(rows) + '\n')
    bad = [r['id'] for r in results if not r['passed']]
    print('controls: %d run, %d as expected, failed: %s' % (len(results), len(results) - len(bad), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
