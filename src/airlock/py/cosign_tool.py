"""cosign_tool.py: the HUMAN's cosign tools of forge-airlock (Apex addendum: no Node). Python stdlib only.

Usage:
  python3 src/airlock/py/cosign_tool.py keygen <new-key-file>
      runs `/usr/bin/ssh-keygen -t ed25519 -N '' -q -C '' -f <private folder>/key`, checks that the new key is a
      regular 0600 file owned by the caller, moves it to <new-key-file> with link(2) (never overwrites; a symbolic
      link at that path is not followed), syncs it and its folder, and prints the token for `init --cosign-pubkey`:
      the base64 blob of the OpenSSH ssh-ed25519 public key (68 characters) + "\\n".
  python3 src/airlock/py/cosign_tool.py sign <key-file>        the message (from `cosign-message`) on stdin
      checks the key file (rules below), checks the message form, shows the six fields on stderr, runs
      `/usr/bin/ssh-keygen -Y sign -n forge-airlock-cosign -P "" -f <key-file>` with stdin a pipe, no terminal (a new
      session) and an empty environment (a key with a passphrase fails at once; it never prompts), checks the SSHSIG
      armor that ssh-keygen wrote, and prints the one-line token for the `REFUND` line: the base64 body of the armor
      without its line breaks (256 characters) + "\\n".
Exit 0 on success; 2 for every refusal (a message on stderr that starts with "cosign: ", nothing on stdout).

Label: NATIVE CHECK, not proved. Trusted: the system OpenSSH (/usr/bin/ssh-keygen with LibreSSL), the kernel's
O_NOFOLLOW, O_NONBLOCK, link(2) and fstat semantics, and this code.

Key file rules (owner decision D-1; proposals/night-shift-20261119/orch-B/h-key/KEY_DESIGN.md section 1), as in the
removed Node helper:
  1. open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK). A symbolic link as the last path part fails (ELOOP). A FIFO
     opens at once (no hang) and step 2 refuses it.
  2. fstat on the OPENED descriptor: regular file; st_uid == geteuid(); (st_mode & 0o077) == 0; size 1..4096.
  3. Read from the same descriptor only. The content must be an UNENCRYPTED OpenSSH private key (openssh-key-v1,
     cipher none, kdf none, one key) whose public key is ssh-ed25519.
  ssh-keygen then opens the file again BY PATH (it cannot take a descriptor). The tool binds that second open to the
  first: the public key inside the signature must be the public key read in step 3, or the signature is refused.
  D-1 has no link-count rule: a hard link to a checked key file is accepted. A symbolic link in a PARENT folder is
  followed (only the last path part is checked).

HONEST LIMIT: an agent that runs as the same OS user as the key owner can read a 0600 file. This tool cannot prevent
that. "The agent cannot self-cosign" holds only when the private key is outside the agent's reach (another OS user, a
hardware key, or a separate machine). Errors never print key bytes.
"""

import base64
import errno
import os
import re
import stat
import subprocess
import sys
import tempfile

SSH_KEYGEN = '/usr/bin/ssh-keygen'
NAMESPACE = b'forge-airlock-cosign'
PREFIX = 'forge-airlock-cosign-v3'
MAX_MESSAGE = 4096
MAX_KEY_FILE = 4096
KEY_TYPE = b'ssh-ed25519'
KEY_TOKEN_LEN, SIG_TOKEN_LEN = 68, 256
ID_RE = re.compile(r'[A-Za-z0-9_-]{1,24}\Z')
HASH_RE = re.compile(r'[0-9a-f]{32}\Z')
B64_RE = re.compile(r'[A-Za-z0-9+/]*={0,2}\Z')
ARMOR_HEAD, ARMOR_FOOT = '-----BEGIN SSH SIGNATURE-----', '-----END SSH SIGNATURE-----'
KEY_HEAD, KEY_FOOT = '-----BEGIN OPENSSH PRIVATE KEY-----', '-----END OPENSSH PRIVATE KEY-----'
TIMEOUT = 30


class Refused(Exception):
    pass


def b64(text):
    """Strict base64: canonical spelling only (the decode encodes back to the same text)."""
    if not isinstance(text, str) or len(text) % 4 or not B64_RE.match(text):
        raise Refused('not canonical base64')
    data = base64.b64decode(text, validate=True)
    if base64.b64encode(data).decode() != text:
        raise Refused('not canonical base64')
    return data


class Wire:
    def __init__(self, data):
        self.data = data

    def take(self, n):
        if len(self.data) < n:
            raise Refused('short SSH wire data')
        part, self.data = self.data[:n], self.data[n:]
        return part

    def string(self):
        return self.take(int.from_bytes(self.take(4), 'big'))


def key_blob_ed25519(blob):
    w = Wire(blob)
    if w.string() != KEY_TYPE:
        raise Refused('not an ssh-ed25519 key')
    key = w.string()
    if len(key) != 32 or w.data:
        raise Refused('not an ssh-ed25519 key blob')
    return blob


def check_sig_token(token):
    """The token of a REFUND line: the SSHSIG form the engine accepts (cosign.rs). Returns the embedded key blob."""
    if len(token) != SIG_TOKEN_LEN:
        raise Refused('the signature token is not %d characters' % SIG_TOKEN_LEN)
    w = Wire(b64(token))
    if w.take(6) != b'SSHSIG' or w.take(4) != b'\0\0\0\1':
        raise Refused('not an SSHSIG version 1 blob')
    key = key_blob_ed25519(w.string())
    if w.string() != NAMESPACE or w.string() != b'' or w.string() != b'sha512':
        raise Refused('namespace, reserved field or hash algorithm is not the expected one')
    sig = Wire(w.string())
    if sig.string() != KEY_TYPE or len(sig.string()) != 64 or sig.data or w.data:
        raise Refused('not one ssh-ed25519 signature of 64 bytes')
    return key


def parse_message(buf):
    """The six LF-terminated lines of PROTOCOL.md section 7. Returns the fields, or raises Refused."""
    if len(buf) > MAX_MESSAGE:
        raise Refused('message is larger than %d bytes' % MAX_MESSAGE)
    if any(b != 0x0a and not 0x20 <= b <= 0x7e for b in buf):
        raise Refused('message has a byte outside printable ASCII and LF')
    text = buf.decode('ascii')
    if not text.endswith('\n'):
        raise Refused('message does not end with LF')
    lines = text[:-1].split('\n')
    if len(lines) != 6:
        raise Refused('message has %d lines, expected 6' % len(lines))
    prefix, store_id, genesis, request_id, pre, action = lines
    if prefix != PREFIX:
        raise Refused('message prefix line is not ' + PREFIX)
    if not ID_RE.match(store_id):
        raise Refused('store_id is not [A-Za-z0-9_-]{1,24}')
    if not HASH_RE.match(genesis):
        raise Refused('genesis_hash is not 32 lowercase hex')
    if not ID_RE.match(request_id):
        raise Refused('request_id is not [A-Za-z0-9_-]{1,24}')
    if not HASH_RE.match(pre):
        raise Refused('pre_state_hash is not 32 lowercase hex')
    if not action or any(not 0x20 <= ord(c) <= 0x7e for c in action):
        raise Refused('action is empty or not printable ASCII')
    return {'store_id': store_id, 'genesis_hash': genesis, 'request_id': request_id, 'pre_state_hash': pre, 'action': action}


def check_key_stat(st, euid):
    """D-1 step 2 on a stat of the OPENED descriptor. Exported for the other-uid test only (no CLI path)."""
    if not stat.S_ISREG(st.st_mode):
        raise Refused('key file is not a regular file')
    if st.st_uid != euid:
        raise Refused('key file owner uid %d is not the effective uid %d' % (st.st_uid, euid))
    if st.st_mode & 0o077:
        raise Refused('key file mode %o has group or other bits' % (st.st_mode & 0o777))
    if not 1 <= st.st_size <= MAX_KEY_FILE:
        raise Refused('key file size %d is not in 1..%d' % (st.st_size, MAX_KEY_FILE))


def private_key_public_blob(data):
    """The public key blob of an UNENCRYPTED openssh-key-v1 file with one ssh-ed25519 key."""
    try:
        text = data.decode('ascii')
    except UnicodeDecodeError:
        raise Refused('key file content refused (not an OpenSSH private key)')
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    if len(lines) < 3 or lines[0] != KEY_HEAD or lines[-1] != KEY_FOOT:
        raise Refused('key file content refused (not an OpenSSH private key)')
    try:
        raw = base64.b64decode(''.join(lines[1:-1]), validate=True)
    except ValueError:
        raise Refused('key file content refused (damaged base64)')
    try:
        w = Wire(raw)
        if w.take(15) != b'openssh-key-v1\0':
            raise Refused('key file content refused (not openssh-key-v1)')
        cipher, kdf, _ = w.string(), w.string(), w.string()
        if cipher != b'none' or kdf != b'none':
            raise Refused('key file content refused (the key is encrypted: a key with a passphrase is not supported; it would prompt)')
        if w.take(4) != b'\0\0\0\1':
            raise Refused('key file content refused (not exactly one key)')
        return key_blob_ed25519(w.string())
    except Refused as e:
        if 'content refused' in str(e):
            raise
        raise Refused('key file content refused (not an Ed25519 key: %s)' % e)


def load_key(path):
    """D-1 steps 1 to 3. Returns the public key blob."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError as e:
        raise Refused('key file refused: %s' % errno.errorcode.get(e.errno, str(e.errno)))
    try:
        st = os.fstat(fd)
        check_key_stat(st, os.geteuid())
        data, got = b'', b'x'
        while len(data) < st.st_size and got:
            got = os.read(fd, st.st_size - len(data))
            data += got
        if len(data) != st.st_size:
            raise Refused('key file became shorter while read')
    finally:
        os.close(fd)
    return private_key_public_blob(data)


def ssh_keygen(argv, data, cwd=None):
    """ssh-keygen with an empty environment, no terminal (a new session), stdin a pipe, a time limit."""
    try:
        return subprocess.run([SSH_KEYGEN] + argv, input=data, capture_output=True, env={}, cwd=cwd, start_new_session=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        raise Refused('ssh-keygen did not end within %d s' % TIMEOUT)
    except OSError as e:
        raise Refused('%s cannot start: %s' % (SSH_KEYGEN, e.strerror))


def cmd_sign(args):
    if len(args) != 1:
        raise Refused('usage: cosign_tool.py sign <key-file>')
    blob = load_key(args[0])
    msg = sys.stdin.buffer.read(MAX_MESSAGE + 1)
    f = parse_message(msg)
    sys.stderr.write('cosign: you sign:\n  store_id       %(store_id)s\n  genesis_hash   %(genesis_hash)s\n  request_id     %(request_id)s\n'
                     '  pre_state_hash %(pre_state_hash)s\n  action         %(action)s\n' % f)
    sys.stderr.flush()
    p = ssh_keygen(['-Y', 'sign', '-n', NAMESPACE.decode(), '-P', '', '-f', os.path.abspath(args[0])], msg)
    if p.returncode != 0:
        why = p.stderr.decode('utf-8', 'replace').strip().splitlines()
        raise Refused('ssh-keygen -Y sign gave exit %d (%s)' % (p.returncode, (why[-1] if why else '')[:160]))
    lines = p.stdout.decode('ascii', 'replace').split('\n')
    if lines[-1:] == ['']:
        lines.pop()
    if len(lines) < 3 or lines[0] != ARMOR_HEAD or lines[-1] != ARMOR_FOOT or any(len(x) > 76 for x in lines[1:-1]):
        raise Refused('ssh-keygen wrote no SSHSIG armor')
    token = ''.join(lines[1:-1])
    if check_sig_token(token) != blob:
        raise Refused('the signature names another key than the checked key file (was the file replaced?)')
    sys.stdout.write(token + '\n')


def cmd_keygen(args):
    if len(args) != 1:
        raise Refused('usage: cosign_tool.py keygen <new-key-file>')
    target = os.path.abspath(args[0])
    folder = os.path.dirname(target)
    tmp = tempfile.mkdtemp(prefix='.cosign-keygen-', dir=folder)  # mode 0700, exclusive
    key = os.path.join(tmp, 'key')
    try:
        p = ssh_keygen(['-t', 'ed25519', '-N', '', '-q', '-C', '', '-f', key], b'')
        if p.returncode != 0:
            raise Refused('ssh-keygen -t ed25519 gave exit %d' % p.returncode)
        st = os.lstat(key)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.geteuid() or stat.S_IMODE(st.st_mode) != 0o600:
            raise Refused('the new key is not a regular 0600 file of the caller')
        with open(key + '.pub', 'rb') as f:
            fields = f.read(4096).decode('ascii').split()
        if len(fields) < 2 or fields[0] != 'ssh-ed25519' or len(fields[1]) != KEY_TOKEN_LEN:
            raise Refused('ssh-keygen wrote an unexpected public key line')
        key_blob_ed25519(b64(fields[1]))
        fd = os.open(key, os.O_RDONLY | os.O_NOFOLLOW)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
        try:
            os.link(key, target, follow_symlinks=False)  # exclusive: EEXIST for any existing path, also a symbolic link
        except FileExistsError:
            raise Refused('cannot create %r (it exists); keygen never overwrites' % args[0])
        dfd = os.open(folder, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
        sys.stdout.write(fields[1] + '\n')
    finally:
        for name in ('key', 'key.pub'):
            try:
                os.unlink(os.path.join(tmp, name))
            except FileNotFoundError:
                pass
        os.rmdir(tmp)


def main(argv):
    try:
        if len(argv) < 2 or argv[1] not in ('sign', 'keygen'):
            raise Refused('usage: cosign_tool.py sign <key-file> | keygen <new-key-file>')
        (cmd_sign if argv[1] == 'sign' else cmd_keygen)(argv[2:])
        sys.stdout.flush()
        return 0
    except Refused as e:
        sys.stderr.write('cosign: %s\n' % e)
        return 2
    except OSError as e:
        sys.stderr.write('cosign: %s\n' % e.strerror)
        return 2


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
