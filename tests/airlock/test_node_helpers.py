"""FINITE TEST of the two Node helpers of forge-airlock: booking_check.cjs and cosign.cjs (Goal 20).

Usage: python3 tests/airlock/test_node_helpers.py <node> [--case NAME]... [--model PATH] [--list]
  <node>   the pinned Node 24.3.0 executable.
  --model  the compiled checker (default build/airlock/checker/model.cjs, made by src/airlock/node/build_checker.py).

One line per case: PASS, FAIL or NOT RUN. Exit 0 only if every selected case passes. A NOT RUN case makes the exit
code non-zero unless its name is on ALLOW_NOT_RUN (printed at the start, with the reason). Python stdlib only.
Private keys exist only in a temporary folder made by this run and removed at its end. Nothing is mocked: every
case runs the real helper as a subprocess, except `sign_other_uid_seam`, which calls the exported check function
with a stat object whose uid differs (a real file of another uid with mode 0600 cannot be opened by this user).

Case to D-1 rule map (KEY_DESIGN.md section 1, U602 regression patterns):
  O_NOFOLLOW (last part)   sign_key_symlink, sign_key_dangling_symlink, keygen_refuses_symlink_path
  O_NONBLOCK + S_ISREG     sign_key_fifo_no_hang, sign_key_directory, sign_key_dev_null
  uid == euid              sign_other_uid_real_file, sign_other_uid_seam
  (mode & 0o077) == 0      sign_key_mode_<mode> for 0640 0604 0644 0660 0666 0610 0601 0620 0602; 0600 and 0400 pass
  size and content         sign_key_missing, sign_key_empty, sign_key_damaged, sign_key_too_large,
                           sign_key_public_pem, sign_key_not_ed25519
  same descriptor read     not separately testable from outside (a reading of the code); no case claims it
  no link-count rule       sign_key_hardlink_accepted (D-1 states a hard link passes)
"""
import json, os, stat, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOOKING = ROOT / 'src/airlock/node/booking_check.cjs'
COSIGN = ROOT / 'src/airlock/node/cosign.cjs'
DEFAULT_MODEL = ROOT / 'build/airlock/checker/model.cjs'
ALLOW_NOT_RUN = {}  # name -> reason. Empty: every NOT RUN fails the suite.
ENV = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'}
L = 2 ** 252 + 27742317777372353535851937790883648493  # Ed25519 group order


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

    def cosign(self, args, data=b'', timeout=60):
        return run([self.node, str(COSIGN), *args], data, timeout)


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


B.update({'booking_missing_model_file': b_missing_model, 'booking_model_throws': b_model_throws,
          'booking_model_substituted_always_true': b_model_always_true,
          'booking_model_one_byte_more': b_model_one_byte_more, 'booking_model_symlink_refused': b_model_symlink,
          'booking_model_directory_refused': b_model_directory, 'booking_no_args': b_no_args})


# ---------------------------------------------------------------- cosign.cjs

def message(store='store-1', rid='req-1', h='0123456789abcdef0123456789abcdef', action='REFUND order-9 7500 GOODWILL'):
    return ('forge-airlock-cosign-v1\n%s\n%s\n%s\n%s\n' % (store, rid, h, action)).encode()


class Keys:
    def __init__(self, ctx):
        self.ctx = ctx
        self.cache = {}

    def get(self, name):
        if name not in self.cache:
            p = self.ctx.tmp / ('key-' + name)
            rc, out, err = self.ctx.cosign(['keygen', str(p)])
            check(rc == 0 and len(out) == 65 and err == b'', 'keygen failed: exit %d %r' % (rc, err))
            self.cache[name] = (p, out.decode().strip())
        return self.cache[name]


def sign(ctx, key, msg):
    rc, out, err = ctx.cosign(['sign', str(key)], msg)
    check(rc == 0 and len(out) == 129 and out.endswith(b'\n'), 'sign failed: exit %d %r' % (rc, err[:200]))
    return out.decode().strip(), err


def expect_verify(ctx, pub, sig, msg, code):
    rc, out, err = ctx.cosign(['verify', pub, sig], msg)
    want = {0: b'VALID\n', 1: b'INVALID\n', 2: b''}[code]
    check(rc == code and out == want, 'exit %d stdout %r stderr %r' % (rc, out, err[:200]))
    if code in (0, 1):
        check(err == b'', 'stderr not empty: %r' % err[:200])
    return 'exit %d %s' % (rc, (out or err[:90]).decode('latin1').strip())


C = {}


def ccase(fn):
    C[fn.__name__] = fn
    return fn


def signed(ctx):
    key, pub = ctx.keys.get('a')
    msg = message()
    sig, _ = sign(ctx, key, msg)
    return pub, sig, msg


@ccase
def keygen_creates_0600(ctx):
    p = ctx.path('new-key')
    rc, out, err = ctx.cosign(['keygen', str(p)])
    st = os.lstat(p)
    check(rc == 0 and err == b'' and len(out) == 65 and out[:64].decode() == out[:64].decode().lower(), 'exit %d' % rc)
    check(stat.S_ISREG(st.st_mode) and stat.S_IMODE(st.st_mode) == 0o600 and st.st_uid == os.geteuid(),
          'mode %o' % st.st_mode)
    check(p.read_bytes().startswith(b'-----BEGIN PRIVATE KEY-----\n'), 'not PKCS#8 PEM')
    return 'exit 0, regular file, mode 0600, PKCS#8 PEM'


@ccase
def keygen_refuses_existing(ctx):
    p = ctx.path('existing')
    p.write_bytes(b'keep')
    rc, out, err = ctx.cosign(['keygen', str(p)])
    check(rc == 2 and out == b'' and p.read_bytes() == b'keep', 'exit %d' % rc)
    return 'exit 2, file unchanged'


@ccase
def keygen_refuses_symlink_path(ctx):
    target = ctx.path('target')
    p = ctx.path('link')
    p.symlink_to(target)
    rc, out, err = ctx.cosign(['keygen', str(p)])
    check(rc == 2 and out == b'' and not target.exists(), 'exit %d target exists %s' % (rc, target.exists()))
    return 'exit 2, dangling link target not created'


@ccase
def sign_verify_valid(ctx):
    pub, sig, msg = signed(ctx)
    return expect_verify(ctx, pub, sig, msg, 0)


@ccase
def sign_stderr_shows_fields(ctx):
    key, _ = ctx.keys.get('a')
    _, err = sign(ctx, key, message())
    for part in (b'store-1', b'req-1', b'0123456789abcdef0123456789abcdef', b'REFUND order-9 7500 GOODWILL'):
        check(part in err, 'field missing on stderr: %r' % part)
    check(b'PRIVATE' not in err, 'key text on stderr')
    return 'store_id, request_id, pre_state_hash, action on stderr'


@ccase
def sign_is_deterministic(ctx):
    key, _ = ctx.keys.get('a')
    s1, _ = sign(ctx, key, message())
    s2, _ = sign(ctx, key, message())
    check(s1 == s2, 'two signatures differ')
    return 'same signature twice (Ed25519 is deterministic)'


@ccase
def verify_wrong_key(ctx):
    _, sig, msg = signed(ctx)
    _, pub_b = ctx.keys.get('b')
    return expect_verify(ctx, pub_b, sig, msg, 1)


@ccase
def verify_altered_request_id(ctx):
    pub, sig, _ = signed(ctx)
    return expect_verify(ctx, pub, sig, message(rid='req-2'), 1)


@ccase
def verify_altered_pre_state_hash(ctx):
    pub, sig, _ = signed(ctx)
    return expect_verify(ctx, pub, sig, message(h='0123456789abcdef0123456789abcdee'), 1)


@ccase
def verify_altered_action(ctx):
    pub, sig, _ = signed(ctx)
    return expect_verify(ctx, pub, sig, message(action='REFUND order-9 7501 GOODWILL'), 1)


@ccase
def verify_replay_other_store(ctx):
    pub, sig, _ = signed(ctx)
    return expect_verify(ctx, pub, sig, message(store='store-2'), 1)


@ccase
def verify_field_shift_refused_or_invalid(ctx):
    # Move bytes across a boundary: "req-1" + action prefix. The form check refuses a line end inside a field.
    pub, sig, _ = signed(ctx)
    return expect_verify(ctx, pub, sig, message(rid='req-1x', action='EFUND order-9 7500 GOODWILL'), 1)


@ccase
def verify_altered_signature_bit(ctx):
    pub, sig, msg = signed(ctx)
    bad = sig[:-1] + ('0' if sig[-1] != '0' else '1')
    return expect_verify(ctx, pub, bad, msg, 1)


def hex_case(name, pub_fn, sig_fn):
    def fn(ctx):
        pub, sig, msg = signed(ctx)
        return expect_verify(ctx, pub_fn(pub), sig_fn(sig), msg, 2)
    C[name] = fn


hex_case('verify_sig_truncated_126', lambda p: p, lambda s: s[:126])
hex_case('verify_sig_odd_127', lambda p: p, lambda s: s[:127])
hex_case('verify_sig_long_130', lambda p: p, lambda s: s + '00')
hex_case('verify_sig_uppercase', lambda p: p, lambda s: s.upper() if s.upper() != s else 'A' + s[1:])
hex_case('verify_sig_non_hex', lambda p: p, lambda s: 'g' + s[1:])
hex_case('verify_pub_truncated_62', lambda p: p[:62], lambda s: s)
hex_case('verify_pub_odd_63', lambda p: p[:63], lambda s: s)
hex_case('verify_pub_uppercase', lambda p: p.upper() if p.upper() != p else 'A' + p[1:], lambda s: s)
hex_case('verify_pub_with_0x', lambda p: '0x' + p[2:], lambda s: s)


@ccase
def verify_s_plus_l_malleability(ctx):
    # Ed25519 S' = S + L. This case records what node:crypto does; it expects "not VALID".
    pub, sig, msg = signed(ctx)
    s = int.from_bytes(bytes.fromhex(sig[64:]), 'little') + L
    if s >= 2 ** 256:
        raise NotRun('S + L does not fit in 32 bytes for this signature')
    bad = sig[:64] + s.to_bytes(32, 'little').hex()
    return expect_verify(ctx, pub, bad, msg, 1) + ' (node:crypto refuses S + L)'


def form_case(name, mutate):
    def fn(ctx):
        pub, sig, msg = signed(ctx)
        return expect_verify(ctx, pub, sig, mutate(msg), 2)
    C[name] = fn


form_case('verify_msg_no_final_lf', lambda m: m[:-1])
form_case('verify_msg_four_lines', lambda m: b'\n'.join(m.split(b'\n')[:4]) + b'\n')
form_case('verify_msg_six_lines', lambda m: m + b'extra\n')
form_case('verify_msg_cr', lambda m: m.replace(b'\n', b'\r\n', 1))
form_case('verify_msg_bad_prefix', lambda m: m.replace(b'cosign-v1', b'cosign-v2'))
form_case('verify_msg_upper_hash', lambda m: m.replace(b'abcdef', b'ABCDEF', 1))
form_case('verify_msg_long_request_id', lambda m: m.replace(b'req-1', b'r' * 25))
form_case('verify_msg_empty_action', lambda m: m[:m.rindex(b'\n', 0, len(m) - 1) + 1] + b'\n')
form_case('verify_msg_nul', lambda m: m.replace(b'GOODWILL', b'GOOD\x00WILL'))
form_case('verify_msg_oversize', lambda m: m[:-1] + b'x' * 4100 + b'\n')


@ccase
def sign_refuses_wrong_form(ctx):
    key, _ = ctx.keys.get('a')
    rc, out, err = ctx.cosign(['sign', str(key)], b'forge-airlock-cosign-v1\nstore-1\nreq-1\n')
    check(rc == 2 and out == b'', 'exit %d stdout %r' % (rc, out))
    return 'exit 2, no signature'


def key_copy(ctx, mode):
    src, _ = ctx.keys.get('a')
    p = ctx.path('key-mode-%o' % mode)
    p.write_bytes(src.read_bytes())
    os.chmod(p, mode)
    return p


def expect_sign_refused(ctx, path, reason, timeout=60):
    rc, out, err = ctx.cosign(['sign', str(path)], message(), timeout)
    check(rc == 2 and out == b'', 'exit %d stdout %r' % (rc, out))
    check(reason.encode() in err, 'reason %r not in stderr %r' % (reason, err[:200]))
    check(b'PRIVATE KEY' not in err, 'key text on stderr')
    return 'exit 2 (%s)' % reason


for _mode in (0o640, 0o604, 0o644, 0o660, 0o666, 0o610, 0o601, 0o620, 0o602):
    C['sign_key_mode_%04o' % _mode] = (lambda m: lambda ctx: expect_sign_refused(ctx, key_copy(ctx, m), 'group or other'))(_mode)


def sign_mode_ok(mode):
    def fn(ctx):
        p = key_copy(ctx, mode)
        _, pub = ctx.keys.get('a')
        sig, _ = sign(ctx, p, message())
        return expect_verify(ctx, pub, sig, message(), 0) + ' (mode %04o accepted)' % mode
    return fn


C['sign_key_mode_0600_ok'] = sign_mode_ok(0o600)
C['sign_key_mode_0400_ok'] = sign_mode_ok(0o400)


@ccase
def sign_key_symlink(ctx):
    src, _ = ctx.keys.get('a')
    p = ctx.path('key-link')
    p.symlink_to(src)
    return expect_sign_refused(ctx, p, 'ELOOP')


@ccase
def sign_key_dangling_symlink(ctx):
    p = ctx.path('key-dangling')
    p.symlink_to(ctx.path('nowhere'))
    return expect_sign_refused(ctx, p, 'ELOOP')


@ccase
def sign_key_directory(ctx):
    p = ctx.path('key-dir')
    p.mkdir(mode=0o700)
    return expect_sign_refused(ctx, p, 'not a regular file')


@ccase
def sign_key_fifo_no_hang(ctx):
    p = ctx.path('key-fifo')
    os.mkfifo(p, 0o600)
    t = time.monotonic()
    detail = expect_sign_refused(ctx, p, 'not a regular file', timeout=10)
    return detail + ' in %.2f s' % (time.monotonic() - t)


@ccase
def sign_key_dev_null(ctx):
    return expect_sign_refused(ctx, Path('/dev/null'), 'not a regular file')


@ccase
def sign_key_missing(ctx):
    return expect_sign_refused(ctx, ctx.path('absent'), 'ENOENT')


def key_bytes_case(name, data, reason):
    def fn(ctx):
        p = ctx.path(name)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.write(fd, data(ctx))
        os.close(fd)
        return expect_sign_refused(ctx, p, reason)
    C[name] = fn


key_bytes_case('sign_key_empty', lambda c: b'', 'size 0')
key_bytes_case('sign_key_damaged', lambda c: c.keys.get('a')[0].read_bytes()[:60] + b'!!\n', 'content refused')
key_bytes_case('sign_key_too_large', lambda c: b'A' * 5000, 'size 5000')


@ccase
def sign_key_public_pem(ctx):
    rc, out, err = run([ctx.node, '-e', "const c=require('node:crypto');process.stdout.write("
                        "c.generateKeyPairSync('ed25519').publicKey.export({format:'pem',type:'spki'}))"])
    check(rc == 0, 'node -e failed')
    p = ctx.path('key-public')
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, out)
    os.close(fd)
    return expect_sign_refused(ctx, p, 'content refused')


@ccase
def sign_key_not_ed25519(ctx):
    rc, out, err = run([ctx.node, '-e', "const c=require('node:crypto');process.stdout.write(c.generateKeyPairSync("
                        "'ec',{namedCurve:'P-256'}).privateKey.export({format:'pem',type:'pkcs8'}))"])
    check(rc == 0 and out.startswith(b'-----BEGIN PRIVATE KEY-----'), 'node -e failed')
    p = ctx.path('key-p256')
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, out)
    os.close(fd)
    return expect_sign_refused(ctx, p, 'content refused')


@ccase
def sign_other_uid_real_file(ctx):
    # A real regular file of another uid that this user can open (mode bits allow read). The uid rule is checked
    # before the mode rule, so the refusal names the uid.
    for cand in ('/etc/hosts', '/etc/shells', '/etc/protocols', '/etc/services'):
        try:
            st = os.stat(cand)
        except OSError:
            continue
        if stat.S_ISREG(st.st_mode) and st.st_uid != os.geteuid() and os.access(cand, os.R_OK) and \
                not os.path.islink(cand) and st.st_size <= 4096:
            return expect_sign_refused(ctx, Path(cand), 'is not the effective uid') + ' on ' + cand
    raise NotRun('no readable regular file of another uid with size <= 4096 found')


@ccase
def sign_other_uid_seam(ctx):
    # The exported D-1 check with a stat of uid euid+1 and mode 0600 (the combination a real file cannot give us).
    js = ("const {checkKeyStat}=require(process.argv[1]);const e=process.geteuid();"
          "const st={isFile:()=>true,uid:e+1,mode:0o100600,size:119};"
          "try{checkKeyStat(st,e);process.stdout.write('ACCEPTED')}catch(x){process.stdout.write('REFUSED '+x.message)}")
    rc, out, err = run([ctx.node, '-e', js, str(COSIGN)])
    check(rc == 0 and out.startswith(b'REFUSED') and b'effective uid' in out, 'out %r err %r' % (out, err[:200]))
    return 'SIMULATED stat: refused (%s)' % out.decode()[8:60]


@ccase
def sign_key_hardlink_accepted(ctx):
    src, pub = ctx.keys.get('a')
    p = ctx.path('key-hardlink')
    os.link(src, p)
    sig, _ = sign(ctx, p, message())
    return expect_verify(ctx, pub, sig, message(), 0) + ' (D-1 has no link-count rule; stated limit)'


@ccase
def cosign_bad_subcommand(ctx):
    rc, out, err = ctx.cosign(['sign-anything'])
    check(rc == 2 and out == b'', 'exit %d' % rc)
    return 'exit 2'


CASES = {**B, **C}


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
        ctx.keys = Keys(ctx)
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
