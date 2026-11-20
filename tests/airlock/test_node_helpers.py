"""FINITE TEST of the Node helper of forge-airlock: booking_check.cjs (Goal 20, inventory airlock only).

Usage: python3 tests/airlock/test_node_helpers.py <node> [--case NAME]... [--model PATH] [--list]
  <node>   the pinned Node 24.3.0 executable.
  --model  the compiled checker (default build/airlock/checker/model.cjs, made by src/airlock/node/build_checker.py).

One line per case: PASS, FAIL or NOT RUN. Exit 0 only if every selected case passes. A NOT RUN case makes the exit
code non-zero unless its name is on ALLOW_NOT_RUN (printed at the start, with the reason). Python stdlib only.
Nothing is mocked: every case runs the real helper as a subprocess.

The Node cosign helper (cosign.cjs) is gone (Apex addendum: the engine verifies a cosign with /usr/bin/ssh-keygen).
Its cases moved: the human's tools and the key file rules to tests/airlock/test_cosign.py, the verification to
tests/airlock/test_engine.py (cases cosign, cosign_faults, nonce, weakkey, seams, helper_env).
"""
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOOKING = ROOT / 'src/airlock/node/booking_check.cjs'
DEFAULT_MODEL = ROOT / 'build/airlock/checker/model.cjs'
ALLOW_NOT_RUN = {}  # name -> reason. Empty: every NOT RUN fails the suite.
ENV = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'}


class NotRun(Exception):
    pass


def run(argv, data=b'', timeout=60):
    p = subprocess.run(argv, input=data, capture_output=True, timeout=timeout, cwd=ROOT, env=ENV)
    return p.returncode, p.stdout, p.stderr


def check(cond, detail):
    if not cond:
        raise AssertionError(detail)


# ---------------------------------------------------------------- booking_check.cjs

A0 = [['1', '1', '0'], ['1', '0', '1']]
C0 = ['1', '1']
W0 = ['3', '2', '2']


def cert(x, y=('2', '2'), z=('0', '0', '0'), alpha='0', A=A0, c=C0, w=W0):
    return {'A': [list(r) for r in A], 'c': list(c), 'w': list(w), 'x': list(x), 'y': list(y), 'z': list(z),
            'alpha_bps': alpha}


def enc(obj):
    return json.dumps(obj, separators=(',', ':')).encode()


class Ctx:
    def __init__(self, node, model, tmp):
        self.node, self.model, self.tmp = node, model, tmp
        self.n = 0

    def path(self, name):
        self.n += 1
        return self.tmp / ('%03d-%s' % (self.n, name))

    def booking(self, data, model=None):
        if model is None:
            if not self.model.is_file():
                raise NotRun('model file missing: run src/airlock/node/build_checker.py')
            model = self.model
        return run([self.node, str(BOOKING), str(model)], data)



def expect_booking(ctx, data, code, model=None):
    rc, out, err = ctx.booking(data, model)
    want = {0: b'ACCEPT\n', 1: b'REJECT\n', 2: b''}[code]
    check(rc == code and out == want, 'exit %d stdout %r stderr %r' % (rc, out, err[:200]))
    if code in (0, 1):
        check(err == b'', 'stderr not empty: %r' % err[:200])
    else:
        check(err.startswith(b'booking_check: '), 'no message on stderr')
    return 'exit %d %s' % (rc, (out or err[:90]).decode('latin1').strip())


B = {}


def bcase(name, code):
    def deco(fn):
        B[name] = lambda ctx: expect_booking(ctx, fn(ctx), code)
        return fn
    return deco


bcase('booking_optimum_accept', 0)(lambda c: enc(cert(['0', '1', '1'])))
bcase('booking_overbooking_reject', 1)(lambda c: enc(cert(['1', '1', '0'])))
bcase('booking_overbooking_reject_alpha_10000', 1)(lambda c: enc(cert(['1', '1', '0'], alpha='10000')))
bcase('booking_fractional_x_reject', 1)(lambda c: enc(cert(['0', '2', '0'])))
bcase('booking_invalid_dual_reject', 1)(lambda c: enc(cert(['0', '1', '1'], y=['1', '1'])))
bcase('booking_negative_dual_reject', 1)(lambda c: enc(cert(['0', '1', '1'], y=['2', '-1'], z=['0', '0', '1'])))
bcase('booking_alpha_overclaim_reject', 1)(lambda c: enc(cert(['1', '0', '0'], alpha='2499')))
bcase('booking_alpha_exact_claim_accept', 0)(lambda c: enc(cert(['1', '0', '0'], alpha='2500')))
bcase('booking_suboptimal_zero_gap_reject', 1)(lambda c: enc(cert(['1', '0', '0'])))
bcase('booking_alpha_above_10000_reject', 1)(lambda c: enc(cert(['0', '1', '1'], alpha='10001')))
bcase('booking_rows_mismatch_reject', 1)(lambda c: enc(cert(['0', '1', '1'], c=['1'])))
bcase('booking_ragged_row_reject', 1)(lambda c: enc(cert(['0', '1', '1'], A=[['1', '1', '0'], ['1', '0']])))
bcase('booking_x_length_reject', 1)(lambda c: enc(cert(['0', '1'])))
# DESIGN.md example: z[1] = 0 < w[1] = 2 with y = 0, so the dual is not feasible: REJECT (a finding, not a defect).
bcase('booking_design_md_example_rejects', 1)(lambda c: enc(
    {'A': [['1', '0']], 'c': ['3'], 'w': ['5', '2'], 'x': ['1', '0'], 'y': ['0'], 'z': ['5', '0'], 'alpha_bps': '0'}))
bcase('booking_design_md_example_corrected_accept', 0)(lambda c: enc(
    {'A': [['1', '0']], 'c': ['3'], 'w': ['5', '2'], 'x': ['1', '1'], 'y': ['0'], 'z': ['5', '2'], 'alpha_bps': '0'}))
# Exactness beyond 2^53: as doubles, 2^53+1 == 2^53, and the first case would read as feasible.
BIG = {'A': [['9007199254740993']], 'c': ['9007199254740992'], 'w': ['1'], 'x': ['1'], 'y': ['0'], 'z': ['1'],
       'alpha_bps': '0'}
bcase('booking_exact_2p53_plus1_reject', 1)(lambda c: enc(BIG))
bcase('booking_exact_2p53_plus1_accept', 0)(lambda c: enc(dict(BIG, c=['9007199254740993'])))
D63 = '1' + '0' * 62  # 63 digits
bcase('booking_exact_63_digits_reject', 1)(lambda c: enc(dict(BIG, A=[[D63[:-1] + '1']], c=[D63])))
bcase('booking_exact_63_digits_accept', 0)(lambda c: enc(dict(BIG, A=[[D63]], c=[D63])))
bcase('booking_int_64_chars_negative_ok', 1)(lambda c: enc(dict(BIG, y=['-' + D63])))
bcase('booking_int_65_chars_refused', 2)(lambda c: enc(dict(BIG, c=['1' + '0' * 64])))
bcase('booking_float_string_refused', 2)(lambda c: enc(dict(BIG, c=['1.0'])))
bcase('booking_exponent_string_refused', 2)(lambda c: enc(dict(BIG, c=['1e3'])))
bcase('booking_json_number_refused', 2)(lambda c: b'{"A":[[1]],"c":["1"],"w":["1"],"x":["1"],"y":["0"],"z":["1"],"alpha_bps":"0"}')
bcase('booking_json_float_refused', 2)(lambda c: b'{"A":[["1"]],"c":[1.5],"w":["1"],"x":["1"],"y":["0"],"z":["1"],"alpha_bps":"0"}')
bcase('booking_leading_zero_refused', 2)(lambda c: enc(dict(BIG, c=['01'])))
bcase('booking_minus_zero_refused', 2)(lambda c: enc(dict(BIG, y=['-0'])))
bcase('booking_plus_sign_refused', 2)(lambda c: enc(dict(BIG, c=['+1'])))
bcase('booking_negative_alpha_refused', 2)(lambda c: enc(dict(BIG, alpha_bps='-1')))
bcase('booking_alpha_leading_zero_refused', 2)(lambda c: enc(dict(BIG, alpha_bps='00')))
bcase('booking_empty_string_refused', 2)(lambda c: enc(dict(BIG, c=[''])))
bcase('booking_duplicate_key_refused', 2)(lambda c: enc(cert(['1', '1', '0']))[:-1] + b',"x":["0","1","1"]}')
bcase('booking_duplicate_key_first_refused', 2)(lambda c: b'{"x":["1","1","0"],' + enc(cert(['0', '1', '1']))[1:])
bcase('booking_missing_key_refused', 2)(lambda c: enc({k: v for k, v in BIG.items() if k != 'z'}))
bcase('booking_unknown_key_refused', 2)(lambda c: enc(dict(BIG, extra=['1'])))
bcase('booking_A_flat_refused', 2)(lambda c: enc(dict(BIG, A=['1'])))
bcase('booking_A_depth3_refused', 2)(lambda c: enc(dict(BIG, A=[[['1']]])))
bcase('booking_vector_as_string_refused', 2)(lambda c: enc(dict(BIG, c='1')))
bcase('booking_alpha_as_array_refused', 2)(lambda c: enc(dict(BIG, alpha_bps=['0'])))
bcase('booking_null_refused', 2)(lambda c: enc(dict(BIG, z=None)))
bcase('booking_bool_refused', 2)(lambda c: enc(dict(BIG, z=[True])))
bcase('booking_top_array_refused', 2)(lambda c: b'[' + enc(BIG) + b']')
bcase('booking_escape_refused', 2)(lambda c: enc(BIG).replace(b'"c":["9007199254740992"]', b'"c":["\\u0031"]'))
bcase('booking_non_ascii_refused', 2)(lambda c: enc(BIG).replace(b'"0"', '"٠"'.encode(), 1))
bcase('booking_trailing_bytes_refused', 2)(lambda c: enc(BIG) + b' x')
bcase('booking_two_objects_refused', 2)(lambda c: enc(BIG) + enc(BIG))
bcase('booking_trailing_comma_refused', 2)(lambda c: enc(BIG)[:-1] + b',}')
bcase('booking_empty_input_refused', 2)(lambda c: b'')
bcase('booking_bom_refused', 2)(lambda c: b'\xef\xbb\xbf' + enc(BIG))
bcase('booking_whitespace_ok', 1)(lambda c: json.dumps(BIG, indent=2).encode() + b'\r\n\t ')
bcase('booking_exactly_1MiB_accept', 0)(lambda c: enc(cert(['0', '1', '1'])).ljust(1048576, b' '))
bcase('booking_1MiB_plus_1_refused', 2)(lambda c: enc(cert(['0', '1', '1'])).ljust(1048577, b' '))
bcase('booking_8MiB_refused', 2)(lambda c: b' ' * (8 * 1048576))


def wide(m, n):
    # m rows of n ones; capacity n per row; y = (1, 0, ..., 0); x = w = all ones; optimum n, bound n.
    return {'A': [['1'] * n for _ in range(m)], 'c': [str(n)] * m, 'w': ['1'] * n, 'x': ['1'] * n,
            'y': ['1'] + ['0'] * (m - 1), 'z': ['0'] * n, 'alpha_bps': '0'}


bcase('booking_max_row_4096_accept', 0)(lambda c: enc(wide(1, 4096)))
bcase('booking_max_cells_16x4096_accept', 0)(lambda c: enc(wide(16, 4096)))
bcase('booking_row_4097_refused', 2)(lambda c: enc(wide(1, 4097)))
bcase('booking_cells_65537_refused', 2)(lambda c: enc(dict(wide(16, 4096), A=[['1'] * 4096] * 16 + [['1']])))
bcase('booking_empty_vectors_go_to_dafny', 0)(lambda c: enc(
    {'A': [], 'c': [], 'w': [], 'x': [], 'y': [], 'z': [], 'alpha_bps': '0'}))


def b_missing_model(ctx):
    return expect_booking(ctx, enc(cert(['0', '1', '1'])), 2, model=ctx.path('absent.cjs'))


def b_model_throws(ctx):
    p = ctx.path('throws.cjs')
    p.write_text("throw new Error('model load failure');\n")
    return expect_booking(ctx, enc(cert(['0', '1', '1'])), 2, model=p)


def b_model_always_true(ctx):
    # A substituted model that would accept everything: refused by the pin before it runs.
    p = ctx.path('fake.cjs')
    p.write_text("module.exports = { BookingDualCert: { __default: { VerifyCertifiedBooking: () => true } },"
                 " runtime: { Seq: { of: (...a) => a }, ZERO: 0 } };\n")
    return expect_booking(ctx, enc(cert(['1', '1', '0'])), 2, model=p)


def b_model_one_byte_more(ctx):
    if not ctx.model.is_file():
        raise NotRun('model file missing')
    p = ctx.path('model.cjs')
    p.write_bytes(ctx.model.read_bytes() + b'\n')
    return expect_booking(ctx, enc(cert(['0', '1', '1'])), 2, model=p)


def b_model_symlink(ctx):
    if not ctx.model.is_file():
        raise NotRun('model file missing')
    p = ctx.path('link.cjs')
    p.symlink_to(ctx.model)
    return expect_booking(ctx, enc(cert(['0', '1', '1'])), 2, model=p)


def b_model_directory(ctx):
    p = ctx.path('dir')
    p.mkdir()
    return expect_booking(ctx, enc(cert(['0', '1', '1'])), 2, model=p)


def b_no_args(ctx):
    rc, out, err = run([ctx.node, str(BOOKING)], b'')
    check(rc == 2 and out == b'', 'exit %d stdout %r' % (rc, out))
    return 'exit 2 usage'


# What the three cases above show, and what they do not: their model files lie in the temporary folder, where Node
# finds no node_modules (the model needs bignumber.js), and the always-true fake has no Dafny runtime. So they show
# exit 2 for those files, but each would give exit 2 also WITHOUT the pin or WITHOUT O_NOFOLLOW. The two cases below
# put the file next to the built model, where node_modules is found: there only the pin or O_NOFOLLOW refuses it.
def near_model(ctx, name):
    if not ctx.model.is_file():
        raise NotRun('model file missing')
    return ctx.model.parent / ('%s-%d.cjs' % (name, os.getpid()))


def b_model_substituted_near_runtime(ctx):
    p = near_model(ctx, 'substituted')
    p.write_bytes(ctx.model.read_bytes() + b'\nmodule.exports.BookingDualCert.__default.VerifyCertifiedBooking = function () { return true; };\n')
    try:
        return expect_booking(ctx, enc(cert(['1', '1', '0'])), 2, model=p) + ' (a working model that accepts everything; refused by the pin)'
    finally:
        p.unlink(missing_ok=True)


def b_model_symlink_near_runtime(ctx):
    p = near_model(ctx, 'link')
    p.symlink_to(ctx.model.name)
    try:
        return expect_booking(ctx, enc(cert(['0', '1', '1'])), 2, model=p) + ' (a link to the pinned model; refused by O_NOFOLLOW)'
    finally:
        p.unlink(missing_ok=True)


B.update({'booking_model_substituted_near_runtime': b_model_substituted_near_runtime,
          'booking_model_symlink_near_runtime': b_model_symlink_near_runtime})
B.update({'booking_missing_model_file': b_missing_model, 'booking_model_throws': b_model_throws,
          'booking_model_substituted_always_true': b_model_always_true,
          'booking_model_one_byte_more': b_model_one_byte_more, 'booking_model_symlink_refused': b_model_symlink,
          'booking_model_directory_refused': b_model_directory, 'booking_no_args': b_no_args})


B['booking_eval_mode'] = lambda ctx: _booking_eval(ctx)


def _booking_eval(ctx):
    if not ctx.model.is_file():
        raise NotRun('model file missing: run src/airlock/node/build_checker.py')
    src = BOOKING.read_text()
    rc, out, err = run([ctx.node, '-e', src, '--', str(ctx.model)], enc(cert(['0', '1', '1'])))
    check(rc == 0 and out == b'ACCEPT\n' and err == b'', 'eval mode ACCEPT: exit %d %r %r' % (rc, out, err[:200]))
    rc, out, err = run([ctx.node, '-e', src, '--', str(ctx.model)], enc(cert(['1', '1', '0'])))
    check(rc == 1 and out == b'REJECT\n', 'eval mode REJECT: exit %d %r' % (rc, out))
    return 'node -e <booking_check.cjs> -- <model>: ACCEPT 0, REJECT 1'


CASES = dict(B)


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[2])
        return 2
    node = argv[1]
    names, model, i = [], DEFAULT_MODEL, 2
    while i < len(argv):
        if argv[i] == '--case' and i + 1 < len(argv):
            names.append(argv[i + 1]); i += 2
        elif argv[i] == '--model' and i + 1 < len(argv):
            model = Path(argv[i + 1]).resolve(); i += 2
        elif argv[i] == '--list':
            print('\n'.join(CASES)); return 0
        else:
            print('unknown argument: ' + argv[i]); return 2
    unknown = [n for n in names if n not in CASES]
    if unknown:
        print('unknown case: ' + ', '.join(unknown)); return 2
    rc, out, _ = run([node, '--version'])
    print('node %s %s' % (node, out.decode().strip()))
    print('allowed NOT RUN: ' + (', '.join('%s (%s)' % kv for kv in ALLOW_NOT_RUN.items()) or 'none'))
    counts = {'PASS': 0, 'FAIL': 0, 'NOT RUN': 0}
    bad = False
    with tempfile.TemporaryDirectory(prefix='airlock-node-') as tmp:
        ctx = Ctx(node, model, Path(tmp))
        for name in names or CASES:
            try:
                status, detail = 'PASS', CASES[name](ctx)
            except NotRun as e:
                status, detail = 'NOT RUN', str(e)
                bad |= name not in ALLOW_NOT_RUN
            except subprocess.TimeoutExpired as e:
                status, detail = 'FAIL', 'timeout after %s s' % e.timeout
                bad = True
            except Exception as e:
                status, detail = 'FAIL', '%s: %s' % (type(e).__name__, e)
                bad = True
            counts[status] += 1
            print('%-7s %s: %s' % (status, name, detail))
    print('total %d: %d PASS, %d FAIL, %d NOT RUN' % (sum(counts.values()), counts['PASS'], counts['FAIL'],
                                                      counts['NOT RUN']))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
