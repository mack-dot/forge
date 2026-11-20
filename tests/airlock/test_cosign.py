"""FINITE TEST of the forge-airlock cosign tools without Node (Apex addendum): src/airlock/py/cosign_tool.py (the
human's keygen and sign) and the strict base64 decoder of the engine (src/airlock/cosign.rs, through the engine's
`base64-decode` test-vector subcommand). The engine's verification of a REFUND signature is tested in
tests/airlock/test_engine.py (cases cosign, cosign_faults, nonce, weakkey, seams, helper_env).

Usage: python3 tests/airlock/test_cosign.py <engine> [--case NAME]... [--list]

One line per case: PASS, FAIL or NOT RUN. Exit 0 only if every selected case passes; a NOT RUN case fails the suite.
Python stdlib only. Private keys exist only in a temporary folder made by this run and removed at its end. Every case
runs the real tool (and the real /usr/bin/ssh-keygen) as a subprocess, except `sign_other_uid_seam`, which calls the
exported check function with a stat object whose uid differs (a real 0600 file of another uid cannot be opened).
A token that the tool prints is checked here with the test's own call of `ssh-keygen -Y verify` (a transcription of
the engine's call; both can be wrong in the same way).

Case to D-1 rule map (KEY_DESIGN.md section 1; the same rules as the removed Node helper):
  O_NOFOLLOW (last part)   sign_key_symlink, sign_key_dangling_symlink, keygen_refuses_symlink_path
  O_NONBLOCK + S_ISREG     sign_key_fifo_no_hang, sign_key_directory, sign_key_dev_null
  uid == euid              sign_other_uid_real_file, sign_other_uid_seam
  (mode & 0o077) == 0      sign_key_mode_<mode> for 0640 0604 0644 0660 0666 0610 0601 0620 0602; 0600 and 0400 pass
  size and content         sign_key_missing, sign_key_empty, sign_key_damaged, sign_key_too_large,
                           sign_key_public_line, sign_key_not_ed25519, sign_key_passphrase_fails_fast
  same descriptor read     not separately testable from outside (a reading of the code); no case claims it
  no link-count rule       sign_key_hardlink_accepted (D-1 states a hard link passes)
"""
import base64, os, random, stat, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'src/airlock/py/cosign_tool.py'
SSH_KEYGEN = '/usr/bin/ssh-keygen'
ENV = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'}
ALLOW_NOT_RUN = {}  # name -> reason. Empty: every NOT RUN fails the suite.
L = 2 ** 252 + 27742317777372353535851937790883648493  # Ed25519 group order


class NotRun(Exception):
    pass


def run(argv, data=b'', timeout=60, cwd=None):
    p = subprocess.run([str(a) for a in argv], input=data, capture_output=True, timeout=timeout, cwd=cwd or ROOT, env=ENV)
    return p.returncode, p.stdout, p.stderr


def check(cond, detail):
    if not cond:
        raise AssertionError(detail)


def message(store='store-1', rid='req-1', h='0123456789abcdef0123456789abcdef', action='REFUND t1 order-9 req-1 0123456789abcdef0123456789abcdef GOODWILL 7500',
            genesis='fedcba9876543210fedcba9876543210', prefix='forge-airlock-cosign-v3'):
    return ('%s\n%s\n%s\n%s\n%s\n%s\n' % (prefix, store, genesis, rid, h, action)).encode()


class Ctx:
    def __init__(self, engine, tmp):
        self.engine, self.tmp, self.n, self.cache = engine, tmp, 0, {}

    def path(self, name):
        self.n += 1
        return self.tmp / ('%03d-%s' % (self.n, name))

    def tool(self, args, data=b'', timeout=60):
        return run([sys.executable, '-I', TOOL] + list(args), data, timeout)

    def key(self, name):
        if name not in self.cache:
            p = self.tmp / ('key-' + name)
            rc, out, err = self.tool(['keygen', p])
            check(rc == 0 and len(out) == 69 and err == b'', 'keygen failed: exit %d %r' % (rc, err))
            self.cache[name] = (p, out.decode().strip())
        return self.cache[name]


def ssh_verify(ctx, pub, token, msg, ns='forge-airlock-cosign'):
    """The test's own `ssh-keygen -Y verify` of a token (armor rebuilt with 70-character lines)."""
    d = Path(tempfile.mkdtemp(dir=ctx.tmp))
    (d / 'allowed_signers').write_text('forge-airlock-cosigner namespaces="%s" ssh-ed25519 %s\n' % (ns, pub))
    (d / 'signature').write_text('-----BEGIN SSH SIGNATURE-----\n%s\n-----END SSH SIGNATURE-----\n' % '\n'.join(token[i:i + 70] for i in range(0, len(token), 70)))
    rc, out, err = run([SSH_KEYGEN, '-Y', 'verify', '-f', 'allowed_signers', '-I', 'forge-airlock-cosigner', '-n', ns, '-s', 'signature'], msg, cwd=d)
    return rc, out, err


def sign(ctx, key, msg):
    rc, out, err = ctx.tool(['sign', key], msg)
    check(rc == 0 and len(out) == 257 and out.endswith(b'\n'), 'sign failed: exit %d %r' % (rc, err[:300]))
    return out.decode().strip(), err


def expect_valid(ctx, pub, token, msg):
    rc, out, err = ssh_verify(ctx, pub, token, msg)
    check(rc == 0 and out.startswith(b'Good "forge-airlock-cosign" signature for forge-airlock-cosigner'), 'ssh-keygen -Y verify: exit %d %r %r' % (rc, out, err))
    return 'token verifies with ssh-keygen -Y verify (exit 0)'


C = {}


def case(fn):
    C[fn.__name__] = fn
    return fn


@case
def keygen_creates_0600(ctx):
    p = ctx.path('new-key')
    rc, out, err = ctx.tool(['keygen', p])
    st = os.lstat(p)
    check(rc == 0 and err == b'' and len(out) == 69, 'exit %d %r' % (rc, err))
    check(stat.S_ISREG(st.st_mode) and stat.S_IMODE(st.st_mode) == 0o600 and st.st_uid == os.geteuid(), 'mode %o' % st.st_mode)
    check(p.read_bytes().startswith(b'-----BEGIN OPENSSH PRIVATE KEY-----\n'), 'not an OpenSSH private key')
    blob = base64.b64decode(out.strip(), validate=True)
    check(blob[:15] == b'\0\0\0\x0bssh-ed25519' and len(blob) == 51, 'not an ssh-ed25519 key blob')
    check(sorted(x.name for x in p.parent.iterdir() if x.name.startswith('.cosign-keygen-')) == [], 'a temporary folder stayed')
    return 'exit 0, regular file, mode 0600, OpenSSH key; token = 68 characters of base64 (ssh-ed25519, 32 bytes); no temporary folder left'


@case
def keygen_refuses_existing(ctx):
    p = ctx.path('existing')
    p.write_bytes(b'keep')
    rc, out, err = ctx.tool(['keygen', p])
    check(rc == 2 and out == b'' and p.read_bytes() == b'keep', 'exit %d' % rc)
    return 'exit 2, file unchanged'


@case
def keygen_refuses_existing_0600(ctx):
    # An owner-only file: only the exclusive link(2) keeps it unchanged.
    p = ctx.path('existing-0600')
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, b'keep')
    os.close(fd)
    rc, out, err = ctx.tool(['keygen', p])
    check(rc == 2 and out == b'' and p.read_bytes() == b'keep', 'an existing 0600 file: exit %d, file now %r' % (rc, p.read_bytes()[:16]))
    return 'exit 2, file unchanged'


@case
def keygen_refuses_symlink_path(ctx):
    target = ctx.path('target')
    p = ctx.path('link')
    p.symlink_to(target)
    rc, out, err = ctx.tool(['keygen', p])
    check(rc == 2 and out == b'' and not target.exists(), 'exit %d target exists %s' % (rc, target.exists()))
    return 'exit 2, dangling link target not created'


@case
def sign_verify_valid(ctx):
    key, pub = ctx.key('a')
    token, _ = sign(ctx, key, message())
    return expect_valid(ctx, pub, token, message())


@case
def sign_token_form(ctx):
    key, pub = ctx.key('a')
    token, _ = sign(ctx, key, message())
    blob = base64.b64decode(token, validate=True)
    check(len(token) == 256 and token.endswith('==') and base64.b64encode(blob).decode() == token, 'token form %r' % token[-8:])
    check(blob[:10] == b'SSHSIG\0\0\0\1' and b'forge-airlock-cosign' in blob and b'\0\0\0\x06sha512' in blob, 'SSHSIG fields')
    check(base64.b64decode(pub)[-32:] in blob, 'the embedded key is not the key of the file')
    return 'one line, 256 characters, canonical base64 of SSHSIG v1, namespace forge-airlock-cosign, sha512, the key of the file'


@case
def sign_stderr_shows_fields(ctx):
    key, _ = ctx.key('a')
    _, err = sign(ctx, key, message())
    for part in (b'store-1', b'req-1', b'0123456789abcdef0123456789abcdef', b'genesis_hash   fedcba9876543210fedcba9876543210', b'GOODWILL 7500'):
        check(part in err, 'field missing on stderr: %r' % part)
    check(b'PRIVATE' not in err, 'key text on stderr')
    return 'store_id, genesis_hash, request_id, pre_state_hash, action on stderr; no key text'


@case
def sign_is_deterministic(ctx):
    key, _ = ctx.key('a')
    s1, _ = sign(ctx, key, message())
    s2, _ = sign(ctx, key, message())
    check(s1 == s2, 'two signatures differ')
    return 'same token twice (Ed25519 is deterministic)'


@case
def verify_other_message_invalid(ctx):
    key, pub = ctx.key('a')
    token, _ = sign(ctx, key, message())
    for other in (message(rid='req-2'), message(genesis='fedcba9876543210fedcba9876543211'), message(store='store-2')):
        rc, out, _ = ssh_verify(ctx, pub, token, other)
        check(rc == 255 and out == b'Could not verify signature.\n', 'another message verified: exit %d %r' % (rc, out))
    return '3 changed messages: ssh-keygen exit 255 "Could not verify signature."'


def form_case(name, mutate):
    def fn(ctx):
        key, _ = ctx.key('a')
        rc, out, err = ctx.tool(['sign', key], mutate(message()))
        check(rc == 2 and out == b'' and err.startswith(b'cosign: '), 'exit %d stdout %r' % (rc, out[:60]))
        return 'exit 2 (%s)' % err.decode().strip()[8:70]
    C[name] = fn


form_case('sign_refuses_wrong_form', lambda m: b'forge-airlock-cosign-v3\nstore-1\nreq-1\n')
form_case('sign_msg_no_final_lf', lambda m: m[:-1])
form_case('sign_msg_seven_lines', lambda m: m + b'extra\n')
form_case('sign_msg_cr', lambda m: m.replace(b'\n', b'\r\n', 1))
form_case('sign_msg_old_v2_prefix', lambda m: m.replace(b'cosign-v3', b'cosign-v2'))
form_case('sign_msg_upper_genesis', lambda m: m.replace(b'fedcba', b'FEDCBA', 1))
form_case('sign_msg_long_request_id', lambda m: m.replace(b'req-1\n', b'r' * 25 + b'\n'))
form_case('sign_msg_empty_action', lambda m: m[:m.rindex(b'\n', 0, len(m) - 1) + 1] + b'\n')
form_case('sign_msg_nul', lambda m: m.replace(b'GOODWILL', b'GOOD\x00WILL'))
form_case('sign_msg_oversize', lambda m: m[:-1] + b'x' * 4100 + b'\n')


def key_copy(ctx, mode):
    src, _ = ctx.key('a')
    p = ctx.path('key-mode-%o' % mode)
    p.write_bytes(src.read_bytes())
    os.chmod(p, mode)
    return p


def expect_sign_refused(ctx, path, reason, timeout=60):
    rc, out, err = ctx.tool(['sign', path], message(), timeout)
    check(rc == 2 and out == b'', 'exit %d stdout %r' % (rc, out[:60]))
    check(reason.encode() in err, 'reason %r not in stderr %r' % (reason, err[:200]))
    check(b'PRIVATE KEY' not in err, 'key text on stderr')
    return 'exit 2 (%s)' % reason


for _mode in (0o640, 0o604, 0o644, 0o660, 0o666, 0o610, 0o601, 0o620, 0o602):
    C['sign_key_mode_%04o' % _mode] = (lambda m: lambda ctx: expect_sign_refused(ctx, key_copy(ctx, m), 'group or other'))(_mode)


def sign_mode_ok(mode):
    def fn(ctx):
        p = key_copy(ctx, mode)
        _, pub = ctx.key('a')
        token, _ = sign(ctx, p, message())
        return expect_valid(ctx, pub, token, message()) + ' (mode %04o accepted)' % mode
    return fn


C['sign_key_mode_0600_ok'] = sign_mode_ok(0o600)
C['sign_key_mode_0400_ok'] = sign_mode_ok(0o400)


@case
def sign_key_symlink(ctx):
    src, _ = ctx.key('a')
    p = ctx.path('key-link')
    p.symlink_to(src)
    return expect_sign_refused(ctx, p, 'ELOOP')


@case
def sign_key_dangling_symlink(ctx):
    p = ctx.path('key-dangling')
    p.symlink_to(ctx.path('nowhere'))
    return expect_sign_refused(ctx, p, 'ELOOP')


@case
def sign_key_directory(ctx):
    p = ctx.path('key-dir')
    p.mkdir(mode=0o700)
    return expect_sign_refused(ctx, p, 'not a regular file')


@case
def sign_key_fifo_no_hang(ctx):
    p = ctx.path('key-fifo')
    os.mkfifo(p, 0o600)
    t = time.monotonic()
    detail = expect_sign_refused(ctx, p, 'not a regular file', timeout=10)
    return detail + ' in %.2f s' % (time.monotonic() - t)


@case
def sign_key_dev_null(ctx):
    return expect_sign_refused(ctx, Path('/dev/null'), 'not a regular file')


@case
def sign_key_missing(ctx):
    return expect_sign_refused(ctx, ctx.path('absent'), 'ENOENT')


def write_0600(ctx, name, data):
    p = ctx.path(name)
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, data)
    os.close(fd)
    return p


def key_bytes_case(name, data, reason):
    C[name] = lambda ctx: expect_sign_refused(ctx, write_0600(ctx, name, data(ctx)), reason)


key_bytes_case('sign_key_empty', lambda c: b'', 'size 0')
key_bytes_case('sign_key_damaged', lambda c: c.key('a')[0].read_bytes()[:60] + b'!!\n', 'content refused')
key_bytes_case('sign_key_too_large', lambda c: b'A' * 5000, 'size 5000')
key_bytes_case('sign_key_public_line', lambda c: ('ssh-ed25519 %s\n' % c.key('a')[1]).encode(), 'content refused')


def other_key(ctx, name, argv):
    d = Path(tempfile.mkdtemp(dir=ctx.tmp))
    rc, _, err = run([SSH_KEYGEN] + argv + ['-q', '-C', '', '-f', d / 'k'], timeout=120)
    check(rc == 0, 'ssh-keygen %r failed: %r' % (argv, err))
    return write_0600(ctx, name, (d / 'k').read_bytes())


@case
def sign_key_not_ed25519(ctx):
    return expect_sign_refused(ctx, other_key(ctx, 'key-p256', ['-t', 'ecdsa', '-b', '256', '-N', '']), 'not an Ed25519 key')


@case
def sign_key_passphrase_fails_fast(ctx):
    p = other_key(ctx, 'key-pass', ['-t', 'ed25519', '-N', 'a passphrase'])
    t = time.monotonic()
    detail = expect_sign_refused(ctx, p, 'encrypted', timeout=10)
    return detail + ' in %.2f s; no prompt' % (time.monotonic() - t)


@case
def sign_other_uid_real_file(ctx):
    # A real regular file of another uid that this user can open. The uid rule comes before the mode rule.
    for cand in ('/etc/hosts', '/etc/shells', '/etc/protocols', '/etc/services'):
        try:
            st = os.stat(cand)
        except OSError:
            continue
        if stat.S_ISREG(st.st_mode) and st.st_uid != os.geteuid() and os.access(cand, os.R_OK) and not os.path.islink(cand) and st.st_size <= 4096:
            return expect_sign_refused(ctx, Path(cand), 'is not the effective uid') + ' on ' + cand
    raise NotRun('no readable regular file of another uid with size <= 4096 found')


@case
def sign_other_uid_seam(ctx):
    # The exported D-1 check with a stat of uid euid+1 and mode 0600 (the combination a real file cannot give us).
    code = ("import sys, stat, types; sys.path.insert(0, sys.argv[1]); import cosign_tool as t; e = 1000\n"
            "st = types.SimpleNamespace(st_mode=stat.S_IFREG | 0o600, st_uid=e + 1, st_size=400)\n"
            "try:\n    t.check_key_stat(st, e); print('ACCEPTED')\nexcept t.Refused as x:\n    print('REFUSED ' + str(x))\n")
    rc, out, err = run([sys.executable, '-I', '-c', code, TOOL.parent])
    check(rc == 0 and out.startswith(b'REFUSED') and b'effective uid' in out, 'out %r err %r' % (out, err[:200]))
    return 'SIMULATED stat: refused (%s)' % out.decode().strip()[8:60]


@case
def sign_key_hardlink_accepted(ctx):
    src, pub = ctx.key('a')
    p = ctx.path('key-hardlink')
    os.link(src, p)
    token, _ = sign(ctx, p, message())
    return expect_valid(ctx, pub, token, message()) + ' (D-1 has no link-count rule; stated limit)'


@case
def tool_bad_subcommand(ctx):
    rc, out, err = ctx.tool(['verify'])
    check(rc == 2 and out == b'', 'exit %d' % rc)
    return 'exit 2 (the tool has no verify: only the engine verifies)'


# ---------------------------------------------------------------- the engine's strict base64 decoder
def engine_b64(ctx, token):
    rc, out, _ = run([ctx.engine, 'base64-decode', token])
    text = out.decode().strip()
    if rc == 0 and text.startswith('BASE64'):
        return bytes.fromhex(text[7:]) if len(text) > 6 else b''
    check(rc == 12 and text == 'MALFORMED_REQUEST BAD_BASE64', 'base64-decode %r: exit %d %r' % (token, rc, text))
    return None


def python_strict(token):
    """Python's reference: b64decode(validate=True) AND the canonical spelling (encode gives the same text)."""
    try:
        data = base64.b64decode(token, validate=True)
    except ValueError:
        return None
    return data if base64.b64encode(data).decode() == token else None


@case
def base64_vectors(ctx):
    vectors = ['', 'Zg==', 'Zm8=', 'Zm9v', 'Zm9vYg==', 'Zm9vYmE=', 'Zm9vYmFy',  # RFC 4648 section 10
               'Zh==', 'Zm9=', 'Zg=', 'Zg', 'Zg===', '=Zg=', 'Z=g=', 'Zm9v\n', ' Zm9v', 'Zm9v ', 'Zm-v', 'Zm_v', 'Zm9v====', '====', 'A===', 'AA==AA==',
               '////', '+++/', 'AAAA', 'AA==', 'AAA=', 'AB==', 'AAB=']
    want = {'': b'', 'Zg==': b'f', 'Zm8=': b'fo', 'Zm9v': b'foo', 'Zm9vYg==': b'foob', 'Zm9vYmE=': b'fooba', 'Zm9vYmFy': b'foobar'}
    for v in vectors:
        got, ref = engine_b64(ctx, v), python_strict(v)
        check(got == ref, 'vector %r: engine %r, Python %r' % (v, got, ref))
        if v in want:
            check(got == want[v], 'RFC 4648 vector %r: %r' % (v, got))
    rng = random.Random(20)
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    n = 0
    for i in range(300):
        data = bytes(rng.randrange(256) for _ in range(rng.randrange(0, 70)))
        good = base64.b64encode(data).decode()
        bad = list(good)
        if bad:
            j = rng.randrange(len(bad))
            bad[j] = rng.choice(alphabet + '=-_ .')
        for v in (good, ''.join(bad)):
            got, ref = engine_b64(ctx, v), python_strict(v)
            check(got == ref, 'random vector %r: engine %r, Python %r' % (v, got, ref))
            n += 1
    return '%d fixed (7 of RFC 4648) and %d random vectors: the engine agrees with Python b64decode(validate=True) + canonical spelling' % (len(vectors), n)


CASES = dict(C)


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[5])
        return 2
    names, i = [], 2
    while i < len(argv):
        if argv[i] == '--case' and i + 1 < len(argv):
            names.append(argv[i + 1]); i += 2
        elif argv[i] == '--list':
            print('\n'.join(CASES)); return 0
        else:
            print('unknown argument: ' + argv[i]); return 2
    engine = str(Path(argv[1]).resolve())
    unknown = [n for n in names if n not in CASES]
    if unknown:
        print('unknown case: ' + ', '.join(unknown)); return 2
    rc, out, err = run(['/usr/bin/ssh', '-V'])
    print('ssh-keygen %s (%s)' % (SSH_KEYGEN, err.decode().strip()))
    print('allowed NOT RUN: ' + (', '.join('%s (%s)' % kv for kv in ALLOW_NOT_RUN.items()) or 'none'))
    counts = {'PASS': 0, 'FAIL': 0, 'NOT RUN': 0}
    bad = False
    with tempfile.TemporaryDirectory(prefix='airlock-cosign-') as tmp:
        ctx = Ctx(engine, Path(tmp))
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
    print('total %d: %d PASS, %d FAIL, %d NOT RUN' % (sum(counts.values()), counts['PASS'], counts['FAIL'], counts['NOT RUN']))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
